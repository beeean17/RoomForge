import { BRIDGE_VERSION, type BridgeMessage } from './bridge'

type CvMat = {
  rows: number
  cols: number
  data: Uint8Array
  data32S: Int32Array
  delete(): void
}

type CvRuntime = {
  Mat: new () => CvMat
  Size: new (width: number, height: number) => unknown
  matFromImageData(imageData: ImageData): CvMat
  cvtColor(src: CvMat, dst: CvMat, code: number): void
  GaussianBlur(src: CvMat, dst: CvMat, ksize: unknown, sigmaX: number, sigmaY: number, borderType: number): void
  Canny(src: CvMat, dst: CvMat, threshold1: number, threshold2: number, apertureSize: number, l2gradient: boolean): void
  HoughLinesP(
    image: CvMat,
    lines: CvMat,
    rho: number,
    theta: number,
    threshold: number,
    minLineLength: number,
    maxLineGap: number,
  ): void
  COLOR_RGBA2GRAY: number
  BORDER_DEFAULT: number
  getBuildInformation?: () => string
  onRuntimeInitialized?: () => void
}

type SourceImagePayload = {
  dataUrl?: string
  sourceImageId?: string
  widthPx?: number
  heightPx?: number
  contentType?: string
}

type PointPayload = {
  x: number
  y: number
}

type LinePayload = {
  x1: number
  y1: number
  x2: number
  y2: number
  lengthPx: number
  angleDegrees: number
}

type ProgressReporter = (stage: string, progress: number, label: string, detail?: string) => void

const algorithmId = 'opencv-js-canny-hough-v1'
const maxProcessDimension = 960

let cvRuntimePromise: Promise<CvRuntime> | null = null
let openCvVersion = 'opencv-js'
let activeRequestId: string | undefined
let activeWorkerStage = 'idle'

self.addEventListener('error', (event: ErrorEvent) => {
  postWorkerFailure('opencv_worker_error', workerErrorEventMessage(event))
  event.preventDefault()
})

self.addEventListener('unhandledrejection', (event: PromiseRejectionEvent) => {
  postWorkerFailure('opencv_worker_unhandled_rejection', errorMessage(event.reason))
  event.preventDefault()
})

self.onmessage = (event: MessageEvent<BridgeMessage>) => {
  const message = event.data
  if (message.version !== BRIDGE_VERSION) {
    return
  }

  activeRequestId = message.requestId

  if (message.type === 'roomforge.opencv.loadRuntime') {
    activeWorkerStage = 'runtime_loading'
    void loadRuntime(message)
    return
  }

  if (message.type === 'roomforge.opencv.extractCandidates') {
    activeWorkerStage = 'extracting_candidates'
    void extractCandidates(message)
  }
}

async function loadRuntime(message: BridgeMessage): Promise<void> {
  try {
    postProgress(
      message.requestId,
      'runtime_loading',
      18,
      'OpenCV runtime loading',
      'Importing OpenCV.js inside the browser worker.',
    )
    const cv = await cvRuntime()
    const buildInfo = cv.getBuildInformation?.() ?? ''
    openCvVersion = versionFromBuildInfo(buildInfo)
    postProgress(
      message.requestId,
      'runtime_ready',
      35,
      'OpenCV runtime ready',
      'OpenCV.js image-processing APIs are ready.',
    )
    postBridge({
      type: 'roomforge.opencv.runtimeLoaded',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: {
        mode: 'opencv-js-browser-worker',
        algorithm: algorithmId,
        openCvVersion,
        buildInfoSummary: buildInfo.split('\n').slice(0, 4).join('\n'),
      },
    })
  } catch (error) {
    postBridge({
      type: 'roomforge.opencv.runtimeFailed',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: failurePayload('opencv_runtime_failed', errorMessage(error)),
    })
  }
}

async function extractCandidates(message: BridgeMessage): Promise<void> {
  const sourceImage = sourceImagePayload(message.payload.sourceImage)
  const reportProgress: ProgressReporter = (stage, progress, label, detail) => {
    postProgress(message.requestId, stage, progress, label, detail)
  }
  if (!sourceImage.dataUrl) {
    reportProgress(
      'source_image_missing',
      100,
      'Source image missing',
      'Source image bytes were not provided to the OpenCV worker.',
    )
    postBridge({
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: {
        ...failurePayload(
          'no_source_image',
          'Source image bytes were not provided to the OpenCV worker.',
        ),
        sourceImageId: sourceImage.sourceImageId,
        candidateGeometry: emptyCandidateGeometry(sourceImage),
      },
    })
    return
  }

  try {
    reportProgress(
      'source_image_received',
      40,
      'Source image received',
      'Source image payload reached the OpenCV worker.',
    )
    const cv = await cvRuntime()
    reportProgress(
      'image_decoding',
      48,
      'Decoding source image',
      'Creating an ImageBitmap and processing canvas.',
    )
    const decoded = await decodeSourceImage(sourceImage)
    reportProgress(
      'image_decoded',
      56,
      'Source image decoded',
      `${decoded.processedWidth} x ${decoded.processedHeight} pixels will be processed.`,
    )
    const result = detectRoomBoundary(cv, decoded.imageData, {
      sourceImage,
      originalWidth: decoded.originalWidth,
      originalHeight: decoded.originalHeight,
      processedWidth: decoded.processedWidth,
      processedHeight: decoded.processedHeight,
    }, reportProgress)
    reportProgress(
      'candidate_extraction_complete',
      98,
      'Candidate extraction complete',
      'OpenCV candidate geometry payload is ready.',
    )

    postBridge({
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: result,
    })
  } catch (error) {
    postBridge({
      type: 'roomforge.opencv.candidatesExtracted',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: {
        ...failurePayload('opencv_extract_failed', errorMessage(error)),
        sourceImageId: sourceImage.sourceImageId,
        candidateGeometry: emptyCandidateGeometry(sourceImage),
      },
    })
  }
}

async function cvRuntime(): Promise<CvRuntime> {
  cvRuntimePromise ??= import('@techstark/opencv-js')
    .then((module) => module as unknown as { default?: unknown } & Record<string, unknown>)
    .then((module) => module.default ?? module)
    .then((value) => Promise.resolve(value))
    .then(waitForRuntime)
  return cvRuntimePromise
}

async function waitForRuntime(value: unknown): Promise<CvRuntime> {
  const cv = value as Partial<CvRuntime>
  if (typeof cv.Mat === 'function' && typeof cv.Canny === 'function') {
    return cv as CvRuntime
  }
  await new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(
      () => reject(new Error('OpenCV runtime initialization timed out.')),
      5000,
    )
    cv.onRuntimeInitialized = () => {
      clearTimeout(timeout)
      resolve()
    }
  })
  if (typeof cv.Mat !== 'function' || typeof cv.Canny !== 'function') {
    throw new Error('OpenCV runtime did not expose required image-processing APIs.')
  }
  return cv as CvRuntime
}

async function decodeSourceImage(sourceImage: SourceImagePayload): Promise<{
  imageData: ImageData
  originalWidth: number
  originalHeight: number
  processedWidth: number
  processedHeight: number
}> {
  if (typeof OffscreenCanvas === 'undefined') {
    throw new Error('OffscreenCanvas is unavailable in this browser worker.')
  }
  if (typeof createImageBitmap === 'undefined') {
    throw new Error('createImageBitmap is unavailable in this browser worker.')
  }

  const response = await fetch(sourceImage.dataUrl ?? '')
  const blob = await response.blob()
  const bitmap = await createImageBitmap(blob)
  try {
    const originalWidth = sourceImage.widthPx && sourceImage.widthPx > 0 ? sourceImage.widthPx : bitmap.width
    const originalHeight = sourceImage.heightPx && sourceImage.heightPx > 0 ? sourceImage.heightPx : bitmap.height
    const scale = Math.min(1, maxProcessDimension / Math.max(bitmap.width, bitmap.height))
    const processedWidth = Math.max(1, Math.round(bitmap.width * scale))
    const processedHeight = Math.max(1, Math.round(bitmap.height * scale))
    const canvas = new OffscreenCanvas(processedWidth, processedHeight)
    const context = canvas.getContext('2d', { willReadFrequently: true })
    if (!context) {
      throw new Error('Could not create a 2D canvas context for OpenCV processing.')
    }
    context.drawImage(bitmap, 0, 0, processedWidth, processedHeight)
    return {
      imageData: context.getImageData(0, 0, processedWidth, processedHeight),
      originalWidth,
      originalHeight,
      processedWidth,
      processedHeight,
    }
  } finally {
    bitmap.close()
  }
}

function detectRoomBoundary(
  cv: CvRuntime,
  imageData: ImageData,
  metadata: {
    sourceImage: SourceImagePayload
    originalWidth: number
    originalHeight: number
    processedWidth: number
    processedHeight: number
  },
  reportProgress?: ProgressReporter,
): Record<string, unknown> {
  const src = cv.matFromImageData(imageData)
  const gray = new cv.Mat()
  const blurred = new cv.Mat()
  const edges = new cv.Mat()
  const lines = new cv.Mat()

  try {
    reportProgress?.(
      'preprocessing',
      62,
      'Preprocessing image',
      'Converting the source image to grayscale and smoothing noise.',
    )
    cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY)
    cv.GaussianBlur(gray, blurred, new cv.Size(5, 5), 0, 0, cv.BORDER_DEFAULT)
    reportProgress?.(
      'edge_detection',
      70,
      'Detecting edges',
      'Running Canny edge detection on the preprocessed image.',
    )
    cv.Canny(blurred, edges, 60, 160, 3, false)

    const minLineLength = Math.max(30, Math.min(metadata.processedWidth, metadata.processedHeight) * 0.16)
    const maxLineGap = Math.max(8, Math.min(metadata.processedWidth, metadata.processedHeight) * 0.035)
    reportProgress?.(
      'line_detection',
      78,
      'Detecting wall-like lines',
      'Running probabilistic Hough line detection.',
    )
    cv.HoughLinesP(edges, lines, 1, Math.PI / 180, 42, minLineLength, maxLineGap)

    reportProgress?.(
      'geometry_building',
      88,
      'Building candidate geometry',
      'Sampling edges and assembling boundary candidates.',
    )
    const scaleX = metadata.originalWidth / metadata.processedWidth
    const scaleY = metadata.originalHeight / metadata.processedHeight
    const candidateLines = linePayloads(lines, scaleX, scaleY)
    const edgeStats = scanEdges(edges, scaleX, scaleY)
    const candidateEdges = sampledEdgePoints(edges, scaleX, scaleY)
    const boundaryPoints = boundaryFromStats(edgeStats, metadata.originalWidth, metadata.originalHeight)
    const confidence = confidenceScore({
      edgeDensity: edgeStats.edgeDensity,
      lineCount: candidateLines.length,
      hasBoundary: boundaryPoints.length >= 4,
    })
    reportProgress?.(
      'quality_scoring',
      94,
      'Scoring candidate quality',
      'Calculating confidence and review status.',
    )
    const qualityStatus = qualityStatusFor(confidence, boundaryPoints.length, candidateLines.length)
    const reasonCode = reasonCodeFor(qualityStatus, edgeStats.edgeDensity, candidateLines.length, boundaryPoints.length)
    const reasonMessage = reasonMessageFor(reasonCode)
    const candidateGeometry = {
      image: {
        widthPx: metadata.originalWidth,
        heightPx: metadata.originalHeight,
        processedWidthPx: metadata.processedWidth,
        processedHeightPx: metadata.processedHeight,
      },
      candidateEdges,
      candidateLines,
      candidateCorners: boundaryPoints,
      boundaryHints: boundaryPoints.length >= 4
        ? [
            {
              id: 'boundary-1',
              kind: 'room_boundary',
              coordinateSpace: 'image_pixels',
              confidence,
              points: boundaryPoints,
            },
          ]
        : [],
      candidateSets: boundaryPoints.length >= 4
        ? [
            {
              id: 'candidate-1',
              kind: 'room_boundary',
              coordinateSpace: 'image_pixels',
              confidence,
              points: boundaryPoints,
            },
          ]
        : [],
      overlayStyle: {
        candidate: 'dashed-low-opacity-purple',
        confirmed: 'solid-blue-with-handles',
      },
    }

    return {
      sourceImageId: metadata.sourceImage.sourceImageId,
      coordinateSpace: 'image_pixels',
      confidence,
      qualityStatus,
      reasonCode,
      reasonMessage,
      algorithm: algorithmId,
      openCvVersion,
      candidateGeometry,
    }
  } finally {
    src.delete()
    gray.delete()
    blurred.delete()
    edges.delete()
    lines.delete()
  }
}

function linePayloads(lines: CvMat, scaleX: number, scaleY: number): LinePayload[] {
  const values = lines.data32S
  const result: LinePayload[] = []
  for (let row = 0; row < lines.rows; row += 1) {
    const offset = row * 4
    const x1 = values[offset] * scaleX
    const y1 = values[offset + 1] * scaleY
    const x2 = values[offset + 2] * scaleX
    const y2 = values[offset + 3] * scaleY
    const lengthPx = Math.hypot(x2 - x1, y2 - y1)
    if (lengthPx < 24) {
      continue
    }
    result.push({
      x1: roundPx(x1),
      y1: roundPx(y1),
      x2: roundPx(x2),
      y2: roundPx(y2),
      lengthPx: roundPx(lengthPx),
      angleDegrees: Number((Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI).toFixed(2)),
    })
  }
  return result.sort((left, right) => right.lengthPx - left.lengthPx).slice(0, 48)
}

function scanEdges(edges: CvMat, scaleX: number, scaleY: number): {
  edgeDensity: number
  minX: number
  minY: number
  maxX: number
  maxY: number
} {
  let edgeCount = 0
  let minX = Number.POSITIVE_INFINITY
  let minY = Number.POSITIVE_INFINITY
  let maxX = 0
  let maxY = 0
  for (let y = 0; y < edges.rows; y += 1) {
    const rowOffset = y * edges.cols
    for (let x = 0; x < edges.cols; x += 1) {
      if (edges.data[rowOffset + x] === 0) {
        continue
      }
      edgeCount += 1
      minX = Math.min(minX, x * scaleX)
      minY = Math.min(minY, y * scaleY)
      maxX = Math.max(maxX, x * scaleX)
      maxY = Math.max(maxY, y * scaleY)
    }
  }
  return {
    edgeDensity: edgeCount / Math.max(edges.rows * edges.cols, 1),
    minX,
    minY,
    maxX,
    maxY,
  }
}

function sampledEdgePoints(edges: CvMat, scaleX: number, scaleY: number): PointPayload[] {
  const result: PointPayload[] = []
  const stride = Math.max(1, Math.ceil(Math.sqrt((edges.rows * edges.cols) / 520)))
  for (let y = 0; y < edges.rows; y += stride) {
    const rowOffset = y * edges.cols
    for (let x = 0; x < edges.cols; x += stride) {
      if (edges.data[rowOffset + x] === 0) {
        continue
      }
      result.push({ x: roundPx(x * scaleX), y: roundPx(y * scaleY) })
      if (result.length >= 520) {
        return result
      }
    }
  }
  return result
}

function boundaryFromStats(
  stats: { minX: number; minY: number; maxX: number; maxY: number },
  width: number,
  height: number,
): PointPayload[] {
  if (!Number.isFinite(stats.minX) || !Number.isFinite(stats.minY)) {
    return []
  }
  const insetX = width * 0.015
  const insetY = height * 0.015
  const minX = clamp(stats.minX - insetX, 0, width)
  const minY = clamp(stats.minY - insetY, 0, height)
  const maxX = clamp(stats.maxX + insetX, 0, width)
  const maxY = clamp(stats.maxY + insetY, 0, height)
  if (maxX - minX < width * 0.12 || maxY - minY < height * 0.12) {
    return []
  }
  return [
    { x: roundPx(minX), y: roundPx(minY) },
    { x: roundPx(maxX), y: roundPx(minY) },
    { x: roundPx(maxX), y: roundPx(maxY) },
    { x: roundPx(minX), y: roundPx(maxY) },
  ]
}

function confidenceScore(input: {
  edgeDensity: number
  lineCount: number
  hasBoundary: boolean
}): number {
  const edgeComponent = clamp(input.edgeDensity / 0.08, 0, 1) * 0.34
  const lineComponent = clamp(input.lineCount / 14, 0, 1) * 0.46
  const boundaryComponent = input.hasBoundary ? 0.2 : 0
  return Number(clamp(edgeComponent + lineComponent + boundaryComponent, 0, 0.96).toFixed(2))
}

function qualityStatusFor(confidence: number, cornerCount: number, lineCount: number): string {
  if (cornerCount < 4 || lineCount < 2 || confidence < 0.18) {
    return 'failed'
  }
  return confidence >= 0.68 ? 'success' : 'review_required'
}

function reasonCodeFor(
  qualityStatus: string,
  edgeDensity: number,
  lineCount: number,
  cornerCount: number,
): string | null {
  if (qualityStatus === 'success') {
    return null
  }
  if (edgeDensity < 0.002) {
    return 'weak_edges'
  }
  if (lineCount < 2) {
    return 'insufficient_lines'
  }
  if (cornerCount < 4) {
    return 'insufficient_corners'
  }
  return 'low_confidence'
}

function reasonMessageFor(reasonCode: string | null): string | null {
  if (reasonCode === null) {
    return null
  }
  const messages: Record<string, string> = {
    weak_edges: 'OpenCV found too little edge evidence in the source image.',
    insufficient_lines: 'OpenCV found edges, but not enough long wall-like line segments.',
    insufficient_corners: 'OpenCV could not form a complete room boundary candidate.',
    low_confidence: 'Candidate geometry should be reviewed before save or export.',
  }
  return messages[reasonCode] ?? 'OpenCV candidate extraction needs review.'
}

function sourceImagePayload(value: unknown): SourceImagePayload {
  if (typeof value !== 'object' || value === null) {
    return {}
  }
  const record = value as Record<string, unknown>
  return {
    dataUrl: stringValue(record.dataUrl),
    sourceImageId: stringValue(record.sourceImageId),
    widthPx: numberValue(record.widthPx),
    heightPx: numberValue(record.heightPx),
    contentType: stringValue(record.contentType),
  }
}

function emptyCandidateGeometry(sourceImage: SourceImagePayload): Record<string, unknown> {
  return {
    image: {
      widthPx: sourceImage.widthPx,
      heightPx: sourceImage.heightPx,
    },
    candidateEdges: [],
    candidateLines: [],
    candidateCorners: [],
    boundaryHints: [],
    candidateSets: [],
    overlayStyle: {
      candidate: 'dashed-low-opacity-purple',
      confirmed: 'solid-blue-with-handles',
    },
  }
}

function failurePayload(reasonCode: string, reasonMessage: string): Record<string, unknown> {
  return {
    coordinateSpace: 'image_pixels',
    confidence: 0,
    qualityStatus: 'failed',
    reasonCode,
    reasonMessage,
    algorithm: algorithmId,
    openCvVersion,
  }
}

function postProgress(
  requestId: string | undefined,
  stage: string,
  progress: number,
  label: string,
  detail?: string,
): void {
  activeWorkerStage = stage
  postBridge({
    type: 'roomforge.opencv.progress',
    version: BRIDGE_VERSION,
    requestId,
    payload: {
      stage,
      progress: clamp(progress, 0, 100),
      label,
      detail,
      algorithm: algorithmId,
      openCvVersion,
    },
  })
}

function postWorkerFailure(reasonCode: string, reasonMessage: string): void {
  try {
    postBridge({
      type: 'roomforge.opencv.workerFailed',
      version: BRIDGE_VERSION,
      requestId: activeRequestId,
      payload: {
        ...failurePayload(reasonCode, reasonMessage),
        stage: activeWorkerStage,
      },
    })
  } catch {
    // The worker may already be terminating; the host still receives Worker.onerror.
  }
}

function versionFromBuildInfo(buildInfo: string): string {
  const line = buildInfo
    .split('\n')
    .map((item) => item.trim())
    .find((item) => item.toLowerCase().startsWith('general configuration for opencv'))
  return line?.replace(/^General configuration for\s+/i, '').replace(/=+$/, '').trim() || 'opencv-js'
}

function postBridge(message: BridgeMessage): void {
  self.postMessage(message)
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function roundPx(value: number): number {
  return Number(value.toFixed(2))
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}

function workerErrorEventMessage(event: ErrorEvent): string {
  const location = event.filename
    ? ` (${event.filename}:${event.lineno}:${event.colno})`
    : ''
  return `${event.message || 'Unhandled OpenCV worker error.'}${location}`
}

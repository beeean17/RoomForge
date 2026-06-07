import { BRIDGE_VERSION, type BridgeMessage, type BridgePayload } from './bridge.ts'
import {
  captureSessionFromBridgePayload,
  type CaptureImageReference,
  type CaptureSessionForSceneUnderstanding,
} from './captureSession.ts'
import { mergeSceneCandidates } from './sceneCandidateMerge.ts'
import { computeSceneCoverage, sceneCoveragePayload } from './sceneCoverage.ts'
import { applyMetricPlacementToCandidates } from './scenePlacement.ts'
import {
  furnitureSizePriorForCategory,
  structuralFixtureSizePriorForCategory,
} from './sizePriors.ts'
import {
  spatialModelFromBridgePayload,
  type CandidateSceneObject,
  type SpatialModel,
  type StructuralFixtureObject,
} from './spatialModel.ts'

const providerType = 'browser_cv_mock'
const algorithmId = 'mock-scene-understanding-v1'
const modelId = 'rule-based-mock-provider'
const defaultDetectorScoreThreshold = 0.45

export type DetectorRuntimeConfig = {
  webgpuAvailable?: boolean
  modelAssetsPresent?: boolean
  modelAssetPath?: string
  forceUnsupported?: boolean
  scoreThreshold?: number
}

export type DetectorRuntime = {
  providerType: string
  runtime: 'webgpu' | 'wasm' | 'mock'
  modelId: string
  supported: boolean
  scoreThreshold: number
  failureReasonCode?: string
  failureReason?: string
}

type SourceImageForDetection = {
  dataUrl?: string
  sourceImageId?: string
  widthPx?: number
  heightPx?: number
  contentType?: string
}

export type DetectorOutput = {
  className: string
  score: number
  box: { x: number; y: number; width: number; height: number }
  captureImageId?: string
  sourceImageId?: string
  sourceImageRole?: string
}

export function sceneUnderstandingResponseMessage(
  payload: BridgePayload,
  requestId?: string,
): BridgeMessage {
  const session = captureSessionFromBridgePayload(payload)
  if (!session || session.images.length === 0) {
    const runtime = defaultRuntime()
    return {
      type: 'roomforge.sceneUnderstanding.candidatesFailed',
      version: BRIDGE_VERSION,
      requestId,
      payload: {
        error: {
          code: 'no_capture_images',
          message: 'Capture images are required before scene understanding can run.',
        },
        sceneUnderstandingResult: emptyResult(
          session,
          runtime,
          'no_capture_images',
          'Capture images are required before scene understanding can run.',
        ),
      },
    }
  }

  const runtime = detectorRuntimeFromPayload(payload)
  if (!runtime.supported) {
    const failureReasonCode = runtime.failureReasonCode ?? 'unsupported_runtime'
    const failureReason =
      runtime.failureReason ?? 'No supported browser detector runtime is available.'
    return {
      type: 'roomforge.sceneUnderstanding.candidatesFailed',
      version: BRIDGE_VERSION,
      requestId,
      payload: {
        error: {
          code: failureReasonCode,
          message: failureReason,
        },
        sceneUnderstandingResult: emptyResult(session, runtime, failureReasonCode, failureReason),
      },
    }
  }

  return {
    type: 'roomforge.sceneUnderstanding.candidatesExtracted',
    version: BRIDGE_VERSION,
    requestId,
    payload: {
      sceneUnderstandingResult: detectorResult(
        session,
        detectorOutputsFromPayload(payload, session),
        runtime,
        spatialModelForPlacement(payload),
      ),
    },
  }
}

const workerScope = typeof self === 'undefined' ? null : self

if (workerScope) {
  workerScope.onmessage = (event: MessageEvent<BridgeMessage>) => {
    const message = event.data
    if (message.version !== BRIDGE_VERSION) {
      return
    }
    if (message.type !== 'roomforge.sceneUnderstanding.extractCandidates') {
      return
    }
    workerScope.postMessage(sceneUnderstandingResponseMessage(message.payload, message.requestId))
  }
}

export function detectorRuntimeFromPayload(payload: BridgePayload): DetectorRuntime {
  const config = recordValue(payload.detectorRuntime)
  const scoreThreshold = normalizedScoreThreshold(config.scoreThreshold)
  if (config.forceUnsupported === true) {
    return {
      providerType,
      runtime: 'mock',
      modelId,
      supported: false,
      scoreThreshold,
      failureReasonCode: 'unsupported_runtime',
      failureReason: 'Detector runtime was forced unsupported by configuration.',
    }
  }
  const modelAssetsPresent =
    config.modelAssetsPresent === true || stringValue(config.modelAssetPath).length > 0
  const webgpuAvailable =
    booleanValue(config.webgpuAvailable) ??
    (typeof navigator !== 'undefined' && 'gpu' in navigator)
  const sourceImage = sourceImageFromPayload(payload)

  if (webgpuAvailable && modelAssetsPresent) {
    return {
      providerType: 'browser_cv_webgpu_mock',
      runtime: 'webgpu',
      modelId: 'roomforge-detector-webgpu-mock',
      supported: true,
      scoreThreshold,
    }
  }
  if (modelAssetsPresent) {
    return {
      providerType: 'browser_cv_wasm_mock',
      runtime: 'wasm',
      modelId: 'roomforge-detector-wasm-mock',
      supported: true,
      scoreThreshold,
    }
  }
  if (sourceImage.dataUrl) {
    return {
      providerType: 'browser_cv',
      runtime: 'mock',
      modelId: 'roomforge-image-proposal-v1',
      supported: true,
      scoreThreshold,
    }
  }
  return defaultRuntime(scoreThreshold)
}

export function detectorResult(
  session: CaptureSessionForSceneUnderstanding,
  detections: DetectorOutput[],
  runtime: DetectorRuntime,
  model: SpatialModel = spatialModelFromBridgePayload({}),
): Record<string, unknown> {
  const primaryImage = session.images[0]
  const fixtureImage =
    session.images.find((image) => image.role.includes('wall')) ?? primaryImage
  const mapped = detections
    .filter((detection) => detection.score >= runtime.scoreThreshold)
    .map((detection, index) =>
      detectionToCandidate(detection, imageForDetection(session, detection), index),
    )
  const candidateObjects = mapped
    .filter((item) => item.kind === 'candidate')
    .map((item) => item.value)
  const structuralFixtureCandidateObjects = candidateObjects.filter(
    (candidate) => candidate.objectType === 'structural_fixture',
  )
  const structuralFixtures = mapped
    .filter((item) => item.kind === 'fixture')
    .map((item) => item.value)
  const fallbackWindowPrior = structuralFixtureSizePriorForCategory('window')
  const placedCandidateModel = applyMetricPlacementToCandidates({
    model: {
      ...model,
      candidateObjects: candidateObjects as CandidateSceneObject[],
    },
    images: session.images,
  })
  const mergedCandidateObjects = mergeSceneCandidates(placedCandidateModel.candidateObjects)
  const coverage = computeSceneCoverage({
    availableRoles: session.availableRoles,
    images: session.images,
    candidateObjects: mergedCandidateObjects,
    structuralFixtures: structuralFixtures as StructuralFixtureObject[],
  })

  return {
    resultId: `scene-understanding-${Date.now()}`,
    captureSessionId: session.captureSessionId,
    providerType: runtime.providerType,
    algorithmId: runtime.modelId === 'roomforge-image-proposal-v1'
      ? 'image-proposal-scene-understanding-v1'
      : algorithmId,
    modelId: runtime.modelId,
    runtime: runtime.runtime,
    detectorScoreThreshold: runtime.scoreThreshold,
    confidenceScore: 0.68,
    qualityStatus: 'review_required',
    coverage: sceneCoveragePayload(coverage),
    candidateObjects: mergedCandidateObjects,
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures:
      structuralFixtures.length > 0
        ? structuralFixtures
        : structuralFixtureCandidateObjects.length > 0
          ? []
          : [
              {
                fixtureId: `fixture-${fixtureImage.captureImageId}-window`,
                candidateId: `candidate-${fixtureImage.captureImageId}-window`,
                category: 'window',
                wallId: 'front-wall',
                label: `Detected ${fallbackWindowPrior.category}`,
                position: { x: 1.8, y: 1.1, z: 0 },
                size: fallbackWindowPrior.size,
                rotationDegrees: 0,
                confidenceScore: 0.64,
                locked: false,
              },
            ],
  }
}

function spatialModelForPlacement(payload: BridgePayload): SpatialModel {
  const spatialModel = recordValue(payload.spatialModel)
  return Object.keys(spatialModel).length > 0
    ? spatialModelFromBridgePayload({ scene: spatialModel })
    : spatialModelFromBridgePayload(payload)
}

function emptyResult(
  session: CaptureSessionForSceneUnderstanding | null,
  runtime: DetectorRuntime = defaultRuntime(),
  failureReasonCode = 'no_capture_images',
  failureReason = 'Capture images are required before scene understanding can run.',
): Record<string, unknown> {
  return {
    resultId: `scene-understanding-failed-${Date.now()}`,
    captureSessionId: session?.captureSessionId,
    providerType: runtime.providerType,
    algorithmId,
    modelId: runtime.modelId,
    runtime: runtime.runtime,
    confidenceScore: 0,
    qualityStatus: 'failed',
    failureReasonCode,
    failureReason,
    coverage: { imageCount: 0, availableRoles: [] },
    candidateObjects: [],
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures: [],
  }
}

function detectorOutputsFromPayload(
  payload: BridgePayload,
  session: CaptureSessionForSceneUnderstanding,
): DetectorOutput[] {
  const configured = listValue(payload.detectorOutput)
    .map(detectorOutputValue)
    .filter((item): item is DetectorOutput => item !== null)
  if (configured.length > 0) {
    return configured
  }

  const sourceImage = sourceImageFromPayload(payload)
  if (sourceImage.dataUrl) {
    return imageDrivenDetectorOutputs(sourceImage, session)
  }

  const image = session.images[0]
  return [
    {
      className: 'chair',
      score: 0.66,
      box: {
        x: Math.round((image.widthPx ?? 1600) * 0.42),
        y: Math.round((image.heightPx ?? 900) * 0.48),
        width: Math.round((image.widthPx ?? 1600) * 0.18),
        height: Math.round((image.heightPx ?? 900) * 0.28),
      },
    },
  ]
}

function imageDrivenDetectorOutputs(
  sourceImage: SourceImageForDetection,
  session: CaptureSessionForSceneUnderstanding,
): DetectorOutput[] {
  const image = imageForSourceImage(session, sourceImage)
  const widthPx = sourceImage.widthPx ?? image.widthPx ?? 1600
  const heightPx = sourceImage.heightPx ?? image.heightPx ?? 900
  const signature = sourceImageSignature(sourceImage.dataUrl ?? '')
  const furnitureClasses = ['bed', 'sofa', 'desk', 'chair', 'wardrobe', 'table']
  const furnitureClass = furnitureClasses[signature % furnitureClasses.length]
  const secondClass = furnitureClasses[(signature + 3) % furnitureClasses.length]
  const primaryWidth = Math.round(widthPx * (0.2 + ((signature % 4) * 0.035)))
  const primaryHeight = Math.round(heightPx * (0.24 + ((signature % 5) * 0.025)))
  const primaryX = Math.round(widthPx * (0.12 + ((signature % 7) * 0.045)))
  const primaryY = Math.round(heightPx * (0.46 + ((signature % 3) * 0.04)))
  const outputs: DetectorOutput[] = [
    {
      className: furnitureClass,
      score: 0.58 + ((signature % 11) / 100),
      captureImageId: image.captureImageId,
      sourceImageId: sourceImage.sourceImageId ?? image.sourceImageId,
      sourceImageRole: image.role,
      box: clampBox({
        x: primaryX,
        y: primaryY,
        width: primaryWidth,
        height: primaryHeight,
      }, widthPx, heightPx),
    },
  ]

  if (signature % 2 === 0) {
    outputs.push({
      className: secondClass,
      score: 0.5 + ((signature % 13) / 100),
      captureImageId: image.captureImageId,
      sourceImageId: sourceImage.sourceImageId ?? image.sourceImageId,
      sourceImageRole: image.role,
      box: clampBox({
        x: Math.round(widthPx * 0.58),
        y: Math.round(heightPx * 0.5),
        width: Math.round(widthPx * 0.16),
        height: Math.round(heightPx * 0.22),
      }, widthPx, heightPx),
    })
  }

  if (image.role.includes('wall') || signature % 3 === 0) {
    outputs.push({
      className: signature % 5 === 0 ? 'door' : 'window',
      score: 0.56 + ((signature % 9) / 100),
      captureImageId: image.captureImageId,
      sourceImageId: sourceImage.sourceImageId ?? image.sourceImageId,
      sourceImageRole: image.role,
      box: clampBox({
        x: Math.round(widthPx * 0.62),
        y: Math.round(heightPx * 0.18),
        width: Math.round(widthPx * 0.2),
        height: Math.round(heightPx * 0.22),
      }, widthPx, heightPx),
    })
  }

  return outputs
}

function sourceImageFromPayload(payload: BridgePayload): SourceImageForDetection {
  const direct = recordValue(payload.sourceImage)
  const scene = recordValue(payload.scene)
  const fromScene = recordValue(scene.sourceImage)
  const sourceImage = Object.keys(direct).length > 0 ? direct : fromScene
  return {
    dataUrl: optionalStringValue(sourceImage.dataUrl),
    sourceImageId: optionalStringValue(sourceImage.sourceImageId),
    widthPx: positiveNumberValue(sourceImage.widthPx),
    heightPx: positiveNumberValue(sourceImage.heightPx),
    contentType: optionalStringValue(sourceImage.contentType),
  }
}

function imageForSourceImage(
  session: CaptureSessionForSceneUnderstanding,
  sourceImage: SourceImageForDetection,
): CaptureImageReference {
  return (
    session.images.find((image) => image.sourceImageId === sourceImage.sourceImageId) ??
    session.images[0]
  )
}

function sourceImageSignature(dataUrl: string): number {
  let hash = dataUrl.length
  const stride = Math.max(1, Math.floor(dataUrl.length / 96))
  for (let index = 0; index < dataUrl.length; index += stride) {
    hash = ((hash << 5) - hash + dataUrl.charCodeAt(index)) >>> 0
  }
  return hash
}

function clampBox(
  box: { x: number; y: number; width: number; height: number },
  widthPx: number,
  heightPx: number,
): { x: number; y: number; width: number; height: number } {
  const x = clampNumber(box.x, 0, Math.max(0, widthPx - 2))
  const y = clampNumber(box.y, 0, Math.max(0, heightPx - 2))
  return {
    x,
    y,
    width: clampNumber(box.width, 2, Math.max(2, widthPx - x)),
    height: clampNumber(box.height, 2, Math.max(2, heightPx - y)),
  }
}

function detectorOutputValue(value: unknown): DetectorOutput | null {
  const record = recordValue(value)
  const box = recordValue(record.box ?? record.boundingBox)
  const className =
    stringValue(record.className) || stringValue(record.class) || stringValue(record.category)
  const score = numberValue(record.score ?? record.confidenceScore)
  const x = numberValue(box.x)
  const y = numberValue(box.y)
  const width = numberValue(box.width)
  const height = numberValue(box.height)
  if (
    !className ||
    score === undefined ||
    x === undefined ||
    y === undefined ||
    width === undefined ||
    height === undefined
  ) {
    return null
  }
  return {
    className,
    score,
    box: { x, y, width, height },
    captureImageId: optionalStringValue(record.captureImageId),
    sourceImageId: optionalStringValue(record.sourceImageId),
    sourceImageRole: optionalStringValue(record.sourceImageRole ?? record.imageRole),
  }
}

function detectionToCandidate(
  detection: DetectorOutput,
  image: CaptureImageReference,
  index: number,
):
  | { kind: 'candidate'; value: Record<string, unknown> }
  | { kind: 'fixture'; value: Record<string, unknown> } {
  const category = categoryForClass(detection.className)
  if (category === 'window' || category === 'door') {
    const prior = structuralFixtureSizePriorForCategory(category)
    return {
      kind: 'candidate',
      value: {
        candidateId: `candidate-${image.captureImageId}-${category}-${index}`,
        objectType: 'structural_fixture',
        category,
        label: `Detected ${prior.category}`,
        sourceImageId: image.sourceImageId,
        captureImageId: image.captureImageId,
        sourceImageRole: image.role,
        coordinateSpace: 'image_pixels',
        boundingBox: detection.box,
        confidenceScore: detection.score,
        reviewState: detection.score < 0.7 ? 'review_required' : 'new',
        reviewLabel: detection.score < 0.7 ? 'Needs review' : 'Candidate',
        suggestedAssetId: prior.assetId,
        suggestedPosition: { x: 1 + index * 0.4, y: 0, z: 0 },
        suggestedWallId: wallIdForImageRole(image.role),
        suggestedSize: prior.size,
        suggestedRotationDegrees: rotationForWallId(wallIdForImageRole(image.role)),
      },
    }
  }
  const prior = furnitureSizePriorForCategory(category)
  return {
    kind: 'candidate',
    value: {
      candidateId: `candidate-${image.captureImageId}-${category}-${index}`,
      objectType: 'furniture',
      category: prior.category,
      label: `Detected ${prior.category}`,
      sourceImageId: image.sourceImageId,
      captureImageId: image.captureImageId,
      sourceImageRole: image.role,
      coordinateSpace: 'image_pixels',
      boundingBox: detection.box,
      confidenceScore: detection.score,
      reviewState: detection.score < 0.7 ? 'review_required' : 'new',
      reviewLabel: detection.score < 0.7 ? 'Needs review' : 'Candidate',
      suggestedAssetId: prior.assetId,
      suggestedPosition: { x: 1.2 + index * 0.3, y: 0, z: 1.4 },
      suggestedSize: prior.suggestedSize,
      suggestedRotationDegrees: 0,
    },
  }
}

function categoryForClass(className: string): string {
  const normalized = className.toLowerCase().replaceAll(' ', '_')
  const mapping: Record<string, string> = {
    chair: 'chair',
    couch: 'sofa',
    sofa: 'sofa',
    bed: 'bed',
    dining_table: 'table',
    table: 'table',
    desk: 'desk',
    wardrobe: 'wardrobe',
    closet: 'wardrobe',
    cabinet: 'cabinet',
    shelf: 'shelf',
    bookshelf: 'shelf',
    window: 'window',
    door: 'door',
  }
  return mapping[normalized] ?? 'custom'
}

function wallIdForImageRole(role: string): string {
  if (role === 'right_wall') return 'right-wall'
  if (role === 'back_wall') return 'back-wall'
  if (role === 'left_wall') return 'left-wall'
  return 'front-wall'
}

function rotationForWallId(wallId: string): number {
  if (wallId === 'right-wall') return 90
  if (wallId === 'back-wall') return 180
  if (wallId === 'left-wall') return 270
  return 0
}

function imageForDetection(
  session: CaptureSessionForSceneUnderstanding,
  detection: DetectorOutput,
): CaptureImageReference {
  return (
    session.images.find(
      (image) =>
        image.captureImageId === detection.captureImageId ||
        image.sourceImageId === detection.sourceImageId ||
        image.role === detection.sourceImageRole,
    ) ?? session.images[0]
  )
}

function defaultRuntime(scoreThreshold = defaultDetectorScoreThreshold): DetectorRuntime {
  return {
    providerType,
    runtime: 'mock',
    modelId,
    supported: true,
    scoreThreshold,
  }
}

function normalizedScoreThreshold(value: unknown): number {
  const threshold = numberValue(value)
  if (threshold === undefined || threshold < 0 || threshold > 1) {
    return defaultDetectorScoreThreshold
  }
  return threshold
}

function recordValue(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
}

function listValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : []
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

function optionalStringValue(value: unknown): string | undefined {
  const parsed = stringValue(value)
  return parsed.length > 0 ? parsed : undefined
}

function booleanValue(value: unknown): boolean | undefined {
  return typeof value === 'boolean' ? value : undefined
}

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function positiveNumberValue(value: unknown): number | undefined {
  const parsed = numberValue(value)
  return parsed !== undefined && parsed > 0 ? parsed : undefined
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value))
}

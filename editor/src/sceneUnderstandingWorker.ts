import { BRIDGE_VERSION, type BridgeMessage, type BridgePayload } from './bridge.ts'
import {
  captureSessionFromBridgePayload,
  type CaptureImageReference,
  type CaptureSessionForSceneUnderstanding,
} from './captureSession.ts'
import { mergeSceneCandidates } from './sceneCandidateMerge.ts'
import { applyMetricPlacementToCandidates } from './scenePlacement.ts'
import {
  furnitureSizePriorForCategory,
  structuralFixtureSizePriorForCategory,
} from './sizePriors.ts'
import {
  spatialModelFromBridgePayload,
  type CandidateSceneObject,
  type SpatialModel,
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

  return {
    resultId: `scene-understanding-${Date.now()}`,
    captureSessionId: session.captureSessionId,
    providerType: runtime.providerType,
    algorithmId,
    modelId: runtime.modelId,
    runtime: runtime.runtime,
    detectorScoreThreshold: runtime.scoreThreshold,
    confidenceScore: 0.68,
    qualityStatus: 'review_required',
    coverage: {
      imageCount: session.images.length,
      availableRoles: session.availableRoles,
    },
    candidateObjects: mergedCandidateObjects,
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures: structuralFixtures.length > 0 ? structuralFixtures : [
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
        locked: true,
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
      kind: 'fixture',
      value: {
        fixtureId: `fixture-${image.captureImageId}-${category}-${index}`,
        candidateId: `candidate-${image.captureImageId}-${category}-${index}`,
        category,
        sourceImageId: image.sourceImageId,
        captureImageId: image.captureImageId,
        sourceImageRole: image.role,
        coordinateSpace: 'image_pixels',
        boundingBox: detection.box,
        wallId: 'front-wall',
        label: `Detected ${prior.category}`,
        position: { x: 1 + index * 0.4, y: category === 'door' ? 1 : 1.1, z: 0 },
        size: prior.size,
        rotationDegrees: 0,
        confidenceScore: detection.score,
        locked: true,
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
    window: 'window',
    door: 'door',
  }
  return mapping[normalized] ?? 'custom'
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

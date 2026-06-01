import { BRIDGE_VERSION, type BridgeMessage, type BridgePayload } from './bridge.ts'
import {
  captureSessionFromBridgePayload,
  type CaptureSessionForSceneUnderstanding,
} from './captureSession.ts'

const providerType = 'browser_cv_mock'
const algorithmId = 'mock-scene-understanding-v1'
const modelId = 'rule-based-mock-provider'

export function sceneUnderstandingResponseMessage(
  payload: BridgePayload,
  requestId?: string,
): BridgeMessage {
  const session = captureSessionFromBridgePayload(payload)
  if (!session || session.images.length === 0) {
    return {
      type: 'roomforge.sceneUnderstanding.candidatesFailed',
      version: BRIDGE_VERSION,
      requestId,
      payload: {
        error: {
          code: 'no_capture_images',
          message: 'Capture images are required before scene understanding can run.',
        },
        sceneUnderstandingResult: emptyResult(session),
      },
    }
  }

  return {
    type: 'roomforge.sceneUnderstanding.candidatesExtracted',
    version: BRIDGE_VERSION,
    requestId,
    payload: {
      sceneUnderstandingResult: mockResult(session),
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

function mockResult(session: CaptureSessionForSceneUnderstanding): Record<string, unknown> {
  const primaryImage = session.images[0]
  const fixtureImage =
    session.images.find((image) => image.role.includes('wall')) ?? primaryImage
  return {
    resultId: `scene-understanding-${Date.now()}`,
    captureSessionId: session.captureSessionId,
    providerType,
    algorithmId,
    modelId,
    confidenceScore: 0.68,
    qualityStatus: 'review_required',
    coverage: {
      imageCount: session.images.length,
      availableRoles: session.availableRoles,
    },
    candidateObjects: [
      {
        candidateId: `candidate-${primaryImage.captureImageId}-chair`,
        objectType: 'furniture',
        category: 'chair',
        label: 'Detected chair',
        sourceImageId: primaryImage.sourceImageId,
        captureImageId: primaryImage.captureImageId,
        sourceImageRole: primaryImage.role,
        coordinateSpace: 'image_pixels',
        boundingBox: {
          x: Math.round((primaryImage.widthPx ?? 1600) * 0.42),
          y: Math.round((primaryImage.heightPx ?? 900) * 0.48),
          width: Math.round((primaryImage.widthPx ?? 1600) * 0.18),
          height: Math.round((primaryImage.heightPx ?? 900) * 0.28),
        },
        confidenceScore: 0.66,
        reviewState: 'review_required',
        reviewLabel: 'Needs review',
        suggestedAssetId: 'chair.pending',
        suggestedPosition: { x: 1.2, y: 0, z: 1.4 },
        suggestedSize: { x: 0.55, y: 0.85, z: 0.55 },
        suggestedRotationDegrees: 0,
      },
    ],
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures: [
      {
        fixtureId: `fixture-${fixtureImage.captureImageId}-window`,
        candidateId: `candidate-${fixtureImage.captureImageId}-window`,
        category: 'window',
        wallId: 'front-wall',
        label: 'Detected window',
        position: { x: 1.8, y: 1.1, z: 0 },
        size: { x: 1.1, y: 0.9, z: 0.1 },
        rotationDegrees: 0,
        confidenceScore: 0.64,
        locked: true,
      },
    ],
  }
}

function emptyResult(session: CaptureSessionForSceneUnderstanding | null): Record<string, unknown> {
  return {
    resultId: `scene-understanding-failed-${Date.now()}`,
    captureSessionId: session?.captureSessionId,
    providerType,
    algorithmId,
    modelId,
    confidenceScore: 0,
    qualityStatus: 'failed',
    failureReasonCode: 'no_capture_images',
    failureReason: 'Capture images are required before scene understanding can run.',
    coverage: { imageCount: 0, availableRoles: [] },
    candidateObjects: [],
    placedObjects: [],
    confirmedObjects: [],
    structuralFixtures: [],
  }
}

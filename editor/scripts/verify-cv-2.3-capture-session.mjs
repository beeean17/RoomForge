import assert from 'node:assert/strict'

import {
  captureRoleSummary,
  captureSessionFromBridgePayload,
} from '../src/captureSession.ts'

const payload = {
  captureSession: {
    captureSessionId: 'capture-session-1',
    projectId: 'project-1',
    roomDimensionsId: 'current',
    captureMethod: 'android_guided_photo',
    depthEnabled: false,
    availableRoles: ['overview', 'front_wall'],
    images: [
      {
        captureImageId: 'capture-image-overview',
        captureSessionId: 'capture-session-1',
        sourceImageId: 'source-image-overview',
        role: 'overview',
        storagePath:
          'users/user-1/projects/project-1/capture-sessions/capture-session-1/images/capture-image-overview/overview.png',
        contentType: 'image/png',
        widthPx: 1600,
        heightPx: 900,
        captureOrder: 0,
        guidanceState: 'uploaded',
      },
      {
        captureImageId: 'capture-image-front-wall',
        captureSessionId: 'capture-session-1',
        sourceImageId: 'source-image-front-wall',
        role: 'front_wall',
        storagePath:
          'users/user-1/projects/project-1/capture-sessions/capture-session-1/images/capture-image-front-wall/front.png',
        contentType: 'image/png',
        widthPx: 1500,
        heightPx: 900,
        captureOrder: 1,
        guidanceState: 'uploaded',
      },
    ],
  },
}

const session = captureSessionFromBridgePayload(payload)

assert.notEqual(session, null)
assert.equal(session.captureSessionId, 'capture-session-1')
assert.equal(session.projectId, 'project-1')
assert.equal(session.captureMethod, 'android_guided_photo')
assert.equal(session.depthEnabled, false)
assert.deepEqual(session.availableRoles, ['overview', 'front_wall'])
assert.equal(session.images.length, 2)
assert.equal(session.images[0].captureImageId, 'capture-image-overview')
assert.equal(session.images[0].sourceImageId, 'source-image-overview')
assert.equal(session.images[0].role, 'overview')
assert.equal(session.images[1].widthPx, 1500)
assert.equal(captureRoleSummary(session), '2 capture roles: overview, front_wall')

const sceneScopedSession = captureSessionFromBridgePayload({
  scene: {
    captureSession: payload.captureSession,
  },
})
assert.equal(sceneScopedSession?.captureSessionId, 'capture-session-1')

const inferredRolesSession = captureSessionFromBridgePayload({
  captureSession: {
    captureSessionId: 'capture-session-2',
    images: payload.captureSession.images,
  },
})
assert.deepEqual(inferredRolesSession?.availableRoles, ['overview', 'front_wall'])

assert.equal(captureSessionFromBridgePayload({}), null)
assert.equal(captureRoleSummary(null), 'No capture session images')

console.log('CV-2.3 capture session bridge contract verified')

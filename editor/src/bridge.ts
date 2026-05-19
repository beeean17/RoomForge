export const BRIDGE_VERSION = 1

export type BridgePayload = Record<string, unknown>

export type BridgeMessage = {
  type: string
  version: number
  payload: BridgePayload
  requestId?: string
}

export function isBridgeMessage(value: unknown): value is BridgeMessage {
  if (typeof value !== 'object' || value === null) {
    return false
  }

  const candidate = value as Record<string, unknown>
  return (
    typeof candidate.type === 'string' &&
    typeof candidate.version === 'number' &&
    typeof candidate.payload === 'object' &&
    candidate.payload !== null &&
    (candidate.requestId === undefined || typeof candidate.requestId === 'string')
  )
}

export function postBridgeMessage(target: Window, message: BridgeMessage): void {
  target.postMessage(message, '*')
}

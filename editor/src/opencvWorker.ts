import { BRIDGE_VERSION, type BridgeMessage } from './bridge'

type RuntimeManifest = {
  opencvJs: string
  opencvWasm: string
  mode: string
}

self.onmessage = async (event: MessageEvent<BridgeMessage>) => {
  const message = event.data
  if (message.type !== 'roomforge.opencv.loadRuntime') {
    return
  }

  try {
    const manifestResponse = await fetch('/opencv/opencv-runtime-manifest.json')
    const manifest = (await manifestResponse.json()) as RuntimeManifest
    const [jsResponse, wasmResponse] = await Promise.all([
      fetch(manifest.opencvJs),
      fetch(manifest.opencvWasm),
    ])

    const response: BridgeMessage = {
      type: 'roomforge.opencv.runtimeLoaded',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: {
        mode: manifest.mode,
        opencvJs: manifest.opencvJs,
        opencvWasm: manifest.opencvWasm,
        jsLoaded: jsResponse.ok,
        wasmLoaded: wasmResponse.ok,
        wasmBytes: Number(wasmResponse.headers.get('content-length') ?? 0),
      },
    }
    self.postMessage(response)
  } catch (error) {
    const response: BridgeMessage = {
      type: 'roomforge.opencv.runtimeFailed',
      version: BRIDGE_VERSION,
      requestId: message.requestId,
      payload: {
        message: error instanceof Error ? error.message : String(error),
      },
    }
    self.postMessage(response)
  }
}

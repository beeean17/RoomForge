import { useEffect, useRef, useState } from 'react'

import type { EditorBridgeMessage } from './editorBridge'

export type EditorRuntimeDispatch = (message: EditorBridgeMessage) => void

type EditorRuntimeSurfaceProps = {
  initializeMessage: EditorBridgeMessage | null
  mountKey: number
  onMessage: (message: EditorBridgeMessage) => void
  onReady: (dispatch: EditorRuntimeDispatch) => void
  onError: (error: Error) => void
}

export function EditorRuntimeSurface({
  initializeMessage,
  mountKey,
  onMessage,
  onReady,
  onError,
}: EditorRuntimeSurfaceProps) {
  const hostRef = useRef<HTMLDivElement | null>(null)
  const handleRef = useRef<{ dispatch: EditorRuntimeDispatch; unmount: () => void } | null>(null)
  const onMessageRef = useRef(onMessage)
  const onReadyRef = useRef(onReady)
  const onErrorRef = useRef(onError)
  const [mountedVersion, setMountedVersion] = useState(0)

  useEffect(() => {
    onMessageRef.current = onMessage
  }, [onMessage])

  useEffect(() => {
    onReadyRef.current = onReady
  }, [onReady])

  useEffect(() => {
    onErrorRef.current = onError
  }, [onError])

  useEffect(() => {
    let disposed = false
    handleRef.current = null
    setMountedVersion((version) => version + 1)

    import('../../../../editor/src/runtime')
      .then(({ mountRoomForgeEditorRuntime }) => {
        if (disposed || !hostRef.current) {
          return
        }

        const handle = mountRoomForgeEditorRuntime(hostRef.current, {
          chrome: 'embedded',
          postMessage: (message) => onMessageRef.current(message as EditorBridgeMessage),
        })
        handleRef.current = handle as { dispatch: EditorRuntimeDispatch; unmount: () => void }
        setMountedVersion((version) => version + 1)
        onReadyRef.current(handleRef.current.dispatch)
      })
      .catch((error: unknown) => {
        const runtimeError = error instanceof Error ? error : new Error(String(error))
        onErrorRef.current(runtimeError)
      })

    return () => {
      disposed = true
      handleRef.current?.unmount()
      handleRef.current = null
    }
  }, [mountKey])

  useEffect(() => {
    if (!initializeMessage || !handleRef.current) {
      return
    }

    handleRef.current.dispatch(initializeMessage)
  }, [initializeMessage, mountedVersion])

  return <div ref={hostRef} className="editor-direct-runtime-root" aria-label="RoomForge editor runtime" />
}

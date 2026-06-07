import { mountRoomForgeEditorRuntime } from './runtime'

const app = document.querySelector<HTMLElement>('#app')

if (!app) {
  throw new Error('Missing editor root element.')
}

mountRoomForgeEditorRuntime(app, { chrome: 'full' })

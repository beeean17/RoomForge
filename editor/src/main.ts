import './style.css'

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
<section class="editor-shell">
  <div class="viewport" aria-label="RoomForge editor viewport">
    <div class="room-outline">
      <span class="corner corner-a"></span>
      <span class="corner corner-b"></span>
      <span class="corner corner-c"></span>
      <span class="corner corner-d"></span>
    </div>
  </div>
  <aside class="status-panel">
    <p class="eyebrow">RoomForge editor</p>
    <h1>Three.js boundary ready</h1>
    <p>
      This package owns spatial rendering, OpenCV overlays, geometry correction,
      furniture manipulation, and the typed Flutter bridge.
    </p>
  </aside>
</section>
`

import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __dirname = dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: '127.0.0.1',
    port: 9240,
    fs: {
      allow: [
        resolve(__dirname, '..'),
      ],
    },
  },
  preview: {
    host: '127.0.0.1',
    port: 9241,
  },
})

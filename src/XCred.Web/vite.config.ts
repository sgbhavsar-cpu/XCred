import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'
import fs from 'fs'

// VERSION at the repo root is the single source of truth (also read by Directory.Build.props
// and scripts/publish-portable.ps1). The build date is stamped when the bundle is built.
const appVersion = fs.readFileSync(path.resolve(__dirname, '../../VERSION'), 'utf8').trim()
const buildDate = new Date().toISOString().slice(0, 10)

export default defineConfig({
  plugins: [react(), tailwindcss()],
  define: {
    __APP_VERSION__: JSON.stringify(appVersion),
    __BUILD_DATE__: JSON.stringify(buildDate),
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:5017', changeOrigin: true }
    }
  },
  build: {
    outDir: '../XCred.Api/wwwroot',
    emptyOutDir: true,
    rolldownOptions: {
      // Version in every emitted filename (index-v1.3.0-<hash>.js) on top of the content hash,
      // so a new release can never be served from a stale browser cache.
      output: {
        entryFileNames: `assets/[name]-v${appVersion}-[hash].js`,
        chunkFileNames: `assets/[name]-v${appVersion}-[hash].js`,
        assetFileNames: `assets/[name]-v${appVersion}-[hash][extname]`,
      },
    },
  }
})

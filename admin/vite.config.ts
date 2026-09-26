import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    port: 5175,
    strictPort: true,
    proxy: {
      // Avoid browser CORS / Brave shields on api.github.com
      '/github-api': {
        target: 'https://api.github.com',
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/github-api/, ''),
      },
      '/github-uploads': {
        target: 'https://uploads.github.com',
        changeOrigin: true,
        secure: true,
        rewrite: (path) => path.replace(/^\/github-uploads/, ''),
      },
    },
  },
})

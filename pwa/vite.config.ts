import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// GitHub Pages URL: https://moviles-tin-2026.github.io/pwa-pwa-equipo1/
const BASE = '/pwa-pwa-equipo1/'

export default defineConfig({
  base: BASE,

  // Build output goes to /docs at the repo root so GitHub Pages can serve it
  // directly (Settings → Pages → Deploy from a branch → main → /docs).
  build: {
    outDir: '../docs',
    emptyOutDir: true,
  },

  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'pwa-192.png', 'pwa-512.png'],

      // Service worker precaches all built assets for offline use.
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,ico}'],
      },

      manifest: {
        name: 'PyME-Sync — Professional Inventory Control',
        short_name: 'PyME-Sync',
        description: 'Professional inventory control for small businesses.',
        theme_color: '#3d5016',
        background_color: '#eef0d5',
        display: 'standalone',
        orientation: 'portrait',
        scope: BASE,
        start_url: BASE,
        // PNG icons required by the Microsoft PWA guide (192 + 512 minimum).
        icons: [
          {
            src: 'pwa-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: 'pwa-512.png',
            sizes: '512x512',
            type: 'image/png',
          },
          {
            src: 'pwa-512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any maskable',
          },
        ],
      },
    }),
  ],
})

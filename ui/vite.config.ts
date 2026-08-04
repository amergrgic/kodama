import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    lib: {
      entry: 'src/App.tsx',
      formats: ['es'],
      fileName: () => 'index.mjs',
    },
    outDir: 'dist',
    rollupOptions: {
      external: [
        'react',
        'react-dom',
        'react/jsx-runtime',
        'lucide-react',
        /^@kirocrew\/app-sdk/,
      ],
    },
  },
})

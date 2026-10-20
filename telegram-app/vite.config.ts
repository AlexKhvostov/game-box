import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  server: { proxy: { '/qa-api': 'http://127.0.0.1:4181', '/qa-session': 'http://127.0.0.1:4181', '/qa-health': 'http://127.0.0.1:4181' } },
  // Runtime requires structuredClone, Array.at and Web Locks (also checked at
  // startup). Syntax targets alone do not provide those browser APIs.
  build: { target: ['chrome98', 'safari15.4'], sourcemap: false },
});

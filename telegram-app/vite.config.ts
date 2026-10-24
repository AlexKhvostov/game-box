import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig(({mode})=>{
  const qaPort=Number(loadEnv(mode,'.','UNTOUCH_').UNTOUCH_QA_API_PORT??4181);
  if(!Number.isInteger(qaPort)||qaPort<1024||qaPort>65535)throw Error('qa_port_invalid');
  return {
  plugins: [vue()],
  server: { proxy: Object.fromEntries(['/qa-api','/qa-session','/qa-health'].map(p=>[p,`http://127.0.0.1:${qaPort}`])) },
  // Runtime requires structuredClone, Array.at and Web Locks (also checked at
  // startup). Syntax targets alone do not provide those browser APIs.
  build: { target: ['chrome98', 'safari15.4'], sourcemap: false },
};});

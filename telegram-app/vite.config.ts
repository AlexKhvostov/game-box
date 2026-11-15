import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig(({mode})=>{
  const qaPort=Number(loadEnv(mode,'.','UNTOUCH_').UNTOUCH_QA_API_PORT??4181);
  if(!Number.isInteger(qaPort)||qaPort<1024||qaPort>65535)throw Error('qa_port_invalid');
  return {
  plugins: [vue(),{name:'visible-startup-before-styles',transformIndexHtml:{order:'post',handler(html){
    // A slow stylesheet must not hide the small, self-contained startup screen.
    // boot-guard activates the sheets after loading; Vue waits for them before mounting.
    return html.includes('id="boot-screen"')?html.replace(/<link rel="stylesheet"/g,'<link rel="stylesheet" media="print" data-boot-style'):html;
  }}}],
  server: {fs:{allow:[new URL('.',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'),new URL('../packages/untouch_level_up_web',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')]}, proxy: Object.fromEntries(['/qa-api','/qa-session','/qa-health'].map(p=>[p,`http://127.0.0.1:${qaPort}`])) },
  // Runtime requires structuredClone, Array.at and Web Locks (also checked at
  // startup). Syntax targets alone do not provide those browser APIs.
  build: { target: ['chrome98', 'safari15.4'], sourcemap: false, rollupOptions:{input:{index:new URL('./index.html',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'),shareDownload:new URL('./share-download.html',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')}} },
};});

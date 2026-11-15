import { createApp } from 'vue';
import App from './App.vue';
import './styles.css';
import './parity.css';
import {initializeAnalytics} from '../services/analytics';
import {installAnalyticsUi,analyticsDirective} from '../services/analytics-ui';

declare global { interface Window { __untouchBoot?: {fail(code:string):void;stylesReady():Promise<unknown>;ready():void} } }
async function mount(){
  try{
    await window.__untouchBoot?.stylesReady();
    if(!window.Telegram?.WebApp){window.__untouchBoot?.fail('START-SDK');return;}
    initializeAnalytics();
    installAnalyticsUi();
    const app=createApp(App).directive('analytics',analyticsDirective);
    let failed=false;
    app.config.errorHandler=()=>{failed=true;window.__untouchBoot?.fail('START-INTERFACE');};
    app.mount('#app');
    app.config.errorHandler=undefined;
    if(!failed)window.__untouchBoot?.ready();
  }catch{window.__untouchBoot?.fail('START-INTERFACE');}
}
void mount();

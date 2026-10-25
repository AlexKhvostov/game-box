import { createApp } from 'vue';
import App from './App.vue';
import './styles.css';
import './parity.css';
import {initializeAnalytics} from '../services/analytics';
import {installAnalyticsUi,analyticsDirective} from '../services/analytics-ui';

initializeAnalytics();
installAnalyticsUi();
createApp(App).directive('analytics',analyticsDirective).mount('#app');

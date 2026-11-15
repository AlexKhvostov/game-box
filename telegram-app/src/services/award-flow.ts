import {reactive} from 'vue';
export const awardFlow=reactive({runId:'',presentationAllowed:false});
export function prepareRunPresentation(id:string){awardFlow.runId=id;awardFlow.presentationAllowed=false;}
export function allowRunPresentation(id:string){if(awardFlow.runId===id)awardFlow.presentationAllowed=true;}

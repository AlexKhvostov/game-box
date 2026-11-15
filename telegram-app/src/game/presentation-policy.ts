export interface GamePresentationPolicy {
  enemyReactionsEnabled?: boolean;
  characterSettingsEnabled?: boolean;
  cupAutoCelebrationsEnabled?: boolean;
  startupLoadingMinMs?: number;
}
export interface GamePresentationPreferences {
  controlSensitivity?: number;
  showPlayerFace?: boolean;
  enemyReactionsEnabled?: boolean;
}
export function controlSensitivity(preferences: GamePresentationPreferences) {
  const value=preferences.controlSensitivity;
  return typeof value==='number'&&Number.isFinite(value)?Math.max(.5,Math.min(3,value)):1;
}
export function enemyReactionsAllowed(policy: GamePresentationPolicy|undefined, preferences: GamePresentationPreferences) {
  return policy?.enemyReactionsEnabled!==false&&preferences.enemyReactionsEnabled!==false;
}

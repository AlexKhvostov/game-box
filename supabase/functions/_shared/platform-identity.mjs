// Identity values enter the engine only from trusted server authentication.
export const verifiedIdentity = identity => identity?.platform === 'telegram'
  ? identity.telegramVerified === true : identity?.googleLinked === true;
export const verifiedPlayer = player => player?.platform === 'telegram'
  ? player.telegramVerified === true : player?.googleLinked === true;
export const playerPlatform = player => player?.platform === 'telegram' ? 'telegram' : 'android';

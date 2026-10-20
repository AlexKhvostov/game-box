# Telegram test deployment

Render project: `untouch_telegramm_mini_app` (`prj-dbbiadrncjis738rltqg`).

Static Site settings:

- Repository: `AlexKhvostov/game-box`; delivery branch `codex/telegram-render`.
- Root Directory: `telegram-app`.
- Build Command: `npm ci && npm run build:render`.
- Publish Directory: `dist`.
- `NODE_VERSION=24`; `SKIP_INSTALL_DEPS=true`.
- `VITE_TELEGRAM_API_URL=https://exinizzxqtjnysgibide.supabase.co/functions/v1/telegram-api`.
- `VITE_TELEGRAM_APP_URL=https://t.me/TestUntouch_bot`.
- `VITE_QA_MODE=true` (test build label; does not bypass Telegram authentication).

Only public client sources/assets belong in the delivery branch. Do not include
`.private`, environment files, backend credentials, local QA fixtures, player
data or the Android repository history. The original working checkout remains
the source of development; release preparation creates a bounded delivery commit.
Push requires Alexey's approval under the project AGENTS instructions.

The API is a separate Supabase Edge Function, sharing the existing game database
and Remote Config. Configure its exact HTTPS origin after Render assigns the URL.
Keep `TELEGRAM_STARS_ACCEPTED=false`; no payment webhook is deployed in this stage.
Before opening the bot, accept the compatible shared-ranking database/functions
update and verify that Android retains its current policy and mechanics.

Build local versioned evidence with `tools/build_telegram_web.ps1 -VueTelegram`;
never overwrite a previous release. Compare deployed bundle/asset hashes with
that artifact; Render's `version.json` additionally records the delivery commit.

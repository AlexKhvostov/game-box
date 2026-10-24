from pathlib import Path
p=Path(__file__).resolve().parents[2]/'admin-console/src/users.js'
s=p.read_text(encoding='utf-8')
pairs={
 "user.googleLinked?'Google подключён':'Гостевой аккаунт'":"user.platform==='telegram'?'Telegram':user.googleLinked?'Google подключён':'Гостевой аккаунт'",
 'Ожидает проверки Google':'Ожидает проверки оплаты',
 "filters={connection:'all'":"filters={platform:'all',connection:'all'",
 'Аккаунты Android, состояние игры':'Аккаунты Android и Telegram, состояние игры',
 '<div class="user-filters">':'<div class="user-filters"><label>Платформа<select id="filter-platform"><option value="all">Все платформы</option><option value="android">Android</option><option value="telegram">Telegram</option></select></label>',
 '<th>Игрок</th><th>Состояние</th>':'<th>Игрок</th><th>Платформа</th><th>Состояние</th>',
 '</small></td><td><span class="user-state':'</small></td><td><span class="platform-badge">${user.platform===\'telegram\'?\'Telegram\':\'Android\'}</span></td><td><span class="user-state',
 'после входа в Android-игру':'после входа в игру',
 'Читаем данные новой базы Android.':'Читаем игровые профили Android и Telegram.',
 'ПОДПИСКА GOOGLE PLAY':"ПОДПИСКА ${user.platform==='telegram'?'TELEGRAM STARS':'GOOGLE PLAY'}",
 'ПОЧТА GOOGLE':"${user.platform==='telegram'?'TELEGRAM USERNAME':'ПОЧТА GOOGLE'}",
 "user.email??'Не подключена'":"user.platform==='telegram'?user.telegramUsername??'Не задан':user.email??'Не подключена'",
 'Имя Google-аккаунта не изменится.':'Имя в Google или Telegram не изменится.',
 'Платёж в Google Play не создаётся.':'Платёж не создаётся.',
 'привязка Google и персональные данные игры':'привязка аккаунта и персональные данные игры',
 '<strong>Google Play</strong>':'<strong>${user.platform===\'telegram\'?\'Telegram Stars\':\'Google Play\'}</strong>',
 'отдельно в Google Play':'отдельно в ${user.platform===\'telegram\'?\'Telegram\':\'Google Play\'}',
 'подписка Google Play не отменяется':'подписка не отменяется',
}
for a,b in pairs.items():
    if b in s:continue
    if a not in s:raise SystemExit(f'Missing source anchor: {a}')
    s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
print('Admin user platform badge/filter updated; no publication')

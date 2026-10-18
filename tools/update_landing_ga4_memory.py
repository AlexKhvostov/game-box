"""Record only a verified GA4 landing deployment; preserve neighbouring task notes."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import json
root=Path(__file__).resolve().parents[1]
evidence=root/'docs/release-evidence/landing-ga4-20261014'
release=root/'releases/landing-v1.0.68_20261014_203149_313134'
records=[p for p in release.glob('predeploy-*/deployment.json') if (d:=json.loads(p.read_text(encoding='utf-8-sig'))).get('state')=='uploaded-and-verified' and d.get('httpsVerified')]
assert len(records)==1
assert json.loads((evidence/'release-checks.json').read_text())['passed']
assert all(x['sha256Matched'] for x in json.loads((evidence/'live-files.json').read_text()))
assert all(x['visible'] for x in json.loads((evidence/'utm-received.json').read_text()).values())
clicks=json.loads((evidence/'downloads-received.json').read_text())
assert {(p,s) for c in clicks for p in c['placements'] for s in c['stores']}=={(p,s) for p in ['hero','final'] for s in ['google_play','app_store']}
svg=json.loads((evidence/'debug-events-ui.json').read_text())
expected={'page_view':1,'demo_start':1,'demo_retry':1,'demo_end':2,'download_click':4}
for name,count in expected.items():
    index=max(i for i,value in enumerate(svg) if value==name)
    assert svg[index+1]==str(count),(name,svg[index+1])
stamp=datetime.now(timezone(timedelta(hours=3))).strftime('%d.%m.%Y %H:%M')
proof={'version':'1.0.68','published':True,'ftpsAndHttpsVerified':True,'measurementId':'G-33C1DCKG9G',
       'googleAcceptedEventCountsInTestVisit':expected,'utmConfirmedInGoogle':['source','medium','campaign','content'],
       'downloadPlatformsAndBothPlacementsConfirmedInGoogle':True,'localChecks':9,'changedPaths':6,
       'backup':str(records[0].parent.with_suffix('.zip').relative_to(root)).replace('\\','/'),
       'adsEnabled':False,'androidOrTelegramChanged':False,'updatedMinsk':stamp}
(evidence/'final.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
task=root/'memory/tasks/2026-10-14-landing-ga4.md'
text=task.read_text(encoding='utf-8')
text=text.replace('| Проверка | В работе |','| Проверка | Готово |').replace('| Выпуск | В работе |','| Выпуск | Готово |').replace('| Передача | Запланировано |','| Передача | Готово |')
text+=f'''\n\n## Итог — {stamp} Europe/Minsk

Подключено и опубликовано https://untouch.fun/ —1.0.68, GA4 G-33C1DCKG9G, ресурс546401993/отдельный поток16130663550. В одном настоящем тестовом визите Google принял page_view1, demo_start1, demo_retry1, demo_end2 и download_click4. Подтверждены оба store=google_play/app_store и обе позиции hero/final. В принятом Google page_view отдельно прочитаны source=youtube, medium=shorts, campaign=qa_ga4_20261014, content=setup_check; метки не подменяются. Realtime показал1 пользователя/1 просмотр лендинга; отчёт оставлен открытым.

9 локальных проверок прошли;74 файла/архив/CRC/хеши проверены. Изменено ровно6 путей;68 прежних файлов, изображения и физика сохранены. HTTPS хеши всех6 совпали; штатный FTPS проверил прежний ZIP перед загрузкой и публикацию. [Предыдущие изменяемые файлы в ZIP](../../{proof['backup']}). Первый полный архив неполный, не используется.

Добавлены consent/basic: до разрешения Google SDK не загружается, отказ/отзыв доступны внизу; реклама/Signals выключены. PrivacyRU/EN обновлена только двумя вставками сайта, существующий текст сохранён. Сбор событий приложения/сервер/Telegram/кошельки/Play/платежи не менялись. Необязательные письма Google отключены по отдельному выбору Алексея. Commit/push не выполнялись.

Созданы параметры отчёта store/placement. [Инструкция и доказательства](../../docs/release-evidence/landing-ga4-20261014/README.md), [итог JSON](../../docs/release-evidence/landing-ga4-20261014/final.json). Обычные отчёты/новые параметры обрабатываются24–48часов; приём в DebugView и Realtime уже проверен. Согласие посетителей/блокировщики влияют на полноту статистики. Клик — намерение, не установка; App Store по-прежнему показывает разработку. Отправка сообщений/вступление в тест/покупки не выполнялись.

Обязательной незавершённой работы нет. Следующее действие владельца — использовать согласованные UTM-ссылки в публикациях и смотреть трафик/события; дальнейший мониторинг не планировался автоматически.
'''
task.write_text(text,encoding='utf-8')
summary=f'''## GA4 лендинга опубликована — {stamp} Europe/Minsk

Лендинг1.0.68/G-33C1DCKG9G, отдельный web-поток в game-box-b30d4. Посещения/UTM, первая/повторные попытки, исходы и клики площадок; basic consent/реклама выключена. Google принял1 просмотр/1 старт/1 повтор/2 исхода/4 клика, все4UTM и store/hero/final подтверждены; Realtime1 тестовый посетитель.9 проверок,74 файла/6 изменённых/68 сохранённых, backup/FTPS/HTTPS прошли. Android/Telegram/API/экономика прежние. [Отчёт](tasks/2026-10-14-landing-ga4.md), [инструкция](../docs/release-evidence/landing-ga4-20261014/README.md).

'''
project=root/'memory/PROJECT.md'
project.write_text(summary+project.read_text(encoding='utf-8'),encoding='utf-8')
index=root/'memory/INDEX.md'
index.write_text('- [GA4 лендинга1.0.68](tasks/2026-10-14-landing-ga4.md) — опубликовано; Google принял посещение/UTM/демо/повтор/4 клика, consent, backup/FTPS/HTTPS проверены.\n\n'+index.read_text(encoding='utf-8'),encoding='utf-8')
with (root/'memory/daily/2026-10-14.md').open('a',encoding='utf-8') as f:f.write('\n'+summary.replace('(tasks/','(../tasks/').replace('(../docs/','(../../docs/'))
with (root/'memory/decisions.md').open('a',encoding='utf-8') as f:f.write(f'\n## {stamp} — GA4 лендинга и UTM\n\nАлексей поручил подключить GA4, посещения/источники/демо/повтор/кнопки для UTM-трафика. Использован отдельный web-поток существующего ресурса, basic consent и без рекламы — рабочее решение агента; события и URL проверены Google. Алексей отдельно выбрал отключение необязательных писем. Опубликовано1.0.68 с архивом, приложение/платежи прежние. [Отчёт](tasks/2026-10-14-landing-ga4.md).\n')
roadmap=root/'docs/ROADMAP.md'
roadmap.write_text(summary.replace('(tasks/','(../memory/tasks/').replace('(../docs/','(')+roadmap.read_text(encoding='utf-8'),encoding='utf-8')
with Path('D:/Codex/memory/daily/2026-10-14.md').open('a',encoding='utf-8') as f:f.write(f'\n## {stamp} Europe/Minsk — Untouch, GA4 лендинга\n\nGA4 подключена и опубликована1.0.68: посещения/UTM/демо/повторы/клики, Google DebugView+Realtime подтвердили приём.9 проверок/backup/FTPS/HTTPS, игры/сервер/платежи прежние. [Отчёт](D:/_P_R_O_J_E_C_T/game/square/Untouch/memory/tasks/2026-10-14-landing-ga4.md).\n')
partial=root/'archives/landing-before-ga4-20261014/INCOMPLETE.md'
partial.write_text('Это неполная остановленная попытка полного архива. Не использовать для восстановления.\nПроверенный ZIP прежних изменяемых файлов: '+proof['backup']+'\n',encoding='utf-8')
print('Verified final report and project/central memory saved.')

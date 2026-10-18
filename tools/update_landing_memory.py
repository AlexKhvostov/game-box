"""Record the verified 2026-10-13 landing release without touching older work."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import json,re
root=Path(__file__).resolve().parents[1]
release=root/'releases/landing-v1.0.67_20261013_103733_709'
records=list(release.glob('predeploy-*/deployment.json'))
verified=[p for p in records if (d:=json.loads(p.read_text(encoding='utf-8-sig'))).get('state')=='uploaded-and-verified' and d.get('httpsVerified')]
assert verified,'Publication not verified'
evidence=root/'docs/release-evidence/neon-landing-20261013/published67-checks.json'
qa=json.loads(evidence.read_text(encoding='utf-8'))
assert qa['allImagesLoaded'] and qa['noCropping'] and qa['demoInitialized'] and qa['mobileNoOverflow']
now=datetime.now(timezone(timedelta(hours=3))).strftime('%d.%m.%Y %H:%M')
summary=f'''## Неоновый лендинг — {now} Europe/Minsk

Опубликована и проверена https://untouch.fun/ —1.0.67. Старый сайт1.0.52 сохранён:24 публичных файла/ZIP/SHA-256. Демо сразу сверху, квадратное поле, native Android темп/размеры и7 цветов с градиентами;4 кейса, Google Play closed test и App Store «Пока в разработке». Все6 больших изображений декодированы на домене; contain без обрезки, правильные пропорции скриншотов. FTPS12 изменённых файлов; пакет71 файл/966727байт и HTTPS build/entry files подтверждены; browser desktop/mobile и управление осмотрены. Основной Android/Telegram, юридические страницы и сервер не менялись. [Задача](tasks/2026-10-13-neon-landing.md).

'''
def write(rel,text): (root/rel).write_text(text,encoding='utf-8')
def replace_top(rel,block):
    old=(root/rel).read_text(encoding='utf-8-sig')
    write(rel,re.sub(r'\A## Неоновый лендинг[^\n]*\n.*?(?=\n## )',block.rstrip(),old,count=1,flags=re.S))
replace_top('memory/PROJECT.md',summary)
replace_top('docs/ROADMAP.md',summary.replace('(tasks/','(../memory/tasks/'))
index=(root/'memory/INDEX.md').read_text(encoding='utf-8-sig')
write('memory/INDEX.md',re.sub(r'\A- \[Неоновый лендинг\][^\n]*', '- [Неоновый лендинг](tasks/2026-10-13-neon-landing.md) —1.0.67 опубликована, FTPS/HTTPS/browser проверены; полный архив, демо сверху/native темп и цвета, картинки без обрезки, кейсы и магазины.',index,count=1))
task=(root/'memory/tasks/2026-10-13-neon-landing.md').read_text(encoding='utf-8')
task=re.sub(r'Обновлено:[^\n]*',f'Обновлено:{now} Europe/Minsk. Источник: поручения Алексея в этом чате.',task,count=1)
task=re.sub(r'Текущий этап:[^\n]*','Текущий этап: готово.1.0.67 опубликована и проверена на домене.',task,count=1)
task=task.replace('| Доставка изображений | Проверка |','| Доставка изображений | Готово |').replace('42 небольшие JSON-части собирают6 WebP','48 небольших JSON-частей собирают6 WebP и2 JS-модуля').replace('публичная63 впереди','публичная67: все6 изображений декодированы, демо запущено')
task=task.replace('| Публикация1.0.63 | В работе |','| Публикация1.0.67 | Готово |').replace('65 файлов/898686байт','71 файл/966727байт').replace('FTPS backup/upload в работе','FTPS12/12;59 файлов baseline66 не перезаписывались и HTTPS подтверждены')
task=task.replace('2 новые image_gen сцены,2 канонические','4 новые image_gen сцены; польза для человека — реакция/внимание и офисная минутка').replace('портреты с боковыми полями','все4 горизонтальные сцены целиком')
task=task.replace('| Документация | В работе |','| Документация | Готово |').replace('Актуализируется по фактическому результату','PROJECT/INDEX/ROADMAP/design/LANDING/daily/decisions обновлены')
task+=f'\n\n## Финальная публичная проверка — {now}\n\n[Сайт](https://untouch.fun/?v=1.0.67). FTPS backup: {verified[-1].parent.name}. Все6 image blobs декодированы;4 карточки contain; desktop/mobile overflowfalse. Демо и App Store осмотрены. [JSON проверки](../../docs/release-evidence/neon-landing-20261013/published67-checks.json), [первый экран](../../docs/release-evidence/neon-landing-20261013/published67-desktop.png), [полные портретные сцены](../../docs/release-evidence/neon-landing-20261013/published67-cases.png).\n'
write('memory/tasks/2026-10-13-neon-landing.md',task)
landing=(root/'docs/LANDING.md').read_text(encoding='utf-8-sig')
write('docs/LANDING.md','# Лендинг Untouch\n\n'+summary.replace('(tasks/','(../memory/tasks/')+'Предыдущие публикации ниже — история, не актуальный статус.\n\n'+landing.removeprefix('# Лендинг Untouch').lstrip())
with (root/'memory/daily/2026-10-13.md').open('a',encoding='utf-8') as f:
    f.write(f'\n\n## {now} — неоновый лендинг\n\nАрхив1.0.52 проверен;1.0.67 опубликована FTPS/HTTPS/browser. Демо сверху, native Android темп/цвета; картинки целиком, реальные скриншоты,4 кейса, Google Play/App Store. Четыре новые сцены image_gen, включая реакцию/внимание и офисный чайник. После выявленных HTTP/FTP timeout доставка исправлена small static parts/fresh TLS sessions. Основные игры/данные/юридические страницы не менялись, push не было. Центральный журнал не обновлён из-за границ записи. [Задача](../tasks/2026-10-13-neon-landing.md).\n')
decisions=(root/'memory/decisions.md').read_text(encoding='utf-8-sig')
write('memory/decisions.md',decisions+f'\n\n## {now} — лендинг: демо сверху, полные картинки, native palette\n\nПрямые указания Алексея: сохранить прежний сайт; убрать большой кубик hero, демо сразу на первом экране; темп и соотношения как в Android; метро/компания/реакция/перерыв; Google Play closed test, App Store «Пока в разработке»; картинки целиком, цвета демо как реальная игра. Выбор агента: contain3:2 без обрезки;48 static parts+SHA для доставки6 WebP и2 JS; fresh verified TLS FTP sessions. Реализовано и опубликовано1.0.67. [Отчёт](tasks/2026-10-13-neon-landing.md).\n')
task_path=root/'memory/tasks/2026-10-13-neon-landing.md'
write('memory/tasks/2026-10-13-neon-landing.md',task_path.read_text(encoding='utf-8').replace('полные портретные сцены','новые сцены о пользе')+'\n\n[Реакция PNG](../../assets/branding/landing/reaction-benefit-v1.png), [чайник PNG](../../assets/branding/landing/office-kettle-benefit-v1.png), [новые промпты](../../docs/design/landing-benefit-prompts-20261013.txt). Последнее указание Алексея: акцент на пользе для человека, не на игровом интерфейсе; выполнено в изображениях и текстах.\n')
print('Verified release memory and documentation updated:',now)

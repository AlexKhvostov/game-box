"""Physical invite QA. Synthetic account/API; real Flutter UI, IME and Android intents.

Fresh evidence directory is required before any device mutation. No messages are sent.
"""
import argparse
import hashlib
import json
import re
import socket
import subprocess
import time
import urllib.parse
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADB = Path('C:/Users/alexe/AppData/Local/Android/Sdk/platform-tools/adb.exe')
MAIN = 'com.best4u.untouch'
PROBE = MAIN + '.uiprobe'
COMPONENT = PROBE + '/com.best4u.untouch.MainActivity'
PORT = 8879
CODE = 'ABCDEFGH2345'
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-prefix', required=True)
    parser.add_argument('--smoke', action='store_true', help='Only first two representative frames')
    parser.add_argument('--short-ime', action='store_true', help='Only actual short RU/font2 IME and field/Apply visibility')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9_-]{0,63}', args.evidence_prefix):
        parser.error('Prefix must be 1-64 lowercase ASCII letters/digits/_/- and start with a letter')
    out = ROOT / 'docs/release-evidence/friend-invites-20261013/b7' / args.evidence_prefix
    if out.exists():
        parser.error('Evidence directory already exists; select a fresh prefix')
    out.mkdir(parents=True)
    result = {'checks': [], 'frames': [], 'limitations': [
        'Synthetic HTTP/account/Google/history, not real OAuth or SQL payments',
        'Explicit Android cold/warm intents, not hosted domain verification',
        'Sideload InstallReferrer status, not a Google Play installation',
        'Share chooser opened and dismissed; no receiver selected or message sent',
    ]}
    serial = None
    own_forward = False
    baseline = {}
    claimed_device = False
    window_offset = [0, 0]

    def adb(*words, binary=False):
        cmd = [str(ADB)] + (['-s', serial] if serial else []) + list(words)
        completed = subprocess.run(cmd, capture_output=True, check=True, timeout=35)
        return completed.stdout if binary else completed.stdout.decode('utf-8', 'replace').strip()

    def check(name, passed, detail=None):
        result['checks'].append({'name': name, 'pass': bool(passed), 'detail': detail})
        if not passed:
            raise AssertionError(name + (': ' + str(detail) if detail is not None else ''))

    def stop():
        for package in (MAIN, PROBE):
            adb('shell', 'am', 'force-stop', package)

    def req(route, **query):
        url = f'http://127.0.0.1:{PORT}{route}?' + urllib.parse.urlencode(query)
        with OPENER.open(url, timeout=18) as response:
            return json.load(response)

    def ready():
        deadline = time.time() + 25
        while time.time() < deadline:
            try:
                status = req('/status')
                if status.get('ownCode'):
                    return status
            except (OSError, ValueError):
                pass
            time.sleep(.3)
        raise AssertionError('Probe localhost endpoint did not become ready')

    def start(uri=None):
        words = ['shell', 'am', 'start', '-W', '-n', COMPONENT]
        if uri:
            words += ['-a', 'android.intent.action.VIEW', '-d', uri]
        adb(*words)
        status = ready()
        # Huawei excludes its notch/status strip from the Flutter surface, even
        # in immersive mode. ADB input uses display pixels, Flutter boxes use
        # the application surface. Calibrate while the IME is closed.
        if status['keyboardInset'] == 0:
            width, height = map(int, re.findall(r'(\d+)x(\d+)', adb('shell', 'wm', 'size'))[-1])
            surface = status['screenLogicalSize']
            window_offset[:] = [round((width-surface[0]*status['screenDpr'])/2),
                                round(height-surface[1]*status['screenDpr'])]
        return status

    def show(screen, lang='ru', state='empty', reset=True):
        status = req('/show', screen=screen, lang=lang, state=state, reset=str(reset).lower())
        check(f'{screen}/{lang}/{state}: active provider', status['providerIsCurrent'])
        check(f'{screen}/{lang}/{state}: no Flutter errors', not status['errors'], status['errors'])
        check(f'{screen}/{lang}/{state}: no real actions', status['forbiddenCalls'] == 0)
        return status

    def rectangle(key):
        for _ in range(5):
            try:
                return req('/rect', key=key)['rect']
            except urllib.error.HTTPError:
                size = req('/status')['screenLogicalSize']
                dpr = req('/status')['screenDpr']
                x = int(size[0] * dpr * .65)
                adb('shell', 'input', 'swipe', str(x), str(int(size[1]*dpr*.78)),
                    str(x), str(int(size[1]*dpr*.35)), '250')
                time.sleep(.4)
        raise AssertionError('Could not expose key: ' + key)

    def tap(key):
        rect = rectangle(key)
        dpr = req('/status')['screenDpr']
        adb('shell', 'input', 'tap', str(round((rect['x']+rect['width']/2)*dpr)+window_offset[0]),
            str(round((rect['y']+rect['height']/2)*dpr)+window_offset[1]))
        time.sleep(.65)
        return rect

    def frame(name, key=None):
        geometry = rectangle(key) if key else None
        time.sleep(.3)
        focused = adb('shell', 'dumpsys', 'window')
        # Record only the boolean and public test package; no other window/contact data.
        focus_lines = [line for line in focused.splitlines() if 'mCurrentFocus=' in line]
        check(name + ': probe focused', any(PROBE in line for line in focus_lines))
        status = req('/status')
        check(name + ': no Flutter errors', not status['errors'], status['errors'])
        check(name + ': active provider', status['providerIsCurrent'])
        check(name + ': no real actions', status['forbiddenCalls'] == 0)
        png = out / (name + '.png')
        png.write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
        result['frames'].append({'name': name, 'path': str(png.relative_to(ROOT)),
                                 'sha256': hashlib.sha256(png.read_bytes()).hexdigest(),
                                 'geometry': geometry, 'status': status})
        result['frames'][-1]['windowOffsetPixels'] = list(window_offset)
        print('Captured ' + name, flush=True)

    def layout(short=False):
        stop()
        adb('shell', 'wm', 'size', '960x1440' if short else 'reset')
        adb('shell', 'wm', 'density', '480')
        adb('shell', 'settings', 'put', 'system', 'font_scale', '2.0' if short else '1.0')
        start()

    try:
        devices = [line.split()[0] for line in adb('devices').splitlines()[1:]
                   if len(line.split()) > 1 and line.split()[1] == 'device']
        check('One available physical Android', len(devices) == 1)
        serial = devices[0]
        forwards = [line for line in adb('forward', '--list').splitlines() if line.strip()]
        check('Own forward port unused', not any(f'tcp:{PORT}' in line for line in forwards))
        with socket.socket() as port_check:
            port_check.bind(('127.0.0.1', PORT))
        baseline = {
            'font': adb('shell', 'settings', 'get', 'system', 'font_scale'),
            'size': adb('shell', 'wm', 'size'),
            'density': adb('shell', 'wm', 'density'),
            'usb': adb('shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in'),
            'existingForwards': forwards,
        }
        check('Expected dedicated physical baseline', baseline['font'] == '1.0'
              and baseline['size'] == 'Physical size: 1080x2312'
              and baseline['density'] == 'Physical density: 480' and baseline['usb'] == '2', baseline)
        claimed_device = True
        result['baseline'] = baseline
        stop()
        adb('forward', f'tcp:{PORT}', f'tcp:{PORT}')
        own_forward = True
        start()
        if args.short_ime:
            layout(short=True)
            show('profile')
            tap('inviter-code-field')
            ime = adb('shell', 'dumpsys', 'input_method')
            check('Short RU/font2 actual IME shown', 'mInputShown=true' in ime or 'isInputViewShown=true' in ime)
            check('Short RU/font2 actual keyboard inset', req('/status')['keyboardInset'] > 0)
            apply_rect = rectangle('inviter-apply')
            frame('short-ru-font2-keyboard')
            status = req('/status')
            viewport_scale = status['screenLogicalSize'][0] / status['viewSize'][0]
            keyboard_top = status['screenLogicalSize'][1] - status['keyboardInset'] * viewport_scale
            # Both controls form one compact vertical block; screenshot is the
            # actual simultaneous visibility evidence after exposing Apply.
            check('Short RU/font2 Apply is fully above IME', apply_rect['y'] >= 0
                  and apply_rect['y'] + apply_rect['height'] <= keyboard_top,
                  {'apply': apply_rect, 'keyboardTopScreenDp': keyboard_top})
            check('Short IME does not bind a code', status['bindCalls'] == 0 and status['boundCode'] is None)
            result['completed'] = True
            return
        show('earn')
        frame('normal-ru-earn', 'invite-action-card')
        tap('invite-action-card')
        frame('normal-ru-empty-modal')
        if not args.smoke:
            show('invites', state='paid')
            frame('normal-ru-paid-modal')
            before = req('/status')['bindCalls']
            tap('invitation-copy-code')
            check('Real Clipboard copies current code', req('/clipboard')['clipboard'] == 'AAAAAAAAAAAA')
            tap('invitation-copy-link')
            check('Real Clipboard copies current URL', req('/clipboard')['clipboard'] == 'https://untouch.fun/a/AAAAAAAAAAAA')
            tap('invitation-share')
            focus = adb('shell', 'dumpsys', 'window')
            chooser = [line for line in focus.splitlines() if 'mCurrentFocus=' in line]
            check('Actual Android share chooser opened', any('ResolverActivity' in line or 'ChooserActivity' in line for line in chooser))
            # Do not capture chooser contacts or select a receiver.
            adb('shell', 'input', 'keyevent', '4')
            time.sleep(.6)
            check('Copy/share do not bind or pay', req('/status')['bindCalls'] == before)
            frame('normal-ru-paid-bottom', 'invitation-load-more')
            tap('invitation-load-more')
            check('Real UI pagination called fixture once', req('/status')['calls'].get('invites_list') == 1)
            frame('normal-ru-paid-page2', 'invitation-paid-89')
            show('invites', lang='en', state='paid')
            frame('normal-en-paid-modal')
            show('profile')
            frame('normal-ru-google-checkbox', 'profile-google-private')
            frame('normal-ru-unbound-profile', 'profile-inviter-section')
            tap('inviter-code-field')
            ime = adb('shell', 'dumpsys', 'input_method')
            check('Actual system keyboard visible', 'mInputShown=true' in ime or 'isInputViewShown=true' in ime)
            frame('normal-ru-keyboard', 'inviter-code-field')
            adb('shell', 'input', 'text', 'CCCCCCCCCCCC')
            tap('inviter-apply')
            frame('normal-ru-unknown-code', 'inviter-error')
            tap('inviter-code-field')
            adb('shell', 'input', 'keyevent', '123')
            for _ in range(12):
                adb('shell', 'input', 'keyevent', '67')
            adb('shell', 'input', 'text', CODE)
            tap('inviter-apply')
            check('Actual valid submission binds once after rejected code', req('/status')['boundCode'] == CODE)
            frame('normal-ru-locked-profile', 'inviter-locked-code')
            show('invites', state='page-error')
            tap('invitation-load-more')
            frame('normal-ru-paging-error', 'invitation-load-more')
            check('Paging failure preserves first paid rows', req('/rect', key='invitation-paid-100')['rect']['height'] > 0)
            show('invites', state='unavailable')
            frame('normal-ru-unavailable-modal')
            layout(short=True)
            show('invites', state='paid')
            frame('short-ru-font2-paid-modal')
            show('profile')
            frame('short-ru-font2-unbound-profile', 'profile-inviter-section')
            show('invites', lang='en', state='paid')
            frame('short-en-font2-paid-modal')
            show('profile', lang='en', state='locked')
            frame('short-en-font2-locked-profile', 'inviter-locked-code')
            layout()
            show('home')
            stop()
            cold = start('https://untouch.fun/a/' + CODE)
            time.sleep(.8)
            cold = req('/status')
            check('Actual native cold URI binds current provider', cold['providerIsCurrent'] and cold['boundCode'] == CODE
                  and ('https://untouch.fun/a/' + CODE) in cold['nativeReceived'] and cold['nativeAcknowledgements'] >= 1, cold)
            warm = start('https://untouch.fun/a/JKLMNPQR6789')
            time.sleep(.7)
            warm = req('/status')
            check('Actual native warm onNewIntent preserves first inviter', warm['boundCode'] == CODE
                  and warm['nativeEvents'] >= 1 and warm['nativeAcknowledgements'] >= 2, warm)
            received = len(warm['nativeReceived'])
            start('https://example.invalid/a/' + CODE)
            check('Native ignores foreign host', len(req('/status')['nativeReceived']) == received)
            sdk = req('/sdk')
            check('Actual sideload referrer SDK measured', sdk['actualSideloadSdkStatus'] in ('absent', 'retry', 'available'))
            result['native'] = sdk
            owner = req('/owner')
            check('Canonical synthetic owner replaces outgoing code', owner['profileId'] == 'android:900002'
                  and owner['ownCode'] == 'BBBBBBBBBBBB' and owner['boundCode'] is None, owner)
        result['completed'] = True
    except Exception as error:
        result['error'] = type(error).__name__ + ': ' + str(error)
        result['completed'] = False
        raise
    finally:
        cleanup_errors = []
        if serial and claimed_device:
            for words in [('shell', 'am', 'force-stop', MAIN), ('shell', 'am', 'force-stop', PROBE),
                          ('shell', 'wm', 'size', 'reset'), ('shell', 'wm', 'density', 'reset'),
                          ('shell', 'settings', 'put', 'system', 'font_scale', baseline['font']),
                          ('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', '2')]:
                try:
                    adb(*words)
                except Exception as error:
                    cleanup_errors.append(str(error))
            if own_forward:
                try:
                    adb('forward', '--remove', f'tcp:{PORT}')
                except Exception as error:
                    cleanup_errors.append(str(error))
            result['restored'] = {
                'font': adb('shell', 'settings', 'get', 'system', 'font_scale'),
                'size': adb('shell', 'wm', 'size'),
                'density': adb('shell', 'wm', 'density'),
                'usb': adb('shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in'),
                'forwards': [line for line in adb('forward', '--list').splitlines() if line.strip()],
                'mainStopped': not subprocess.run([str(ADB), '-s', serial, 'shell', 'pidof', MAIN],
                                                 capture_output=True, check=False).stdout.strip(),
                'probeStopped': not subprocess.run([str(ADB), '-s', serial, 'shell', 'pidof', PROBE],
                                                  capture_output=True, check=False).stdout.strip(),
            }
        result['cleanupErrors'] = cleanup_errors
        result['passed'] = sum(item['pass'] for item in result['checks'])
        result['failed'] = sum(not item['pass'] for item in result['checks'])
        (out / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({'completed': result.get('completed'), 'passed': result['passed'],
                          'failed': result['failed'], 'frames': len(result['frames']),
                          'cleanupErrors': cleanup_errors, 'evidence': str(out)}))


if __name__ == '__main__':
    main()

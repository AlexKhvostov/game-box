"""Verify foreground reconnection on the emulator; never clears app data."""
import json
import os
from pathlib import Path
import subprocess
import time

OUT = Path(__file__).resolve().parents[1] / 'docs/release-evidence/android-google-20261010'
ADB = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
PACKAGE = 'com.best4u.untouch'
ACTIVITY = PACKAGE + '/' + PACKAGE + '.MainActivity'


def adb(*args):
    return subprocess.run([str(ADB), '-s', 'emulator-5554', *args],
                          check=True, capture_output=True, text=True).stdout.strip()


def markers():
    pid = adb('shell', 'pidof', PACKAGE)
    if not pid:
        return []
    lines = adb('logcat', '-d', '--pid=' + pid, '-s', 'flutter:I', '*:S').splitlines()
    # Keep only our public connection states, never account details or tokens.
    return [line for line in lines if 'Mobile connection: synchronized' in line
            or 'Mobile connection: retry pending' in line]


def wait_for(state, previous=0, seconds=45):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        found = [line for line in markers() if 'Mobile connection: ' + state in line]
        if len(found) > previous:
            return found
        time.sleep(1)
    raise RuntimeError('Connection state was not observed: ' + state)


def capture(name):
    adb('shell', 'screencap', '-p', '/sdcard/untouch-network-qa.png')
    adb('pull', '/sdcard/untouch-network-qa.png', str(OUT / (name + '.png')))


def resume():
    adb('shell', 'input', 'keyevent', '3')
    time.sleep(1)
    adb('shell', 'am', 'start', '-W', '-n', ACTIVITY)


def network(wifi, data):
    adb('shell', 'svc', 'wifi', 'enable' if wifi else 'disable')
    adb('shell', 'svc', 'data', 'enable' if data else 'disable')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wifi = adb('shell', 'settings', 'get', 'global', 'wifi_on') == '1'
    data = adb('shell', 'settings', 'get', 'global', 'mobile_data') == '1'
    results = {}
    try:
        initial = wait_for('synchronized')
        capture('release59-native-home')
        resume()
        wait_for('synchronized', len(initial))
        results['resumeOnline'] = 'passed'
        print('resumeOnline passed', flush=True)

        before_retry = len([line for line in markers() if 'retry pending' in line])
        before_success = len([line for line in markers() if 'synchronized' in line])
        network(False, False)
        time.sleep(2)
        resume()
        wait_for('retry pending', before_retry)
        capture('resume-offline')
        network(wifi, data)
        wait_for('synchronized', before_success, seconds=55)
        capture('resume-reconnected')
        results['offlineResumeThenNetworkReturns'] = 'passed without app restart'
        print('offlineResumeThenNetworkReturns passed', flush=True)

        network(False, False)
        time.sleep(2)
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'start', '-W', '-n', ACTIVITY)
        wait_for('retry pending')
        capture('cold-start-offline')
        network(wifi, data)
        wait_for('synchronized', seconds=55)
        capture('cold-start-reconnected')
        results['offlineColdStartThenNetworkReturns'] = 'passed without another app restart'
        results['markers'] = markers()
        print('offlineColdStartThenNetworkReturns passed', flush=True)
    finally:
        network(wifi, data)
    results.update(package=PACKAGE, physicalDevice=False, appDataCleared=False,
                   originalNetworkRestored=True)
    (OUT / 'native-reconnect.json').write_text(json.dumps(results, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()

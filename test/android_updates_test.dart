import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/data/android_updates.dart';
import 'package:game_box/data/scores_store.dart';
import 'package:game_box/data/economy_store.dart';

const offered = PlayUpdateInfo(
  installedVersion: 196,
  availableVersion: 197,
  available: true,
  flexibleAllowed: true,
);
const downloaded = PlayUpdateInfo(
  installedVersion: 196,
  availableVersion: 197,
  available: true,
  flexibleAllowed: true,
  installStatus: 11,
);
const downloading = PlayUpdateInfo(
  installedVersion: 196,
  availableVersion: 197,
  available: true,
  flexibleAllowed: true,
  installStatus: 2,
  downloadedBytes: 40,
  totalBytes: 100,
);

class FakePlayUpdates implements PlayUpdateSource {
  final stream = StreamController<PlayUpdateInfo>.broadcast(sync: true);
  PlayUpdateInfo current = offered;
  PlayUpdateInfo? startResult;
  Object? checkError, downloadError, completeError;
  Future<PlayUpdateInfo>? checkPending, startPending;
  int checks = 0, starts = 0, completions = 0;
  @override
  Stream<PlayUpdateInfo> get events => stream.stream;
  void send(PlayUpdateInfo value) {
    current = value;
    stream.add(value);
  }

  @override
  Future<PlayUpdateInfo> check() async {
    checks++;
    if (checkError != null) throw checkError!;
    return checkPending ?? Future.value(current);
  }

  @override
  Future<PlayUpdateInfo> startFlexible() async {
    starts++;
    if (downloadError != null) throw downloadError!;
    return startPending ?? Future.value(startResult ?? current);
  }

  @override
  Future<void> complete() async {
    completions++;
    if (completeError != null) throw completeError!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late FakePlayUpdates source;
  late AndroidUpdates updates;
  late DateTime clock;
  int saves = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    source = FakePlayUpdates();
    clock = DateTime(2026, 10, 24, 18);
    saves = 0;
    updates = AndroidUpdates(
      source: source,
      preferences: prefs,
      prepareForRestart: () async {
        saves++;
      },
      now: () => clock,
    );
  });
  tearDown(() async {
    updates.dispose();
    await source.stream.close();
  });

  test('Unsupported Play and failed automatic checks stay silent', () async {
    source.current = const PlayUpdateInfo(supported: false);
    await updates.start();
    expect(updates.prompt, isNull);
    source.checkError = StateError('offline');
    await updates.refresh(force: true);
    expect(updates.phase, UpdatePhase.unavailable);
    expect(updates.prompt, isNull);
  });
  test('Only a higher accessible Flexible version is offered', () async {
    source.current = const PlayUpdateInfo(
      installedVersion: 197,
      availableVersion: 197,
      available: true,
      flexibleAllowed: true,
    );
    await updates.start();
    expect(updates.prompt, isNull);
    source.current = const PlayUpdateInfo(
      installedVersion: 196,
      availableVersion: 197,
      available: true,
      flexibleAllowed: false,
    );
    await updates.refresh(force: true);
    expect(updates.prompt, isNull);
    source.current = offered;
    await updates.refresh(force: true);
    expect(updates.prompt, UpdatePrompt.available);
  });
  test(
    'Offer deferral survives a controller restart and expires after a day',
    () async {
      await updates.start();
      await updates.defer(UpdatePrompt.available);
      final next = AndroidUpdates(
        source: source,
        preferences: prefs,
        prepareForRestart: () async {},
        now: () => clock,
      );
      await next.start();
      expect(next.prompt, isNull);
      clock = clock.add(const Duration(hours: 25));
      await next.refresh(force: true);
      expect(next.prompt, UpdatePrompt.available);
      next.dispose();
    },
  );
  test('A different update bypasses deferral of the older version', () async {
    await updates.start();
    await updates.defer(UpdatePrompt.available);
    source.send(
      const PlayUpdateInfo(
        installedVersion: 196,
        availableVersion: 198,
        available: true,
        flexibleAllowed: true,
      ),
    );
    expect(updates.prompt, UpdatePrompt.available);
  });
  test(
    'Play cancellation defers without an error or automatic retry',
    () async {
      source.startResult = const PlayUpdateInfo(
        installedVersion: 196,
        availableVersion: 197,
        available: true,
        flexibleAllowed: true,
        canceled: true,
      );
      await updates.start();
      await updates.download();
      expect(updates.phase, UpdatePhase.available);
      expect(updates.prompt, isNull);
      expect(updates.busy, false);
      expect(source.starts, 1);
    },
  );
  test(
    'Progress and downloaded state survive a late consent response',
    () async {
      final consent = Completer<PlayUpdateInfo>();
      source.startPending = consent.future;
      await updates.start();
      final request = updates.download();
      source.send(downloading);
      expect(updates.progress, .4);
      source.send(downloaded);
      consent.complete(offered);
      await request;
      expect(updates.phase, UpdatePhase.ready);
      expect(updates.prompt, UpdatePrompt.ready);
      expect(source.completions, 0);
    },
  );
  test('Check response cannot overwrite a newer progress event', () async {
    await updates.start();
    final check = Completer<PlayUpdateInfo>();
    source.checkPending = check.future;
    final refreshing = updates.refresh(force: true);
    source.send(downloaded);
    check.complete(offered);
    await refreshing;
    expect(updates.phase, UpdatePhase.ready);
  });
  test(
    'Downloaded update is recovered after restart even without availability',
    () async {
      source.current = const PlayUpdateInfo(
        installedVersion: 196,
        availableVersion: 197,
        installStatus: 11,
      );
      await updates.start();
      expect(updates.prompt, UpdatePrompt.ready);
      expect(source.completions, 0);
    },
  );
  test(
    'Ready Later persists without discarding the downloaded update',
    () async {
      source.current = downloaded;
      await updates.start();
      await updates.defer(UpdatePrompt.ready);
      expect(updates.prompt, isNull);
      expect(updates.phase, UpdatePhase.ready);
      final next = AndroidUpdates(
        source: source,
        preferences: prefs,
        prepareForRestart: () async {},
      );
      await next.start();
      expect(next.prompt, isNull);
      expect(next.phase, UpdatePhase.ready);
      next.dispose();
      expect(source.completions, 0);
    },
  );
  test('Offline status check preserves already downloaded update', () async {
    source.current = downloaded;
    await updates.start();
    source.checkError = StateError('offline');
    await updates.refresh(force: true);
    expect(updates.phase, UpdatePhase.ready);
    expect(updates.prompt, UpdatePrompt.ready);
  });
  test('Duplicate download presses open only one Play consent', () async {
    final consent = Completer<PlayUpdateInfo>();
    source.startPending = consent.future;
    await updates.start();
    final first = updates.download();
    await updates.download();
    expect(source.starts, 1);
    consent.complete(offered);
    await first;
  });
  test(
    'Explicit download error remains visible and retry is user initiated',
    () async {
      await updates.start();
      source.downloadError = StateError('network');
      await updates.download();
      expect(updates.phase, UpdatePhase.failed);
      expect(updates.prompt, UpdatePrompt.failed);
      expect(source.starts, 1);
      updates.markPromptShown(UpdatePrompt.failed);
      expect(updates.prompt, isNull);
      source.downloadError = null;
      await updates.retry();
      expect(source.starts, 2);
      expect(updates.phase, UpdatePhase.available);
    },
  );
  test(
    'A failed status while downloading waits for the UI to present it',
    () async {
      await updates.start();
      source.send(downloading);
      source.send(
        const PlayUpdateInfo(
          installedVersion: 196,
          availableVersion: 197,
          installStatus: 5,
          errorCode: -100,
        ),
      );
      expect(updates.prompt, UpdatePrompt.failed);
      expect(source.completions, 0);
    },
  );
  test('Install does nothing during a party or before download', () async {
    await updates.start();
    await updates.install(isSafe: () => true);
    expect(saves, 0);
    source.send(downloaded);
    await updates.install(isSafe: () => false);
    expect(saves, 0);
    expect(source.completions, 0);
  });
  test('Install waits for local persistence and rechecks safety', () async {
    updates.dispose();
    final saved = Completer<void>();
    bool safe = true;
    updates = AndroidUpdates(
      source: source,
      preferences: prefs,
      prepareForRestart: () => saved.future,
    );
    source.current = downloaded;
    await updates.start();
    final install = updates.install(isSafe: () => safe);
    expect(source.completions, 0);
    expect(updates.busy, true);
    safe = false;
    saved.complete();
    await install;
    expect(source.completions, 0);
    expect(updates.busy, false);
    expect(updates.phase, UpdatePhase.ready);
  });
  test('Storage failure prevents restart and exposes retry', () async {
    updates.dispose();
    updates = AndroidUpdates(
      source: source,
      preferences: prefs,
      prepareForRestart: () async {
        throw StateError('storage');
      },
    );
    source.current = downloaded;
    await updates.start();
    await updates.install(isSafe: () => true);
    expect(source.completions, 0);
    expect(updates.prompt, UpdatePrompt.failed);
  });
  test(
    'Successful install rechecks download, saves and completes exactly once',
    () async {
      source.current = downloaded;
      await updates.start();
      await updates.defer(UpdatePrompt.ready);
      await updates.install(isSafe: () => true);
      await updates.install(isSafe: () => true);
      expect(saves, 1);
      expect(source.completions, 1);
      expect(updates.phase, UpdatePhase.installing);
      expect(prefs.getInt('play_flexible_update_v1_installing_version'), 197);
    },
  );
  test(
    'Lost downloaded package is not installed from a stale ready state',
    () async {
      source.current = downloaded;
      await updates.start();
      source.current = offered;
      await updates.install(isSafe: () => true);
      expect(source.completions, 0);
    },
  );
  test('Completion failure can recover downloaded update via retry', () async {
    source.current = downloaded;
    await updates.start();
    await updates.defer(UpdatePrompt.ready);
    source.completeError = StateError('Play');
    await updates.install(isSafe: () => true);
    expect(updates.prompt, UpdatePrompt.failed);
    await updates.retry();
    expect(updates.prompt, UpdatePrompt.ready);
    expect(source.starts, 0);
  });
  test(
    'Success toast is only for a confirmed installed requested version',
    () async {
      await prefs.setInt('play_flexible_update_v1_installing_version', 197);
      await updates.start();
      expect(updates.successNotice, false);
      source.send(const PlayUpdateInfo(installedVersion: 197));
      expect(updates.successNotice, true);
      await Future<void>.delayed(Duration.zero);
      expect(
        prefs.containsKey('play_flexible_update_v1_installing_version'),
        false,
      );
    },
  );
  test(
    'Native map preserves large byte counts and rejects missing support',
    () {
      final value = PlayUpdateInfo.fromMap({
        'supported': true,
        'downloadedBytes': 5000000000,
        'totalBytes': 6000000000,
        'installStatus': 2,
      });
      expect(value.downloadedBytes, 5000000000);
      expect(PlayUpdateInfo.fromMap({}).supported, false);
    },
  );
  test(
    'Installed status releases the UI instead of leaving a permanent lock',
    () async {
      source.current = const PlayUpdateInfo(
        installedVersion: 197,
        availableVersion: 197,
        installStatus: 4,
      );
      await updates.start();
      expect(updates.phase, UpdatePhase.unavailable);
      expect(updates.prompt, isNull);
    },
  );
  test(
    'Restart barrier preserves the last local attempt across a fresh store',
    () async {
      final scores = ScoresStore();
      await scores.loadLocal();
      final recording = scores.recordAttempt(
        1234,
        riskCount: 7,
        runDistance: 12,
      );
      await scores.prepareForAppRestart();
      await recording;
      final reloaded = ScoresStore();
      await reloaded.loadLocal();
      expect(reloaded.latestAttempt?.timeMs, 1234);
      expect(reloaded.latestAttempt?.riskCount, 7);
      scores.dispose();
      reloaded.dispose();
    },
  );
  test('Restart barrier preserves the latest economy snapshot', () async {
    final economy = EconomyStore();
    await economy.load();
    economy.completeRound(timeMs: 12345, runDistance: 10, riskCount: 2);
    await economy.prepareForAppRestart();
    final reloaded = EconomyStore();
    await reloaded.load();
    expect(reloaded.bestTimeMs, 12345);
    expect(reloaded.tokens, economy.tokens);
    economy.dispose();
    reloaded.dispose();
  });
  test(
    'Invalid ready version cannot trigger restart or a false success marker',
    () async {
      source.current = const PlayUpdateInfo(
        installedVersion: 197,
        availableVersion: 197,
        installStatus: 11,
      );
      await updates.start();
      await updates.install(isSafe: () => true);
      expect(source.completions, 0);
      expect(updates.phase, UpdatePhase.failed);
      expect(
        prefs.containsKey('play_flexible_update_v1_installing_version'),
        false,
      );
    },
  );
  test('Native MethodChannel calls the expected Android methods', () async {
    final called = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativePlayUpdateSource.methods, (
      call,
    ) async {
      called.add(call.method);
      return call.method == 'complete'
          ? null
          : {
              'supported': true,
              'installedVersion': 196,
              'availableVersion': 197,
            };
    });
    const native = NativePlayUpdateSource();
    expect((await native.check()).availableVersion, 197);
    await native.startFlexible();
    await native.complete();
    expect(called, ['check', 'startFlexible', 'complete']);
    messenger.setMockMethodCallHandler(NativePlayUpdateSource.methods, null);
  });
}

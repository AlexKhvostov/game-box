import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../tools/ad_formats_rc_probe.dart';

void main() {
  test(
    'QA has no implicit ON, and both switches come only from fetched RC',
    () async {
      expect(ProbeAdFormatsRemote.initial.banner.enabled, false);
      expect(ProbeAdFormatsRemote.initial.automatic.enabled, false);
      var applied = ProbeAdFormatsRemote.initial;
      var banner = false, automatic = false;
      final source = ProbeAdFormatsRemote(
        apply: (next) => applied = next,
        fetch: () async => jsonEncode({
          'banner': {'enabled': banner, 'installDelaySec': 0},
          'automatic': {'enabled': automatic},
        }),
      );
      for (final pair in [
        (false, false),
        (true, false),
        (false, true),
        (true, true),
      ]) {
        banner = pair.$1;
        automatic = pair.$2;
        final settings = await source.fetchBanner();
        expect(settings.enabled, banner);
        expect(applied.banner.enabled, banner);
        expect(applied.automatic.enabled, automatic);
        expect(applied.automatic.resumeGraceSec, 180);
        expect(applied.rewardedEnabled, true);
      }
      expect(source.refreshes, 4);
      expect(source.lastError, null);
    },
  );
  test(
    'missing or invalid QA RC never silently enables automatic ads',
    () async {
      var applied = ProbeAdFormatsRemote.initial;
      for (final raw in [
        '{}',
        'null',
        '{"banner":{"enabled":true}}',
        '{"banner":{"enabled":false},"automatic":{"enabled":1}}',
      ]) {
        final source = ProbeAdFormatsRemote(
          apply: (next) => applied = next,
          fetch: () async => raw,
        );
        await expectLater(source.fetchBanner(), throwsFormatException);
        expect(applied.banner.enabled, false);
        expect(applied.automatic.enabled, false);
      }
    },
  );
  test(
    'the old local banner switch cannot override Firebase in the QA entry point',
    () {
      final entry = File(
        'tools/android_automatic_ads_probe.dart',
      ).readAsStringSync();
      expect(entry, isNot(contains("path == '/banner-config'")));
      expect(entry, isNot(contains('bool bannerEnabled = true')));
      expect(
        entry,
        contains('ProbeAdFormatsRemote(apply: economy.applyAdvertising)'),
      );
    },
  );
}

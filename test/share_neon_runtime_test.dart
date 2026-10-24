import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/result/share_social_sheet.dart';
import 'package:game_box/features/result/social_share_card.dart';
import 'package:game_box/l10n/app_localizations.dart';

void main() {
  for (final locale in ['ru', 'en']) {
    for (final scale in [1.0, 2.0]) {
      for (final size in [
        const Size(320, 480),
        const Size(390, 844),
        const Size(430, 932),
      ]) {
        testWidgets('S03 $locale ${size.width}x${size.height} text $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(useMaterial3: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    key: const ValueKey('open-share'),
                    onPressed: () => unawaited(
                      showShareSocialSheet(
                        context,
                        timeMs: 21349,
                        riskCount: 16,
                        runSteps: 1998,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('open-share')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final preview = tester.getRect(
            find.byKey(const ValueKey('share-preview')),
          );
          final send = tester.getRect(find.byKey(const ValueKey('share-send')));
          final cancel = tester.getRect(
            find.byKey(const ValueKey('share-cancel')),
          );
          expect(preview.height, greaterThanOrEqualTo(preview.width * .95));
          expect(send.height, greaterThanOrEqualTo(48));
          expect(cancel.height, greaterThanOrEqualTo(44));
          expect(send.bottom, lessThanOrEqualTo(size.height));
          expect(cancel.bottom, lessThanOrEqualTo(size.height));
          if (scale == 1) expect(send.width, lessThan(preview.width * .95));
          expect(
            find.text(locale == 'ru' ? '21.349 с' : '21.349 s'),
            findsOneWidget,
          );
          expect(
            find.text(locale == 'ru' ? 'Риск 16' : 'Risk 16'),
            findsOneWidget,
          );
          expect(
            find.text(locale == 'ru' ? 'Шаги 1998' : 'Steps 1998'),
            findsOneWidget,
          );
          final image = tester.widget<Image>(
            find.byKey(const ValueKey('share-scene')),
          );
          expect(image.image, SocialShareCard.imageProvider);
          await tester.ensureVisible(
            find.text(
              locale == 'ru'
                  ? 'Сколько продержитесь вы?'
                  : 'How long can you survive?',
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('share-cancel')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('share-preview')), findsNothing);
          expect(find.byKey(const ValueKey('open-share')), findsOneWidget);
        });
      }
    }
  }
  testWidgets('S03 long data wraps safely and optional values stay absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: SingleChildScrollView(
                child: SocialShareCard(
                  appTitle: 'Untouch',
                  timeLabel: '86400.000',
                  riskCount: 9999999,
                  runSteps: 9999999,
                  boast: 'How long can you survive?',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Risk 9999999'), findsOneWidget);
    expect(find.text('Steps 9999999'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SocialShareCard(
            appTitle: 'Untouch',
            timeLabel: '0.000',
            boast: 'How long can you survive?',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Risk'), findsNothing);
    expect(find.textContaining('Steps'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

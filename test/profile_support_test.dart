import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/l10n/app_localizations.dart';
import 'package:game_box/ui/profile_support.dart';

void main() {
  for (final dark in [false, true]) {
    for (final language in ['ru', 'en']) {
      testWidgets(
        '$language dark$dark support fits 320, opens public pages, copies ID and handles errors',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 560));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final calls = <MethodCall>[];
          var fail = false;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            ProfileSupport.channel,
            (call) async {
              calls.add(call);
              if (fail) throw PlatformException(code: 'browser_unavailable');
              return null;
            },
          );
          String? copied;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            },
          );
          addTearDown(() {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              ProfileSupport.channel,
              null,
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
          });
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView(
                  children: [
                    ProfileSupport(playerId: 'android:123', dark: dark),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final page in ['privacy', 'deletion', 'support']) {
            final button = find.byKey(ValueKey('profile-$page'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(calls.last.method, 'openPage');
            expect(calls.last.arguments, {'page': page, 'language': language});
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('profile-copy-id')),
          );
          await tester.tap(find.byKey(const ValueKey('profile-copy-id')));
          await tester.pumpAndSettle();
          expect(copied, 'android:123');
          expect(calls.length, 3);
          fail = true;
          await tester.ensureVisible(
            find.byKey(const ValueKey('profile-deletion')),
          );
          await tester.tap(find.byKey(const ValueKey('profile-deletion')));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              language == 'ru' ? 'Не удалось открыть' : 'Could not open',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

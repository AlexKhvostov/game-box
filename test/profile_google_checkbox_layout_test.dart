import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'blue_glass_profile_test.dart' as fixture;

void main() {
  for (final lang in ['ru', 'en']) {
    for (final size in [const Size(390, 844), const Size(320, 480)]) {
      for (final linked in [false, true]) {
        for (final hidden in linked ? [false, true] : [false]) {
          testWidgets(
            'Google right control $lang $size linked$linked hidden$hidden',
            (tester) async {
              final account = fixture.ProfileTestAccount()
                ..id = 'qa:profile'
                ..nickname = 'MintPlayer'
                ..googleLinked = linked
                ..hideGoogleAccount = hidden
                ..googleName = 'Fixture Player'
                ..googleEmail = 'fixture@example.invalid';
              await fixture.mountProfile(
                tester,
                language: lang,
                size: size,
                scale: 2,
                linked: linked,
                fixtureAccount: account,
              );
              final panel = find.byKey(
                const ValueKey('profile-google-setting'),
              );
              await tester.scrollUntilVisible(
                panel,
                60,
                scrollable: find
                    .descendant(
                      of: find.byKey(const ValueKey('profile-content')),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              final checkbox = find.byKey(
                const ValueKey('profile-google-private'),
              );
              expect(
                find.byKey(const ValueKey('profile-ranking-privacy')),
                findsNothing,
              );
              expect(
                find.text(
                  lang == 'ru'
                      ? 'Отображение в рейтинге'
                      : 'Leaderboard visibility',
                ),
                findsNothing,
              );
              if (linked) {
                expect(
                  find.descendant(of: panel, matching: checkbox),
                  findsOneWidget,
                );
                await tester.ensureVisible(checkbox);
                final status = tester.getRect(
                  find.byKey(const ValueKey('profile-google-status')),
                );
                final details = tester.getRect(
                  find.byKey(const ValueKey('profile-google-name')),
                );
                final group = find.byKey(
                  const ValueKey('profile-google-privacy-group'),
                );
                final hint = find.byKey(
                  const ValueKey('profile-google-privacy-hint'),
                );
                final control = tester.getRect(checkbox);
                final comment = tester.getRect(hint);
                expect(
                  find.descendant(of: group, matching: checkbox),
                  findsOneWidget,
                );
                expect(
                  find.descendant(of: group, matching: hint),
                  findsOneWidget,
                );
                expect(control.top, greaterThanOrEqualTo(details.bottom));
                expect(control.top, greaterThanOrEqualTo(status.bottom));
                // Approved compact Google card keeps the full privacy explanation
                // inside the switch tile instead of adding a separate row.
                expect(control.contains(comment.topLeft), isTrue);
                expect(control.contains(comment.bottomRight), isTrue);
                expect(tester.getRect(panel).contains(control.center), true);
                expect(
                  find.byKey(const ValueKey('profile-google-link')),
                  findsNothing,
                );
              } else {
                expect(checkbox, findsNothing);
                final connect = find.byKey(
                  const ValueKey('profile-google-link'),
                );
                expect(
                  find.descendant(of: panel, matching: connect),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
}

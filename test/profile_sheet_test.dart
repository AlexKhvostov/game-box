import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_box/app/theme.dart';
import 'package:game_box/data/economy_store.dart';
import 'package:game_box/data/mobile_account.dart';
import 'package:game_box/data/player_preferences.dart';
import 'package:game_box/features/profile/profile_screen.dart';

void main() {
  testWidgets('profile fits small screen, edits nickname and persists sound', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final economy = EconomyStore();
    await economy.load();
    final preferences = PlayerPreferences();
    await preferences.load();
    final account = _ProfileAccount()
      ..id = 'android:1'
      ..nickname = 'user00000001';
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: economy),
          ChangeNotifierProvider.value(value: preferences),
          ChangeNotifierProvider<MobileAccount>.value(value: account),
        ],
        child: MaterialApp(
          theme: buildGameTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProfileSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('profile-nickname-input'));
    expect(tester.widget<TextField>(input).controller!.text, 'user00000001');
    expect(find.byKey(const ValueKey('profile-nickname-save')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-nickname-save')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    final save = find.byKey(const ValueKey('profile-nickname-save'));
    final inputRect = tester.getRect(input);
    final saveRect = tester.getRect(save);
    expect(
      find.byKey(const ValueKey('profile-nickname-message')),
      findsNothing,
    );
    expect(saveRect.left, greaterThan(inputRect.right));
    expect(saveRect.top, inputRect.top);
    await tester.tap(input);
    await tester.enterText(input, 'abcd');
    await tester.pumpAndSettle();
    expect(find.text('Use 5–40 characters'), findsOneWidget);
    // Validation is below the input; a compact sheet may grow to show it.
    expect(tester.getRect(input).size, inputRect.size);
    expect(tester.getRect(save).size, saveRect.size);
    expect(tester.getRect(save).top, tester.getRect(input).top);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('profile-nickname-message')))
          .top,
      greaterThanOrEqualTo(tester.getRect(input).bottom),
    );
    expect(account.renameCalls, 0);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(input, 'TakenName');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-nickname-save')));
    await tester.pumpAndSettle();
    expect(find.text('Nickname taken. Choose another.'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(tester.getRect(save).size, saveRect.size);
    expect(tester.getRect(input).size, inputRect.size);
    expect(account.renameCalls, 1);

    expect(tester.widget<TextField>(input).controller!.text, 'TakenName');
    expect(account.nickname, 'user00000001');
    await tester.enterText(input, 'abcde');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-nickname-save')));
    await tester.pumpAndSettle();
    expect(account.nickname, 'abcde');
    expect(account.renameCalls, 2);
    expect(find.byKey(const ValueKey('profile-nickname-save')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-nickname-save')),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('Sounds'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-sound-switch')));
    await tester.pumpAndSettle();
    expect(preferences.sound, false);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool('device_sound'), false);
    expect(tester.takeException(), isNull);
  });
}

class _ProfileAccount extends MobileAccount {
  int renameCalls = 0;
  @override
  Future<void> rename(String name) async {
    renameCalls++;
    if (name == 'TakenName') throw const MobileApiError('nickname_taken');
    nickname = name;
    notifyListeners();
  }
}

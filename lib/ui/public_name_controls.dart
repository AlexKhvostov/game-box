import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mobile_account.dart';
import 'game_ui.dart';

final _rulesPrompts = Expando<Future<bool>>();

Future<bool> ensureCommunityRules(
  BuildContext context,
  MobileAccount account,
) async {
  if (account.communityRulesVersion >= 1) return true;
  var pending = _rulesPrompts[account];
  if (pending == null) {
    final owner = account.id;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    pending = () async {
      final accepted = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        barrierColor: GameUi.modalBarrier,
        builder: (c) => AlertDialog(
          key: const ValueKey('community-rules'),
          title: Text(ru ? 'Правила публичных имён' : 'Public name rules'),
          content: SingleChildScrollView(
            child: Text(
              ru
                  ? 'Ник и открытое имя Google видны другим игрокам.\n\nНе используйте оскорбления, травлю, угрозы, дискриминацию, сексуальный контент и призывы к насилию. Не публикуйте чужие личные данные, контакты и рекламу. Не выдавайте себя за другого человека или администратора.\n\nНа имя можно пожаловаться или скрыть его. Администратор может скрыть нарушающее правила имя; игра, результаты и баланс сохраняются.\n\nНажимая «Принять правила», вы соглашаетесь соблюдать эти правила.'
                  : 'Your nickname and public Google name are visible to other players.\n\nDo not use insults, bullying, threats, discrimination, sexual content or calls for violence. Do not publish personal contact details, other people’s private data or advertising. Do not impersonate another person or an administrator.\n\nPlayers can report or hide names. An administrator may hide a name that breaks these rules; gameplay, scores and balances remain available.\n\nBy tapping “Accept rules”, you agree to follow these rules.',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('community-rules-cancel'),
              onPressed: () => Navigator.pop(c, false),
              child: Text(ru ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              key: const ValueKey('community-rules-accept'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(ru ? 'Принять правила' : 'Accept rules'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted || account.id != owner) {
        return false;
      }
      await account.acceptCommunityRules();
      return account.id == owner;
    }();
    _rulesPrompts[account] = pending;
  }
  try {
    return await pending;
  } finally {
    _rulesPrompts[account] = null;
  }
}

String publicPlayerName(BuildContext context, String? uid, String name) {
  if (context.watch<MobileAccount?>()?.isPlayerHidden(uid) != true) return name;
  return Localizations.localeOf(context).languageCode == 'ru'
      ? 'Скрытое имя'
      : 'Hidden name';
}

bool _canAct(MobileAccount? account, String? uid) =>
    account?.ready == true &&
    uid != null &&
    uid.startsWith('supabase:') &&
    MobileAccount.validOwner(uid) &&
    uid != account!.id;

Future<void> showPublicNameActions(
  BuildContext context, {
  required String? uid,
  required String name,
}) async {
  final account = context.read<MobileAccount?>();
  if (!_canAct(account, uid)) return;
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final hidden = account!.isPlayerHidden(uid);
  final owner = account.id;
  final action = await showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (c) => SimpleDialog(
      title: Text(hidden ? (ru ? 'Скрытое имя' : 'Hidden name') : name),
      children: [
        SimpleDialogOption(
          key: const ValueKey('public-report'),
          onPressed: () => Navigator.pop(c, 'report'),
          child: Text(ru ? 'Пожаловаться на имя' : 'Report name'),
        ),
        SimpleDialogOption(
          key: const ValueKey('public-hide'),
          onPressed: () => Navigator.pop(c, 'hide'),
          child: Text(
            hidden
                ? (ru ? 'Показать имя' : 'Show name')
                : (ru ? 'Скрыть имя у меня' : 'Hide name for me'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c),
          child: Text(ru ? 'Отмена' : 'Cancel'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted || account.id != owner) return;
  try {
    if (action == 'hide') {
      await account.hidePublicName(uid!, !hidden);
    } else {
      const reasons = {
        'offensive_name': [
          'Оскорбления или неприемлемое имя',
          'Offensive or inappropriate name',
        ],
        'personal_data': [
          'Личные данные или контакты',
          'Personal data or contact details',
        ],
        'impersonation': ['Выдаёт себя за другого', 'Impersonation'],
        'other': ['Другое нарушение', 'Another violation'],
      };
      final reason = await showDialog<String>(
        context: context,
        useRootNavigator: false,
        builder: (c) => SimpleDialog(
          title: Text(ru ? 'Причина жалобы' : 'Report reason'),
          children: [
            for (final entry in reasons.entries)
              SimpleDialogOption(
                key: ValueKey('report-${entry.key}'),
                onPressed: () => Navigator.pop(c, entry.key),
                child: Text(entry.value[ru ? 0 : 1]),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c),
              child: Text(ru ? 'Отмена' : 'Cancel'),
            ),
          ],
        ),
      );
      if (reason == null || !context.mounted || account.id != owner) return;
      await account.reportPublicName(uid!, reason);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          action == 'report'
              ? (ru
                    ? 'Жалоба отправлена администратору.'
                    : 'Report sent to the administrator.')
              : (ru
                    ? 'Отображение имени изменено. Места и результаты сохранены.'
                    : 'Name visibility updated. Ranks and scores are unchanged.'),
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      final code = error is MobileApiError ? error.code : '';
      final message = switch (code) {
        'reports_daily_limit' =>
          ru
              ? 'На сегодня лимит жалоб исчерпан. Повторите завтра.'
              : 'The daily report limit is reached. Try tomorrow.',
        'hidden_names_limit' =>
          ru
              ? 'Можно скрыть до 200 имён. Очистите список в профиле.'
              : 'You can hide up to 200 names. Clear the list in Profile.',
        'profile_changed' =>
          ru
              ? 'Профиль изменился. Откройте имя игрока заново.'
              : 'Your profile changed. Open the player name again.',
        _ =>
          ru
              ? 'Не удалось сохранить. Проверьте сеть и повторите.'
              : 'Could not save. Check your connection and retry.',
      };
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class PublicNameActions extends StatelessWidget {
  const PublicNameActions({
    super.key,
    required this.uid,
    required this.name,
    this.compact = false,
  });
  final String? uid;
  final String name;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (!_canAct(context.watch<MobileAccount?>(), uid)) {
      return const SizedBox.shrink();
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final label = ru ? 'Жалоба / скрыть имя' : 'Report / hide name';
    return compact
        ? IconButton(
            tooltip: label,
            onPressed: () =>
                showPublicNameActions(context, uid: uid, name: name),
            icon: const Icon(Icons.more_horiz),
          )
        : TextButton.icon(
            key: const ValueKey('public-name-actions'),
            onPressed: () =>
                showPublicNameActions(context, uid: uid, name: name),
            icon: const Icon(Icons.flag_outlined),
            label: Text(label),
          );
  }
}

class HiddenNamesSetting extends StatelessWidget {
  const HiddenNamesSetting({super.key});
  @override
  Widget build(BuildContext context) {
    final account = context.watch<MobileAccount?>();
    if (account == null || account.hiddenPlayers.isEmpty) {
      return const SizedBox.shrink();
    }
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return TextButton(
      key: const ValueKey('hidden-names-reset'),
      onPressed: account.busy
          ? null
          : () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(
                    ru ? 'Показать скрытые имена?' : 'Show hidden names?',
                  ),
                  content: Text(
                    ru
                        ? 'Список скрытых имён очистится. Имена можно снова скрыть в рейтинге.'
                        : 'This clears your hidden-name list. You can hide names again in the ranking.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(ru ? 'Отмена' : 'Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(ru ? 'Показать все' : 'Show all'),
                    ),
                  ],
                ),
              );
              if (yes != true || !context.mounted) return;
              try {
                await account.resetHiddenNames();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        ru
                            ? 'Не удалось сохранить. Повторите позже.'
                            : 'Could not save. Please retry later.',
                      ),
                    ),
                  );
                }
              }
            },
      child: Text(
        ru
            ? 'Скрытые имена: ${account.hiddenPlayers.length} · показать все'
            : 'Hidden names: ${account.hiddenPlayers.length} · show all',
      ),
    );
  }
}

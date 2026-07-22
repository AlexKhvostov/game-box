import '../domain/economy_config.dart';
import 'app_localizations.dart';

/// Локализованные подписи earn / shop по id (RC хранит id + reward).
abstract final class L10nCatalog {
  static String earnTitle(AppLocalizations l10n, EarnAction a) {
    return switch (a.id) {
      'watch_ad' => l10n.earnWatchAd,
      'social_post' => l10n.earnSocialPost,
      'enable_notifications' => l10n.earnNotifications,
      'rate_app' => l10n.earnRateApp,
      'invite_friend' => l10n.earnInviteFriend,
      _ => a.title.isEmpty ? l10n.earnReward : a.title,
    };
  }

  static String earnSubtitle(AppLocalizations l10n, EarnAction a) {
    return switch (a.id) {
      'watch_ad' => l10n.earnWatchAdSub,
      'social_post' => l10n.earnSocialPostSub,
      'enable_notifications' => l10n.earnNotificationsSub,
      'rate_app' => l10n.earnRateAppSub,
      'invite_friend' => l10n.earnInviteFriendSub,
      _ => a.subtitle,
    };
  }

  static String packTitle(AppLocalizations l10n, String id) {
    return switch (id) {
      'pack_s' => l10n.packHandful,
      'pack_m' => l10n.packStack,
      'pack_l' => l10n.packChest,
      'pack_xl' => l10n.packVault,
      _ => id,
    };
  }

  static String? packBadge(AppLocalizations l10n, String? badgeKey) {
    return switch (badgeKey) {
      'deal' => l10n.badgeDeal,
      'best' => l10n.badgeBest,
      'max' => l10n.badgeMax,
      null || '' => null,
      _ => badgeKey,
    };
  }
}

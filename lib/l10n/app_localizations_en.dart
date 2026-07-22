// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Game Box';

  @override
  String get tapToStart => 'Tap to start';

  @override
  String get noLivesOpenCrystals => 'Out of lives — open crystals';

  @override
  String get noLivesTitle => 'Out of lives';

  @override
  String get noLivesBody =>
      'Exchange crystals or earn more by tapping the crystal balance above.';

  @override
  String livesGained(int count) {
    return '+$count lives';
  }

  @override
  String buyLivesButton(int lives, int cost) {
    return '+$lives lives · $cost crystals';
  }

  @override
  String get toCrystals => 'Get crystals';

  @override
  String get seconds => 'seconds';

  @override
  String get newScore => 'New score';

  @override
  String rankFaster(int place, int percent) {
    return '#$place · faster than $percent%';
  }

  @override
  String get share => 'Share';

  @override
  String get ok => 'OK';

  @override
  String get saveScoreTitle => 'Save score';

  @override
  String saveScoreSubtitle(String time) {
    return '$time s · top 20';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get leaderboardEmpty => 'Empty so far — be the first';

  @override
  String get enterName => 'Enter a name';

  @override
  String savedPlace(int place) {
    return 'Saved · #$place';
  }

  @override
  String get saving => 'Saving…';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get crystals => 'Crystals';

  @override
  String get crystalsGenitive => 'crystals';

  @override
  String giftToast(int count) {
    return 'Gift! +$count crystals';
  }

  @override
  String get daily => 'Daily';

  @override
  String get earn => 'Earn';

  @override
  String get earnPreviewHint => 'Preview until ads & SDKs are connected';

  @override
  String get shop => 'Shop';

  @override
  String get plusActive => 'Plus active';

  @override
  String get plusCancel => 'Cancel subscription';

  @override
  String plusButton(String price) {
    return 'Plus · $price';
  }

  @override
  String get plusToast => 'Plus · Daily ×2';

  @override
  String get plusCancelledToast => 'Plus turned off';

  @override
  String get plusManageTitle => 'Manage Plus';

  @override
  String get plusManageSubtitle =>
      'Subscription perks for the game. This is a local preview — real billing will go through Google Play / App Store later.';

  @override
  String get plusManageBenefitAds => 'No ads';

  @override
  String get plusManageBenefitDaily => '×2 crystals on the Daily bonus';

  @override
  String plusManagePrice(String price) {
    return 'Price: $price';
  }

  @override
  String plusManageNextCharge(String date) {
    return 'Next charge: $date';
  }

  @override
  String get resetDataTitle => 'Reset all data?';

  @override
  String get resetDataBody =>
      'Progress, crystals, lives, records and Plus will be cleared. The app will look like a fresh install.';

  @override
  String get resetDataDone => 'Data reset';

  @override
  String giftCrystals(int count) {
    return '+$count crystals';
  }

  @override
  String get claimGift => 'Claim gift';

  @override
  String dayReward(int day, int amount) {
    return 'Day $day · +$amount';
  }

  @override
  String get dailyStreakHint => 'Claim every day to keep your streak';

  @override
  String dailyStreakActive(int days) {
    return 'Streak $days days · miss a day = back to day 1';
  }

  @override
  String premiumTimesBase(int base, String mult) {
    return '$base × $mult';
  }

  @override
  String premiumTimesLocked(String mult) {
    return '×$mult with Plus';
  }

  @override
  String get claimed => 'Claimed';

  @override
  String get claim => 'Claim';

  @override
  String dailyToast(int count) {
    return 'Daily +$count';
  }

  @override
  String crystalsPlus(int count) {
    return '+$count crystals';
  }

  @override
  String get earnWatchAd => 'Watch an ad';

  @override
  String get earnWatchAdSub => 'Short video';

  @override
  String get earnSocialPost => 'Social post';

  @override
  String get earnSocialPostSub => 'Tell your friends';

  @override
  String get earnNotifications => 'Notifications';

  @override
  String get earnNotificationsSub => 'Allow push alerts';

  @override
  String get earnRateApp => 'Rate the game';

  @override
  String get earnRateAppSub => 'Stars in the store';

  @override
  String get earnInviteFriend => 'Invite a friend';

  @override
  String get earnInviteFriendSub => 'Share a link';

  @override
  String get earnReward => 'Reward';

  @override
  String get packHandful => 'Handful';

  @override
  String get packStack => 'Stack';

  @override
  String get packChest => 'Chest';

  @override
  String get packVault => 'Vault';

  @override
  String get badgeDeal => 'Deal';

  @override
  String get badgeBest => 'Best price';

  @override
  String get badgeMax => 'Max';

  @override
  String get playerFallback => 'Player';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get online => 'online';

  @override
  String get offline => 'offline';

  @override
  String get colPlace => '#';

  @override
  String get colPlayer => 'Player';

  @override
  String get colCountry => 'CC';

  @override
  String get colTime => 'Time';

  @override
  String get tabDaily => 'Daily';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabEarn => 'Earn';

  @override
  String get plusTitle => 'Plus';

  @override
  String get plusBenefits => 'No ads';

  @override
  String get plusDailyBoost => 'on Daily';

  @override
  String get giftReady => 'Ready!';

  @override
  String get tapHintPlayful => 'Tap anywhere to dodge';

  @override
  String livesBalance(int count) {
    return '$count lives';
  }

  @override
  String get colDate => 'Date';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodAll => 'All';

  @override
  String get livesConvertTitle => 'Get lives';

  @override
  String get livesConvertSubtitle => 'Exchange crystals for lives';

  @override
  String livesPackLabel(int count) {
    return '+$count lives';
  }

  @override
  String get shopFree => 'FREE';

  @override
  String get shopWatchAd => 'Watch & get';

  @override
  String get shopWatchAdSub => 'Short video · free crystals';

  @override
  String get yourPlacesTitle => 'Your places';

  @override
  String get shareRankHint => 'Where this score ranks if you save it';

  @override
  String get rankSliceToday => 'Today';

  @override
  String get rankSliceWeek => 'This week';

  @override
  String get rankSliceMonth => 'This month';

  @override
  String get rankSliceYear => 'This year';

  @override
  String get rankSliceAll => 'All time';

  @override
  String get youGhost => 'You';

  @override
  String get periodMine => 'Mine';

  @override
  String get colAttempt => 'Attempt';

  @override
  String get myAttemptsEmpty => 'No runs yet — play a round';

  @override
  String get attemptShared => 'Shared';

  @override
  String get attemptLocal => 'Not shared';
}

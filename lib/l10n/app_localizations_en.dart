// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Untouch';

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
  String rankToday(int percent) {
    return 'Better than $percent% of players!';
  }

  @override
  String get share => 'Save';

  @override
  String get shareSocial => 'Share';

  @override
  String shareBoast(String time, String app) {
    return 'I lasted ${time}s in $app!';
  }

  @override
  String get shareSend => 'Send';

  @override
  String shareScoreCaption(String app, String time) {
    return '$app — ${time}s';
  }

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
  String get plusActiveShort => 'On';

  @override
  String get plusNoAdsShort => 'No ads';

  @override
  String get plusCrystalsDoubleShort => '×2';

  @override
  String get playInfoEnemies => 'Enemies';

  @override
  String get playInfoSpeed => 'Speed';

  @override
  String get playInfoRun => 'Run';

  @override
  String get playInfoNear => 'Risk';

  @override
  String riskCrystalHint(int every, int reward) {
    return '$every risks = $reward crystal';
  }

  @override
  String runCrystalHint(int every, int reward) {
    return '$every run = $reward crystal';
  }

  @override
  String riskCrystalsEarned(int count) {
    return '+$count';
  }

  @override
  String get playInfoScore => 'Score';

  @override
  String get attemptTapToSave => 'Tap to save';

  @override
  String get earn => 'Earn';

  @override
  String get earnPreviewHint => 'Preview until ads & SDKs are connected';

  @override
  String get shop => 'Shop';

  @override
  String get plusActive => 'Boost active';

  @override
  String get plusCancel => 'Cancel subscription';

  @override
  String plusButton(String price) {
    return 'Boost · $price';
  }

  @override
  String get plusToast => 'Boost · Daily ×2';

  @override
  String get plusCancelledToast => 'Boost turned off';

  @override
  String get plusManageTitle => 'Manage Boost';

  @override
  String get plusOfferTitle => 'Boost subscription';

  @override
  String get plusOfferSubtitle =>
      'Boost is a weekly subscription for \$1. You get no ads and ×2 crystals on the Daily bonus. Cancel anytime in this window (billing via Google Play / App Store later).';

  @override
  String plusSubscribe(String price) {
    return 'Subscribe · $price';
  }

  @override
  String get plusManageSubtitle =>
      'Boost gives perks in the game. This is a local preview — real billing will go through Google Play / App Store later.';

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
      'Progress, crystals, lives, records and Boost will be cleared. The app will look like a fresh install.';

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
    return '×$mult with Boost';
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
  String get earnInstallBonus => 'Install bonus';

  @override
  String get earnInstallBonusSub => 'Welcome gift for installing';

  @override
  String get earnSurvive10 => 'Survive 10 seconds';

  @override
  String get earnSurvive10Sub => 'Stay alive for 10s in one run';

  @override
  String get earnRecord20 => '20 second record';

  @override
  String get earnRecord20Sub => 'Reach a 20s personal best';

  @override
  String get earnRisks5 => '5 risks in one run';

  @override
  String get earnRisks5Sub => 'Score 5 risks in a single game';

  @override
  String get earnBonusLocked => 'Play to unlock';

  @override
  String earnBonusUnlocked(String title) {
    return 'Unlocked: $title';
  }

  @override
  String get earnUnlockedBannerTap => 'Tap to claim in Earn';

  @override
  String get riskTipHow =>
      'Risk counts when you barely miss an enemy — close, but no touch.';

  @override
  String riskTipConvert(int every, int reward) {
    return 'At the end of the run: every $every risks = $reward crystal(s).';
  }

  @override
  String get runTipHow =>
      'Run is the distance your cube travels during the round.';

  @override
  String runTipConvert(int every, int reward) {
    return 'At the end of the run: every $every run = $reward crystal(s).';
  }

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
  String get colBoosts => 'Boosts';

  @override
  String get tabDaily => 'Daily';

  @override
  String get tabShop => 'Shop';

  @override
  String get tabRent => 'Rent';

  @override
  String get tabEarn => 'Earn';

  @override
  String get plusTitle => 'Boost';

  @override
  String get plusBenefits => 'No ads';

  @override
  String get plusDailyBoost => 'on Daily';

  @override
  String get giftReady => 'Ready!';

  @override
  String tapHintChallenge(int seconds) {
    return 'Can you last $seconds sec?';
  }

  @override
  String tapHintNextChallenge(int seconds) {
    return 'Think you can do $seconds sec?';
  }

  @override
  String get tapHintPlayful => 'Tap and dodge';

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
  String get statLives => 'Lives';

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
  String get shopRentalsTitle => 'Rent';

  @override
  String get rentJumpTitle => 'Jump';

  @override
  String get rentJumpSub => 'Second finger — jump over an enemy';

  @override
  String get rentHelmetTitle => 'Helmet';

  @override
  String get rentHelmetSub => 'Survive one hit per run';

  @override
  String rentHourSub(int minutes) {
    return '$minutes min pack';
  }

  @override
  String rentMinsLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String rentDiscountBadge(int percent) {
    return '−$percent%';
  }

  @override
  String rentActive(String time) {
    return 'Active · $time';
  }

  @override
  String get rentExtend => 'Extend';

  @override
  String get rentBuy => 'Rent';

  @override
  String get rentNotEnough => 'Not enough crystals';

  @override
  String get rentInactive => 'Off';

  @override
  String get jumpRentalNeeded => 'Rent Jump in Shop';

  @override
  String get helmetBroken => 'Helmet shattered';

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
  String get periodMine => 'My attempts';

  @override
  String get colAttempt => 'Attempt';

  @override
  String get myAttemptsEmpty => 'No runs yet — play a round';

  @override
  String get attemptShared => 'Shared';

  @override
  String get attemptLocal => 'Not shared';
}

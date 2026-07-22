import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Box'**
  String get appTitle;

  /// No description provided for @tapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get tapToStart;

  /// No description provided for @noLivesOpenCrystals.
  ///
  /// In en, this message translates to:
  /// **'Out of lives — open crystals'**
  String get noLivesOpenCrystals;

  /// No description provided for @noLivesTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of lives'**
  String get noLivesTitle;

  /// No description provided for @noLivesBody.
  ///
  /// In en, this message translates to:
  /// **'Exchange crystals or earn more by tapping the crystal balance above.'**
  String get noLivesBody;

  /// No description provided for @livesGained.
  ///
  /// In en, this message translates to:
  /// **'+{count} lives'**
  String livesGained(int count);

  /// No description provided for @buyLivesButton.
  ///
  /// In en, this message translates to:
  /// **'+{lives} lives · {cost} crystals'**
  String buyLivesButton(int lives, int cost);

  /// No description provided for @toCrystals.
  ///
  /// In en, this message translates to:
  /// **'Get crystals'**
  String get toCrystals;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @newScore.
  ///
  /// In en, this message translates to:
  /// **'New score'**
  String get newScore;

  /// No description provided for @rankFaster.
  ///
  /// In en, this message translates to:
  /// **'#{place} · faster than {percent}%'**
  String rankFaster(int place, int percent);

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @saveScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Save score'**
  String get saveScoreTitle;

  /// No description provided for @saveScoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{time} s · top 20'**
  String saveScoreSubtitle(String time);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty so far — be the first'**
  String get leaderboardEmpty;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @savedPlace.
  ///
  /// In en, this message translates to:
  /// **'Saved · #{place}'**
  String savedPlace(int place);

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @crystals.
  ///
  /// In en, this message translates to:
  /// **'Crystals'**
  String get crystals;

  /// No description provided for @crystalsGenitive.
  ///
  /// In en, this message translates to:
  /// **'crystals'**
  String get crystalsGenitive;

  /// No description provided for @giftToast.
  ///
  /// In en, this message translates to:
  /// **'Gift! +{count} crystals'**
  String giftToast(int count);

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @earn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get earn;

  /// No description provided for @earnPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Preview until ads & SDKs are connected'**
  String get earnPreviewHint;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @plusActive.
  ///
  /// In en, this message translates to:
  /// **'Plus active'**
  String get plusActive;

  /// No description provided for @plusCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get plusCancel;

  /// No description provided for @plusButton.
  ///
  /// In en, this message translates to:
  /// **'Plus · {price}'**
  String plusButton(String price);

  /// No description provided for @plusToast.
  ///
  /// In en, this message translates to:
  /// **'{brand} Plus · Daily ×2'**
  String plusToast(String brand);

  /// No description provided for @plusCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Plus turned off'**
  String get plusCancelledToast;

  /// No description provided for @plusManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Plus'**
  String get plusManageTitle;

  /// No description provided for @plusManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription perks for the game. This is a local preview — real billing will go through Google Play / App Store later.'**
  String get plusManageSubtitle;

  /// No description provided for @plusManageBenefitAds.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get plusManageBenefitAds;

  /// No description provided for @plusManageBenefitDaily.
  ///
  /// In en, this message translates to:
  /// **'×2 crystals on the Daily bonus'**
  String get plusManageBenefitDaily;

  /// No description provided for @plusManagePrice.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String plusManagePrice(String price);

  /// No description provided for @plusManageNextCharge.
  ///
  /// In en, this message translates to:
  /// **'Next charge: {date}'**
  String plusManageNextCharge(String date);

  /// No description provided for @resetDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all data?'**
  String get resetDataTitle;

  /// No description provided for @resetDataBody.
  ///
  /// In en, this message translates to:
  /// **'Progress, crystals, lives, records and Plus will be cleared. The app will look like a fresh install.'**
  String get resetDataBody;

  /// No description provided for @resetDataDone.
  ///
  /// In en, this message translates to:
  /// **'Data reset'**
  String get resetDataDone;

  /// No description provided for @giftCrystals.
  ///
  /// In en, this message translates to:
  /// **'+{count} crystals'**
  String giftCrystals(int count);

  /// No description provided for @claimGift.
  ///
  /// In en, this message translates to:
  /// **'Claim gift'**
  String get claimGift;

  /// No description provided for @dayReward.
  ///
  /// In en, this message translates to:
  /// **'Day {day} · +{amount}'**
  String dayReward(int day, int amount);

  /// No description provided for @dailyStreakHint.
  ///
  /// In en, this message translates to:
  /// **'Claim every day to keep your streak'**
  String get dailyStreakHint;

  /// No description provided for @dailyStreakActive.
  ///
  /// In en, this message translates to:
  /// **'Streak {days} days · miss a day = back to day 1'**
  String dailyStreakActive(int days);

  /// No description provided for @premiumTimesBase.
  ///
  /// In en, this message translates to:
  /// **'{base} × {mult}'**
  String premiumTimesBase(int base, String mult);

  /// No description provided for @premiumTimesLocked.
  ///
  /// In en, this message translates to:
  /// **'×{mult} Plus'**
  String premiumTimesLocked(String mult);

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @dailyToast.
  ///
  /// In en, this message translates to:
  /// **'Daily +{count}'**
  String dailyToast(int count);

  /// No description provided for @crystalsPlus.
  ///
  /// In en, this message translates to:
  /// **'+{count} crystals'**
  String crystalsPlus(int count);

  /// No description provided for @earnWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad'**
  String get earnWatchAd;

  /// No description provided for @earnWatchAdSub.
  ///
  /// In en, this message translates to:
  /// **'Short video'**
  String get earnWatchAdSub;

  /// No description provided for @earnSocialPost.
  ///
  /// In en, this message translates to:
  /// **'Social post'**
  String get earnSocialPost;

  /// No description provided for @earnSocialPostSub.
  ///
  /// In en, this message translates to:
  /// **'Tell your friends'**
  String get earnSocialPostSub;

  /// No description provided for @earnNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get earnNotifications;

  /// No description provided for @earnNotificationsSub.
  ///
  /// In en, this message translates to:
  /// **'Allow push alerts'**
  String get earnNotificationsSub;

  /// No description provided for @earnRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate the game'**
  String get earnRateApp;

  /// No description provided for @earnRateAppSub.
  ///
  /// In en, this message translates to:
  /// **'Stars in the store'**
  String get earnRateAppSub;

  /// No description provided for @earnInviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get earnInviteFriend;

  /// No description provided for @earnInviteFriendSub.
  ///
  /// In en, this message translates to:
  /// **'Share a link'**
  String get earnInviteFriendSub;

  /// No description provided for @earnReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get earnReward;

  /// No description provided for @packHandful.
  ///
  /// In en, this message translates to:
  /// **'Handful'**
  String get packHandful;

  /// No description provided for @packStack.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get packStack;

  /// No description provided for @packChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get packChest;

  /// No description provided for @packVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get packVault;

  /// No description provided for @badgeDeal.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get badgeDeal;

  /// No description provided for @badgeBest.
  ///
  /// In en, this message translates to:
  /// **'Best price'**
  String get badgeBest;

  /// No description provided for @badgeMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get badgeMax;

  /// No description provided for @playerFallback.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerFallback;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get offline;

  /// No description provided for @colPlace.
  ///
  /// In en, this message translates to:
  /// **'#'**
  String get colPlace;

  /// No description provided for @colPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get colPlayer;

  /// No description provided for @colCountry.
  ///
  /// In en, this message translates to:
  /// **'CC'**
  String get colCountry;

  /// No description provided for @colTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get colTime;

  /// No description provided for @tabDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get tabDaily;

  /// No description provided for @tabShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get tabShop;

  /// No description provided for @tabEarn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get tabEarn;

  /// No description provided for @plusTitle.
  ///
  /// In en, this message translates to:
  /// **'{brand} Plus'**
  String plusTitle(String brand);

  /// No description provided for @plusBenefits.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get plusBenefits;

  /// No description provided for @plusDailyBoost.
  ///
  /// In en, this message translates to:
  /// **'on Daily'**
  String get plusDailyBoost;

  /// No description provided for @giftReady.
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get giftReady;

  /// No description provided for @tapHintPlayful.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to dodge'**
  String get tapHintPlayful;

  /// No description provided for @livesBalance.
  ///
  /// In en, this message translates to:
  /// **'{count} lives'**
  String livesBalance(int count);

  /// No description provided for @colDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get colDate;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @periodAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get periodAll;

  /// No description provided for @livesConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Get lives'**
  String get livesConvertTitle;

  /// No description provided for @livesConvertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange crystals for lives'**
  String get livesConvertSubtitle;

  /// No description provided for @livesPackLabel.
  ///
  /// In en, this message translates to:
  /// **'+{count} lives'**
  String livesPackLabel(int count);

  /// No description provided for @shopFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get shopFree;

  /// No description provided for @shopWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch & get'**
  String get shopWatchAd;

  /// No description provided for @shopWatchAdSub.
  ///
  /// In en, this message translates to:
  /// **'Short video · free crystals'**
  String get shopWatchAdSub;

  /// No description provided for @yourPlacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your places'**
  String get yourPlacesTitle;

  /// No description provided for @shareRankHint.
  ///
  /// In en, this message translates to:
  /// **'Where this score ranks if you save it'**
  String get shareRankHint;

  /// No description provided for @rankSliceToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rankSliceToday;

  /// No description provided for @rankSliceWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get rankSliceWeek;

  /// No description provided for @rankSliceMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get rankSliceMonth;

  /// No description provided for @rankSliceYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get rankSliceYear;

  /// No description provided for @rankSliceAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rankSliceAll;

  /// No description provided for @youGhost.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youGhost;

  /// No description provided for @periodMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get periodMine;

  /// No description provided for @colAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt'**
  String get colAttempt;

  /// No description provided for @myAttemptsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No runs yet — play a round'**
  String get myAttemptsEmpty;

  /// No description provided for @attemptShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get attemptShared;

  /// No description provided for @attemptLocal.
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get attemptLocal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

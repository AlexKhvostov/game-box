// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Untouch';

  @override
  String get tapToStart => 'Коснитесь, чтобы начать';

  @override
  String get noLivesOpenCrystals => 'Нет жизней — откройте кристалы';

  @override
  String get noLivesTitle => 'Нет жизней';

  @override
  String get noLivesBody =>
      'Обменяйте кристалы или заработайте их, нажав на баланс сверху.';

  @override
  String livesGained(int count) {
    return '+$count жизней';
  }

  @override
  String buyLivesButton(int lives, int cost) {
    return '+$lives жизней · $cost кристалов';
  }

  @override
  String get toCrystals => 'К кристалам';

  @override
  String get seconds => 'секунд';

  @override
  String get newScore => 'Новый результат';

  @override
  String rankFaster(int place, int percent) {
    return '#$place · быстрее $percent%';
  }

  @override
  String rankToday(int percent) {
    return 'Лучше $percent% игроков!';
  }

  @override
  String get share => 'Сохранить';

  @override
  String get shareSocial => 'Поделиться';

  @override
  String shareBoast(String time, String app) {
    return 'Я продержался $time сек в $app!';
  }

  @override
  String get shareSend => 'Отправить';

  @override
  String shareScoreCaption(String app, String time) {
    return '$app — $time с';
  }

  @override
  String get ok => 'OK';

  @override
  String get saveScoreTitle => 'Сохранить результат';

  @override
  String saveScoreSubtitle(String time) {
    return '$time с · топ 20';
  }

  @override
  String get nameLabel => 'Имя';

  @override
  String get leaderboardEmpty => 'Пока пусто — будьте первым';

  @override
  String get enterName => 'Введите имя';

  @override
  String savedPlace(int place) {
    return 'Сохранено · #$place';
  }

  @override
  String get saving => 'Сохранение…';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get crystals => 'Кристалы';

  @override
  String get crystalsGenitive => 'кристалов';

  @override
  String giftToast(int count) {
    return 'Подарок! +$count кристалов';
  }

  @override
  String get daily => 'Ежедневно';

  @override
  String get plusActiveShort => 'Вкл';

  @override
  String get plusNoAdsShort => 'Без рекламы';

  @override
  String get plusCrystalsDoubleShort => '×2';

  @override
  String get playInfoEnemies => 'Враги';

  @override
  String get playInfoSpeed => 'Скор.';

  @override
  String get playInfoRun => 'Пробег';

  @override
  String get playInfoNear => 'Риск';

  @override
  String riskCrystalHint(int every, int reward) {
    return '$every рисков = $reward кристалл';
  }

  @override
  String runCrystalHint(int every, int reward) {
    return '$every пробега = $reward кристалл';
  }

  @override
  String riskCrystalsEarned(int count) {
    return '+$count';
  }

  @override
  String get playInfoScore => 'Очки';

  @override
  String get attemptTapToSave => 'Нажмите, чтобы сохранить';

  @override
  String get earn => 'Заработать';

  @override
  String get earnPreviewHint => 'Заглушки до подключения рекламы и SDK';

  @override
  String get shop => 'Магазин';

  @override
  String get plusActive => 'Boost активен';

  @override
  String get plusCancel => 'Отменить подписку';

  @override
  String plusButton(String price) {
    return 'Boost · $price';
  }

  @override
  String get plusToast => 'Boost · ежедневно ×2';

  @override
  String get plusCancelledToast => 'Boost отключён';

  @override
  String get plusManageTitle => 'Управление Boost';

  @override
  String get plusOfferTitle => 'Подписка Boost';

  @override
  String get plusOfferSubtitle =>
      'Boost — еженедельная подписка за \$1. Без рекламы и ×2 кристаллы в ежедневном бонусе. Отменить можно в этом окне (оплата через Google Play / App Store — позже).';

  @override
  String plusSubscribe(String price) {
    return 'Подписаться · $price';
  }

  @override
  String get plusManageSubtitle =>
      'Boost даёт бонусы в игре. Пока это локальный preview — после подключения магазина списание пойдёт через Google Play / App Store.';

  @override
  String get plusManageBenefitAds => 'Без рекламы';

  @override
  String get plusManageBenefitDaily => '×2 кристаллы в ежедневном бонусе';

  @override
  String plusManagePrice(String price) {
    return 'Стоимость: $price';
  }

  @override
  String plusManageNextCharge(String date) {
    return 'Следующее списание: $date';
  }

  @override
  String get resetDataTitle => 'Сбросить данные?';

  @override
  String get resetDataBody =>
      'Прогресс, кристалы, жизни, рекорды и Boost будут очищены. Приложение станет как после первой установки.';

  @override
  String get resetDataDone => 'Данные сброшены';

  @override
  String giftCrystals(int count) {
    return '+$count кристалла';
  }

  @override
  String get claimGift => 'Забрать подарок';

  @override
  String dayReward(int day, int amount) {
    return 'День $day · +$amount';
  }

  @override
  String get dailyStreakHint => 'Забирайте награду каждый день подряд';

  @override
  String dailyStreakActive(int days) {
    return 'Серия $days дн. · пропуск сбрасывает на день 1';
  }

  @override
  String premiumTimesBase(int base, String mult) {
    return '$base × $mult';
  }

  @override
  String premiumTimesLocked(String mult) {
    return '×$mult с Boost';
  }

  @override
  String get claimed => 'Получено';

  @override
  String get claim => 'Получить';

  @override
  String dailyToast(int count) {
    return 'Ежедневно +$count';
  }

  @override
  String crystalsPlus(int count) {
    return '+$count кристалов';
  }

  @override
  String get earnWatchAd => 'Смотреть рекламу';

  @override
  String get earnWatchAdSub => 'Короткий ролик';

  @override
  String get earnSocialPost => 'Пост в соцсети';

  @override
  String get earnSocialPostSub => 'Расскажите друзьям';

  @override
  String get earnNotifications => 'Уведомления';

  @override
  String get earnNotificationsSub => 'Разрешить пуши';

  @override
  String get earnRateApp => 'Оценить игру';

  @override
  String get earnRateAppSub => 'Звёзды в магазине';

  @override
  String get earnInviteFriend => 'Пригласить друга';

  @override
  String get earnInviteFriendSub => 'Поделиться ссылкой';

  @override
  String get earnInstallBonus => 'Бонус за установку';

  @override
  String get earnInstallBonusSub => 'Приз за скачивание игры';

  @override
  String get earnSurvive10 => 'Продержаться 10 секунд';

  @override
  String get earnSurvive10Sub => '10 секунд в одной партии';

  @override
  String get earnRecord20 => 'Рекорд 20 секунд';

  @override
  String get earnRecord20Sub => 'Личный рекорд от 20 секунд';

  @override
  String get earnRisks5 => '5 рисков за партию';

  @override
  String get earnRisks5Sub => 'Набрать 5 рисков в одной игре';

  @override
  String get earnBonusLocked => 'Откроется в игре';

  @override
  String earnBonusUnlocked(String title) {
    return 'Открыто: $title';
  }

  @override
  String get earnUnlockedBannerTap => 'Нажмите, чтобы забрать в Earn';

  @override
  String get riskTipHow =>
      'Риск засчитывается, когда вы едва разминулись с врагом — близко, но без касания.';

  @override
  String riskTipConvert(int every, int reward) {
    return 'В конце партии: каждые $every рисков = $reward кристалл(ов).';
  }

  @override
  String get runTipHow =>
      'Пробег — расстояние, которое прошёл ваш кубик за партию.';

  @override
  String runTipConvert(int every, int reward) {
    return 'В конце партии: каждые $every единиц пробега = $reward кристалл(ов).';
  }

  @override
  String get earnReward => 'Награда';

  @override
  String get packHandful => 'Горсть';

  @override
  String get packStack => 'Стопка';

  @override
  String get packChest => 'Сундук';

  @override
  String get packVault => 'Сейф';

  @override
  String get badgeDeal => 'Выгодно';

  @override
  String get badgeBest => 'Лучшая цена';

  @override
  String get badgeMax => 'Максимум';

  @override
  String get playerFallback => 'Игрок';

  @override
  String get leaderboardTitle => 'Рейтинг';

  @override
  String get online => 'онлайн';

  @override
  String get offline => 'офлайн';

  @override
  String get colPlace => '#';

  @override
  String get colPlayer => 'Игрок';

  @override
  String get colCountry => 'Стр';

  @override
  String get colTime => 'Время';

  @override
  String get colBoosts => 'Бусты';

  @override
  String get tabDaily => 'Ежедневно';

  @override
  String get tabShop => 'Покупки';

  @override
  String get tabRent => 'Аренда';

  @override
  String get tabEarn => 'Действия';

  @override
  String get plusTitle => 'Boost';

  @override
  String get plusBenefits => 'Без рекламы';

  @override
  String get plusDailyBoost => 'в Daily';

  @override
  String get giftReady => 'Готово!';

  @override
  String tapHintChallenge(int seconds) {
    return 'Продержишься хотя бы $seconds сек?';
  }

  @override
  String tapHintNextChallenge(int seconds) {
    return 'А слабо $seconds сек?';
  }

  @override
  String get tapHintPlayful => 'Коснись и уворачивайся';

  @override
  String livesBalance(int count) {
    return '$count жизней';
  }

  @override
  String get colDate => 'Дата';

  @override
  String get periodDay => 'День';

  @override
  String get periodWeek => 'Неделя';

  @override
  String get periodMonth => 'Месяц';

  @override
  String get periodYear => 'Год';

  @override
  String get periodAll => 'Всё';

  @override
  String get livesConvertTitle => 'Получить жизни';

  @override
  String get livesConvertSubtitle => 'Обменяйте кристалы на жизни';

  @override
  String get statLives => 'Жизни';

  @override
  String livesPackLabel(int count) {
    return '+$count жизней';
  }

  @override
  String get shopFree => 'FREE';

  @override
  String get shopWatchAd => 'Смотри и получи';

  @override
  String get shopWatchAdSub => 'Короткое видео · бесплатно';

  @override
  String get shopRentalsTitle => 'Аренда';

  @override
  String get rentJumpTitle => 'Прыжок';

  @override
  String get rentJumpSub => 'Второй палец — перепрыгнуть врага';

  @override
  String get rentHelmetTitle => 'Шлем';

  @override
  String get rentHelmetSub => 'Один удар без смерти за партию';

  @override
  String rentHourSub(int minutes) {
    return 'Пакет на $minutes мин';
  }

  @override
  String rentMinsLabel(int minutes) {
    return '$minutes мин';
  }

  @override
  String rentDiscountBadge(int percent) {
    return '−$percent%';
  }

  @override
  String rentActive(String time) {
    return 'Активно · $time';
  }

  @override
  String get rentExtend => 'Продлить';

  @override
  String get rentBuy => 'Арендовать';

  @override
  String get rentNotEnough => 'Не хватает кристалов';

  @override
  String get rentInactive => 'Выкл';

  @override
  String get jumpRentalNeeded => 'Арендуйте прыжок в магазине';

  @override
  String get helmetBroken => 'Шлем разбит';

  @override
  String get yourPlacesTitle => 'Ваши места';

  @override
  String get shareRankHint => 'Куда попадёт результат, если сохранить';

  @override
  String get rankSliceToday => 'Сегодня';

  @override
  String get rankSliceWeek => 'На этой неделе';

  @override
  String get rankSliceMonth => 'В этом месяце';

  @override
  String get rankSliceYear => 'В этом году';

  @override
  String get rankSliceAll => 'За всё время';

  @override
  String get youGhost => 'Вы';

  @override
  String get periodMine => 'Мои попытки';

  @override
  String get colAttempt => 'Попытка';

  @override
  String get myAttemptsEmpty => 'Пока пусто — сыграйте раунд';

  @override
  String get attemptShared => 'В рейтинге';

  @override
  String get attemptLocal => 'Не сохранено';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Game Box';

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
  String get share => 'Share';

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
  String get daily => 'Daily';

  @override
  String get earn => 'Заработать';

  @override
  String get earnPreviewHint => 'Заглушки до подключения рекламы и SDK';

  @override
  String get shop => 'Магазин';

  @override
  String get plusActive => 'Plus активна';

  @override
  String plusButton(String price) {
    return 'Plus · $price';
  }

  @override
  String plusToast(String brand) {
    return '$brand Plus · Daily ×2';
  }

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
    return '×$mult Plus';
  }

  @override
  String get claimed => 'Получено';

  @override
  String get claim => 'Получить';

  @override
  String dailyToast(int count) {
    return 'Daily +$count';
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
  String get earnReward => 'Награда';

  @override
  String get packHandful => 'Горсть';

  @override
  String get packStack => 'Стопка';

  @override
  String get packChest => 'Сундук';

  @override
  String get packVault => 'Сокровищница';

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
  String get tabDaily => 'Daily';

  @override
  String get tabShop => 'Покупки';

  @override
  String get tabEarn => 'Действия';

  @override
  String plusTitle(String brand) {
    return '$brand Plus';
  }

  @override
  String get plusBenefits => 'Без рекламы';

  @override
  String get plusDailyBoost => 'в Daily';

  @override
  String get giftReady => 'Готово!';

  @override
  String get tapHintPlayful => 'Коснись экрана и уворачивайся';

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
  String get periodMine => 'Мои';

  @override
  String get colAttempt => 'Попытка';

  @override
  String get myAttemptsEmpty => 'Пока пусто — сыграйте раунд';

  @override
  String get attemptShared => 'В рейтинге';

  @override
  String get attemptLocal => 'Не сохранено';
}

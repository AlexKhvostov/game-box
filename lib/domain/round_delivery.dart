abstract final class RoundDelivery {
  static bool rulesError(String? code) => const {
    'rules_changed',
    'revision_mismatch',
    'economy_update_required',
    'update_required',
  }.contains(code);
  static String message(String code, {required bool ru}) {
    if (rulesError(code)) {
      return ru
          ? 'Правила обновились. Перезапустите игру.'
          : 'Rules changed. Please restart the game.';
    }
    if (code == 'insufficient_energy') {
      return ru
          ? 'Недостаточно энергии на сервере. Результат сохранён на телефоне.'
          : 'The server balance is too low. The result is kept on this device.';
    }
    return ru
        ? 'Результат не принят сервером. Сохранён на телефоне.'
        : 'The server did not accept this result. It is kept on this device.';
  }
}

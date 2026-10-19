abstract final class RoundDelivery {
  static bool rulesError(String? code) => const {
    'rules_changed',
    'revision_mismatch',
    'economy_update_required',
    'update_required',
  }.contains(code);
  static String message(String code, {required bool ru}) {
    if (code == 'round_storage_failed') {
      return ru
          ? 'Не удалось прочитать историю на телефоне. Данные сохранены; новые попытки приостановлены.'
          : 'The local history could not be read. Your data is preserved; new runs are paused.';
    }
    if (rulesError(code)) {
      return ru
          ? 'Настройки этой попытки устарели. Новые настройки загрузятся автоматически перед следующей игрой.'
          : 'This run used older settings. New settings will load automatically before the next game.';
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

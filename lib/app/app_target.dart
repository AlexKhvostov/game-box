/// Целевая платформа сборки (через `--dart-define=APP_TARGET=…`).
enum AppTarget {
  /// Android APK / iOS — полное приложение с выбором режима.
  mobile,

  /// Telegram Web App — только аркада «на рекорд».
  telegram,
}

/// Конфигурация текущей сборки.
abstract final class AppTargetConfig {
  static const _raw = String.fromEnvironment(
    'APP_TARGET',
    defaultValue: 'mobile',
  );

  static AppTarget get current => switch (_raw) {
    'telegram' => AppTarget.telegram,
    _ => AppTarget.mobile,
  };

  static bool get isTelegram => current == AppTarget.telegram;

  static bool get isMobile => current == AppTarget.mobile;

  /// Исторический режим этажей доступен только в отдельной dev-сборке.
  static const _enableFloors = bool.fromEnvironment('ENABLE_FLOORS');

  /// Публичная мобильная сборка открывает аркаду сразу.
  static bool get showModePicker => isMobile && _enableFloors;

  /// Режим «Этажи» в сборке.
  static bool get showFloorsMode => isMobile && _enableFloors;
}

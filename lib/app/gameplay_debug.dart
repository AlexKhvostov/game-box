/// Visual diagnostics only; independent from the isolated test wallet.
abstract final class GameplayDebug {
  static const enabled = bool.fromEnvironment('GAMEPLAY_DEBUG');
}

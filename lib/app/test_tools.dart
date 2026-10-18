/// Explicit local test builds only. Ordinary APK/AAB builds keep this false.
abstract final class TestTools {
  static const enabled = bool.fromEnvironment('TEST_TOOLS');
  static const storagePrefix = enabled ? 'test_wallet_v1_' : '';
}

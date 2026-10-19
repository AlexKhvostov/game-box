import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/mobile_gameplay_tuning.dart';
import '../domain/gameplay_config.dart';
import 'android_firebase_config.dart';
import 'economy_store.dart';
import 'mobile_account.dart';
import 'shared_config_loader.dart';

/// Apply a server snapshot only at the idle -> new run boundary. The existing
/// account, result outbox and wallet worker survive; a paid run keeps its rules.
class AndroidConfigSession extends ChangeNotifier {
  AndroidConfigSession(this.snapshot, this.account, this.economy)
    : gameplay = MobileGameplayTuning.apply(snapshot.gameplay);
  SharedConfigs snapshot;
  GameplayConfig gameplay;
  final MobileAccount account;
  final EconomyStore economy;
  Future<bool>? _refreshing;

  Future<bool> synchronize({bool force = false}) => _refreshing ??=
      _synchronize(force: force).whenComplete(() => _refreshing = null);

  Future<bool> _synchronize({required bool force}) async {
    final owner = account.id;
    if (force || account.serverGameConfig == null) {
      if (!account.ready) {
        await account.load();
      } else {
        await account.refreshProfile();
      }
    }
    if (owner != null && account.id != owner) return false;
    final raw = account.serverGameConfig;
    if (raw == null) return !force; // Older API/offline keeps the cached path.
    final encoded = jsonEncode(raw);
    final next = AndroidFirebaseConfig.parse(encoded, 'game-server');
    if (next.revision == snapshot.revision) {
      if (account.rulesRevision != next.revision) {
        account.applyRulesRevision(next.revision);
        return true;
      }
      return !force;
    }
    // Cache is optional: a storage failure cannot invalidate a good response.
    try {
      await (await SharedPreferences.getInstance()).setString(
        AndroidFirebaseConfig.cacheKey,
        encoded,
      );
    } catch (_) {}
    snapshot = next;
    gameplay = MobileGameplayTuning.apply(next.gameplay);
    economy.applyConfig(next.economy);
    account.applyRulesRevision(next.revision);
    notifyListeners();
    return true;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'economy_store.dart';
import 'mobile_account.dart';

/// Server-confirmed operations are journaled before any network action.
class MobileWalletBridge {
  MobileWalletBridge(this.account, this.economy);
  final MobileAccount account;
  final EconomyStore economy;
  String get _key => '${account.storagePrefix}mobile_wallet_operations_v1';
  String get _ownerKey => '${account.storagePrefix}mobile_wallet_owner_v1';
  late SharedPreferences _prefs;
  final List<Map<String, dynamic>> _pending = [];
  final Set<String> _confirmed = {};
  final Map<String, MobileApiError> _rejected = {};
  Future<void> _job = Future.value();
  bool _sending = false;
  String? _walletOwner;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    await account.restoreCachedOwner();
    _walletOwner = _prefs.getString(_ownerKey);
    // The snapshot's embedded owner must match the independently stored secure
    // credentials. A split old-owner pointer can never authorize cached V2.
    await economy.restoreEnergyCacheForOwner(
      await account.cachedCredentialOwner(),
    );
    try {
      _pending.addAll(
        (jsonDecode(_prefs.getString(_key) ?? '[]') as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    } catch (_) {
      /* Invalid local data cannot authorize a server credit. */
    }
    economy.sendOperation = _enqueue;
    economy.sendEnergyOperation = _enqueueEnergy;
    account.beforeRound = flush;
    account.addListener(_updated);
  }

  void _enqueue(String kind, Map<String, dynamic> args) {
    _pending.add({
      'id': account.operationId(),
      'kind': kind,
      'args': args,
      'owner': account.id ?? _walletOwner,
    });
    unawaited(flush().catchError((Object _) {}));
  }

  Future<void> _enqueueEnergy(String kind, Map<String, dynamic> args) async {
    if (!account.ready || account.busy || account.googleStage != null) {
      throw const MobileApiError('profile_unavailable');
    }
    final owner = account.id;
    final existing = _pending
        .where(
          (row) =>
              row['owner'] == owner &&
              row['kind'] == kind &&
              jsonEncode(row['args']) == jsonEncode(args),
        )
        .firstOrNull;
    final id = existing?['id'] as String? ?? account.operationId();
    if (existing == null) {
      _pending.add({
        'id': id,
        'kind': kind,
        'args': args,
        'owner': owner,
        'awaited': true,
      });
    }
    // flush serializes every durable write and persists this command before POST.
    await flush();
    final error = _rejected.remove(id);
    final confirmed = _confirmed.remove(id);
    if (error != null) throw error;
    if (account.id != owner) throw const MobileApiError('wallet_owner_changed');
    if (!confirmed) throw const MobileApiError('wallet_operation_unconfirmed');
  }

  Future<void> _checked(Future<bool> write) async {
    if (!await write) throw const MobileApiError('wallet_storage_failed');
  }

  Future<void> _savePending() =>
      _checked(_prefs.setString(_key, jsonEncode(_pending)));

  void _updated() {
    if (!account.ready || _sending) return;
    // Serialize wallet writes with journal writes too, including owner changes.
    unawaited(flush().catchError((Object _) {}));
  }

  Future<void> _applyWallet() async {
    final owner = account.id;
    final wallet = account.wallet;
    final serverNow = account.serverNow;
    if (owner == null || wallet == null || account.walletOwner != owner) return;
    final sameOwner = _walletOwner == owner;
    await economy.applyServerWallet(
      wallet,
      preserveBest: sameOwner,
      serverNow: serverNow,
      owner: owner,
    );
    // The atomic snapshot already contains its owner and clock at this point.
    // Only then update the legacy pointer used by old operation journals.
    if (account.id != owner) throw const MobileApiError('wallet_owner_changed');
    await _checked(_prefs.setString(_ownerKey, owner));
    _walletOwner = owner;
  }

  Future<void> _archiveAndRemove(
    Map<String, dynamic> op,
    String key,
    String reason, {
    String? owner,
  }) async {
    final records = _prefs.getStringList(key) ?? [];
    if (!records.any((entry) {
      try {
        final item = jsonDecode(entry) as Map;
        return item['id'] == op['id'] && item['reason'] == reason;
      } catch (_) {
        return false;
      }
    })) {
      records.add(
        jsonEncode({
          ...op,
          'owner': ?owner,
          'reason': reason,
          'deferredAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    }
    // A failed plugin write may already have changed its in-memory cache.
    // Always retry the archive write, even when that cache contains the row.
    await _checked(_prefs.setStringList(key, records));
    await _remove(op);
    if (op['awaited'] == true) {
      _rejected[op['id'] as String] = MobileApiError(reason);
    }
  }

  Future<void> _remove(Map<String, dynamic> op) async {
    final remaining = _pending.where((item) => item['id'] != op['id']).toList();
    await _checked(_prefs.setString(_key, jsonEncode(remaining)));
    _pending.removeWhere((item) => item['id'] == op['id']);
  }

  static const _terminal = {
    'bonus_not_ready',
    'bonus_unavailable',
    'daily_not_ready',
    'timed_not_ready',
    'ad_not_ready',
    'insufficient_crystals',
    'bonus_already_claimed',
    'bonus_locked',
    'bonus_invalid',
    'offer_invalid',
    'charge_empty',
    'ad_unavailable',
    'ad_verification_unavailable',
    'ad_session_required',
    'ad_session_invalid',
    'ad_session_claimed',
    'ad_session_expired',
    'age_payload_invalid',
    'feedback_rating',
    'update_required',
    'energy_unavailable',
    'energy_empty',
    'energy_not_ready',
    'energy_reward_locked',
    'energy_reward_claimed',
    'feedback_invalid',
    'feedback_already_sent',
    'feedback_length',
    'feedback_locked',
    'insufficient_energy',
    'legacy_operation_disabled',
    'economy_update_required',
    'reward_already_claimed',
    'subscription_verification_pending',
    'energy_test_grant_unavailable',
    'energy_test_grant_invalid',
    'operation_conflict',
  };

  Future<void> flush() {
    final next = _job.then((_) async {
      _sending = true;
      try {
        await _savePending();
        if (!account.ready) await account.load();
        if (!account.ready) throw const MobileApiError('connection_failed');
        while (_pending.isNotEmpty) {
          final op = _pending.first;
          final owner = op['owner'] ?? _walletOwner;
          if (owner == null || owner != account.id) {
            await _archiveAndRemove(
              op,
              'mobile_wallet_quarantine_v2',
              owner == null ? 'wallet_owner_unknown' : 'wallet_owner_changed',
              owner: owner,
            );
            continue;
          }
          if (const {
            'energy_test_grant',
            'beta_free_crystals',
          }.contains(op['kind'])) {
            await _archiveAndRemove(
              op,
              'mobile_wallet_deferred_v2',
              'retired_credit_operation',
              owner: owner,
            );
            continue;
          }
          // A command appended while another request was in flight is persisted
          // here as well. A false write must never reach the network.
          await _savePending();
          try {
            await account.walletOperation(
              op['id'] as String,
              op['kind'] as String,
              Map<String, dynamic>.from(op['args'] as Map),
            );
          } on MobileApiError catch (error) {
            final terminal = _terminal.contains(error.code);
            if (!terminal) rethrow;
            await _archiveAndRemove(
              op,
              'mobile_wallet_deferred_v2',
              error.code,
              owner: owner,
            );
            await account.refreshProfile();
            continue;
          }
          // Persist the monetary snapshot first; then acknowledge/dequeue.
          if (account.id != owner) {
            throw const MobileApiError('wallet_owner_changed');
          }
          await _applyWallet();
          await _remove(op);
          if (op['awaited'] == true) {
            _confirmed.add(op['id'] as String);
          }
        }
        await _applyWallet();
      } finally {
        _sending = false;
      }
    });
    _job = next.catchError((Object _) {});
    return next;
  }
}

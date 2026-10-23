import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'economy_store.dart';
import 'mobile_account.dart';

/// Game input never waits for this worker. Each run has a durable, unique
/// request, frozen equipment and an owner; only server acknowledgements publish
/// scores or authorize rewards. A saved result may display a provisional UI
/// receipt while that acknowledgement is pending; validation is unchanged.
class InstantRoundJournal {
  InstantRoundJournal({
    required this.account,
    required this.economy,
    required this.published,
    required this.recoverResult,
    required this.changed,
    this.rejected,
    this.mayDeliver,
    int Function()? elapsedMilliseconds,
  }) : _elapsed = elapsedMilliseconds {
    account.addListener(_accountChanged);
  }

  final MobileAccount account;
  final EconomyStore economy;
  final Future<void> Function(String owner, String attemptId) published;
  final Map<String, dynamic>? Function(String attemptId) recoverResult;
  final void Function() changed;
  final Future<void> Function(String owner, String attemptId, String code)?
  rejected;
  final bool Function()? mayDeliver;
  final int Function()? _elapsed;
  final Stopwatch _clock = Stopwatch()..start();
  int get _now => _elapsed?.call() ?? _clock.elapsedMilliseconds;
  final List<Map<String, dynamic>> _rows = [];
  final Map<String, int> _activationAges = {};
  final Map<String, int> _finishNotBefore = {};
  SharedPreferences? _prefs;
  String? _owner, _active;
  Future<void> _writes = Future.value();
  final _savedSnapshots = <String, String>{};
  Future<void> _binding = Future.value();
  Timer? _retry;
  bool _running = false, _disposed = false, _loaded = false;
  bool _needsWork = false;
  int? _retryAt;
  int _backoff = 1;
  String? lastError;
  String? _blockedRevision;
  bool get rulesUpdateRequired => _blockedRevision == account.rulesRevision;
  String? get activeKey => _active;
  bool get ready => _loaded && _owner == account.id;
  bool get hasPending => _rows.any((r) => r['rejected'] == null);
  bool pendingAttempt(String id) =>
      _rows.any((r) => r['requestId'] == id && r['rejected'] == null);

  /// Read-only identity for merging an acknowledged server result with a
  /// still-pending local receipt. Never rewrites or acknowledges the journal.
  String? serverRoundIdFor(String requestId) {
    if (!ready) return null;
    final row = _rows.where((r) => r['requestId'] == requestId).firstOrNull;
    return row?['roundId'] as String?;
  }

  String _key(String owner) =>
      '${account.storagePrefix}instant_rounds_v1_$owner';

  void _accountChanged() {
    if (_owner != account.id) {
      unawaited(bindOwner());
    }
  }

  Future<void> bindOwner() {
    final owner = account.id;
    _binding = _binding
        .catchError((Object _) {})
        .then((_) async {
          if (_disposed ||
              owner != account.id ||
              (_loaded && owner == _owner)) {
            return;
          }
          _loaded = false;
          await _writes.catchError((Object _) {});
          _prefs ??= await SharedPreferences.getInstance();
          if (_disposed || owner != account.id) return;
          _owner = owner;
          _active = null;
          _rows.clear();
          _activationAges.clear();
          _finishNotBefore.clear();
          _blockedRevision = null;
          if (owner != null) {
            _blockedRevision = _prefs!.getString(
              '${_key(owner)}_blocked_revision',
            );
            final raw = _prefs!.getString(_key(owner));
            if (raw != null) {
              final saved = jsonDecode(raw) as List;
              for (final item in saved) {
                final row = Map<String, dynamic>.from(item as Map);
                if (row['owner'] != owner) continue;
                if (row['result'] == null) {
                  final result = recoverResult(row['requestId'] as String);
                  if (result != null) {
                    row['result'] = result;
                  } else {
                    // A killed process cannot resume a moving game. Its already
                    // started attempt is paid once, without inventing a score.
                    row['abandoned'] = true;
                  }
                }
                _rows.add(row);
                if (row['result'] != null &&
                    row['rewardPresented'] == true &&
                    (row['presentationAmount'] as int? ?? 0) > 0) {
                  economy.presentEnergyCredit(
                    'round:${row['requestId']}',
                    0,
                    animate: false,
                  );
                }
              }
            }
          }
          _loaded = true;
          _costs();
          changed();
          retry();
        })
        .catchError((Object _) {
          // Preserve an unreadable journal for recovery; never replace it with an
          // empty queue or publish guessed results.
          _loaded = false;
          lastError = 'round_storage_failed';
          changed();
        });
    return _binding;
  }

  String? begin({
    required bool helmet,
    required bool jump,
    required int cost,
    String? preparedKey,
    int proofVersion = 1,
  }) {
    final owner = _owner;
    if (!ready ||
        rulesUpdateRequired ||
        owner == null ||
        _active != null ||
        _rows.length >= 10000 ||
        cost < 1 ||
        economy.energy < cost ||
        economy.energyOwner != owner ||
        account.googleStage != null) {
      return null;
    }
    final requestId = preparedKey ?? account.operationId();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(requestId) ||
        _rows.any((row) => row['requestId'] == requestId)) {
      return null;
    }
    _rows.add({
      'owner': owner,
      'requestId': requestId,
      'helmet': helmet,
      'jump': jump,
      'cost': cost,
      'revision': economy.energyConfig.revision,
      'rulesRevision': account.rulesRevision,
      'proofVersion': proofVersion,
      'rewardRunEvery': economy.config.runRewardEvery,
      'rewardRiskEvery': economy.config.riskRewardEvery,
    });
    _active = requestId;
    lastError = null;
    _costs();
    changed();
    // Local animation can start now. No HTTP is sent until the intent is saved.
    unawaited(
      _save().then((_) => retry()).catchError((Object _) {
        lastError = 'round_storage_failed';
        _later();
      }),
    );
    return requestId;
  }

  Future<void> complete(String key, Map<String, dynamic> result) async {
    final owner = _owner;
    final row = _rows.where((r) => r['requestId'] == key).firstOrNull;
    if (row == null) return;
    row['result'] = Map<String, dynamic>.from(result);
    final runEvery = row['rewardRunEvery'] as int?;
    final riskEvery = row['rewardRiskEvery'] as int?;
    final amount =
        runEvery != null && runEvery > 0 && riskEvery != null && riskEvery > 0
        ? (result['runDistance'] as int) ~/ runEvery +
              (result['riskCount'] as int) ~/ riskEvery
        : 0;
    row['rewardPresented'] = true;
    row['presentationAmount'] = amount;
    if (_active == key) _active = null;
    await _save();
    if (_disposed ||
        owner != _owner ||
        owner != account.id ||
        owner != economy.energyOwner) {
      return;
    }
    if (row['rejected'] == null) {
      economy.presentEnergyCredit('round:$key', amount);
    }
    changed();
    retry();
  }

  void _costs({bool notify = true}) {
    final owner = _owner;
    if (owner == null) return;
    economy.setPendingRunCosts(owner, {
      for (final row in _rows)
        if (row['charged'] != true && row['rejected'] == null)
          row['requestId'] as String: row['cost'] as int,
    }, notify: notify);
  }

  Future<void> _save() {
    final owner = _owner;
    if (owner == null || _prefs == null) return Future.value();
    final encoded = jsonEncode(_rows);
    final job = _writes.catchError((Object _) {}).then((_) async {
      if (_savedSnapshots[owner] == encoded) return;
      if (!await _prefs!.setString(_key(owner), encoded)) {
        throw StateError('round_storage_failed');
      }
      _savedSnapshots[owner] = encoded;
    });
    _writes = job;
    return job;
  }

  void retry() {
    if (_running) {
      _needsWork = true;
      return;
    }
    _retry?.cancel();
    _retry = null;
    _retryAt = null;
    if (_disposed || !ready || _rows.isEmpty) return;
    unawaited(_work());
  }

  void _later([int? milliseconds]) {
    if (_disposed || _rows.isEmpty) return;
    final delay = milliseconds ?? _backoff * 1000;
    if (_retry != null && (_retryAt ?? 0) <= _now + delay) return;
    _retry?.cancel();
    _retryAt = _now + delay;
    _retry = Timer(Duration(milliseconds: delay), retry);
  }

  Future<Map<String, dynamic>> _request(
    String owner,
    Map<String, dynamic> command,
  ) async {
    if (_disposed || _owner != owner || account.id != owner) {
      throw const MobileApiError('wallet_owner_changed');
    }
    return account.synchronizeRun(owner, command);
  }

  Future<void> _wallet() async {
    if (_disposed || _owner != account.id || account.wallet == null) return;
    _costs(notify: false);
    await economy.applyServerWallet(
      account.wallet!,
      owner: _owner,
      serverNow: account.serverNow,
      preserveBest: true,
    );
  }

  static const _terminal = {
    'insufficient_energy',
    'rules_changed',
    'revision_mismatch',
    'economy_update_required',
    'update_required',
    'profile_disabled',
    'result_boost_invalid',
    'round_canceled',
    'operation_conflict',
    'result_invalid',
    'result_time_invalid',
    'result_metrics_invalid',
    'result_proof_required',
    'result_proof_invalid',
    'body_too_large',
    'round_invalid',
    'round_not_activated',
    'round_already_started',
    'round_not_found',
  };

  static const _rulesErrors = {
    'rules_changed',
    'revision_mismatch',
    'economy_update_required',
    'update_required',
  };

  Future<void> _retireRejected(String owner, Map<String, dynamic> row) async {
    final code = row['rejected'] as String;
    final obsoleteProtocol =
        code == 'update_required' && row['proofVersion'] != 1;
    if (_rulesErrors.contains(code) &&
        !obsoleteProtocol &&
        row['rulesRevision'] == account.rulesRevision) {
      _blockedRevision = account.rulesRevision;
      if (!await _prefs!.setString(
        '${_key(owner)}_blocked_revision',
        account.rulesRevision,
      )) {
        throw StateError('round_storage_failed');
      }
    }
    _costs();
    // A run rejected during play still needs its local metrics recorded once.
    if (row['result'] == null && row['abandoned'] != true) {
      changed();
      return;
    }
    final key = row['requestId'] as String;
    economy.settleEnergyCredit('round:$key', rejected: true);
    await rejected?.call(owner, key, code);
    final archiveKey = '${_key(owner)}_rejected';
    final archived = _prefs!.getStringList(archiveKey) ?? [];
    archived.removeWhere((raw) {
      try {
        return (jsonDecode(raw) as Map)['requestId'] == key;
      } catch (_) {
        return false;
      }
    });
    archived.add(jsonEncode(row));
    if (archived.length > 200) archived.removeRange(0, archived.length - 200);
    if (!await _prefs!.setStringList(archiveKey, archived)) {
      throw StateError('round_storage_failed');
    }
    _rows.remove(row);
    _activationAges.remove(key);
    _finishNotBefore.remove(key);
    await _save();
    changed();
  }

  Future<void> _work() async {
    if (mayDeliver?.call() == false) return;
    _running = true;
    final owner = _owner!;
    try {
      await _save();
      for (final row in [..._rows]) {
        if (_disposed || owner != _owner || owner != account.id) return;
        final key = row['requestId'] as String;
        if (row['rejected'] != null) {
          await _retireRejected(owner, row);
          continue;
        }
        try {
          if (!account.onlineAllowed || !account.ready) {
            _later();
            return;
          }
          if (row['roundId'] == null) {
            await account.beforeRound?.call();
            final data = await _request(owner, {
              'action': 'round_start',
              'requestId': key,
              'helmet': row['helmet'],
              'jump': row['jump'],
              'rulesRevision': row['rulesRevision'],
              'proofVersion': row['proofVersion'],
              'revision': row['revision'],
            });
            if (owner != _owner || _disposed) return;
            row['roundId'] = data['roundId'];
            row['charged'] = true;
            // Lost replies replay this exact ID. The wallet and projected cost
            // now describe the same charge; subsequent profile loads retain it.
            await _wallet();
            await _save();
          }
          if (row['activated'] != true) {
            await _request(owner, {
              'action': 'round_activate',
              'requestId': key,
            });
            if (owner != _owner || _disposed) return;
            row['activated'] = true;
            _activationAges[key] = _now;
            await _wallet();
            await _save();
          }
          if (row['abandoned'] != true) {
            final result = row['result'];
            if (result is! Map) continue;
            final notBefore = _finishNotBefore[key] ?? 0;
            if (_now < notBefore) {
              _later(notBefore - _now);
              continue;
            }
            // A late activation must never relax the server's elapsed-time
            // check. Delay only delivery, never input or the result screen.
            final age = _now - (_activationAges[key] ??= _now);
            final remaining = (result['timeMs'] as int) - age;
            if (remaining > 0) {
              _later(remaining);
              continue;
            }
            final finished = await _request(owner, {
              'action': 'round_finish',
              'roundId': row['roundId'],
              ...Map<String, dynamic>.from(result),
            });
            if (owner != _owner || _disposed) return;
            await _wallet();
            economy.settleEnergyCredit(
              'round:$key',
              amount: (finished['energyReward'] as num?)?.toInt(),
            );
            await published(owner, key);
          }
          _rows.remove(row);
          _activationAges.remove(key);
          _finishNotBefore.remove(key);
          await _save();
          _backoff = 1;
          _costs();
          changed();
        } on MobileApiError catch (error) {
          if (owner != _owner || _disposed) return;
          lastError = error.code;
          if (error.code == 'result_time_invalid') {
            // An early finish is not a permanent refusal: server time may
            // lag a recovered activation. Skip this row without blocking later
            // results, retry at its deadline, and bound repeated bad replies.
            final refusals = ((row['timeRefusals'] as int?) ?? 0) + 1;
            row['timeRefusals'] = refusals;
            if (refusals < 8) {
              final delay = (error.retryAfterMs ?? (1000 * (1 << refusals)))
                  .clamp(100, 3600000);
              _finishNotBefore[key] = _now + delay;
              await _save();
              _later(delay);
              changed();
              continue;
            }
          }
          if (_terminal.contains(error.code)) {
            if (error.code == 'insufficient_energy') {
              // Another device or an administrator may have spent the cached
              // balance. Refresh it before releasing this local reservation;
              // otherwise the rejected cost would become spendable again.
              await _request(owner, {'action': 'profile'});
              if (owner != _owner || _disposed) return;
              await _wallet();
            }
            row['rejected'] = error.code;
            await _save();
            await _retireRejected(owner, row);
            continue;
          }
          _backoff = (_backoff * 2).clamp(2, 60);
          _later();
          return;
        }
      }
    } catch (_) {
      _backoff = (_backoff * 2).clamp(2, 60);
      _later();
    } finally {
      _running = false;
      if (!_disposed && (owner != _owner || _needsWork)) {
        _needsWork = false;
        retry();
      }
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    account.removeListener(_accountChanged);
  }
}

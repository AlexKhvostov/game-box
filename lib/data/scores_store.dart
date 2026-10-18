import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/score_entry.dart';
import '../domain/average_ranking.dart';
import 'legacy_scores_source.dart';
import 'mobile_account.dart';
import 'economy_store.dart';
import 'instant_round_journal.dart';
import 'package:http/http.dart' as http;

/// Shared Android ranking with durable, account-scoped automatic delivery.
class ScoresStore extends ChangeNotifier {
  ScoresStore({
    this.account,
    this.legacySource,
    http.Client? client,
    this.storagePrefix = '',
    EconomyStore? instantEconomy,
  }) : _client = client ?? http.Client() {
    _attemptOwner = account?.id;
    final walletFlush = account?.beforeRound;
    account?.beforeRound = () async {
      await _scheduleDelivery();
      await walletFlush?.call();
    };
    account?.addListener(_accountUpdated);
    if (account != null && instantEconomy != null) {
      _instant = InstantRoundJournal(
        account: account!,
        economy: instantEconomy,
        changed: _changed,
        mayDeliver: () => _historyWritable,
        recoverResult: (id) {
          final a = _attempts.where((a) => a.id == id).firstOrNull;
          return a == null ? null : _attemptResult(a);
        },
        rejected: (owner, id, code) async {
          if (_disposed || account!.id != owner) return;
          final index = _attempts.indexWhere((a) => a.id == id);
          if (index >= 0) {
            _attempts[index] = _attempts[index].copyWith(
              deliveryError: code,
              clearReplayProof: true,
            );
            await _persistAttempts();
          }
          _changed();
        },
        published: (owner, id) async {
          if (_disposed || account!.id != owner) return;
          final index = _attempts.indexWhere((a) => a.id == id);
          if (index >= 0) {
            _attempts[index] = _attempts[index].copyWith(
              shared: true,
              clearReplayProof: true,
              displayName: account!.nickname,
            );
            await _persistAttempts();
            _lastRemoteOkAt = null;
            _schedulePublishedRefresh();
          }
          _changed();
        },
      );
    }
    account?.beforeIdentityChange = () async {
      await _scheduleDelivery();
      await _recording;
      if (_outbox.isNotEmpty ||
          _roundPending != null ||
          _instant?.activeKey != null ||
          _instant?.hasPending == true) {
        throw const MobileApiError('round_delivery_pending');
      }
    };
  }
  String? _attemptOwner;
  Future<void> _ownerChange = Future.value();
  void _accountUpdated() {
    if (account?.id == null || _attemptOwner == account!.id) return;
    _attemptOwner = account!.id;
    _periodScores.clear();
    _scores.clear();
    averageRanking = null;
    try {
      _loadAverageCache();
    } catch (_) {
      averageRanking = null;
      _periodScores.clear();
    }
    _attempts.clear();
    _outbox.clear();
    if (_prefs != null) {
      _ownerChange = _loadAttempts().then((_) => _changed());
    }
  }

  final MobileAccount? account;
  final LegacyScoresSource? legacySource;
  bool get supportsAverage =>
      account?.storagePrefix.startsWith('supabase_android_') ?? false;
  AverageRanking? averageRanking;
  String get _averageCacheKey =>
      '${storagePrefix}average_ranking_v1_${_attemptOwner ?? 'pending'}';
  String get _recordCacheKey =>
      '${storagePrefix}record_ranking_v1_${_attemptOwner ?? 'pending'}';
  void _loadAverageCache() {
    averageRanking = null;
    if (supportsAverage) {
      _periodScores.clear();
      final records = _prefs?.getString(_recordCacheKey);
      if (records != null) {
        try {
          final decoded = jsonDecode(records) as Map<String, dynamic>;
          for (final item in decoded.entries) {
            _periodScores[item.key] = (item.value as List)
                .map(
                  (v) =>
                      ScoreEntry.fromJson(Map<String, dynamic>.from(v as Map)),
                )
                .toList();
          }
          _scores
            ..clear()
            ..addAll(_periodScores['all'] ?? []);
        } catch (_) {
          _periodScores.clear();
        }
      }
    }
    final raw = _prefs?.getString(_averageCacheKey);
    if (!supportsAverage || raw == null) return;
    try {
      averageRanking = AverageRanking.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      averageRanking = null;
    }
  }

  final String storagePrefix;
  final http.Client _client;
  InstantRoundJournal? _instant;
  bool get instantRoundsEnabled => _instant != null;
  bool get localHistoryReadable => _historyWritable;
  bool get rulesUpdateRequired => _instant?.rulesUpdateRequired ?? false;
  String? get roundDeliveryError => _instant?.lastError;
  String? get activeInstantRoundKey => _instant?.activeKey;
  String? beginInstantRound({
    required bool helmet,
    required bool jump,
    required int cost,
  }) => _historyWritable
      ? _instant?.begin(helmet: helmet, jump: jump, cost: cost)
      : null;
  Map<String, dynamic> _attemptResult(LocalAttempt a) => {
    'timeMs': a.timeMs,
    'runDistance': a.runDistance,
    'riskCount': a.riskCount,
    'hadJump': a.hadJump,
    'hadHelmet': a.hadHelmet,
    if (a.replayProof != null) 'proof': a.replayProof,
  };
  final Map<String, List<ScoreEntry>> _periodScores = {};
  Future<String?>? _roundPending;
  Future<bool> beginRound({
    bool helmet = false,
    bool jump = false,
    String? economyRevision,
  }) async {
    await _recording;
    await _ensureLocalReady();
    if (!_historyWritable) throw const MobileApiError('round_storage_failed');
    _roundPending = account?.startRound(
      helmet: helmet,
      jump: jump,
      economyRevision: economyRevision,
    );
    final confirmed = account == null || await _roundPending != null;
    if (!confirmed) _roundPending = null;
    return confirmed;
  }

  Future<void> activateRound() async => account?.activateRound();

  Future<void> cancelRound() async {
    await account?.cancelRound();
    _roundPending = null;
  }

  String get _kOutbox => '${storagePrefix}mobile_round_outbox_v1';
  Future<void> _delivery = Future.value();
  Future<void> _localWrites = Future.value();
  Future<void>? _recording;
  final List<Map<String, dynamic>> _outbox = [];
  Timer? _retryTimer;
  int _retrySeconds = 1;
  bool _disposed = false;
  bool _historyWritable = true;
  Timer? _publishedRefresh;
  void _schedulePublishedRefresh() {
    if (_disposed) return;
    _publishedRefresh?.cancel();
    final owner = _attemptOwner;
    _publishedRefresh = Timer(const Duration(milliseconds: 350), () {
      _publishedRefresh = null;
      if (!_disposed && owner == _attemptOwner) unawaited(load());
    });
  }

  String get _stateKey =>
      '${storagePrefix}mobile_score_state_v2_${_attemptOwner ?? 'pending'}';
  bool isAttemptPending(String id) =>
      _outbox.any((item) => item['attemptId'] == id) ||
      (_instant?.pendingAttempt(id) ?? false);
  Future<void> retryPendingResults() async {
    _instant?.retry();
    await _scheduleDelivery();
  }

  void _armRetry() {
    if (_disposed || _outbox.isEmpty || _retryTimer != null) return;
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      _retryTimer = null;
      if (_roundPending != null) {
        _armRetry();
        return;
      }
      unawaited(_scheduleDelivery());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _publishedRefresh?.cancel();
    _instant?.dispose();
    account?.removeListener(_accountUpdated);
    super.dispose();
  }

  void _changed() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> _ensureLocalReady() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _ownerChange;
    if (_localReady) return;
    await _loadLocal();
    await _loadAttempts();
    _localReady = true;
  }

  Future<void> loadLocal() async {
    await _ensureLocalReady();
    if (_historyWritable) await _instant?.bindOwner();
  }

  String get _kScores => supportsAverage
      ? '${storagePrefix}local_scores_v2_${_attemptOwner ?? 'pending'}'
      : '${storagePrefix}local_scores_v1';
  String get _kAttempts => account == null
      ? '${storagePrefix}local_attempts_v1'
      : '${storagePrefix}mobile_attempts_v1_${account!.id ?? 'pending'}';
  static const _maxTimeMs = 60 * 60 * 1000; // 1 час — античит-потолок
  static const _maxAttempts = 200;

  SharedPreferences? _prefs;
  final List<ScoreEntry> _scores = [];
  final List<LocalAttempt> _attempts = [];
  bool online = false;
  bool loading = false;
  bool _localReady = false;
  DateTime? _lastRemoteOkAt;
  Future<void>? _inFlightLoad;

  List<ScoreEntry> get scores => scoresForPeriod(null);
  LocalAttempt? get latestAttempt => _attempts.isEmpty ? null : _attempts.first;

  /// Мои попытки (сохранённые и нет), новые сверху.
  List<LocalAttempt> get myAttempts {
    final copy = [..._attempts];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  /// Сортировка по времени (убыв.). [since] — нижняя граница даты записи.
  List<ScoreEntry> scoresForPeriod(DateTime? since) {
    final copy = [
      for (final s in _scores)
        if (since == null || !s.createdAt.isBefore(since)) s,
    ];
    copy.sort((a, b) => b.timeMs.compareTo(a.timeMs));
    return copy;
  }

  /// День / неделя / месяц / год / всё время.
  List<ScoreEntry> scoresForNamedPeriod(String period) {
    if (account != null && _periodScores.containsKey(period)) {
      return List.unmodifiable(_periodScores[period]!);
    }
    final now = DateTime.now().toUtc();
    switch (period) {
      case 'day':
        return scoresForPeriod(DateTime(now.year, now.month, now.day));
      case 'week':
        return scoresForPeriod(now.subtract(const Duration(days: 7)));
      case 'month':
        return scoresForPeriod(DateTime(now.year, now.month, 1));
      case 'year':
        return scoresForPeriod(DateTime(now.year, 1, 1));
      default:
        return scoresForPeriod(null);
    }
  }

  /// Обновить с сервера, если кэш устарел или офлайн.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    final last = _lastRemoteOkAt;
    if (online && last != null && DateTime.now().difference(last) < maxAge) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    // Не запускаем параллельные load — ждём текущий.
    if (_inFlightLoad != null) return _inFlightLoad!;
    _inFlightLoad = _loadBody();
    try {
      await _inFlightLoad;
    } finally {
      _inFlightLoad = null;
    }
  }

  Future<void> _loadBody() async {
    loading = true;
    _changed();

    await _ensureLocalReady();
    if (_historyWritable) {
      await _instant?.bindOwner();
      _instant?.retry();
    }
    _changed();

    if (account != null) {
      if (!account!.onlineAllowed) {
        online = false;
        loading = false;
        _changed();
        return;
      }
      await _scheduleDelivery();
      final loadingOwner = account!.id;
      try {
        final firebaseBoards =
            (account!.storagePrefix.startsWith('firebase_android_') ||
                account!.storagePrefix.startsWith('supabase_android_'))
            ? await account!.request({
                'action': 'scores',
                'period': 'allPeriods',
              })
            : null;
        final periods = await Future.wait(
          ['all', 'day', 'week', 'month', 'year'].map((period) async {
            final Map body;
            if (firebaseBoards != null) {
              body = {'scores': (firebaseBoards['periods'] as Map)[period]};
            } else {
              final uri = Uri.parse(
                'https://untouch.ballaball.xyz/api/scores.php',
              ).replace(queryParameters: {'period': period});
              final response = await _client
                  .get(uri)
                  .timeout(const Duration(seconds: 4));
              body = jsonDecode(response.body) as Map;
              if (response.statusCode != 200 || body['source'] != 'mysql') {
                throw const MobileApiError('ranking_unavailable');
              }
            }
            if (body['scores'] is! List) {
              throw const MobileApiError('ranking_unavailable');
            }
            return MapEntry(
              period,
              (body['scores'] as List).map((value) {
                final row = value as Map;
                return ScoreEntry(
                  id: '${row['id']}',
                  displayName: row['playerName'] as String,
                  accountName: row['googleName'] as String?,
                  timeMs: (row['timeMs'] as num).toInt(),
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                    (row['createdAt'] as num).toInt(),
                    isUtc: true,
                  ),
                  uid: row['userId'] as String?,
                  runDistance: (row['runDistance'] as num?)?.toInt() ?? 0,
                  riskCount: (row['riskCount'] as num?)?.toInt() ?? 0,
                  hadJump: row['hadJump'] == true,
                  hadHelmet: row['hadHelmet'] == true,
                  place: (row['place'] as num?)?.toInt(),
                );
              }).toList(),
            );
          }),
        );
        if (account!.id != loadingOwner) {
          throw const MobileApiError('wallet_owner_changed');
        }
        _periodScores
          ..clear()
          ..addEntries(periods);
        _scores
          ..clear()
          ..addAll(_periodScores['all']!);
        if (supportsAverage && firebaseBoards?['average'] is Map) {
          averageRanking = AverageRanking.fromJson(
            Map<String, dynamic>.from(firebaseBoards!['average'] as Map),
          );
          await _prefs!.setString(
            _averageCacheKey,
            jsonEncode(averageRanking!.toJson()),
          );
        }
        online = true;
        _lastRemoteOkAt = DateTime.now();
        await _persistLocal();
      } catch (_) {
        online = false;
      }
      loading = false;
      _changed();
      return;
    }

    if (!(legacySource?.ready ?? false)) {
      online = false;
      loading = false;
      _changed();
      return;
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final remote = await legacySource!.load();
        _scores
          ..clear()
          ..addAll(remote);
        online = true;
        _lastRemoteOkAt = DateTime.now();
        await _persistLocal();
        loading = false;
        _changed();
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint('Legacy leaderboard load attempt ${attempt + 1}: $e\n$st');
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    debugPrint('Legacy leaderboard load gave up: $lastError');
    online = false;
    loading = false;
    _changed();
  }

  Future<void> _loadLocal() async {
    final prefs = _prefs!;
    _scores.clear();
    try {
      _loadAverageCache();
    } catch (_) {
      averageRanking = null;
      _periodScores.clear();
    }
    try {
      final raw = prefs.getString(_kScores);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final parsed = list
            .map((item) => ScoreEntry.fromJson(item as Map<String, dynamic>))
            .toList();
        _scores
          ..clear()
          ..addAll(parsed);
      }
    } catch (_) {
      // Disposable ranking data must never prevent startup. Preserve its raw
      // value until a successful server fetch replaces this cache.
      debugPrint('Ignoring unreadable ranking cache');
    }
  }

  Future<void> _persistLocal() async {
    final prefs = _prefs!;
    final encoded = jsonEncode(_scores.map((e) => e.toJson()).toList());
    final recordsKey = _recordCacheKey;
    final records = supportsAverage
        ? jsonEncode(
            _periodScores.map(
              (key, value) =>
                  MapEntry(key, value.map((r) => r.toJson()).toList()),
            ),
          )
        : null;
    await prefs.setString(_kScores, encoded);
    if (records != null) await prefs.setString(recordsKey, records);
  }

  Future<void> _loadAttempts() async {
    _historyWritable = true;
    try {
      await _loadAttemptsBody();
    } catch (_) {
      // This value also contains unsent results. Do not overwrite, delete or
      // silently replace it; allow the app to open with an explicit storage error.
      _historyWritable = false;
      _attempts.clear();
      _outbox.clear();
      debugPrint('Local result journal needs recovery');
    }
  }

  Future<void> _loadAttemptsBody() async {
    _attempts.clear();
    _outbox.clear();
    final state = account == null ? null : _prefs!.getString(_stateKey);
    if (state != null) {
      final data = jsonDecode(state) as Map;
      _attempts.addAll(
        (data['attempts'] as List).map(
          (e) => LocalAttempt.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      _outbox.addAll(
        (data['outbox'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      _armRetry();
      await _adoptLocalPractice();
      return;
    }
    final raw = _prefs!.getString(_kAttempts);
    if (raw == null || raw.isEmpty) {
      await _adoptLocalPractice();
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        _attempts.add(LocalAttempt.fromJson(item as Map<String, dynamic>));
      }
      if (account != null) {
        // Legacy outbox did not store an owner. Only migrate rows whose attempt
        // exists in this profile's history; never send another profile's rows.
        final legacy = jsonDecode(_prefs!.getString(_kOutbox) ?? '[]') as List;
        _outbox.addAll(
          legacy
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((e) => _attempts.any((a) => a.id == e['attemptId'])),
        );
        await _persistAttempts();
        _armRetry();
      }
    } catch (e, st) {
      debugPrint('Local attempts load failed: $e\n$st');
      rethrow;
    }
    await _adoptLocalPractice();
  }

  Future<void> _adoptLocalPractice() async {
    final owner = _attemptOwner;
    if (account == null || owner == null) return;
    final adoptedKey = '${storagePrefix}mobile_practice_adopted_owner_v1';
    final adopted = _prefs!.getString(adoptedKey);
    if (adopted != null && adopted != owner) return;
    final raw = _prefs!.getString(
      '${storagePrefix}mobile_score_state_v2_pending',
    );
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map;
      // Unconfirmed practice never has a server round or publication payload.
      if ((data['outbox'] as List).isNotEmpty) return;
      final practice = (data['attempts'] as List)
          .map(
            (e) => LocalAttempt.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((a) => !a.shared && !_attempts.any((v) => v.id == a.id));
      _attempts.addAll(practice);
      _attempts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (_attempts.length > _maxAttempts) {
        _attempts.removeRange(_maxAttempts, _attempts.length);
      }
      await _persistAttempts();
      await _prefs!.setString(adoptedKey, owner);
    } catch (_) {
      // Invalid unowned data never authorizes a score or crosses identities.
    }
  }

  Future<void> _persistAttempts() async {
    if (!_historyWritable) throw const MobileApiError('round_storage_failed');
    final key = account == null ? _kAttempts : _stateKey;
    final attempts = _attempts.map((e) => e.toJson()).toList();
    final encoded = jsonEncode(
      account == null ? attempts : {'attempts': attempts, 'outbox': _outbox},
    );
    final write = _localWrites.then((_) async {
      if (!await _prefs!.setString(key, encoded)) {
        throw StateError('Score storage failed');
      }
    });
    _localWrites = write.catchError((Object _) {});
    await write;
  }

  /// Сброс локальных очков и попыток (тех. сброс «как после установки»).
  Future<void> clearLocalData() async {
    if (!_historyWritable) throw const MobileApiError('round_storage_failed');
    _prefs ??= await SharedPreferences.getInstance();
    _scores.clear();
    // Do not discard confirmed rounds awaiting acknowledgement during a reset.
    _attempts.removeWhere((attempt) => !isAttemptPending(attempt.id));
    _lastRemoteOkAt = null;
    await _prefs!.remove(_kScores);
    await _persistAttempts();
    _changed();
    await load();
  }

  /// Каждая партия (даже без Share) попадает в «Мои попытки».
  Future<void> recordAttempt(
    int timeMs, {
    int riskCount = 0,
    int runDistance = 0,
    bool hadJump = false,
    bool hadHelmet = false,
    Map<String, dynamic>? replayProof,
  }) {
    final recording = _recordAttempt(
      timeMs,
      riskCount: riskCount,
      runDistance: runDistance,
      hadJump: hadJump,
      hadHelmet: hadHelmet,
      replayProof: replayProof,
    );
    _recording = recording;
    return recording.whenComplete(() {
      if (identical(_recording, recording)) _recording = null;
    });
  }

  Future<void> _recordAttempt(
    int timeMs, {
    required int riskCount,
    required int runDistance,
    required bool hadJump,
    required bool hadHelmet,
    Map<String, dynamic>? replayProof,
  }) async {
    final instantKey = _instant?.activeKey;
    await _ensureLocalReady();
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    _attempts.insert(
      0,
      LocalAttempt(
        id: instantKey ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timeMs: safeTime,
        createdAt: DateTime.now(),
        riskCount: riskCount.clamp(0, 99999),
        runDistance: runDistance.clamp(0, 9999999),
        hadJump: hadJump,
        hadHelmet: hadHelmet,
        replayProof: replayProof,
      ),
    );
    if (_attempts.length > _maxAttempts) {
      _attempts.removeRange(_maxAttempts, _attempts.length);
    }
    final attempt = _attempts.first;
    if (instantKey != null) {
      // Save visible history first. If the process dies before journal update,
      // its request ID recovers these exact metrics on the next launch.
      await _persistAttempts();
      await _instant!.complete(instantKey, _attemptResult(attempt));
      _changed();
      return;
    }
    final roundPending = _roundPending;
    if (account != null && roundPending != null) {
      final round = await roundPending;
      if (round != null &&
          safeTime > 0 &&
          !_outbox.any((item) => item['roundId'] == round)) {
        _outbox.add({
          'roundId': round,
          'attemptId': attempt.id,
          'result': {
            'timeMs': safeTime,
            'runDistance': attempt.runDistance,
            'riskCount': attempt.riskCount,
            'hadJump': hadJump,
            'hadHelmet': hadHelmet,
          },
        });
      }
    }
    // Attempt and delivery payload commit in ONE value, before any network work.
    await _persistAttempts();
    _roundPending = null;
    _changed();
    _retrySeconds = 1;
    _armRetry();
  }

  Future<void> _scheduleDelivery() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _delivery = _delivery
        .then((_) async {
          if (_disposed ||
              account == null ||
              !account!.onlineAllowed ||
              _prefs == null ||
              _outbox.isEmpty) {
            return;
          }
          if (!account!.ready) await account!.load();
          if (!account!.ready) return;
          var acknowledged = false;
          for (final item in [..._outbox]) {
            try {
              await account!.finishRound(
                item['roundId'] as String,
                Map<String, dynamic>.from(item['result'] as Map),
              );
              final index = _attempts.indexWhere(
                (a) => a.id == item['attemptId'],
              );
              if (index >= 0) {
                _attempts[index] = _attempts[index].copyWith(
                  shared: true,
                  displayName: account!.nickname,
                );
              }
              _outbox.remove(item);
              await _persistAttempts();
              acknowledged = true;
            } on MobileApiError catch (e) {
              if ([
                'round_not_found',
                'round_invalid',
                'result_invalid',
                'result_time_invalid',
                'result_boost_invalid',
              ].contains(e.code)) {
                _outbox.remove(item);
                await _persistAttempts();
                continue;
              }
              break;
            } catch (_) {
              break;
            }
          }
          if (acknowledged) {
            _lastRemoteOkAt = null;
            // A lost PROFILE response must not turn an accepted score into a
            // pending score. Round acknowledgement is the publication boundary.
            try {
              await account!.refreshProfile();
            } catch (_) {}
          }
          _changed();
        })
        .catchError((Object _) {})
        .whenComplete(() {
          if (_outbox.isEmpty) {
            _retrySeconds = 1;
          } else {
            _retrySeconds = (_retrySeconds * 2).clamp(2, 120);
            _armRetry();
          }
        });
    return _delivery;
  }

  Future<void> _markNearestAttemptShared(
    int timeMs, {
    String? displayName,
  }) async {
    final safe = timeMs.clamp(0, _maxTimeMs);
    final i = _attempts.indexWhere((a) => !a.shared && a.timeMs == safe);
    if (i < 0) return;
    _attempts[i] = _attempts[i].copyWith(
      shared: true,
      displayName: displayName,
    );
    await _persistAttempts();
  }

  RankInfo rankFor(int timeMs, {String period = 'all'}) {
    final list = scoresForNamedPeriod(period);
    final total = list.length;
    if (supportsAverage) {
      final mine = list
          .where((s) => s.uid == account!.id && s.timeMs == timeMs)
          .firstOrNull;
      final better = list.where((s) => s.timeMs > timeMs).length;
      return RankInfo(
        place: mine?.place ?? better + 1,
        percentile: 0,
        totalCount: total,
        placeKnown: mine?.place != null || better < 200,
        percentileKnown: false,
      );
    }
    if (total == 0) {
      return const RankInfo(place: 1, percentile: 100, totalCount: 0);
    }
    final better = list.where((s) => s.timeMs > timeMs).length;
    final place = better + 1;
    final percentile = (100 * (1 - better / total)).round().clamp(0, 100);
    return RankInfo(place: place, percentile: percentile, totalCount: total);
  }

  /// Места результата по срезам: день / неделя / месяц / год / всё.
  PeriodRanks ranksByPeriod(int timeMs) {
    return PeriodRanks(
      day: rankFor(timeMs, period: 'day'),
      week: rankFor(timeMs, period: 'week'),
      month: rankFor(timeMs, period: 'month'),
      year: rankFor(timeMs, period: 'year'),
      all: rankFor(timeMs, period: 'all'),
    );
  }

  Future<RankInfo> saveScore({
    required String displayName,
    required int timeMs,
    String? countryCode,
    int riskCount = 0,
    int runDistance = 0,
    bool hadJump = false,
    bool hadHelmet = false,
  }) async {
    if (account != null) {
      final saved = _attempts.any((a) => a.timeMs == timeMs && a.shared);
      if (!saved) throw const MobileApiError('round_not_confirmed');
      await load();
      return rankFor(timeMs);
    }
    final safeTime = timeMs.clamp(0, _maxTimeMs);
    final cc = (countryCode ?? '--').toUpperCase();
    final risk = riskCount.clamp(0, 99999);
    final run = runDistance.clamp(0, 9999999);
    final myUid = legacySource?.uid;
    final entry = ScoreEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: displayName,
      timeMs: safeTime,
      createdAt: DateTime.now(),
      countryCode: cc,
      uid: myUid,
      riskCount: risk,
      runDistance: run,
      hadJump: hadJump,
      hadHelmet: hadHelmet,
    );

    if ((legacySource?.ready ?? false) && myUid != null) {
      try {
        final onlineEntry = await legacySource!.save(entry);
        // Временно добавим себя, пока ждём полный refresh
        if (!_scores.any((s) => s.id == onlineEntry.id)) {
          _scores.add(onlineEntry);
        }
        await _markNearestAttemptShared(safeTime, displayName: displayName);
        await _persistLocal();
        _changed();
        _lastRemoteOkAt = null; // форсируем полный reload
        await load();
        return rankFor(safeTime);
      } catch (e, st) {
        debugPrint('Legacy score save failed: $e\n$st');
      }
    }

    _scores.add(entry);
    await _markNearestAttemptShared(safeTime, displayName: displayName);
    await _persistLocal();
    _changed();
    return rankFor(safeTime);
  }
}

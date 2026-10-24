import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'android_invite_source.dart';
import 'invite_code.dart';
import 'mobile_account.dart';

class InvitePaidRow {
  InvitePaidRow.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      userId = data['userId'] as String?,
      nickname = data['nickname'] as String?,
      rewardedAt = (data['rewardedAt'] as num).toInt(),
      amount = (data['amount'] as num).toInt(),
      currency = data['currency'] as String? ?? 'crystals',
      originalAmount =
          (data['originalAmount'] as num?)?.toInt() ??
          (data['amount'] as num).toInt(),
      originalCurrency =
          data['originalCurrency'] as String? ??
          data['currency'] as String? ??
          'crystals',
      energyEquivalent =
          (data['energyEquivalent'] as num?)?.toInt() ??
          ((data['amount'] as num).toInt() *
              (data['currency'] == 'energy' ? 1 : 2)) {
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id) ||
        rewardedAt < 0 ||
        amount < 0 ||
        energyEquivalent < 0 ||
        !{'energy', 'crystals', 'tokens'}.contains(currency)) {
      throw const MobileApiError('invite_response_invalid');
    }
  }
  final String id;
  final String? userId;
  final String? nickname;
  final int rewardedAt, amount, energyEquivalent, originalAmount;
  final String currency, originalCurrency;
}

class InviteState {
  InviteState.fromJson(Map<String, dynamic> data)
    : profileId = data['profileId'] as String,
      ownCode = data['ownCode'] as String,
      inviteUrl = data['inviteUrl'] as String,
      inviterAssigned = data['inviterAssigned'] == true,
      inviterCode = data['inviterCode'] as String?,
      googleLinked = data['googleLinked'] == true,
      completedGames = (data['completedGames'] as num).toInt(),
      bonusStatus = data['bonusStatus'] as String,
      reward = (data['reward'] as num).toInt(),
      currency = data['currency'] as String? ?? 'crystals',
      energyRewardTotal =
          (data['energyRewardTotal'] as num?)?.toInt() ??
          ((data['rewardTotal'] as num).toInt() *
              (data['currency'] == 'energy' ? 1 : 2)),
      requiredGames = (data['requiredGames'] as num).toInt(),
      rewardTotal = (data['rewardTotal'] as num).toInt(),
      nextCursor = data['nextCursor'] as String?,
      pendingNextCursor = data['pendingNextCursor'] as String?,
      invitedCount = (data['invitedCount'] as num?)?.toInt(),
      pendingRows = List.unmodifiable(
        (data['pendingRows'] as List? ?? const []).whereType<Map>().map(
          (row) => Map<String, dynamic>.unmodifiable(row),
        ),
      ),
      paidRows = List.unmodifiable(
        (data['paidRows'] as List).map(
          (row) =>
              InvitePaidRow.fromJson(Map<String, dynamic>.from(row as Map)),
        ),
      ) {
    if (!MobileAccount.validOwner(profileId) ||
        InviteCode.normalize(ownCode) != ownCode ||
        !(inviteUrl == InviteCode.url(ownCode) ||
            ((profileId.startsWith('firebase:') ||
                    profileId.startsWith('supabase:')) &&
                inviteUrl == InviteCode.firebaseUrl(ownCode))) ||
        inviterAssigned != (inviterCode != null) ||
        (inviterCode != null &&
            InviteCode.normalize(inviterCode) != inviterCode) ||
        reward < 0 ||
        reward > 100000 ||
        requiredGames != 5 ||
        completedGames < 0 ||
        completedGames > 5 ||
        rewardTotal < 0 ||
        !{
          'unbound',
          'waiting_games',
          'waiting_google',
          'rewarded',
          'inviter_unavailable',
        }.contains(bonusStatus)) {
      throw const MobileApiError('invite_response_invalid');
    }
  }
  final String profileId, ownCode, inviteUrl, bonusStatus;
  final bool inviterAssigned, googleLinked;
  final String? inviterCode, nextCursor, pendingNextCursor;
  final int completedGames,
      reward,
      requiredGames,
      rewardTotal,
      energyRewardTotal;
  final String currency;
  final int? invitedCount;
  final List<Map<String, dynamic>> pendingRows;
  final List<InvitePaidRow> paidRows;
}

abstract interface class InviteVault {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesInviteVault implements InviteVault {
  PreferencesInviteVault({this.storagePrefix = ''});
  final String storagePrefix;
  static const key = 'mobile_invite_delivery_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString('$storagePrefix$key');
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      '$storagePrefix$key',
      value,
    )) {
      throw const MobileApiError('invite_storage_failed');
    }
  }
}

class _PendingInvite {
  _PendingInvite(this.code, this.source, {this.guestOwner});
  final String code, source;
  String? guestOwner;
  Map<String, dynamic> toJson() => {
    'code': code,
    'source': source,
    'guestOwner': guestOwner,
  };
}

/// Invitation delivery survives Google cancellation/restore independently of the guest wallet.
class MobileInvites extends ChangeNotifier with WidgetsBindingObserver {
  MobileInvites({
    required this.account,
    required this.source,
    InviteVault? vault,
    this.enabled = true,
    bool startupResolved = false,
    this.retryDelay = const Duration(seconds: 5),
  }) : _vault =
           vault ??
           PreferencesInviteVault(storagePrefix: account.storagePrefix),
       // Public argument intentionally initializes a private lifecycle flag.
       // ignore: prefer_initializing_formals
       _startupResolved = startupResolved;
  final MobileAccount account;
  final AndroidInviteSource source;
  final InviteVault _vault;
  final bool enabled;
  final Duration retryDelay;
  InviteState? state;
  String? error;
  bool busy = false;
  _PendingInvite? _pending;
  bool _referrerDone = false,
      _loaded = false,
      _disposed = false,
      _dirty = false;
  bool _started = false, _foreground = true, _startupResolved;
  String? _owner;
  bool _accountBusy = false, _googleLinked = false;
  int _epoch = 0;
  Future<void> _queue = Future.value();
  Timer? _retry;
  String? get pendingCode => _pending?.code;

  void start() {
    if (_started || !enabled) return;
    _started = true;
    _owner = account.id;
    _accountBusy = account.busy || account.googleStage != null;
    _googleLinked = account.googleLinked;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    account.addListener(_accountChanged);
    source.listen(() => unawaited(refresh()));
    unawaited(refresh());
  }

  bool get startupResolved => _startupResolved;

  void markStartupResolved() {
    if (_startupResolved || _disposed) return;
    _startupResolved = true;
    notifyListeners();
    unawaited(refresh());
  }

  void _accountChanged() {
    final nextBusy = account.busy || account.googleStage != null;
    if (_owner == account.id &&
        _accountBusy == nextBusy &&
        _googleLinked == account.googleLinked) {
      return;
    }
    if (_owner != account.id) {
      state = null;
      error = null;
    }
    _owner = account.id;
    _accountBusy = nextBusy;
    _googleLinked = account.googleLinked;
    _epoch++;
    notifyListeners();
    if (!nextBusy) {
      unawaited(refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(refresh());
    } else {
      _retry?.cancel();
      _retry = null;
    }
  }

  Future<void> _serialized(Future<void> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await _vault.read();
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map;
        _referrerDone = json['referrerDone'] == true;
        final pending = json['pending'];
        if (pending is Map &&
            InviteCode.normalize(pending['code']) != null &&
            {
              'manual',
              'app_link',
              'install_referrer',
            }.contains(pending['source'])) {
          _pending = _PendingInvite(
            InviteCode.normalize(pending['code'])!,
            pending['source'] as String,
            guestOwner: pending['guestOwner'] as String?,
          );
        }
      } catch (_) {
        /* Malformed local storage never authorizes a payout. */
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    _dirty = true;
    await _vault.write(
      jsonEncode({
        'referrerDone': _referrerDone,
        'pending': _pending?.toJson(),
      }),
    );
    _dirty = false;
  }

  void _armRetry() {
    if (_disposed || !_foreground || !enabled) return;
    _retry?.cancel();
    _retry = Timer(retryDelay, () {
      _retry = null;
      unawaited(refresh());
    });
  }

  bool _sameOwner(String owner, int epoch) =>
      !_disposed &&
      _foreground &&
      account.id == owner &&
      epoch == _epoch &&
      !account.busy &&
      account.googleStage == null;

  Future<Map<String, dynamic>?> _requestForOwner(
    String owner,
    int epoch,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await account.request(payload);
      return _sameOwner(owner, epoch) ? response : null;
    } catch (_) {
      // Rejected replies have the same ownership boundary as successful replies.
      // An old guest's terminal error must not consume a restored player's delivery.
      if (!_sameOwner(owner, epoch)) return null;
      rethrow;
    }
  }

  Future<InviteState?> _fetch(
    String action, {
    Map<String, dynamic> args = const {},
  }) async {
    final owner = account.id;
    final epoch = _epoch;
    if (owner == null || account.busy || account.googleStage != null) {
      return null;
    }
    final response = await _requestForOwner(owner, epoch, {
      'action': action,
      ...args,
    });
    if (response == null) return null;
    InviteState parsed;
    try {
      parsed = InviteState.fromJson(
        Map<String, dynamic>.from(response['invites'] as Map),
      );
    } catch (_) {
      throw const MobileApiError('invite_response_invalid');
    }
    if (parsed.profileId != owner) {
      throw const MobileApiError('invite_response_invalid');
    }
    state = parsed;
    error = null;
    notifyListeners();
    // Reuse the account's revision/version guards; never apply a private profile to another owner.
    try {
      await account.refreshProfile();
    } catch (_) {
      if (!_sameOwner(owner, epoch)) return null;
      rethrow;
    }
    return _sameOwner(owner, epoch) ? parsed : null;
  }

  Future<bool> _collect() async {
    final url = await source.peekAppLink();
    if (url != null) {
      final code = InviteCode.fromAppLink(url);
      if (code != null && _pending == null) {
        _pending = _PendingInvite(code, 'app_link');
        await _persist(); // Native source is acknowledged only after durable storage succeeded.
      }
      await source.acknowledgeAppLink(url);
      return true;
    }
    if (!_referrerDone) {
      final referrer = await source.readInstallReferrer();
      if (referrer.status == InviteReferrerStatus.retry) {
        _armRetry();
        return false;
      }
      final code = InviteCode.fromReferrer(referrer.value);
      if (code != null && _pending == null) {
        _pending = _PendingInvite(code, 'install_referrer');
      }
      _referrerDone = true;
      await _persist();
    }
    return false;
  }

  Future<void> refresh() => _serialized(() async {
    if (_disposed || !enabled || !_foreground || !account.onlineAllowed) return;
    _retry?.cancel();
    _retry = null;
    busy = true;
    notifyListeners();
    final startingEpoch = _epoch;
    try {
      await _load();
      if (_dirty) await _persist();
      for (var iteration = 0; iteration < 16; iteration++) {
        // Validate the durable first candidate before acknowledging another native link.
        final hadPending = _pending != null;
        final collected = hadPending ? false : await _collect();
        if (!_foreground || _disposed) return;
        if (!account.ready ||
            account.busy ||
            account.googleStage != null ||
            (!_startupResolved && !account.googleLinked)) {
          _armRetry();
          return;
        }
        var current = await _fetch('invites_state');
        if (current == null) return;
        if (_pending != null) {
          final pending = _pending!;
          if (!current.inviterAssigned) {
            try {
              current = await _fetch(
                'invites_bind',
                args: {'code': pending.code, 'source': pending.source},
              );
            } on MobileApiError catch (failure) {
              if ({
                'invite_code_invalid',
                'invite_not_found',
                'invite_self',
              }.contains(failure.code)) {
                _pending = null;
                await _persist();
                continue;
              }
              if (failure.code != 'invite_already_bound') rethrow;
              current = await _fetch('invites_state');
            }
          }
          if (current == null) return;
          if (current.inviterAssigned) {
            if (current.googleLinked || current.inviterCode != pending.code) {
              _pending = null;
            } else {
              pending.guestOwner = current.profileId;
            }
            await _persist();
          }
        }
        if (_pending != null || (!collected && !hadPending)) return;
      }
      _armRetry(); // Drain a bounded native queue without blocking startup.
    } catch (failure) {
      if (!_disposed && startingEpoch == _epoch) {
        final unsupported =
            failure is MobileApiError && failure.code == 'action_invalid';
        error = unsupported
            ? 'invites_unavailable'
            : (failure is MobileApiError ? failure.code : 'connection_failed');
        if (unsupported) {
          _retry?.cancel();
          _retry = null;
        } else {
          _armRetry();
        }
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  });

  Future<void> bindManual(String input) => _serialized(() async {
    if (_disposed ||
        !enabled ||
        !account.onlineAllowed ||
        !account.ready ||
        account.busy ||
        account.googleStage != null) {
      throw const MobileApiError('profile_unavailable');
    }
    final code = InviteCode.normalize(input);
    if (code == null) throw const MobileApiError('invite_code_invalid');
    await _load();
    busy = true;
    notifyListeners();
    try {
      final result = await _fetch(
        'invites_bind',
        args: {'code': code, 'source': 'manual'},
      );
      if (result == null) throw const MobileApiError('profile_changed');
      _pending = result.googleLinked
          ? null
          : _PendingInvite(code, 'manual', guestOwner: result.profileId);
      await _persist();
    } catch (failure) {
      if (failure is MobileApiError && failure.code == 'action_invalid') {
        throw const MobileApiError('invites_unavailable');
      }
      if (failure is MobileApiError &&
          failure.code == 'invite_storage_failed') {
        _armRetry();
      }
      rethrow;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  });

  Future<void> loadMore() => _serialized(() async {
    final previous = state;
    if (_disposed ||
        previous == null ||
        (previous.nextCursor == null && previous.pendingNextCursor == null) ||
        account.busy ||
        account.googleStage != null) {
      return;
    }
    final owner = account.id;
    final epoch = _epoch;
    if (owner == null) return;
    final response = await _requestForOwner(owner, epoch, {
      'action': 'invites_list',
      'before': previous.nextCursor,
      'beforePending': previous.pendingNextCursor,
    });
    if (response == null) return;
    try {
      final page = Map<String, dynamic>.from(response['invites'] as Map);
      if (page['profileId'] != owner ||
          page['reward'] is! num ||
          page['requiredGames'] != 5) {
        throw const MobileApiError('invite_response_invalid');
      }
      final rows = <String, InvitePaidRow>{
        for (final row in previous.paidRows) row.id: row,
      };
      for (final raw in page['paidRows'] as List) {
        final row = InvitePaidRow.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        rows[row.id] = row;
      }
      state = InviteState.fromJson({
        'profileId': previous.profileId,
        'ownCode': previous.ownCode,
        'inviteUrl': previous.inviteUrl,
        'inviterAssigned': previous.inviterAssigned,
        'inviterCode': previous.inviterCode,
        'googleLinked': previous.googleLinked,
        'completedGames': previous.completedGames,
        'bonusStatus': previous.bonusStatus,
        'reward': previous.reward,
        'currency': previous.currency,
        'energyRewardTotal': page['energyRewardTotal'],
        'pendingRows': <String, Map<String, dynamic>>{
          for (final row in previous.pendingRows) '${row['id']}': row,
          for (final raw
              in (page['pendingRows'] as List? ?? const []).whereType<Map>())
            '${raw['id']}': Map<String, dynamic>.from(raw),
        }.values.toList(),
        'pendingNextCursor': previous.pendingNextCursor == null
            ? null
            : page['pendingNextCursor'],
        'invitedCount': page['invitedCount'] ?? previous.invitedCount,
        'requiredGames': previous.requiredGames,
        'rewardTotal': page['rewardTotal'],
        'nextCursor': previous.nextCursor == null ? null : page['nextCursor'],
        'paidRows': rows.values
            .map(
              (row) => {
                'id': row.id,
                'nickname': row.nickname,
                'rewardedAt': row.rewardedAt,
                'amount': row.amount,
                'currency': row.currency,
                'energyEquivalent': row.energyEquivalent,
                'originalAmount': row.originalAmount,
                'originalCurrency': row.originalCurrency,
              },
            )
            .toList(),
      });
      notifyListeners();
    } catch (_) {
      throw const MobileApiError('invite_response_invalid');
    }
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    if (_started) {
      account.removeListener(_accountChanged);
      WidgetsBinding.instance.removeObserver(this);
      source.dispose();
    }
    super.dispose();
  }
}

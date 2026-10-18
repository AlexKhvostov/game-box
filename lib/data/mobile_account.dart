import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'google_identity.dart';

abstract interface class AccountVault {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureAccountVault implements AccountVault {
  SecureAccountVault({String storagePrefix = ''})
    : _key = '${storagePrefix}untouch_mobile_credentials_v1';
  final String _key;
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

class MobileApiError implements Exception {
  const MobileApiError(this.code, {this.retryAfterMs});
  final String code;
  final int? retryAfterMs;
}

enum GoogleConnectionStage { preparing, choosingAccount, verifying }

class MobileAccount extends ChangeNotifier {
  MobileAccount({
    AccountVault? vault,
    http.Client? client,
    Uri? endpoint,
    this.rulesRevision = '',
    this.mayUseOnline,
    this.storagePrefix = '',
  }) : _vault = vault ?? SecureAccountVault(storagePrefix: storagePrefix),
       _client = client ?? http.Client(),
       endpoint =
           endpoint ??
           Uri.parse('https://untouch.ballaball.xyz/api/mobile.php');
  final AccountVault _vault;
  final http.Client _client;
  final Uri endpoint;
  final String rulesRevision;
  final String storagePrefix;
  static bool validOwner(String value) => RegExp(
    r'^(android:[1-9][0-9]*|firebase:[A-Za-z0-9_-]{1,128}|supabase:[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$',
  ).hasMatch(value);
  final bool Function()? mayUseOnline;
  bool get onlineAllowed => mayUseOnline?.call() ?? true;
  String? id;
  String? nickname;
  bool googleLinked = false;
  String? googleName;
  String? googleEmail;
  bool hideGoogleAccount = true;
  bool busy = false;
  GoogleConnectionStage? googleStage;
  String? error;
  String? _secret;
  String? _installation;
  Future<void>? _loading;
  bool get ready => id != null;
  Map<String, dynamic>? wallet;
  String? _confirmedWalletOwner;
  String? get walletOwner => _confirmedWalletOwner;
  int? serverNow;
  Map<String, dynamic>? _pendingRoundStart;
  int _walletVersion = -1;
  int _profileRevision = 0;
  Future<void> Function()? beforeRound;
  Future<void> Function()? beforeIdentityChange;
  String? _googleUnlinkOperationId;
  String? _googleUnlinkOwner;

  Future<String?> cachedCredentialOwner() async {
    try {
      final raw = await _vault.read();
      if (raw == null) return null;
      final owner = (jsonDecode(raw) as Map)['owner'];
      return owner is String && validOwner(owner) ? owner : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> restoreCachedOwner() async {
    try {
      if (id != null || !storagePrefix.startsWith('supabase_')) return;
      final raw = await _vault.read();
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map;
      final owner = saved['owner'];
      if (owner is! String ||
          !validOwner(owner) ||
          saved['secret'] is! String ||
          saved['installation'] is! String) {
        return;
      }
      id = owner;
      _secret = saved['secret'] as String;
      _installation = saved['installation'] as String;
      // This identifies local history only. The transport independently verifies
      // the current Supabase session before sending any owner-bound command.
    } catch (_) {
      // Corrupt or unavailable local credentials cannot establish an owner.
    }
  }

  String operationId() => _randomHex(32);
  Future<void> walletOperation(
    String operationId,
    String kind,
    Map<String, dynamic> args,
  ) async {
    await _walletOperationResponse(operationId, kind, args);
  }

  Future<Map<String, dynamic>> _walletOperationResponse(
    String operationId,
    String kind,
    Map<String, dynamic> args,
  ) async {
    if (busy ||
        googleStage == GoogleConnectionStage.choosingAccount ||
        googleStage == GoogleConnectionStage.verifying) {
      throw const MobileApiError('profile_unavailable');
    }
    final owner = id;
    final response = await request({
      'action': 'wallet_operation',
      'operationId': operationId,
      'kind': kind,
      'args': args,
    });
    if (id != owner) throw const MobileApiError('wallet_owner_changed');
    _apply(response);
    notifyListeners();
    return response;
  }

  Future<void> refreshProfile() async {
    if (!ready || busy) return;
    final revision = _profileRevision;
    final profile = await request({'action': 'profile'});
    // A response started before Google link/restore or a wallet update must
    // not overwrite the newer profile, even if it arrives after that action.
    if (busy || revision != _profileRevision) return;
    _apply(profile);
    notifyListeners();
  }

  Future<void> verifyPlay(String productId, String token) async {
    if (!ready) await load();
    if (!ready) throw const MobileApiError('profile_unavailable');
    final owner = id;
    final response = await request({
      'action': 'play_verify',
      'productId': productId,
      'purchaseToken': token,
    });
    if (id != owner) throw const MobileApiError('purchase_owner_invalid');
    _apply(response);
    notifyListeners();
  }

  Future<Map<String, dynamic>> quotePlay(
    String productId,
    String requestId,
  ) async {
    if (!ready || busy) throw const MobileApiError('profile_unavailable');
    final owner = id;
    final response = await request({
      'action': 'play_quote',
      'productId': productId,
      'requestId': requestId,
    });
    final raw = response['quote'];
    if (id != owner ||
        raw is! Map ||
        raw['owner'] != owner ||
        raw['productId'] != productId ||
        raw['requestId'] != requestId ||
        raw['immutableSku'] != true ||
        raw['terms'] is! Map) {
      throw const MobileApiError('offer_invalid');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> syncPlay() async {
    if (busy) return;
    if (!ready) await load();
    if (!ready) throw const MobileApiError('profile_unavailable');
    final revision = _profileRevision;
    final profile = await request({'action': 'play_sync'});
    if (busy || revision != _profileRevision) return;
    _apply(profile);
    notifyListeners();
  }

  Future<void> setGooglePrivacy(bool hide) async {
    if (busy) throw const MobileApiError('profile_unavailable');
    await walletOperation(operationId(), 'google_privacy', {'hide': hide});
  }

  Future<void> refreshGoogleDetails(NativeGoogleIdentity google) async {
    if (!googleLinked || busy || !onlineAllowed || googleEmail != null) return;
    final token = await google.cachedToken();
    if (token == null || busy) return;
    final owner = id;
    final revision = _profileRevision;
    final profile = await request({
      'action': 'google_details',
      'idToken': token,
    });
    if (id != owner || busy) return;
    if (revision != _profileRevision) {
      await refreshProfile();
      return;
    }
    _apply(profile);
    notifyListeners();
  }

  Future<void> linkGoogle(GoogleIdentity google) async {
    if (!onlineAllowed) throw const MobileApiError('online_disabled');
    if (busy || googleStage != null) {
      throw const MobileApiError('profile_unavailable');
    }
    googleStage = GoogleConnectionStage.preparing;
    notifyListeners();
    try {
      if (!ready) await load();
      await beforeRound?.call();
      if (!ready || busy) throw const MobileApiError('profile_unavailable');
      busy = true;
      googleStage = GoogleConnectionStage.choosingAccount;
      notifyListeners();
      final token = await google.token();
      googleStage = GoogleConnectionStage.verifying;
      notifyListeners();
      try {
        _apply(await request({'action': 'google_link', 'idToken': token}));
      } on MobileApiError catch (error) {
        if (error.code != 'google_profile_exists') rethrow;
        // One account selection means sign in, including an existing profile.
        await beforeIdentityChange?.call();
        await _restoreWithToken(token);
      }
      if (!googleLinked) throw const MobileApiError('google_not_linked');
      _googleUnlinkOperationId = null;
      _googleUnlinkOwner = null;
    } finally {
      busy = false;
      googleStage = null;
      notifyListeners();
    }
  }

  Future<void> unlinkGoogle(GoogleIdentity google) async {
    if (!onlineAllowed) throw const MobileApiError('online_disabled');
    if (!ready || busy || googleStage != null) {
      throw const MobileApiError('profile_unavailable');
    }
    if (!googleLinked) return;
    final owner = id;
    googleStage = GoogleConnectionStage.preparing;
    notifyListeners();
    try {
      await beforeRound?.call();
      if (id != owner || busy) {
        throw const MobileApiError('wallet_owner_changed');
      }
      busy = true;
      notifyListeners();
      if (_googleUnlinkOwner != owner || _googleUnlinkOperationId == null) {
        _googleUnlinkOwner = owner;
        _googleUnlinkOperationId = operationId();
      }
      final result = await request({
        'action': 'google_unlink',
        'operationId': _googleUnlinkOperationId,
      });
      if (id != owner || (result['profile'] as Map?)?['id'] != owner) {
        throw const MobileApiError('wallet_owner_changed');
      }
      _apply(result);
      _googleUnlinkOperationId = null;
      _googleUnlinkOwner = null;
      if (googleLinked) throw const MobileApiError('google_unlink_unconfirmed');
      error = null;
      // The server owns the binding. SDK failure cannot undo a confirmed unlink.
      if (google is GoogleIdentitySession) {
        try {
          await (google as GoogleIdentitySession).signOut();
        } catch (_) {
          // A later explicit Connect still opens the normal Google chooser.
        }
      }
    } finally {
      busy = false;
      googleStage = null;
      notifyListeners();
    }
  }

  Future<void> restoreGoogle(GoogleIdentity google) async {
    if (!onlineAllowed) throw const MobileApiError('online_disabled');
    if (busy || googleStage != null) {
      throw const MobileApiError('profile_unavailable');
    }
    googleStage = GoogleConnectionStage.preparing;
    notifyListeners();
    try {
      await beforeRound?.call();
      await beforeIdentityChange?.call();
      if (busy) throw const MobileApiError('profile_unavailable');
      busy = true;
      googleStage = GoogleConnectionStage.choosingAccount;
      notifyListeners();
      final token = await google.token();
      googleStage = GoogleConnectionStage.verifying;
      notifyListeners();
      await _restoreWithToken(token);
      if (!googleLinked) throw const MobileApiError('google_not_linked');
    } finally {
      busy = false;
      googleStage = null;
      notifyListeners();
    }
  }

  Future<void> _restoreWithToken(String token) async {
    _installation ??= _randomHex(16);
    _secret ??= _randomHex(32);
    final previous = await _vault.read();
    // Clear cached-owner authority before the server can transfer credentials.
    await _vault.write(
      jsonEncode({'installation': _installation, 'secret': _secret}),
    );
    try {
      _apply(
        await request({
          'action': 'google_restore',
          'idToken': token,
          'installation': _installation,
          'secret': _secret,
        }, guest: true),
      );
      await _saveCredentials();
    } catch (error) {
      if (error is MobileApiError &&
          {
            'google_profile_not_found',
            'google_token_invalid',
            'google_token_missing',
          }.contains(error.code)) {
        if (previous != null) await _vault.write(previous);
      } else {
        // A lost restore response may already have changed the server owner.
        // Reconcile credentials before any old-owner queue can use them again.
        id = null;
        wallet = null;
        _confirmedWalletOwner = null;
        _walletVersion = -1;
        _profileRevision++;
      }
      rethrow;
    }
  }

  String _randomHex(int bytes) {
    final random = Random.secure();
    return List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    bool guest = false,
  }) async {
    if (!onlineAllowed) throw const MobileApiError('online_disabled');
    final response = await _client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (!guest && _secret != null) 'Authorization': 'Bearer $_secret',
          },
          // Keep existing guest/round/billing requests compatible with the
          // deployed V2 API. A newer server separately negotiates the bonus.
          body: jsonEncode({
            'economyVersion': 2,
            'energyContract': 3,
            ...payload,
          }),
        )
        .timeout(
          Duration(
            // The server may need up to eight seconds to refresh Google's
            // signing certificates before it can validate the ID token.
            seconds: '${payload['action']}'.startsWith('play_')
                ? 60
                : '${payload['action']}'.startsWith('google_')
                ? 15
                : 6,
          ),
        );
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const MobileApiError('service_unavailable');
    }
    if (response.statusCode != 200 || data['ok'] != true) {
      final retry = data['retryAfterMs'];
      throw MobileApiError(
        data['error'] as String? ?? 'service_unavailable',
        retryAfterMs: retry is int && retry > 0 && retry <= 3600000
            ? retry
            : null,
      );
    }
    return data;
  }

  void _apply(Map<String, dynamic> data) {
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    final nextId = profile['id'] as String;
    final explicitVersion = (profile['walletVersion'] as num?)?.toInt();
    // Unlink advances this server version. Late wallet/purchase replies must
    // not restore identity details from an older profile snapshot either.
    if (id == nextId &&
        explicitVersion != null &&
        explicitVersion < _walletVersion) {
      return;
    }
    serverNow =
        (profile['serverNow'] as num?)?.toInt() ??
        (data['serverNow'] as num?)?.toInt();
    final nextName = profile['nickname'] as String;
    if (!validOwner(nextId) || nextName.isEmpty) {
      throw const MobileApiError('profile_invalid');
    }
    if (id != nextId) {
      _googleUnlinkOperationId = null;
      _googleUnlinkOwner = null;
      _walletVersion = -1;
      wallet = null;
      _confirmedWalletOwner = null;
    }
    final version = (profile['walletVersion'] as num?)?.toInt() ?? 0;
    if (profile['wallet'] is Map && version >= _walletVersion) {
      wallet = Map<String, dynamic>.from(profile['wallet'] as Map);
      _confirmedWalletOwner = nextId;
      _walletVersion = version;
    }
    id = nextId;
    nickname = nextName;
    googleLinked = profile['googleLinked'] == true;
    if (!googleLinked) {
      _googleUnlinkOperationId = null;
      _googleUnlinkOwner = null;
    }
    googleName = googleLinked ? profile['googleName'] as String? : null;
    googleEmail = googleLinked ? profile['googleEmail'] as String? : null;
    hideGoogleAccount = profile['hideGoogleAccount'] != false;
    _profileRevision++;
  }

  Future<void> load() {
    if (!onlineAllowed) return Future.value();
    if (_loading != null) return _loading!;
    final pending = _load();
    _loading = pending;
    return pending.whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final raw = await _vault.read();
      if (raw != null) {
        final credentials = jsonDecode(raw) as Map;
        _secret = credentials['secret'] as String;
        _installation = credentials['installation'] as String;
        if (credentials['pendingRoundStart'] is Map) {
          _pendingRoundStart = Map<String, dynamic>.from(
            credentials['pendingRoundStart'] as Map,
          );
        }
      } else {
        _installation = _randomHex(16);
        _secret = _randomHex(32);
        // Persist before registration, so a lost response cannot create another player.
        await _vault.write(
          jsonEncode({'installation': _installation, 'secret': _secret}),
        );
      }
      _apply(
        await request({
          'action': 'guest',
          'installation': _installation,
          'secret': _secret,
          'timezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
        }, guest: true),
      );
      await _saveCredentials();
    } catch (e) {
      error = e is MobileApiError ? e.code : 'connection_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> rename(String name) async {
    if (!ready || busy) throw const MobileApiError('profile_unavailable');
    busy = true;
    notifyListeners();
    try {
      _apply(await request({'action': 'rename', 'nickname': name.trim()}));
      error = null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _saveCredentials() => _vault.write(
    jsonEncode({
      'installation': _installation,
      'secret': _secret,
      'owner': ?id,
      if (_pendingRoundStart != null) 'pendingRoundStart': _pendingRoundStart,
    }),
  );

  Future<String?> startRound({
    bool helmet = false,
    bool jump = false,
    String? economyRevision,
  }) async {
    roundError = null;
    if (!onlineAllowed) {
      roundError = 'online_disabled';
      return null;
    }
    try {
      if (!ready) await load();
      if (!ready) return null;
      if (busy || googleStage != null) {
        throw const MobileApiError('profile_unavailable');
      }
      await beforeRound?.call();
      if (_pendingRoundStart?['owner'] != id ||
          _pendingRoundStart?['activated'] == true) {
        _pendingRoundStart = null;
      }
      _pendingRoundStart ??= {
        'owner': id,
        'requestId': _randomHex(32),
        'rulesRevision': rulesRevision,
        'helmet': helmet,
        'jump': jump,
        'revision': ?economyRevision,
      };
      await _saveCredentials(); // Also retry a previous failed durable write.
      final pending = _pendingRoundStart!;
      final data = await request({'action': 'round_start', ...pending});
      if (data['profile'] is Map) {
        _apply(data);
        notifyListeners();
      }
      if (data['activated'] == true || data['finished'] == true) {
        throw const MobileApiError('round_already_started');
      }
      final roundId = data['roundId'] as String;
      if (data['hadHelmet'] is bool) pending['helmet'] = data['hadHelmet'];
      if (data['hadJump'] is bool) pending['jump'] = data['hadJump'];
      if (data['attemptCost'] is num) {
        pending['attemptCost'] = data['attemptCost'];
      }
      // Retain the receipt until finish/cancel, including a process death
      // between acceptance and the first game frame.
      pending['roundId'] = roundId;
      await _saveCredentials();
      return roundId;
    } catch (e) {
      roundError = e is MobileApiError ? e.code : 'connection_failed';
      if ({
        'insufficient_lives',
        'energy_unavailable',
        'round_canceled',
        'round_already_started',
        'insufficient_energy',
        'no_lives',
        'rules_changed',
        'economy_update_required',
        'update_required',
        'revision_mismatch',
      }.contains(roundError)) {
        _pendingRoundStart = null;
        await _saveCredentials();
      }
      return null;
    }
  }

  String? get pendingRoundRequestId =>
      _pendingRoundStart?['requestId'] as String?;
  Map<String, dynamic>? get acceptedRoundLoadout =>
      _pendingRoundStart == null ? null : Map.unmodifiable(_pendingRoundStart!);

  Future<void> activateRound() async {
    final pending = _pendingRoundStart;
    if (pending == null || pending['owner'] != id) {
      throw const MobileApiError('round_unavailable');
    }
    final data = await request({
      'action': 'round_activate',
      'requestId': pending['requestId'],
    });
    pending['activated'] = true;
    await _saveCredentials();
    if (data['profile'] is Map) {
      _apply(data);
      notifyListeners();
    }
  }

  /// The caller persists its owner-scoped intent before sending. These requests
  /// never drive the game screen or reuse the legacy single pending receipt.
  Future<Map<String, dynamic>> synchronizeRun(
    String owner,
    Map<String, dynamic> command,
  ) async {
    if (id != owner || !ready || googleStage != null) {
      throw const MobileApiError('wallet_owner_changed');
    }
    final data = await request({...command, 'expectedOwner': owner});
    if (id != owner || data['profile']?['id'] != owner) {
      throw const MobileApiError('wallet_owner_changed');
    }
    _apply(data);
    notifyListeners();
    return data;
  }

  Future<void> cancelRound() async {
    final pending = _pendingRoundStart;
    if (pending == null || pending['owner'] != id) return;
    final data = await request({
      'action': 'round_cancel',
      'requestId': pending['requestId'],
    });
    if (data['profile'] is Map) {
      _apply(data);
      notifyListeners();
    }
    _pendingRoundStart = null;
    await _saveCredentials();
  }

  String? roundError;

  Future<void> finishRound(String roundId, Map<String, dynamic> result) async {
    final data = await request({
      'action': 'round_finish',
      'roundId': roundId,
      ...result,
    });
    if (data['profile'] is Map) {
      _apply(data);
      notifyListeners();
    }
    if (_pendingRoundStart?['roundId'] == roundId) {
      _pendingRoundStart = null;
      await _saveCredentials();
    }
  }
}

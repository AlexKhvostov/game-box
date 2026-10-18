import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'mobile_account.dart';
import '../domain/android_energy.dart';
import '../domain/energy_test_catalog.dart';

class PlayBillingService extends ChangeNotifier {
  PlayBillingService(this.account, {bool? testServicePreview})
    : _testServicePreview = testServicePreview ?? TestServicePreview.enabled {
    account.addListener(_accountUpdated);
  }
  final MobileAccount account;
  final bool _testServicePreview;
  bool get testServicePreview =>
      TestServicePreview.enabled || _testServicePreview;
  static const enabled = bool.fromEnvironment('GOOGLE_PLAY_BILLING');
  static const ids = {
    'pack_s',
    'pack_m',
    'pack_l',
    'pack_xl',
    'plus_weekly',
    'energy_100_v1',
    'energy_250_v1',
    'energy_500_v1',
    'energy_1000_v1',
    'energy_batteries_2_v1',
    'energy_batteries_5_v1',
  };
  static const energySubscriptionIds = {
    'energy_batteries_2_v1',
    'energy_batteries_5_v1',
  };
  final Map<String, GooglePlayPurchaseDetails> _ownedSubscriptions = {};
  bool get energyEnabled => account.wallet?['energyVersion'] == 2;
  String get _pendingKey => '${account.storagePrefix}untouch_play_pending_v1';
  String get _launchKey => '${account.storagePrefix}untouch_play_launches_v2';
  final Map<String, Map<String, dynamic>> _launches = {};
  final _storage = const FlutterSecureStorage();
  final Map<String, ProductDetails> products = {};
  final List<Map<String, String>> _pending = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _work = Future.value();
  Future<void>? _retrying;
  bool available = false;
  bool busy = false;
  String? error;

  String? _catalogRevision;
  Future<void>? _catalogLoading;
  bool _disposed = false;
  static bool isEnergySubscription(String id) =>
      RegExp(r'^energy_batteries_[25]_v[1-9][0-9]{0,3}$').hasMatch(id);
  static bool isEnergyProduct(String id) =>
      isEnergySubscription(id) ||
      RegExp(r'^energy_[1-9][0-9]{0,6}_v[1-9][0-9]{0,3}$').hasMatch(id);
  AndroidEnergyConfig get _energyConfig => AndroidEnergyConfig.fromJson(
    Map<String, dynamic>.from(
      account.wallet?['energyConfig'] is Map
          ? account.wallet!['energyConfig'] as Map
          : const {},
    ),
  );
  void _accountUpdated() {
    if (testServicePreview) return;
    if (!available || !energyEnabled || _disposed) return;
    final identity =
        '${account.id}:${jsonEncode(account.wallet?['energyConfig'])}';
    if (identity == _catalogRevision) return;
    unawaited(refreshCatalog().catchError((Object _) {}));
  }

  Future<void> refreshCatalog() =>
      _catalogLoading ??= _refreshCatalog().whenComplete(() {
        _catalogLoading = null;
        if (!_disposed) _accountUpdated();
      });
  Future<void> _refreshCatalog() async {
    if (testServicePreview) return;
    if (!available) return;
    _catalogRevision =
        '${account.id}:${jsonEncode(account.wallet?['energyConfig'])}';
    final catalog = _energyConfig;
    final desired = energyEnabled
        ? {
            ...catalog.packages.map((offer) => offer.id),
            ...catalog.subscriptions.map((offer) => offer.id),
          }
        : ids;
    if (desired.isEmpty) return;
    final response = await InAppPurchase.instance.queryProductDetails(desired);
    if (_disposed) return;
    if (response.error != null) throw const MobileApiError('store_unavailable');
    products.addEntries(
      response.productDetails
          .where(supportedProduct)
          .map((product) => MapEntry(product.id, product)),
    );
    notifyListeners();
  }

  String? price(String id) => products[id]?.price;

  EnergyOfferPrice? energyOfferPrice(String id) {
    final product = products[id];
    if (product != null) {
      return EnergyOfferPrice(
        price: product.price,
        rawPrice: product.rawPrice,
        currencyCode: product.currencyCode,
        currencySymbol: product.currencySymbol,
      );
    }
    return testServicePreview ? EnergyTestCatalog.price(id) : null;
  }

  /// Savings use the actual localized store price and current immutable amount.
  /// No percentage is shown before comparable Google prices are available.
  int? energyDiscount(String id, AndroidEnergyConfig config) {
    if (config.packages.isEmpty) return null;
    final baseline = config.packages.reduce(
      (a, b) => a.amount <= b.amount ? a : b,
    );
    EnergyPackage? selected;
    for (final offer in config.packages) {
      if (offer.id == id) selected = offer;
    }
    final base = energyOfferPrice(baseline.id), target = energyOfferPrice(id);
    if (selected == null ||
        base == null ||
        target == null ||
        selected.amount <= 0 ||
        baseline.amount <= 0 ||
        base.rawPrice <= 0 ||
        target.rawPrice <= 0 ||
        !base.rawPrice.isFinite ||
        !target.rawPrice.isFinite ||
        base.reference != target.reference ||
        base.currencyCode.isEmpty ||
        base.currencyCode != target.currencyCode) {
      return null;
    }
    final saving =
        1 -
        (target.rawPrice / selected.amount) / (base.rawPrice / baseline.amount);
    final percent = (saving * 100).round();
    return percent > 0 ? percent.clamp(1, 99) : null;
  }

  int? batteryDiscount(String id, AndroidEnergyConfig config) {
    if (config.subscriptions.isEmpty) return null;
    final baseline = config.subscriptions.reduce(
      (a, b) => a.additionalBatteries <= b.additionalBatteries ? a : b,
    );
    EnergySubscriptionOffer? selected;
    for (final offer in config.subscriptions) {
      if (offer.id == id) selected = offer;
    }
    final base = energyOfferPrice(baseline.id), target = energyOfferPrice(id);
    if (selected == null ||
        base == null ||
        target == null ||
        baseline.additionalBatteries <= 0 ||
        selected.additionalBatteries <= 0 ||
        baseline.basePlanId != selected.basePlanId ||
        base.rawPrice <= 0 ||
        target.rawPrice <= 0 ||
        !base.rawPrice.isFinite ||
        !target.rawPrice.isFinite ||
        base.reference != target.reference ||
        base.currencyCode.isEmpty ||
        base.currencyCode != target.currencyCode) {
      return null;
    }
    final percent =
        ((1 -
                    (target.rawPrice / selected.additionalBatteries) /
                        (base.rawPrice / baseline.additionalBatteries)) *
                100)
            .round();
    return percent > 0 ? percent.clamp(1, 99) : null;
  }

  static bool supportedProduct(ProductDetails product) {
    if (!ids.contains(product.id) && !isEnergyProduct(product.id)) return false;
    if (product.id != 'plus_weekly' && !isEnergySubscription(product.id)) {
      return true;
    }
    if (product is! GooglePlayProductDetails) return false;
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return false;
    final offer = offers[index];
    return offer.basePlanId == 'weekly' &&
        offer.offerId == null &&
        offer.installmentPlanDetails == null &&
        offer.pricingPhases.length == 1 &&
        offer.pricingPhases.single.billingPeriod == 'P1W' &&
        offer.pricingPhases.single.recurrenceMode ==
            RecurrenceMode.infiniteRecurring;
  }

  Future<void> initialize() async {
    if (testServicePreview) return;
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final launchRaw = await _storage.read(key: _launchKey);
      if (launchRaw != null) {
        final map = jsonDecode(launchRaw) as Map;
        for (final entry in map.entries) {
          _launches['${entry.key}'] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
      final saved = await _storage.read(key: _pendingKey);
      if (saved != null) {
        _pending.addAll(
          (jsonDecode(saved) as List).map(
            (e) => Map<String, String>.from(e as Map),
          ),
        );
      }
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        (purchases) {
          _work = _work.then((_) => _handle(purchases)).catchError((Object _) {
            error = 'verification_pending';
            notifyListeners();
          });
        },
        onError: (Object _) {
          busy = false;
          error = 'store_unavailable';
          notifyListeners();
        },
      );
      available = await InAppPurchase.instance.isAvailable();
      if (!available) return;
      final response = await InAppPurchase.instance.queryProductDetails(ids);
      if (response.error != null) {
        error = 'store_unavailable';
        return;
      }
      products.addEntries(
        response.productDetails
            .where(supportedProduct)
            .map((p) => MapEntry(p.id, p)),
      );
      await refreshCatalog();
      await retryPending();
      await InAppPurchase.instance.restorePurchases();
      await account.syncPlay();
    } catch (_) {
      error = 'store_unavailable';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _clearLaunch(String? id) async {
    if (id == null || id.isEmpty) {
      _launches.clear();
    } else {
      _launches.remove(id);
    }
    await _storage.write(key: _launchKey, value: jsonEncode(_launches));
  }

  /// A restored purchase is owned by Google's verified token, never by an old
  /// launch for the same SKU. Native purchased events may use a launch only
  /// when the account identifier supplied back by Billing matches its owner.
  static String journalOwner(
    PurchaseDetails purchase,
    Map<String, dynamic>? launch,
  ) {
    if (purchase.status != PurchaseStatus.purchased ||
        launch == null ||
        purchase is! GooglePlayPurchaseDetails) {
      return '';
    }
    final owner = launch['owner'];
    final nativeOwner = purchase.billingClientPurchase.obfuscatedAccountId;
    return owner is String &&
            nativeOwner == sha256.convert(utf8.encode(owner)).toString()
        ? owner
        : '';
  }

  Future<void> buy(String id) async {
    if (testServicePreview) {
      throw const MobileApiError('test_service_unavailable');
    }
    final product = products[id];
    if (!available || product == null || !account.ready || busy) {
      throw const MobileApiError('play_product_unavailable');
    }
    if (!account.googleLinked) {
      throw const MobileApiError('purchase_requires_recovery');
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await account.beforeRound?.call();
      if (energyEnabled && !id.startsWith('energy_')) {
        throw const MobileApiError('legacy_product_disabled');
      }
      if (!energyEnabled && id.startsWith('energy_')) {
        throw const MobileApiError('energy_unavailable');
      }
      if (energyEnabled) {
        final owner = account.id;
        final quote = await account.quotePlay(id, account.operationId());
        final terms = Map<String, dynamic>.from(quote['terms'] as Map);
        final config = _energyConfig;
        final matchingPack = config.packages.where((offer) => offer.id == id);
        final matchingSub = config.subscriptions.where(
          (offer) => offer.id == id,
        );
        final packValid =
            matchingPack.length == 1 &&
            terms['kind'] == 'energy' &&
            terms['amount'] == matchingPack.single.amount;
        final subValid =
            matchingSub.length == 1 &&
            terms['kind'] == 'energy_subscription' &&
            terms['batteryCount'] == matchingSub.single.totalBatteries &&
            terms['basePlanId'] == matchingSub.single.basePlanId &&
            terms['batteryCapacity'] == matchingSub.single.batteryCapacity &&
            (terms['chargeHours'] as num?)?.toDouble() ==
                matchingSub.single.chargeHours;
        if (account.id != owner || (!packValid && !subValid)) {
          throw const MobileApiError('offer_changed');
        }
        // Persist the displayed immutable offer and owner BEFORE Google opens.
        // The verified token is credited from the immutable server SKU registry,
        // never from this client quote ID or the latest public configuration.
        _launches[id] = quote;
        await _storage.write(key: _launchKey, value: jsonEncode(_launches));
      }
      ChangeSubscriptionParam? replacement;
      if (isEnergySubscription(id)) {
        final current = account.wallet?['energySubscription'];
        final currentId = current is Map
            ? current['productId'] as String?
            : null;
        if (currentId == id) {
          throw const MobileApiError('subscription_already_active');
        }
        if (currentId != null && isEnergySubscription(currentId)) {
          final past = await InAppPurchase.instance
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
              .queryPastPurchases();
          for (final purchase in past.pastPurchases) {
            if (isEnergySubscription(purchase.productID)) {
              _ownedSubscriptions[purchase.productID] = purchase;
            }
          }
          final old = _ownedSubscriptions[currentId];
          if (old == null) {
            throw const MobileApiError('subscription_restore_required');
          }
          replacement = ChangeSubscriptionParam(
            oldPurchaseDetails: old,
            replacementMode: id.startsWith('energy_batteries_5_')
                ? ReplacementMode.chargeProratedPrice
                : ReplacementMode.deferred,
          );
        }
      }
      final param = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: sha256
            .convert(utf8.encode(account.id!))
            .toString(),
        changeSubscriptionParam: replacement,
        offerToken: product is GooglePlayProductDetails
            ? product.offerToken
            : null,
      );
      final launched = id == 'plus_weekly' || isEnergySubscription(id)
          ? await InAppPurchase.instance.buyNonConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyConsumable(
              purchaseParam: param,
              autoConsume: false,
            );
      if (!launched) throw const MobileApiError('purchase_not_started');
    } catch (_) {
      busy = false;
      notifyListeners();
      await _clearLaunch(id);
      rethrow;
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        busy = true;
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        busy = false;
        await _clearLaunch(purchase.productID);
        error = purchase.status == PurchaseStatus.error
            ? 'purchase_failed'
            : null;
        notifyListeners();
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      if (purchase is GooglePlayPurchaseDetails &&
          isEnergySubscription(purchase.productID)) {
        _ownedSubscriptions[purchase.productID] = purchase;
      }
      final token = purchase.verificationData.serverVerificationData;
      if ((!ids.contains(purchase.productID) &&
              !isEnergyProduct(purchase.productID)) ||
          token.isEmpty) {
        busy = false;
        error = 'purchase_invalid';
        notifyListeners();
        continue;
      }
      if (!_pending.any((e) => e['token'] == token)) {
        _pending.add({
          'productId': purchase.productID,
          'token': token,
          'owner': journalOwner(purchase, _launches[purchase.productID]),
          if (journalOwner(
                purchase,
                _launches[purchase.productID],
              ).isNotEmpty &&
              _launches[purchase.productID]?['requestId'] is String)
            'quoteId': _launches[purchase.productID]!['requestId'] as String,
        });
        await _storage.write(key: _pendingKey, value: jsonEncode(_pending));
        _launches.remove(purchase.productID);
        await _storage.write(key: _launchKey, value: jsonEncode(_launches));
      }
      await retryPending();
      // Google API on the server consumes/acknowledges verified purchases. An
      // unverified purchase stays in secure storage and is never credited locally.
      busy = false;
      notifyListeners();
    }
  }

  Future<void> retryPending() {
    // Startup, restored stream and the Restore button may overlap. Serialize
    // the secure journal updates so a completed purchase cannot reappear.
    return _retrying ??= _retryPending().whenComplete(() => _retrying = null);
  }

  Future<void> _retryPending() async {
    for (final entry in [..._pending]) {
      if (!account.ready) await account.load();
      if (entry['owner']!.isNotEmpty && entry['owner'] != account.id) {
        error = 'purchase_owner_invalid';
        continue;
      }
      try {
        await account.verifyPlay(entry['productId']!, entry['token']!);
        _pending.remove(entry);
        await _storage.write(key: _pendingKey, value: jsonEncode(_pending));
        error = null;
      } catch (_) {
        error = 'verification_pending';
      }
    }
  }

  Future<void> restore() async {
    if (testServicePreview) {
      throw const MobileApiError('test_service_unavailable');
    }
    if (!available) throw const MobileApiError('store_unavailable');
    await retryPending();
    await InAppPurchase.instance.restorePurchases(
      applicationUserName: account.id == null
          ? null
          : sha256.convert(utf8.encode(account.id!)).toString(),
    );
    await account.syncPlay();
  }

  @override
  void dispose() {
    _disposed = true;
    account.removeListener(_accountUpdated);
    _subscription?.cancel();
    super.dispose();
  }
}

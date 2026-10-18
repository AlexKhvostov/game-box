/// Explicit build mode: prices can be previewed, purchases cannot be launched.
/// This never creates ProductDetails, an entitlement, or a wallet reward.
abstract final class TestServicePreview {
  static const enabled = bool.fromEnvironment('TEST_SERVICE_PREVIEW');
}

class EnergyOfferPrice {
  const EnergyOfferPrice({
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    required this.currencySymbol,
    this.reference = false,
  });
  final String price, currencyCode, currencySymbol;
  final double rawPrice;
  final bool reference;
}

/// Approved developer prices, separate from Google's live product metadata.
/// Unknown prepared SKU versions have no invented reference price.
abstract final class EnergyTestCatalog {
  static const usd = <String, int>{
    'energy_100_v1': 2,
    'energy_250_v1': 4,
    'energy_500_v1': 6,
    'energy_1000_v1': 9,
    'energy_batteries_2_v1': 1,
    'energy_batteries_5_v1': 3,
  };

  static EnergyOfferPrice? price(String id) {
    final value = usd[id];
    return value == null
        ? null
        : EnergyOfferPrice(
            price: '\$$value',
            rawPrice: value.toDouble(),
            currencyCode: 'USD',
            currencySymbol: r'$',
            reference: true,
          );
  }
}

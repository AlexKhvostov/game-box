import 'package:intl/intl.dart';
import '../../domain/android_energy.dart';
import '../../domain/energy_test_catalog.dart';

class SubscriptionSaving {
  const SubscriptionSaving(this.percent, this.comparisonPrice);
  final int percent;
  final String comparisonPrice;
}

/// Compare the additional bonus units, for the same duration and currency.
/// This is a comparable regular price, never an invented historic store price.
SubscriptionSaving? subscriptionSaving({
  required EnergySubscriptionOffer offer,
  required List<EnergySubscriptionOffer> offers,
  required EnergyOfferPrice? Function(String) priceFor,
  required String locale,
}) {
  if (offer.totalBatteries != 5 || offers.isEmpty) return null;
  final baseline = offers.reduce(
    (a, b) => a.additionalBatteries <= b.additionalBatteries ? a : b,
  );
  final base = priceFor(baseline.id), price = priceFor(offer.id);
  if (base == null ||
      price == null ||
      baseline.additionalBatteries <= 0 ||
      baseline.basePlanId != offer.basePlanId ||
      baseline.periodDays != offer.periodDays ||
      base.reference != price.reference ||
      base.currencyCode.isEmpty ||
      base.currencyCode != price.currencyCode ||
      !base.rawPrice.isFinite ||
      !price.rawPrice.isFinite ||
      base.rawPrice <= 0 ||
      price.rawPrice <= 0) {
    return null;
  }
  final regular =
      base.rawPrice * offer.additionalBatteries / baseline.additionalBatteries;
  final percent = ((1 - price.rawPrice / regular) * 100).round();
  if (percent <= 0 || percent >= 100) return null;
  final format = NumberFormat.currency(
    locale: locale,
    name: price.currencyCode,
    symbol: price.currencySymbol.isEmpty
        ? price.currencyCode
        : price.currencySymbol,
  );
  return SubscriptionSaving(percent, format.format(regular));
}

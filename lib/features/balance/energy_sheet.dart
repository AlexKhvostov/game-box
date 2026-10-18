// Current energy navigation. Legacy presentation is isolated in legacy_energy_sheet.dart.
import 'package:flutter/material.dart';
import 'simple_energy_sheet.dart';
export 'energy_services.dart'
    show EnergyBillingStatus, EnergyFeedbackForm, buySimpleEnergy;

class EnergySheet extends StatelessWidget {
  const EnergySheet({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  Widget build(BuildContext context) => const SimpleEnergyWindow();
}

Future<void> showEnergySheet(BuildContext c, {int initialTab = 0}) =>
    showSimpleEnergyWindow(c);
Future<void> showEnergyAbilitySheet(BuildContext c, {required bool helmet}) =>
    showSimpleEnergyWindow(
      c,
      page: helmet ? EnergyPage.helmet : EnergyPage.jump,
    );
Future<void> showEnergySubscriptionSheet(BuildContext c) =>
    showSimpleEnergyWindow(c, page: EnergyPage.subscription);

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/play_billing_service.dart';
import '../domain/energy_test_catalog.dart';
import 'game_sheet.dart';
import 'game_ui.dart';

enum TestService { payment, restore, video }

bool testServicePreviewActive(BuildContext context) =>
    context.read<PlayBillingService?>()?.testServicePreview ??
    TestServicePreview.enabled;

Future<void> showTestServiceUnavailable(
  BuildContext context, {
  TestService service = TestService.payment,
  String? productId,
  int? amount,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    animationStyle: GameUi.windowAnimationStyle,
    builder: (c) => _TestServiceDialog(
      service: service,
      productId: productId,
      amount: amount,
    ),
  );
}

class _TestServiceDialog extends StatelessWidget {
  const _TestServiceDialog({
    required this.service,
    this.productId,
    this.amount,
  });
  final TestService service;
  final String? productId;
  final int? amount;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final message = switch (service) {
      TestService.payment =>
        ru
            ? 'В тестовой версии оплата пока недоступна.'
            : 'Payments are not available in this test version yet.',
      TestService.restore =>
        ru
            ? 'В тестовой версии восстановление покупок пока недоступно.'
            : 'Purchase restoration is not available in this test version yet.',
      TestService.video =>
        ru
            ? 'В тестовой версии просмотр рекламы пока недоступен.'
            : 'Video ads are not available in this test version yet.',
    };
    return Dialog(
      key: const ValueKey('test-service-unavailable'),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: GameSheetChrome(
          modal: true,
          fitContent: true,
          backgroundGradient: GameUi.navySheetGradient,
          glass: GameGlass.none,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameSheetHeader(
                    title: ru ? 'Тестовая версия' : 'Test version',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GameUi.text, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    key: const ValueKey('test-service-unavailable-close'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(ru ? 'Понятно' : 'OK'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

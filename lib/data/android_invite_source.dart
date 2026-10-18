import 'package:flutter/services.dart';

enum InviteReferrerStatus { available, absent, retry }

class InviteReferrer {
  const InviteReferrer(this.status, [this.value]);
  final InviteReferrerStatus status;
  final String? value;
}

abstract interface class AndroidInviteSource {
  void listen(VoidCallback onAvailable);
  Future<String?> peekAppLink();
  Future<void> acknowledgeAppLink(String url);
  Future<InviteReferrer> readInstallReferrer();
  void dispose();
}

class NativeAndroidInviteSource implements AndroidInviteSource {
  NativeAndroidInviteSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('untouch/invites');
  final MethodChannel _channel;

  @override
  void listen(VoidCallback onAvailable) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'appLinkAvailable') onAvailable();
    });
  }

  @override
  Future<String?> peekAppLink() => _channel.invokeMethod<String>('peekAppLink');

  @override
  Future<void> acknowledgeAppLink(String url) =>
      _channel.invokeMethod<void>('ackAppLink', {'url': url});

  @override
  Future<InviteReferrer> readInstallReferrer() async {
    final data = await _channel.invokeMapMethod<String, dynamic>(
      'readReferrer',
    );
    return switch (data?['status']) {
      'available' => InviteReferrer(
        InviteReferrerStatus.available,
        data?['value'] is String ? data!['value'] as String : null,
      ),
      'absent' => const InviteReferrer(InviteReferrerStatus.absent),
      _ => const InviteReferrer(InviteReferrerStatus.retry),
    };
  }

  @override
  void dispose() => _channel.setMethodCallHandler(null);
}

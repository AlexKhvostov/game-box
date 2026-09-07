import 'package:flutter/material.dart';

/// Stub вне web (Android APK и т.п.).
bool get isInsideTelegram => false;

int? get userId => null;

String? get username => null;

String? get firstName => null;

final ValueNotifier<EdgeInsets> viewPadding =
    ValueNotifier<EdgeInsets>(EdgeInsets.zero);

void bootstrapFullscreen() {}

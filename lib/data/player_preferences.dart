import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/gameplay_config.dart';
import '../ui/game_sfx.dart';

class PlayerPreferences extends ChangeNotifier {
  bool sound = true;
  bool music = true;
  bool lightTheme = false;
  bool googleStartupSeen = false;
  bool ageStartupSeen = false;
  late SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    sound = _prefs.getBool('device_sound') ?? true;
    music = _prefs.getBool('device_music') ?? true;
    lightTheme = _prefs.getBool('device_light_theme') ?? false;
    googleStartupSeen = _prefs.getBool('google_startup_seen_v1') ?? false;
    ageStartupSeen = _prefs.getBool('age_startup_seen_v1') ?? false;
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    sound = value;
    await _prefs.setBool('device_sound', value);
    notifyListeners();
  }

  Future<void> setMusic(bool value) async {
    music = value;
    await _prefs.setBool('device_music', value);
    notifyListeners();
  }

  Future<void> setLightTheme(bool value) async {
    lightTheme = value;
    await _prefs.setBool('device_light_theme', value);
    notifyListeners();
  }

  Future<void> markGoogleStartupSeen() async {
    googleStartupSeen = true;
    await _prefs.setBool('google_startup_seen_v1', true);
  }

  Future<void> markAgeStartupSeen() async {
    if (!await _prefs.setBool('age_startup_seen_v1', true)) {
      throw StateError('Could not persist age startup state');
    }
    ageStartupSeen = true;
  }

  void applyAudio(AudioConfig base) {
    final json = base.toJson();
    if (!sound) {
      for (final key in json.keys.where((key) => key.startsWith('sfx'))) {
        if (json[key] is bool) json[key] = false;
      }
    }
    if (!music) json['music'] = false;
    GameSfx.applyConfig(AudioConfig.fromJson(json));
  }
}

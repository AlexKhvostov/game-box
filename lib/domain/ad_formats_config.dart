class BannerFormatConfig {
  const BannerFormatConfig({
    this.enabled = false,
    this.installDelaySec = 86400,
    this.unitId = '',
  });
  final bool enabled;
  final int installDelaySec;
  final String unitId;
}

class AutomaticFormatConfig {
  const AutomaticFormatConfig({
    this.enabled = true,
    this.longAbsenceSec = 300,
    this.resumeGraceSec = 180,
  });
  final bool enabled;
  final int longAbsenceSec;
  final int resumeGraceSec;
}

class AdFormatsConfig {
  const AdFormatsConfig({
    this.banner = const BannerFormatConfig(),
    this.automatic = const AutomaticFormatConfig(),
    this.rewardedEnabled = true,
  });
  final BannerFormatConfig banner;
  final AutomaticFormatConfig automatic;
  final bool rewardedEnabled;
  Map<String, dynamic> toJson() => {
    'banner': {
      'enabled': banner.enabled,
      'installDelaySec': banner.installDelaySec,
      'unitId': banner.unitId,
    },
    'automatic': {
      'enabled': automatic.enabled,
      'longAbsenceSec': automatic.longAbsenceSec,
      'resumeGraceSec': automatic.resumeGraceSec,
    },
    'rewarded': {'enabled': rewardedEnabled},
  };

  factory AdFormatsConfig.fromJson(dynamic raw) {
    if (raw == null) return const AdFormatsConfig();
    if (raw is! Map) throw const FormatException('Invalid advertising policy');
    Map block(String key) {
      final value = raw[key];
      if (value == null && !raw.containsKey(key)) return const {};
      if (value is! Map) throw const FormatException('Invalid ad format');
      return value;
    }

    bool flag(Map value, String key, bool fallback) {
      if (!value.containsKey(key)) return fallback;
      if (value[key] is! bool) throw const FormatException('Invalid ad switch');
      return value[key] as bool;
    }

    int seconds(Map value, String key, int fallback) {
      if (!value.containsKey(key)) return fallback;
      final v = value[key];
      if (v is! int || v < 0 || v > 2592000) {
        throw const FormatException('Invalid ad delay');
      }
      return v;
    }

    final b = block('banner'), a = block('automatic'), r = block('rewarded');
    final unit = b.containsKey('unitId') ? b['unitId'] : '';
    if (unit is! String ||
        (unit.isNotEmpty && !RegExp(r'^R-M-\d+-\d+$').hasMatch(unit))) {
      throw const FormatException('Invalid banner unit');
    }
    return AdFormatsConfig(
      banner: BannerFormatConfig(
        enabled: flag(b, 'enabled', false),
        installDelaySec: seconds(b, 'installDelaySec', 86400),
        unitId: unit,
      ),
      automatic: AutomaticFormatConfig(
        enabled: flag(a, 'enabled', true),
        longAbsenceSec: seconds(a, 'longAbsenceSec', 300),
        resumeGraceSec: seconds(a, 'resumeGraceSec', 180),
      ),
      rewardedEnabled: flag(r, 'enabled', true),
    );
  }
}

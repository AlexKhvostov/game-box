import 'package:flutter/material.dart';
import '../data/app_analytics.dart';

RouteSettings analyticsWindow(String window) =>
    RouteSettings(name: '/analytics/window/$window');

/// Tracks only explicitly named product windows; other modals still obscure
/// their active time. No text, route arguments or account details are captured.
class AnalyticsNavigatorObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  AnalyticsNavigatorObserver({this.nowMs});
  final int Function()? nowMs;
  final Stopwatch _clock = Stopwatch()..start();
  int _readMs() => nowMs?.call() ?? _clock.elapsedMilliseconds;
  static final List<Route<dynamic>> _visibleRoutes = [];
  static final Set<AnalyticsNavigatorObserver> _owners = {};
  final List<Route<dynamic>> _routes = [];
  final Map<Route<dynamic>, _WindowVisit> _visits = {};
  bool _foreground = true;
  bool _observing = false;

  static void _checkpointAll() {
    for (final owner in _owners) {
      for (final visit in owner._visits.values) {
        final delta = visit.drain();
        if (delta > 0) {
          AppAnalytics.event('window_time', {
            'window': visit.name,
            'active_ms': delta,
          });
        }
      }
    }
  }

  static void _resetAll() {
    for (final owner in _owners) {
      for (final visit in owner._visits.values) {
        visit.reset();
      }
    }
    if (_owners.isNotEmpty) _owners.first._sync();
  }

  static void _foregroundAll(bool value) {
    for (final owner in _owners) {
      owner._foreground = value;
    }
    if (_owners.isNotEmpty) _owners.first._sync();
  }

  String get source {
    if (_visibleRoutes.isEmpty) return AppAnalytics.screen;
    for (final owner in _owners) {
      final visit = owner._visits[_visibleRoutes.last];
      if (visit != null) return visit.name;
    }
    return AppAnalytics.screen;
  }

  void _sync() {
    for (final owner in _owners) {
      for (final entry in owner._visits.entries) {
        entry.value.setActive(
          owner._foreground &&
              _visibleRoutes.isNotEmpty &&
              identical(entry.key, _visibleRoutes.last),
        );
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    final from = source;
    _owners.add(this);
    AppAnalytics.checkpointWindows = _checkpointAll;
    AppAnalytics.resetWindowTiming = _resetAll;
    AppAnalytics.windowsForeground = _foregroundAll;
    AppAnalytics.hasActiveWindows = () => _owners.any(
      (owner) => owner._visits.values.any((visit) => visit._activeAt != null),
    );
    _routes.add(route);
    _visibleRoutes.add(route);
    const prefix = '/analytics/window/';
    final name = route.settings.name;
    if (name != null && name.startsWith(prefix)) {
      final visit = _WindowVisit(name.substring(prefix.length), _readMs);
      _visits[route] = visit;
      AppAnalytics.event('window_opened', {
        'window': visit.name,
        'view_id': visit.id,
        'source': from,
      });
    }
    _sync();
  }

  void _remove(Route<dynamic> route, String reason) {
    _checkpointAll();
    final visit = _visits.remove(route);
    _routes.remove(route);
    _visibleRoutes.remove(route);
    if (visit != null) {
      visit.setActive(false);
      AppAnalytics.event('window_closed', {
        'window': visit.name,
        'view_id': visit.id,
        'reason': reason,
        'active_duration_ms': visit.elapsedMs,
      });
    }
    _sync();
    if (_routes.isEmpty && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route, 'dismissed');
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route, 'removed');
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _remove(oldRoute, 'replaced');
    if (newRoute != null) didPush(newRoute, null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void dispose() {
    _checkpointAll();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    for (final route in _routes) {
      _visibleRoutes.remove(route);
    }
    _owners.remove(this);
    if (_owners.isEmpty) {
      AppAnalytics.checkpointWindows = null;
      AppAnalytics.resetWindowTiming = null;
      AppAnalytics.windowsForeground = null;
      AppAnalytics.hasActiveWindows = null;
    }
    _routes.clear();
    _visits.clear();
    _sync();
  }
}

class _WindowVisit {
  _WindowVisit(this.name, this.nowMs);
  final String name;
  final String id = AppAnalytics.nextId();
  final int Function() nowMs;
  int _elapsed = 0;
  int? _activeAt;
  int _reportedMs = 0;
  int get elapsedMs =>
      _elapsed + (_activeAt == null ? 0 : nowMs() - _activeAt!);
  int drain() {
    final elapsed = elapsedMs;
    final delta = elapsed - _reportedMs;
    _reportedMs = elapsed;
    return delta;
  }

  void reset() {
    _elapsed = _reportedMs = 0;
    if (_activeAt != null) _activeAt = nowMs();
  }

  void setActive(bool active) {
    if (active) {
      _activeAt ??= nowMs();
    } else if (_activeAt != null) {
      _elapsed += nowMs() - _activeAt!;
      _activeAt = null;
    }
  }
}

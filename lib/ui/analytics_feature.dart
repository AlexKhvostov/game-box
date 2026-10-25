import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../data/app_analytics.dart';

/// One impression per visible feature/state, never an impression per rebuild.
/// Half of the element must be on-screen and its route must be current.
class AnalyticsFeature extends StatefulWidget {
  const AnalyticsFeature({
    super.key,
    required this.feature,
    required this.placement,
    required this.child,
    this.enabled = true,
    this.rewardType,
    this.amount,
  });
  final String feature, placement;
  final bool enabled;
  final String? rewardType;
  final int? amount;
  final Widget child;
  @override
  State<AnalyticsFeature> createState() => _AnalyticsFeatureState();
}

class _AnalyticsFeatureState extends State<AnalyticsFeature>
    with WidgetsBindingObserver {
  ScrollPosition? _scroll;
  String? _emitted;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_checkLater);
      _scroll = position;
      _scroll?.addListener(_checkLater);
    }
    _checkLater();
  }

  @override
  void didUpdateWidget(AnalyticsFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkLater();
  }

  void _checkLater() {
    if (AppAnalytics.sink == null ||
        _emitted == '${widget.feature}:${widget.placement}:${widget.enabled}') {
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !(ModalRoute.isCurrentOf(context) ?? true)) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final signature =
          '${widget.feature}:${widget.placement}:${widget.enabled}';
      if (_emitted == signature) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      final media = MediaQuery.of(context);
      var visible = bounds.intersect(Offset.zero & media.size);
      // A scroll viewport can clip a card even when it lies inside the screen.
      context.visitAncestorElements((element) {
        final render = element.renderObject;
        if (render is RenderAbstractViewport && render is RenderBox) {
          final viewport = render as RenderBox;
          if (!viewport.hasSize) return true;
          visible = visible.intersect(
            viewport.localToGlobal(Offset.zero) & viewport.size,
          );
        }
        return true;
      });
      if (visible.isEmpty ||
          visible.width * visible.height <
              box.size.width * box.size.height * .5) {
        return;
      }
      _emitted = signature;
      AppAnalytics.event('feature_shown', {
        'feature': widget.feature,
        'placement': widget.placement,
        'enabled': widget.enabled,
      });
      if (widget.enabled && widget.rewardType != null) {
        AppAnalytics.event('reward_available', {
          'reward_type': widget.rewardType!,
          'placement': widget.placement,
          if (widget.amount != null) 'amount': widget.amount!,
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLater();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkLater);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

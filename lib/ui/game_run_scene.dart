import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One static illustration, decoded at its displayed size. Sharing can request
/// a sharper decode for its exported PNG without adding animation work.
class GameRunScene extends StatelessWidget {
  const GameRunScene({super.key, this.exportPixelRatio = 1});
  static const asset = 'assets/branding/ui/run-scene-v1.png';
  static const resultAsset = 'assets/branding/ui/result-scene-v1.png';
  static const aspectRatio = 2.5;
  final double exportPixelRatio;

  static ImageProvider resultProvider(double width, double pixelRatio) =>
      ResizeImage.resizeIfNeeded(
        // One bounded decode is shared by result, preview and PNG export.
        // Previously their slightly different widths decoded/uploaded again
        // during the sheet's entrance, so its artwork could appear late.
        1086,
        null,
        const AssetImage(resultAsset),
      );

  static ImageProvider provider(double width, double pixelRatio) =>
      ResizeImage.resizeIfNeeded(
        1086, // Shared bounded banner decode for preview and PNG export.
        null,
        const AssetImage(asset),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AspectRatio(
      aspectRatio: aspectRatio,
      child: Image(
        image: provider(
          constraints.maxWidth,
          math.max(MediaQuery.devicePixelRatioOf(context), exportPixelRatio),
        ),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}

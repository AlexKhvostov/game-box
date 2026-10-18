import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The approved UI-kit vectors, bundled with the game (no network assets).
class RankingArt extends StatelessWidget {
  const RankingArt(this.name, {super.key, this.width = 20, this.height});
  final String name;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/branding/ranking/$name.svg',
    width: width,
    height: height ?? width,
    excludeFromSemantics: true,
    fit: BoxFit.contain,
  );
}

import 'dart:math';

class Offset {
  const Offset(this.dx, this.dy);
  final double dx, dy;
  static const zero = Offset(0, 0);
  Offset operator +(Offset o) => Offset(dx + o.dx, dy + o.dy);
  Offset operator -(Offset o) => Offset(dx - o.dx, dy - o.dy);
  Offset operator -() => Offset(-dx, -dy);
  Offset operator *(double n) => Offset(dx * n, dy * n);
  Offset operator /(double n) => Offset(dx / n, dy / n);
  double get distance => sqrt(dx * dx + dy * dy);
}

class Size {
  const Size(this.width, this.height);
  final double width, height;
}

class Rect {
  const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);
  const Rect.fromLTWH(double x, double y, double w, double h)
    : left = x,
      top = y,
      right = x + w,
      bottom = y + h;
  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;
  Offset get center => Offset((left + right) / 2, (top + bottom) / 2);
  bool overlaps(Rect o) =>
      left < o.right && right > o.left && top < o.bottom && bottom > o.top;
  Rect inflate(double n) =>
      Rect.fromLTRB(left - n, top - n, right + n, bottom + n);
}

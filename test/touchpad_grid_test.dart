import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_box/features/game/game_touchpad.dart';

void main() {
  test(
    'perspective grid adds rows as height grows, keeping near cells square',
    () {
      double previousDepth = 0;
      for (final height in [300.0, 600.0, 900.0]) {
        final grid = TouchpadGrid(Size(540, height));
        final nearHeight = grid.bottom - grid.rowY(1);
        expect(nearHeight / grid.cell, inInclusiveRange(.8, 1));
        expect(grid.depth, greaterThan(previousDepth));
        previousDepth = grid.depth;
        expect(grid.rowY(grid.depth), closeTo(grid.top, .001));
        var lastSpacing = double.infinity;
        for (var row = 1; row < grid.depth; row++) {
          final spacing = grid.rowY(row - 1.0) - grid.rowY(row.toDouble());
          expect(spacing, greaterThan(0));
          expect(spacing, lessThan(lastSpacing));
          lastSpacing = spacing;
        }
      }
    },
  );
}

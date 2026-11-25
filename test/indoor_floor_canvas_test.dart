import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/widgets/indoor_floor_canvas.dart';

void main() {
  testWidgets('measurement coordinates refer to image bounds, not viewport',
      (tester) async {
    Offset? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 400,
      height: 400,
      child: IndoorFloorCanvas(
          floor: 'B2',
          onPick: (x, y) {
            selected = Offset(x, y);
          }),
    ))));
    final map = find.byKey(const ValueKey('indoor-map-image'));
    final bounds = tester.getRect(map);
    await tester.tapAt(
        bounds.topLeft + Offset(bounds.width * .005, bounds.height * .5));
    await tester.pump();
    expect(selected!.dx, closeTo(.5, .01));
    expect(selected!.dy, closeTo(50, .01));
  });
}

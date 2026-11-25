import 'package:flutter/material.dart';

/// Percent coordinates always refer to the image canvas, including x < 1%.
class IndoorFloorCanvas extends StatelessWidget {
  const IndoorFloorCanvas(
      {required this.floor,
      this.xPct,
      this.yPct,
      this.onPick,
      this.points = const [],
      this.markerColor = Colors.blue,
      super.key});
  final String floor;
  final double? xPct, yPct;
  final void Function(double, double)? onPick;
  final List<Offset> points;
  final Color markerColor;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        minScale: .8,
        maxScale: 6,
        boundaryMargin: const EdgeInsets.all(40),
        child: Center(
            child: AspectRatio(
          aspectRatio: floor == 'B1' ? 2047 / 1877 : 3920 / 2240,
          child: LayoutBuilder(
              builder: (context, bounds) => GestureDetector(
                    key: const ValueKey('indoor-map-image'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: onPick == null
                        ? null
                        : (event) => onPick!(
                            (event.localPosition.dx / bounds.maxWidth * 100)
                                .clamp(0, 100),
                            (event.localPosition.dy / bounds.maxHeight * 100)
                                .clamp(0, 100)),
                    child: Stack(children: [
                      Positioned.fill(
                          child: Image.asset(
                              'assets/images/$floor-simplified.png',
                              fit: BoxFit.fill)),
                      for (final p in points)
                        Positioned(
                            left: bounds.maxWidth * p.dx / 100 - 4,
                            top: bounds.maxHeight * p.dy / 100 - 4,
                            child: const IgnorePointer(
                                child: Icon(Icons.circle,
                                    size: 8, color: Colors.orange))),
                      if (xPct != null && yPct != null)
                        Positioned(
                            left: bounds.maxWidth * xPct! / 100 - 12,
                            top: bounds.maxHeight * yPct! / 100 - 12,
                            child: IgnorePointer(
                                child: Icon(Icons.my_location,
                                    size: 24, color: markerColor))),
                    ]),
                  )),
        )),
      );
}

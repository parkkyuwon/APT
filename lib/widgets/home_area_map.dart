import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Online street map for choosing the private home area, independent of BLE maps.
class HomeAreaMap extends StatefulWidget {
  const HomeAreaMap(
      {super.key,
      this.center,
      required this.radiusMeters,
      this.onSelected,
      this.tileProvider});
  final LatLng? center;
  final double radiusMeters;
  final ValueChanged<LatLng>? onSelected;
  final TileProvider? tileProvider;

  @override
  State<HomeAreaMap> createState() => _HomeAreaMapState();
}

class _HomeAreaMapState extends State<HomeAreaMap> {
  final _controller = MapController();
  bool _tileError = false;
  int _retry = 0;
  CameraFit? get _fit => widget.center == null
      ? null
      : CameraFit.coordinates(coordinates: [
          for (final bearing in [0.0, 90.0, 180.0, 270.0])
            const Distance()
                .offset(widget.center!, widget.radiusMeters, bearing)
        ], padding: const EdgeInsets.all(32), maxZoom: 17);

  @override
  void didUpdateWidget(HomeAreaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.center != null &&
        (widget.center != oldWidget.center ||
            widget.radiusMeters != oldWidget.radiusMeters)) {
      _controller.fitCamera(_fit!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTileError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                key: const Key('home-area-map'),
                mapController: _controller,
                options: MapOptions(
                  initialCenter:
                      widget.center ?? const LatLng(37.5665, 126.9780),
                  initialZoom: 15,
                  initialCameraFit: _fit,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, point) => widget.onSelected?.call(point),
                ),
                children: [
                  TileLayer(
                    key: ValueKey(_retry),
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'apt.ev.service',
                    maxNativeZoom: 19,
                    panBuffer: 0,
                    tileProvider: widget.tileProvider,
                    tileDisplay: const TileDisplay.instantaneous(),
                    errorTileCallback: (_, __, ___) => _onTileError(),
                  ),
                  if (widget.center != null) ...[
                    CircleLayer(circles: [
                      CircleMarker(
                          point: widget.center!,
                          radius: widget.radiusMeters,
                          useRadiusInMeter: true,
                          color: Colors.blue.withValues(alpha: .18),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2)
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                          point: widget.center!,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_pin,
                              size: 40, color: Colors.red))
                    ]),
                  ],
                  SimpleAttributionWidget(
                      source: const Text('OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11)),
                      onTap: () => launchUrl(Uri.parse(
                          'https://www.openstreetmap.org/copyright'))),
                ],
              ),
            )),
        if (_tileError)
          Row(children: [
            const Expanded(child: Text('지도를 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.')),
            TextButton(
                onPressed: () => setState(() {
                      _tileError = false;
                      _retry++;
                    }),
                child: const Text('다시 시도')),
          ]),
        const Text('지도에서 집 위치를 선택하거나 현재 위치를 사용하세요.',
            style: TextStyle(fontSize: 12)),
        const Text('온라인 지도 표시 시 지도 영역과 IP 주소가 OpenStreetMap에 전달될 수 있습니다.',
            style: TextStyle(fontSize: 11)),
      ]);
}

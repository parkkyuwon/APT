import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/screens/public/map_view_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ApiServices services;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    services = ApiServices.from(await ApiClient.init());
  });
  testWidgets('both floor maps zoom and pan across the full viewport',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppStateProvider(services),
      child: const MaterialApp(home: MapViewScreen()),
    ));
    await tester.pumpAndSettle();
    for (final floor in ['B1', 'B2']) {
      await tester.tap(find.text(floor));
      await tester.pumpAndSettle();
      expect(
          (tester.widget<Image>(find.byType(Image).hitTestable()).image
                  as AssetImage)
              .assetName,
          'assets/images/$floor-simplified.png');
      final viewerFinder = find.byType(InteractiveViewer).hitTestable();
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final viewport = tester.getRect(viewerFinder);
      expect(viewport.width, 400);
      expect(viewport.height, greaterThan(700));
      final controller = viewer.transformationController!;
      controller.value = Matrix4.diagonal3Values(3, 3, 1)
        ..setTranslationRaw(-viewport.width, -viewport.height, 0);
      await tester.pump();
      final imageRect = tester.getRect(find.byType(Image).hitTestable());
      expect(imageRect.width, closeTo(1200, 1));
      final before = controller.value.clone();
      // Pan in the space below the initial fitted image.
      await tester.dragFrom(Offset(viewport.center.dx, viewport.bottom - 60),
          const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(controller.value, isNot(before));
      expect(tester.takeException(), isNull);
    }
  });
}

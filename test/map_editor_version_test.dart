import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/screens/admin/map_editor_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditorState extends AppStateProvider {
  EditorState(super.services);
  AppState snapshot = AppState.fromJson({
    'stateVersion': 4,
    'slots': {
      'fast50': [
        {'id': 'fast50-1', 'typeId': 'fast50'}
      ]
    },
    'slotMapPositions': {
      'fast50-1': {'floor': 'B1', 'x': 20, 'y': 20}
    }
  });
  Map<String, dynamic>? submitted;
  @override
  AppState get state => snapshot;
  void advance() {
    snapshot = AppState.fromJson({...snapshot.toJson(), 'stateVersion': 5});
    notifyListeners();
  }

  @override
  Future<void> saveFullState(Map<String, dynamic> payload) async {
    submitted = payload;
  }
}

void main() {
  testWidgets('map edits retain the loaded version after provider refresh',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    final state = EditorState(ApiServices.from(client));
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppStateProvider>.value(
      value: state,
      child: const MaterialApp(home: MapEditorScreen()),
    ));
    await tester.pump();
    expect(
        (tester.widget<Image>(find.byType(Image).first).image as AssetImage)
            .assetName,
        'assets/images/B1-simplified.png');
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump();
    await tester.tap(find.byType(Image).first);
    await tester.pump();
    state.advance();
    await tester.pump();
    await tester.tap(find.byTooltip('저장'));
    await tester.pump();
    expect(state.submitted?['stateVersion'], 4);
    expect(state.submitted?['slotMapPositions'], isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

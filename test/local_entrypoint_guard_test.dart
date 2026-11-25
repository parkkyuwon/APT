import 'package:apt_ev_charging/main_local_test.dart' as local;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local entrypoint refuses normal production build settings', () async {
    await expectLater(local.main(), throwsStateError);
  });
}

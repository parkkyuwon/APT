import 'package:apt_ev_charging/core/errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authStatusFromString', () {
    test('known values', () {
      expect(authStatusFromString('pending'), AuthStatus.pending);
      expect(authStatusFromString('approved'), AuthStatus.approved);
      expect(authStatusFromString('rejected'), AuthStatus.rejected);
      expect(authStatusFromString('blocked'), AuthStatus.blocked);
      expect(authStatusFromString('withdrawn'), AuthStatus.withdrawn);
      expect(authStatusFromString('dormant'), AuthStatus.dormant);
    });
    test('case-insensitive + trim', () {
      expect(authStatusFromString('  APPROVED  '), AuthStatus.approved);
    });
    test('unknown/null is unknown', () {
      expect(authStatusFromString(null), AuthStatus.unknown);
      expect(authStatusFromString(''), AuthStatus.unknown);
      expect(authStatusFromString('foo'), AuthStatus.unknown);
    });
  });

  group('ApiException', () {
    test('flags and message', () {
      final e = ApiException(
        statusCode: 401,
        message: '로그인 필요',
        authStatus: AuthStatus.pending,
        needsConsent: true,
      );
      expect(e.statusCode, 401);
      expect(e.isAuthRequired, true);
      expect(e.isForbidden, false);
      expect(e.needsConsent, true);
      expect(e.message, '로그인 필요');
      expect(e.toString(), contains('401'));
    });
    test('403 isForbidden', () {
      final e = ApiException(statusCode: 403, message: '권한 없음');
      expect(e.isForbidden, true);
      expect(e.isAuthRequired, false);
    });
  });
}

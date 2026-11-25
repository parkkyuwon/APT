import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/core/plate_recognition.dart';

void main() {
  test('typed input accepts exactly one full plate', () {
    expect(isSinglePlate('123 가-4567'), isTrue);
    expect(isSinglePlate('서울12가3456'), isTrue);
    expect(isSinglePlate('123가4567,234나5678'), isFalse);
    expect(isSinglePlate('123가4567 234나5678'), isFalse);
    expect(isSinglePlate('123가4567\n234나5678'), isFalse);
    expect(isSinglePlate('123가4567/234나5678'), isFalse);
    expect(isSinglePlate('123가4567;234나5678'), isFalse);
    expect(isSinglePlate('차량 123가4567'), isFalse);
    expect(plateMatches('123가4567,234나5678', ['123가4567,234나5678']), isFalse);
  });
  test('unrelated Korean labels never become a regional plate prefix', () {
    expect(extractPlateCandidates('대한민국\n123가4567'), ['123가4567']);
    expect(extractPlateCandidates('차량번호 123가4567'), ['123가4567']);
    expect(extractPlateCandidates('서울 12 가 3456'), ['서울12가3456']);
  });
  test('keeps Korean glyphs and removes only spacing and hyphens', () {
    expect(normalizePlate('123 가-4567'), '123가4567');
    expect(extractPlateCandidates('서울 12 가 3456\n123 나 4567'),
        ['서울12가3456', '123나4567']);
    expect(plateMatches('123가4567', ['123나4567']), isFalse);
    expect(plateMatches('123 가-4567', ['123가4567']), isTrue);
    expect(plateMatches('', ['']), isFalse);
  });
}

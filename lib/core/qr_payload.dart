/// 슬롯 QR/NFC 페이로드 빌더. 관리자 QR 콘솔, 사용자 슬롯 상세 다이얼로그,
/// CSV 출력 모두 같은 형식을 사용해 동작 일관성 유지.
///
/// `mode=smart` 파라미터는 웹·앱 모두에 "QR 진입 자동 채움" 신호.
/// - 웹(script.js): 충전 시간 자동 입력 + 주차 다이얼로그 자동 오픈
/// - 앱(home_screen): 다이얼로그 없이 즉시 자동 주차 등록
const String kAppDefaultBaseUrl = 'https://apt-ev-charging.vercel.app';

String slotQrPayload(String slotId, {String baseUrl = kAppDefaultBaseUrl}) =>
    '$baseUrl/index.html?slot=$slotId&mode=smart';

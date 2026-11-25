# 1.1.4+20 배포 검증 기록

## 범위와 사용자 결정

전화번호 수집 제거, Google 계정 기반 가입과 필수 닉네임(1~30자), 단일 차량번호 전체 검증, 번호판 사진 OCR 비교 후 관리자 승인, 개인정보 정리/회원 삭제 버튼, 관리자 OCR 테스트, 입주민 이슈 게시판, 사진 포함 충전기 고장 신고를 앱과 별도 서버에 반영한다. 차량 변경은 기존 1대를 교체하며 새 OCR/재승인이 필요하다. 동일 차량의 닉네임 수정은 승인을 유지한다.

추가 음성통화는 현재 주차 차주가 해당 주차에서 수신을 허용한 경우에만 가능하다. 기본 꺼짐, QR 자동 등록도 꺼짐이다. 사용자는 ‘권장 설계로 구현하고 TURN 설정 후 활성화’를 선택했다. 앱 전경에서만 통화하며 수락 전에는 마이크를 열지 않는다. 다른 화면을 push해도 전역 패널이 수락/거절/종료를 표시한다. 앱은 음성을 녹음하지 않는다.

## 운영 변경 이력

- 운영 프로젝트: `apt-ev-charging`, 도메인 `https://apt-ev-charging.vercel.app`.
- 기존 배포: `apt-ev-charging-e8iervni8-polkolpk-7667s-projects.vercel.app` (`dpl_EW12gK6D42nAV5gr5zQfAkJBYbYw`). 도메인 전환 전 복구 대상이다.
- `resident-community.sql`과 갱신된 `member-management.sql`을 보존 검사 트랜잭션으로 운영 적용했다. 기존 회원 53개와 주차 상태 1개가 유지됐으며 실제 회원 삭제·개인정보 정리·승인 작업은 실행하지 않았다.
- 기존 `GOOGLE_CLIENT_ID` 끝의 잘못된 문자만 제거했다. 같은 기존 클라이언트 ID임을 확인했고 새 ID·권한·자격 증명을 생성하지 않았다. 운영 환경 재조회로 형식을 검증했다.
- 위 설정을 사용하는 도메인 미전환 준비 배포: `apt-ev-charging-l7nxjzrs9-polkolpk-7667s-projects.vercel.app`, READY. 음성통화 추가 전 배포이므로 최종 후보와 구분한다.
- `parking-voice.sql`도 전용 보존 검사로 운영 적용했다. 회원 53개·주차 상태 1개 유지, 수신 허용·통화·신호는 모두 0건이다. 운영 기능 플래그와 TURN 설정 모두 꺼짐/없음을 읽기 전용으로 확인했다.
- 최종 준비 서버: `apt-ev-charging-7ofeb55qh-polkolpk-7667s-projects.vercel.app` (`dpl_D5qfYZG2MwpJVkkSUivRcydZXZpD`), READY. 공개 dashboard 200, 비회원 board/reports/voice 접근 401을 확인했다. 운영 도메인을 inspect하여 기존 배포가 유지됨도 확인했다.

## 검증 증거

- 통화 전 전체 Flutter 테스트 156개, 서버 테스트 101개 통과.
- 최종 전체 Flutter 테스트 187개 통과(74초, `D:/Temp/apt-voice-flutter-final.log`). 전역 패널의 숨김 상태 여백, 시계 역행에도 유지되는 타이머, 대기 상태의 잘못된 종료 안내 방지 회귀를 포함한다.
- 통화 API 4개, 통화 Controller/화면/주차 선택 집중 검증 18개, 인증·화면 전환 3개 통과. TURN 미설정, 수락 전 마이크 금지, 백그라운드/로그아웃 종료, 짧은 lease, 링 중 heartbeat, 원격 신호 순서 및 pushed 화면 수신을 포함한다.
- 최종 서버 전체 테스트 124개 통과(16.8초, `D:/Temp/apt-voice-server-full.log`). 배포 보존 검사 7개를 포함한다. 실제 PGlite에 통화 SQL을 적용하고 재적용해 기존 회원과 점유/차단 주차를 보존하는 경로도 검사했다. 기본 꺼짐 메타데이터 추가만 허용하며 기존 차량·기존 동의 변경은 롤백한다.
- 최종 `flutter analyze --no-fatal-infos`는 `No issues found`(6.1초, `D:/Temp/apt-voice-analyze-final.log`).
- 통화 추가 전 운영 설정 release AAB는 216.7초에 빌드됐으나 최종 게시물로 사용하지 않는다. 새 통화 플러그인을 포함한 ARM64 Debug APK는 163.6초에 빌드됐고 네이티브 라이브러리 8개의 16KB ELF 정렬을 확인했다. 실제 기기 실행은 별도다. 최종 Release 빌드·서명·manifest·16KB 정렬 검증은 아래 최종 산출물과 함께 기록한다. 빌드 로그의 환경 정의 echo는 제거해 키 값을 남기지 않는다.

## 최종 Android 산출물

`AppBundle/releases/2026-10-20-v1.1.4-20/apt-ev-service-v1.1.4-20.aab` (84,901,873 bytes, 빌드 204.0초).

- 패키지 `apt.ev.service`, `versionName=1.1.4`, `versionCode=20`, minSdk 24, targetSdk 36.
- SHA256: `6e16997bacd66fdfb74548866ee6222379bffd38c1369b8ec4005b942694f73a`.
- bundletool 검증·서명 검증 성공. 버전 19 업로드 인증서와 일치하며 Android Debug 인증서가 아니다.
- 64비트 네이티브 라이브러리 10개 모두 16KB ELF LOAD 정렬, BundleConfig `PAGE_ALIGNMENT_16K` 확인.
- 마이크 권한 있음. 전화 걸기/전화번호 읽기/주소록/광범위 사진·동영상 읽기 권한 없음.
- 같은 폴더에 Dart symbols 3개, R8 mapping, manifest/config, 공개 인증서, 해시, 분석·테스트·빌드·마이그레이션 로그 및 한국어 출시 설명 초안을 보관했다. 실제 스토어 업로드·제출은 0건이다.

## 배포·실기기 제한

운영 TURN 관련 설정이 없으므로 통화를 비활성화한다. 임의 공개 TURN 자격 증명이나 유료 서비스 계정을 만들지 않는다. 공급자·지역·정책을 정하고 단기 자격 증명 설정을 준비한 뒤 Android/iOS 기기 2대의 Wi-Fi/LTE 음성, 권한 거절/허용, 잠금·백그라운드 종료를 검증해야 한다. 카메라/OCR·Google 로그인·QR/BLE도 실제 기기 확인과 구분한다.

Play Console 로그인을 알려주셨으나 자동화 도구의 연결 목록은 여전히 `apps:[], browsers:[]`이다. 기존 Chrome과 IAB 접근도 사용할 수 없었다. Console 업로드·심사 제출은 수행됐다고 보고하지 않는다. iOS는 macOS/Xcode 접근이 없다.

임시 환경 파일·폴더를 함께 정리하는 명령은 자동 승인 검토에서 `blocked by policy`로 거절됐다. 이후 경로를 읽기 전용으로 검증하고 삭제 범위를 해당 `production.env` 단일 파일로 줄인 명령은 허용됐으며, 파일이 없어졌음을 확인했다. 빈 폴더와 위치 포인터(`D:/Temp/apt-release-private-current.txt`)만 남긴다. 비밀이나 연결 문자열은 저장소·이 기록에 복사하지 않았다.

새 가입/차량 교체는 새 앱의 OCR을 요구하므로, 준비 서버의 도메인 전환은 새 앱 배포 가능 상태와 함께 판단한다. 승인된 기존 웹 회원의 조회·주차·닉네임 수정은 보존하며 새 OCR/최종 승인은 앱으로 안내한다.

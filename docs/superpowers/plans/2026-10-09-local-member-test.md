# 실행 계획

- PM: 기존 GPT-6.1 Sol pm_review. 구현/구조/블루스택 검증: root. 가상 서버 구현: GPT-6 Luna. 독립 QC: PM.
- 새 의존성 없이 기존 AptEvApp, ApiServices, Dio adapter와 테스트 패턴을 사용한다. Dart 명명 규칙을 유지한다.
- 먼저 가상 서버의 회원 상태 변경, 로그아웃 이후 쓰기 거절, 미등록 경로 거절 테스트를 작성하고 실패를 확인한다. adapter 구현 후 재실행한다.
- debug 진입점 및 Android 별도 패키지 조건을 추가한다. 로컬 전용 API 주소와 release 금지 조건을 확인한다.
- 분석/관련 테스트/전체 테스트를 순차 실행하고 debug APK를 빌드한다. 블루스택에서 회원 흐름을 확인하고 증거를 저장한다.
- 마지막에 일반 앱을 실행하여 비회원 모드와 접근 제한을 확인한다. 가상 테스트와 외부 미검증 항목을 구분해 보고한다.
- Flutter/Gradle 동시 빌드를 금지하고 테스트 workers=2, Gradle workers=2를 사용한다.

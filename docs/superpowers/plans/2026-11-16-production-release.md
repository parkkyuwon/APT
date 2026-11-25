# 차량 인증 정책 Android 배포 진행

사용자 요청: 완료된 작업 동작 검증 후 Play Console 배포. 서버·DB 의존성을 먼저 반영하며 기존 주차장 원본 이미지를 유지한다.

작업 재개 시 `docs/verification/RELEASE_1.1.5_22_2026-11-16.md`의 **작업 재개 시 적용할 주의사항**을 먼저 적용한다. 사용자가 명시적으로 요청한 인계 조건이며 서버/DB 중복 배포 방지, Console 버전 확인, 미검증 범위 명시, 원본 지도·기존 변경 보존을 포함한다.

- [x] 변경 상태·기존 배포 기록·서명/Firebase 설정 파일 존재 확인. 민감한 내용은 출력하지 않음.
- [x] 최신 Flutter 전체 230개·분석 이상 없음, 서버 전체 150개 테스트 통과 확인.
- [x] 회원·주차 보존 확인 후 상태 버전·차량 정책 SQL 반영 및 서버/웹 배포. 운영 배포 `dpl_3A5VznwniVJYhiFVu1p3QiBGph2E` 확인.
- [x] 후보 `1.1.5+22` 서명 release AAB 생성, manifest·서명·16KB 정렬·해시 검증.
- [ ] 실행 가능한 Android 장치에서 확인. NFC RF와 실제 Google 로그인은 별도 미검증 범위로 구분.
- [ ] Console 최고 versionCode·현재 출시 상태 확인 후 새 AAB 업로드·검토 제출·관리형 게시 상태 기록.

초기 Console 접근: 브라우저 호스트가 연결되지 않았고 Windows Chrome 현재 URL 판별 실패로 Computer Use가 해당 턴의 제어를 중단했다. Console UI 입력·파일 업로드·출시는 수행되지 않았다. 사용자에게 Chrome Play Console 로그인과 브라우저 연결 활성화를 요청했으며 번들 준비와 서버 작업은 계속한다. 원격 최고 versionCode는 미확인이므로 22는 업로드 전 후보 번호다.

사용자가 Chrome 연결을 알린 뒤 재확인했으나 같은 정책 차단이 반복됐다. 연결 기기도 0대이므로 실기기 실행 검증은 미수행이다. 최종 증거: `docs/verification/RELEASE_1.1.5_22_2026-11-16.md`.

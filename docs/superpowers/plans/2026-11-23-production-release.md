# 지하 위치 기능 Android 배포

사용자가 2026-11-23 Play Console 배포를 명시했다. 현재 작업 트리의 구현과 B1/B2 분리 저장을 배포 대상으로 한다. 이전 회원·주차 자료, 원본 지도, 업로드 서명과 기존 배포 설정을 보존한다.

- [x] Console 기존 production 22 (1.1.5), alpha 21, internal 16과 게시되지 않은 변경 없음 확인. 패키지 apt.ev.service.
- [x] 앱 286개·서버 159개 테스트, 분석 문제 없음과 debug 빌드 검증 기록 확인.
- [x] 새 indoor-positioning SQL만 적용. 기존 회원·주차 행과 15개 테이블 건수 보존.
- [x] 서버 privacy1.4 포함 후보 `dpl_6vHjmP2tfitgPq4fxr4pFkiR8CMu`를 canonical 승격·검증. rollback `dpl_3A5VznwniVJYhiFVu1p3QiBGph2E` 보존.
- [x] 23번의 사용 여부가 불명확하고 사전 안내 반영이 필요해 1.1.6+24를 새로 빌드. 운영 URL/Firebase, 업로드 인증서, manifest, 16KB, 모든 ABI 사전 안내 표식 검증 통과. 최종 대상 `AppBundle/releases/2026-11-23-v1.1.6-24/apt-ev-service-v1.1.6-24.aab`.
- [ ] Console AAB 업로드·릴리스 노트·새 권한 관련 필요한 선언 확인.
- [ ] 실제 관찰한 상태에 따라 심사 제출·관리형 게시·출시 여부 기록.

Maps 키가 없으면 GoogleMap을 생성하지 않으며 현재 위치/위경도 입력으로 개인 반경을 설정한다. 키 파일 경로에 대한 사용자 질문과 독립적으로 서명 번들 준비를 진행한다. iOS는 이번 Android 배포 대상이 아니다. 연결된 Android/iOS 실기기가 없어 실측 정상 동작을 보증하지 않는다. 콘솔이 요구하는 실제 검증 영상/필수 선언/인증은 사실대로 처리하며 자료가 없으면 그 항목을 완료로 표시하지 않는다.

후속: Android17 휴대폰 연결을 확인했으나 설치본은 Play 서명 22번으로 로컬 서명과 달라 앱/데이터를 보존하며 최신본을 확보하는 단계다. 영상 촬영은 미수행. Play API 서비스 계정 인증이 아직 없으므로 브라우저 자동화로 전환하지 않는다. 상세 촬영 전제와 절차는 `docs/verification/PLAY_BACKGROUND_LOCATION_VIDEO_2026-11-23.md`를 따른다.

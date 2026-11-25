# 카메라·사진 보안검토 대응

**상태: 보류 — 원문 수신 후 Android targetSdk 36 전환으로 범위 정정.** 사용자가 전달한 실제 안내는 API 35 대상 앱의 API 36 이상 전환 및 새 프로덕션 버전 게시 요구다. 카메라 제재가 아니다. 이 계획은 초기 조사 기록이며 카메라 구현에 착수하지 않았고 관련 소스 변경도 없다. 현재 실행 방향은 `docs/architecture/ANDROID_API36_REVIEW.md`를 따른다. 아래 미완료 항목은 현 작업의 남은 의무가 아니다.

사용자 요청: 배포 등록 후 받은 카메라 사용 보안검토 문제 해결. 검토 기관과 요청 원문은 확인 질문을 보냈으며 아직 미수신이다. 원문에 따른 심사 해결 여부는 별도 확정한다.

Blue Ocean PM은 기존 사용자 지정 `gpt-6.1-sol` `/root/pm_review`, 구현·검증은 root가 맡는다. PC 메모리 여유가 제한되어 Flutter 명령은 순차 실행하며 PM만 독립 검토한다. 변경 하위 그래프는 `app/auth → member-ui → services/profile → http/backend`, `member-ui → platform/image_picker`다. 기존 Provider, 두 사진 화면, image_picker와 시스템 카메라/선택기를 재사용한다.

방향은 차량 사진 인증을 유지하며 Android 불필요 직접 CAMERA 및 전체 사진 읽기 선언을 제거하는 것이다. pinned image_picker Android 구현과 병합 manifest로 검증한다. iOS의 QR 스캔/QR 사진 저장 오기 대신 실제 차량 번호판 사진 촬영·선택 목적을 기재한다. 두 화면에 목적·관리자 검토·버튼 제출 시 서버 전송을 기존 설명 위치에 표시한다. 시각 개편 없이 기존 Text·버튼을 유지하는 설명 보완으로 GUI DR를 면제한다. 새 카메라/추적 SDK·서버 변경·스토어 제출은 없다.

사진 선택은 `requestFullMetadata:false`, 사용자 취소 시 전송 없음, 권한 거절 시 설명과 갤러리 대안 유지, 화면 종료 뒤 비동기 결과 setState 금지를 검사한다. 실제 사용자인지와 업로드 여부, 데이터 보존·삭제·공유는 현재 서버 계약과 운영 정책을 확인해야 하며 사실을 꾸며 쓰지 않는다. 기존 삭제 보장 문구는 서버 검증 없이 재사용하지 않는다.

- [ ] pinned plugin 계약과 공식 정책 근거 확인
- [ ] 사진 선택·거절·취소·화면 종료 회귀 RED→GREEN
- [ ] Android/iOS 최소권한·목적 설명 및 두 화면 적용
- [ ] 전체 테스트·분석·Android APK 및 병합 권한 검사
- [ ] 재심사 대응 문서, 외부 설정 및 미검증 조건 기록
- [ ] GPT-6.1-sol PM 독립 검토

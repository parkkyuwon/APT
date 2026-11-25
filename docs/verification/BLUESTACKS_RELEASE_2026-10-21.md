# BlueStacks 검증 후 Play 배포 — 1.1.4+20

> 릴리스 20의 검증 이력이다. 선택적 마이크 하드웨어 선언과 최신 동의 문구를 포함하는 후속 릴리스 21로 교체 준비 중이며, 21의 빌드·제출 결과는 별도 기록을 따른다.

사용자가 ‘블루스택에서 동작검증을 하고 이후 플레이 콘솔에서 배포’를 요청했다. 브라우저 연결 후 Play Console의 `apt.ev.service`와 현재 프로덕션 `19 (1.1.3)`를 확인했다. 운영 데이터 변경용 테스트 계정·게시글·신고·주차를 만들지 않는다.

## 실행 환경 및 설치 준비

- BlueStacks App Player 5.22.280.1025, Pie64, Android 9/API28. adb `127.0.0.1:5555`로 `sys.boot_completed=1` 확인.
- 기존 `apt.ev.service`는 1.1.0/code15, Android Debug 인증서였다. 기존 앱 데이터를 삭제하거나 앱을 제거하지 않는다.
- 최종 서명 AAB SHA256은 `6e16997bacd66fdfb74548866ee6222379bffd38c1369b8ec4005b942694f73a`다. bundletool로 해당 AAB의 장치용 x86_64/hdpi/ko APK 세트를 생성했다.
- 검증 복사본에만 기존 Android Debug 인증서를 사용해 기존 설치와 호환되게 했다. 서명 SHA256 `d15ab19d8280db385c422eea60d3134226d4fef6590760738a2b2115e2d70e9c` 일치를 확인했다. 게시용 AAB와 그 업로드 서명은 변경하지 않는다.
- bundletool 설치가 지연되어 설치 스레드를 진단했다. `SplitApkInstallerBase.installCommit` 대기와 `dex2oat`를 확인했고, 실제 최적화 대상은 `com.android.vending` 자동 업데이트였다. 다른 앱의 설치를 중단하지 않는다.

## 확인할 범위

- [x] 앱 업데이트 후 code20/min24/target36 확인.
- [x] 최종 AAB 파생 APK의 기동, 로그인/게스트 진입, 공개 목록·지도·이용안내, 뒤로가기와 재기동 확인.
- [x] 관찰 구간의 앱 PID 로그에서 필터링한 Flutter 예외·native crash·ANR 0건 확인.
- [x] 별도 `.localtest` 앱의 격리된 메모리 fixture에서 회원·관리자 화면 확인. 이 결과는 실제 Google 인증·운영 API 쓰기·실제 통화 성공을 증명하지 않는다.
- [x] 번호판 2개 입력 거절, 필수 닉네임, 관리자 OCR 테스트, 게시판·고장 신고 화면 확인. 수신 기본 꺼짐은 실행 중 표본으로 확인하지 않았으며 단위 테스트 증거와 구분한다.
- [ ] 검증 결과에 따라 Play Console에 원본 서명 AAB를 업로드·검토 제출한다. 실제 게시 상태를 별도로 기록한다.

통화는 TURN 미설정으로 비활성이다. BlueStacks 단일 기기와 Android9 검증은 실제 휴대폰 두 대 음성·Android16/16KB 페이지 기기·BLE 하드웨어 검증을 대체하지 않는다.

## 확인된 릴리스 20 화면

최종 AAB 파생 설치본에서 로그인 화면 → 게스트 공개 목록 → B1/B2 지도 → 이용안내 → 로그인 복귀와 cold 재기동을 확인했다. 다음 이미지는 해당 설치본의 확인 증거이며, 별도 localtest 앱 결과와 구분한다.

- [로그인](bluestacks-20261021/release-login.png), [공개 목록](bluestacks-20261021/release-guest-list.png)
- [B1 지도](bluestacks-20261021/release-map-b1.png), [B2 지도](bluestacks-20261021/release-map-b2.png)
- [이용안내](bluestacks-20261021/release-guide.png), [로그인 복귀](bluestacks-20261021/release-return-login.png), [cold 재기동](bluestacks-20261021/release-cold-relaunch.png)

Google 로그인 완료, 실사진 OCR, 회원·관리자 운영 API 쓰기, 실제 음성 연결과 Play 게시 완료는 이 공개 화면 검증에 포함되지 않는다. 릴리스 21의 선택적 마이크 하드웨어 선언과 그 산출물 검증도 별도 기록을 따른다.

## 격리된 localtest 20 확인

별도 `.localtest` 앱을 설치했고 기존 앱 제거·데이터 초기화는 하지 않았다. 메모리 fixture에서 다음을 확인했으며 운영 데이터를 쓰거나 로컬 회원 삭제 버튼을 실행하지 않았다.

- [프로필 수정](bluestacks-20261021/local-profile-edit.png): 닉네임 1~30자와 단일 차량번호 입력 화면.
- [차량번호 2개 거절](bluestacks-20261021/local-two-plates-rejected.png): 완전한 번호판 두 개를 쉼표로 입력하면 번호판 한 개 안내와 저장 비활성 표시.
- [게시판 빈 목록](bluestacks-20261021/local-board.png), [글 작성](bluestacks-20261021/local-board-compose.png), [사진 선택 고장 신고 양식](bluestacks-20261021/local-charger-report-compose.png).
- [관리자 허브](bluestacks-20261021/local-admin-hub.png), [승인 관리](bluestacks-20261021/local-admin-approvals.png), [회원 정리 버튼](bluestacks-20261021/local-admin-member-cleanup.png).
- [관리자 OCR 일치](bluestacks-20261021/local-admin-ocr-match.png): 합성 PNG의 `12가3456`을 실제 한국어 ML Kit가 인식해 입력 `12가3456`과 일치했다. 실제 촬영 사진의 인식 정확도를 증명하지 않는다.

localtest PID 4185 관찰 구간에서 필터링한 `E/flutter`, `FATAL`, ANR, `MissingPlugin`, `UnsatisfiedLink`는 0건이었다. 첫 debug 기동은 Play Store 업데이트와 겹쳐 느렸으나 이후 화면이 로드됐다. class verification 정보 메시지와 에뮬레이터 GL 오류는 있었으므로 모든 로그가 비어 있었다고 판단하지 않는다. 확인 후 에뮬레이터를 종료했다.

최신 동의·가입·로컬 adapter 집중 테스트 20개가 통과했다. 전체 Flutter 187개 통과는 별도 선행 실행 결과다. 수신 기본 꺼짐·TURN 비활성은 단위 테스트 근거이며 이 UI 실행에서 수신 옵션을 직접 표본 확인하지 않았다.

## 최종 릴리스 21 재확인

최종 AAB SHA256 `207a8a7fdb4531da22952183af62314f18b403e32826c3ed603dad99cc5b9284`에서 연결 장치용 분할 APK를 다시 만들었다. APK 검증 복사본만 기존 debug 인증서로 서명했으며 게시 AAB는 그대로 보존했다. bundletool 설치 종료 코드 0, 기존 데이터 보존, 패키지 `apt.ev.service`의 code21/min24/target36을 확인했다.

설치 완료 후 `am start -W`는 `Status: ok`였고 PID 4453에서 [로그인](bluestacks-20261021/release21-login.png), [게스트 목록](bluestacks-20261021/release21-guest-list.png), [B1 지도](bluestacks-20261021/release21-map-b1.png)가 표시됐다. 관찰 구간의 `E/flutter`, `FATAL EXCEPTION`, `ANR in`, `MissingPluginException`, `UnsatisfiedLinkError` 필터는 0건이었다. 설치 완료 전 먼저 실행한 PID 4158은 패키지 설치의 stop 이벤트 후 종료됐으므로 이 결과에서 제외했다.

Play는 최종 21 AAB를 수신했고, 마이크 선택 선언 후 이전 버전 대비 지원 기기 감소가 0개임을 확인했다. [기기 호환성 화면](bluestacks-20261021/play-v21-compatibility-restored.jpg). 최종 Google 검토 전송·게시 상태는 [21 릴리스 기록](RELEASE_1.1.4_21_2026-10-21.md)에서 확인한다.

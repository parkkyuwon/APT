# 주차 권한·연락처·지도 수정 Play 제출 (2026-10-14)

사용자는 기능 수정·검증 후 Play Console 배포까지 진행하도록 승인했다.
연결된 Console에서 `apt.ev.service`의 기존 프로덕션 17(1.1.1)이 100% 출시된
상태와 게시되지 않은 변경사항이 없음을 확인하고 새 버전 18을 준비했다.

## 검증과 릴리스 파일

- Flutter 전체 테스트: **119개 통과**. `D:/Temp/apt-parking-release-18-tests.log`.
- 정적 분석: No issues found. `D:/Temp/apt-parking-analyze-final.log`.
- 로컬 Android 9/API28 회원·관리자 및 B1/B2 확대·이동·축소 화면 확인.
  [상세 검증 기록](PARKING_PERMISSIONS_2026-10-14.md).
- 실제 Google 이름 변경 후 로그인, 운영 회원 상태 저장 및 OS 실기기 검증은
  별도 미검증 항목이다. 이번 작업은 백엔드·DB를 변경하지 않았다.
- 버전: `1.1.2+18`. 정상 진입점 `lib/main.dart`, 기존 운영 API/Firebase 설정으로
  난독화 release AAB 빌드. 로컬 fixture 및 `LOCAL_MEMBER_TEST` define을 사용하지 않았다.
- [보관 AAB](../../AppBundle/releases/2026-10-14-v1.1.2-18/AptEvService-1.1.2-18.aab)
  (52,355,977 bytes, 약 49.9MiB).
- SHA256: `9E5FD8ACB3C90AED6BB281B7DEA57E5AB2223428BDAD517D92BA2B639BFAD621`.
- bundletool validate 및 jarsigner 서명 검증 통과. 자체 서명 인증서와 timestamp
  부재에 대한 jarsigner 안내는 기록하되, 서명 자체 검증은 성공했다.
- 실제 manifest: package `apt.ev.service`, versionCode 18, versionName 1.1.2,
  minSdk24, targetSdk36. 광범위 사진·동영상·저장소 읽기 권한 없음.
- Console에서 ReTrace 매핑·네이티브 디버그 기호 첨부, 지원 기기 감소 0 확인.

## Console 수행 결과

1. 프로덕션 새 릴리스에 버전 18 AAB 업로드 및 최적화 완료.
2. 이메일 기반 주차 판정, 관리자 수정·출차·차단, 비공개 연락처, 지도 확대·축소
   개선에 대한 한국어 출시 노트 입력.
3. 기존 제공 국가 범위와 100% 출시 설정으로 저장. 버전 17은 새 릴리스에 포함하지 않음.
4. 게시 개요에서 **이번 프로덕션 변경사항 1개만** 검토 전송 확정.
5. `검토 중인 변경사항`에 `18 (1.1.2) / 전체 출시 시작` 표시 확인.
   확인 시 빠른 자동 검사가 진행 중이며 성공하면 Google 검토로 전송되는 상태였다.

제출 직후에는 실제 게시된 상태가 아니었다. 자동 검사 통과, Google 심사 승인과
관리형 게시의 최종 게시가 남아 있었다. 관리형 게시 설정은 변경하지 않았다.

후속 확인(2026-10-14): 브라우저 재연결 후 버전18의 Google 승인 및 게시 준비 상태를
확인했다. 사용자의 기존 배포 승인에 따라 변경사항1개 게시→변경사항 출시를 완료했다.
Console 최근 게시일이 2026-10-14로 갱신되고 게시되지 않은 변경사항 없음이 확인됐다.
Play 반영에는 시간이 걸릴 수 있다. 새 회원 관리 버전19는 별도 제출한다.

![버전18 게시 완료](../../AppBundle/releases/2026-10-14-v1.1.2-18/console-published.png)

![검토 전송 접수 증거](../../AppBundle/releases/2026-10-14-v1.1.2-18/console-review-submitted.png)

로그: `D:/Temp/apt-parking-release-18-build.log` 및
`D:/Temp/apt-parking-release-18-manifest.xml`. 환경 값·키는 이 문서에 복사하지 않았다.

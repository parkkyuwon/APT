# 카메라·사진 접근 심사 대응 PM/QC 검토

> 2026-10-09 후속: 사용자에게서 별도로 받은 사진·동영상 권한 경고에 따라 Android 광범위 사진/저장소 권한 제거 작업을 재개했다. [새 검증 기록](../verification/PHOTO_PERMISSIONS_RELEASE.md)을 참고한다. 아래 보류 설명은 이전 API36 요청 시점의 조사 기록이다. 이번 수정 범위는 Android manifest와 새 배포 후보이며 iOS 설명·화면 수명 개선 전체를 완료한 것으로 해석하지 않는다.

검토일: 2026-10-09. PM: `gpt-6.1-sol`. Blue Ocean을 현재 Flutter/Provider/Dio 구조에 맞춰 적용한다. PM은 읽기 전용 소스 검토와 이 문서만 담당하고 root가 구현·직렬 Flutter 검증을 수행한다. 스토어 제출·버전 변경·서버 변경은 범위에 없다.

## 원문 수신에 따른 범위 전환

사용자가 전달한 실제 안내는 현재 Android 15/API 35 대상 앱이 요구를 충족하지 않으며 Android 16/API 36 이상을 대상으로 새 버전을 프로덕션에 게시하라는 내용이다. 카메라 사용 보안제재의 근거가 아니다. 카메라·사진 권한 작업은 구현 전에 보류했고 카메라 관련 소스/manifest 변경은 수행하지 않았다. 아래는 초기 추정에 따른 조사 기록이며 현재 실행 계획이나 완료 결과가 아니다. 현재 작업은 [Android API36 전환 검토](ANDROID_API36_REVIEW.md)로 전환한다.

## 요청과 현재 판단

사용자가 배포 등록 후 카메라 사용 보안검토 요청에 대한 해결을 요청했다. 대상 스토어와 정확한 심사 요청 원문은 확인 중이다. 권한·실제 기능 불일치는 우선 정정할 수 있으나 심사 사유를 특정하거나 승인 성공을 보장하지 않는다. 이번 작업의 수락은 앱 및 대응 자료의 준비이며 스토어의 실제 승인과 구분한다.

영향 범위는 아키텍처의 `platform`, `member-ui`, `auth`, `services`, `http`, `build`다. `ProfileSetupScreen`의 최초 입력/내 정보 수정과 `PhotoVerificationScreen`의 재인증이 `image_picker` 촬영/단일 사진 선택을 제공한다. 사진은 앱에서 변환·미리보기 후 `저장하기` 또는 `사진 전송` 동작으로 `ProfileApi.updateProfile()`의 `/api/profile` `vehiclePhoto` 필드에 전달된다. 자동 카메라 촬영·갤러리 전체 읽기·QR 카메라 스캔·QR 이미지 라이브러리 저장 코드는 이번 `lib/` 검색에서 확인되지 않았다.

초기 Android manifest에는 `CAMERA`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`가 선언돼 있고 iOS 카메라 purpose string은 구현되지 않은 QR 스캔을 언급한다. PhotoLibraryAdd purpose string도 QR 저장을 언급한다. root는 pinned plugin 소스와 실제 병합 manifest를 확인해 필요 없는 선언을 제거한다. iOS는 플러그인 계약상 필요한 카메라/사진 선택 설명을 정확한 차량 인증 용도로 유지한다.

## 최소 구현 방향과 승인

- 기존 `image_picker`의 OS 카메라/단일 선택 흐름을 재사용한다. Android CAMERA·광범위 이미지/저장소 권한은 현재 pinned plugin이 요구하지 않는 것이 확인되면 제거한다. APK 병합 manifest에서도 제거를 확인한다. 플러그인을 업그레이드하거나 새 카메라 패키지를 추가하지 않는다.
- iOS 설명은 차량 번호판 사진을 촬영/선택해 차량 인증과 관리자 검토에 제출한다는 실제 용도에 맞춘다. 녹음·영상·전체 앨범 탐색·QR 저장 목적을 추가하지 않는다. 불필요한 PhotoLibraryAdd 키는 실제 코드와 플러그인 계약 확인 후 제거한다.
- 최초 프로필·내 정보 수정·재인증의 사진 진입 전에 용도와 업로드 시점을 알린다. 촬영/선택만으로 전송하지 않고 미리보기 후 기존 제출 버튼으로 전송한다. 사용자의 취소·권한 거절은 오류 코드 그대로 노출하기보다 짧은 설명과 갤러리 선택 대안으로 처리한다.
- picker/사진 변환/업로드의 async 완료 시 mounted와 인증 연속성을 확인해 로그아웃으로 화면이 사라진 뒤 setState하지 않는다. 취소·거절·처리 오류 이후 다시 선택 가능한 상태를 유지하고 제출 중 중복 동작을 막는다.
- 서버 사진 보존기간·삭제 시점·공유·처리자 접근·탈퇴 삭제 정책은 이 저장소로 확정하지 않는다. 개인정보 처리방침 및 스토어 데이터 공개 문항은 운영자가 실제 서버 사실을 확인한 후 채운다. `ProfileApi.withdraw`의 기존 7일 주석은 서버 검증 근거가 아니다.

PM은 위 정정을 승인한다. 기존 버튼과 미리보기 구성은 유지하고 텍스트/오류 피드백/권한 설정을 정정하므로 이미지 기반 GUI DR는 면제한다. 실제 기기 권한·촬영·선택 검증은 면제하지 않는다. 타 기능·서버 계약·UI 구조 변경은 범위에 없다.

## 수락 기준과 검증

1. Android APK의 병합 manifest에 불필요한 CAMERA/READ_MEDIA_IMAGES/READ_EXTERNAL_STORAGE가 남지 않는다. 코드에 전역 갤러리 접근이나 새 촬영 라이브러리를 추가하지 않는다.
2. iOS purpose strings는 실제 차량 사진 용도 및 플러그인 요구와 일치한다. 미구현 QR 스캔·저장 문구를 제거한다.
3. 프로필 입력/수정 및 재인증에서 사용자 목적·전송 버튼 시점을 알리고 선택/촬영/취소/거절만으로 서버 요청을 보내지 않는다. 성공 선택은 미리보기만 생성하며 제출 때만 `vehiclePhoto`를 전송한다.
4. 권한 거절·취소·picker 오류·화면 dispose를 제어 가능한 plugin seam에서 회귀 검증한다. 로그인 사용자 변경 뒤 이전 사용자의 사진이 다른 세션으로 제출되지 않게 한다.
5. 분석·해당 회귀·전체 테스트·Android debug 빌드를 root가 직렬 실행하고 병합 manifest를 읽어 검증한다. 실기기 Android/iOS 및 iOS 빌드 미수행 시 한계를 명시한다.
6. 정확한 스토어 요청 원문과 운영자의 보존/삭제/공유 사실에 따라 검토 답변과 데이터 공개를 정합하게 작성한다. 앱 수정으로 심사가 승인됐다고 주장하거나 스토어에 제출하지 않는다.

## 공식 근거

[Flutter image_picker 공식 패키지 안내](https://pub.dev/packages/image_picker)는 Android OS intent/Photo Picker 및 iOS purpose keys를 설명한다. 일반 최신 안내를 pinned 버전 소스와 대조해야 한다. [Google Play 최소 범위 권한 안내](https://support.google.com/googleplay/android-developer/answer/16935362)는 시스템 picker로 충분한 기능의 민감 권한 최소화를 요구한다. [Apple App Review 개인정보 지침](https://developer.apple.com/app-store/review/guidelines/#privacy)은 용도·개인정보 공개와 일치하는 접근을 기준으로 한다. 대상 스토어가 확정되면 관련 심사 원문과 구체 조항을 대응 자료에 연결한다.

## QC 상태

초기 소스 검토만 완료, 카메라 구현과 추가 검증은 보류했다. 실제 요청 원문은 target SDK 36 전환이며 카메라 관련 제재가 아니다. 사진 권한·개인정보 공개 개선은 별도 요청이 있을 때 재개한다. 서버 보존/삭제 사실은 미확인이다.

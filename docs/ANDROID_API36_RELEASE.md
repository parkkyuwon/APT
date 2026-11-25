# Google Play 대상 API 갱신

> 후속 사진·동영상 권한 경고 대응으로 최신 업로드 후보는 `1.1.0+16`이다. [사진 권한 수정 및 심사 요청 결과](verification/PHOTO_PERMISSIONS_RELEASE.md)를 참고한다. 아래 버전 15는 초기 API36 검증 기록이며 새 제출에 재사용하지 않는다.

사용자가 받은 안내는 Android 15(API 35) 대상 앱을 Android 16(API 36) 이상으로 갱신하라는 요청이다. 카메라 권한 심사 요청과는 별개다. [Google Play 공식 정책](https://support.google.com/googleplay/android-developer/answer/11926878)을 참고한다.

현재 설정은 `android/app/build.gradle.kts`의 `compileSdk=36`, `targetSdk=36`, 앱 식별자 `apt.ev.service`이며 `pubspec.yaml` 버전은 `1.1.0+15`다. Flutter 3.41.6, AGP 8.11.1 및 기존 업로드 서명을 사용한다. 운영 주소·Google 클라이언트 ID는 `lib/config/env.dart`의 기존 기본값이며 운영 서버에 요청을 보내지는 않았다.

## 로컬 빌드

```powershell
flutter build appbundle --release --no-pub --obfuscate --split-debug-info=build/symbols/api36
```

예상 산출물은 `build/app/outputs/bundle/release/app-release.aab`다. 난독화 진단에는 `build/symbols/api36`의 심볼과 R8 mapping 파일을 해당 릴리스와 함께 보관한다. SDK나 의존성 변경 후에는 먼저 `flutter pub get`을 실행한다.

2026-10-09 로컬 검증에서 분석 오류 0, 테스트 85개 통과, release AAB 빌드 및 bundletool 검증 성공을 확인했다. 실제 AAB manifest는 `apt.ev.service`, 최소 API 24, 대상 API 36, versionCode 15, versionName 1.1.0이다. 서명 검증은 통과했으며 Android Debug 인증서는 아니었다. AAB 설정은 `PAGE_ALIGNMENT_16K`이고 ARM64/x86_64의 6개 네이티브 라이브러리에서 16KB ELF 정렬을 확인했다. 실제 16KB 기기 실행과 Console 업로드 인증서 대조는 미수행이다.

초기 API 36 검증 AAB SHA256은 `b8824cd8b81b4d68ffdf0c653ed32e7fea63cc2b5844392fbfc8729f25a62f94`이다. 이후 회원 화면 수정과 새 아이콘을 포함해 재빌드한 최신 후보의 SHA256은 `583209edc7d0a6e5d3671e1848d3aeb7c9bfb3bd492615ba0f29cb228a94c6f0`이다. 최신 산출물과 검증 결과는 [배포 후보 기록](verification/PLAY_RELEASE_CANDIDATE.md)을 참고한다.

## Play Console에서 이어서 할 일

1. 출시 개요·App Bundle 탐색기에서 이미 사용된 최고 versionCode를 확인한다. 15가 이미 사용됐으면 `pubspec.yaml`의 `+15`를 그보다 큰 번호로 변경하고 다시 빌드한다. 기존 applicationId와 업로드 키를 유지한다.
2. 앱 무결성의 업로드 인증서를 로컬 서명과 대조한다. 로컬 서명 검증만으로 Console에 등록된 인증서와 일치한다고 판단할 수 없다.
3. 내부 테스트에 새 AAB를 업로드하고 Android 16에서 로그인/로그아웃, 사진 촬영·선택·취소, QR 링크, 관리자 BLE, 뒤로가기, 키보드와 시스템 바 겹침을 확인한다. 태블릿·가로화면도 확인한다. [Android 16 대상 동작 변경](https://developer.android.com/about/versions/16/behavior-changes-16)을 참고한다.
4. 검증한 릴리스를 프로덕션으로 승격하고 제출·게시 절차를 완료한다. 내부 테스트 업로드나 로컬 빌드만으로 사용자가 받은 프로덕션 게시 요구가 완료되지 않는다.
5. 새 프로덕션 릴리스 적용 후 정책 상태 및 알림에서 API 요구가 해소됐는지 확인한다.

실제 Console 최고 버전·업로드 인증서 일치, 실기기 동작 및 프로덕션 게시 상태는 이 저장소에서 확인되지 않았다. 로컬 검증 근거와 PM 수락은 [ANDROID_API36_REVIEW.md](architecture/ANDROID_API36_REVIEW.md)에 기록한다. `android/deploy.bat`와 fastlane deploy는 외부 업로드 작업이므로 빌드 검증 명령으로 실행하지 않는다.

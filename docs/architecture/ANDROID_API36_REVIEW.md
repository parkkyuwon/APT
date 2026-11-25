# Android API 36 전환 PM/QC 검토

검토일: 2026-10-09. PM: `gpt-6.1-sol`, Blue Ocean 적용. root가 구현/직렬 검증, PM이 독립 읽기 검토와 이 문서를 담당한다.

## 원문과 범위

사용자가 전달한 실제 Play 안내는 API 35 대상 앱이 요구를 충족하지 않으며 Android 16/API 36 이상을 대상으로 새 프로덕션 버전을 게시하라는 내용이다. 카메라·사진 정책 문제가 아니므로 해당 초기 개선 계획은 구현 전에 보류했다. 이번 범위는 Android 대상 SDK 전환과 로컬 새 버전 빌드/검증/게시 준비 자료다. 인증된 Play Console 확인이나 실제 프로덕션 게시는 수행하지 않는다.

아키텍처 하위 그래프는 `build → platform → app`이다. 현재 `android/app/build.gradle.kts`는 compileSdk 36, targetSdk 35, applicationId `apt.ev.service`, Java/Kotlin 17이고 `pubspec.yaml`은 `1.1.0+14`다. Gradle 8.14와 Flutter 3.41.6을 재사용한다. API 목표를 맞추기 위해 앱 UI·서버 API·카메라 권한·플러그인 패키지를 무관하게 변경하지 않는다.

## 승인된 최소 방향

- targetSdk를 36으로 올리고 compileSdk 36 및 기존 minSdk/앱 식별자/언어 수준을 유지한다. 정책 주석·개발 문서의 target35 설명을 실제 target36으로 정정한다.
- 새 빌드 버전을 로컬 `1.1.0+15`로 준비할 수 있다. Play Console의 최고 사용 versionCode를 확인하지 못했으므로 15가 실제 업로드에 충분히 큰 값이라는 보장은 하지 않는다. 기존 빌드/배포 스크립트의 중복 version override와 충돌 여부는 확인한다.
- 공식 Android 16 변경을 현재 Flutter/native 사용과 대조한다. edge-to-edge, predictive back 및 큰 화면/회전 검증을 실제 Android 16 확인 범위로 남긴다. 근거 없는 opt-out·UI 개편·새 패키지는 추가하지 않는다.
- 로컬 release AAB와 debug APK를 실제 빌드하고 산출물 manifest의 package/target36/versionCode를 검사한다. Play 제출용은 운영 환경/업로드키 기준이며 자리표시자 환경의 검증용 산출물과 구분한다.
- 기존 release 서명이 key.properties 부재 시 debug 키로 fallback하므로 release 빌드 성공만으로 게시 준비 완료를 주장하지 않는다. 민감한 key.properties 내용은 읽어 출력하지 않고 서명 설정 유무 및 산출물 검증 상태를 기록한다. 업로드키와 Console 인증서의 일치는 실제 Console 근거가 없으면 미확인이다.
- ARM64 네이티브 라이브러리의 16KB 페이지 호환·AAB 정렬 관련 검증을 가능한 로컬 도구로 확인하고 실제 16KB OS 실행은 미수행이면 한계를 명시한다.

PM은 이 방향을 승인한다. SDK/버전/문서 변경이며 시각 배치 변경이 없으므로 GUI DR는 면제한다. Android 16 기기 동작 검증은 면제하지 않는다.

## 수락 기준

1. Gradle 및 실제 APK/AAB manifest의 targetSdk가 36이고 앱 식별자·기존 minSdk가 유지된다.
2. 새 산출물 versionCode/name이 의도한 로컬 값과 일치한다. 최고 사용 Play code 및 서명 인증서 일치는 확인 가능 범위와 한계를 기록한다.
3. 현재 Gradle/Flutter/plugin 조합에서 분석·전체 테스트·debug APK·release AAB 검증을 실행하고 성공/실패를 구분한다. release 빌드 실패나 debug fallback이면 원인·제출용 한계를 명시한다.
4. Android 16 변경 중 현재 앱 영향과 기기 확인 항목, 네이티브 16KB 검증 범위를 기록한다. 소스 검토/빌드 성공을 실기기 정상 동작으로 주장하지 않는다.
5. 문서와 아키텍처 색인은 target/version/검증 변경을 반영한다. 스토어 프로덕션 게시 요구는 별도 운영 단계로 남기고 무심코 배포 스크립트를 실행하지 않는다.

## 근거와 검토 상태

[Android 16 target behavior](https://developer.android.com/about/versions/16/behavior-changes-16)의 edge-to-edge/back/large-screen 변경을 확인했다. [Google Play target API 안내](https://developer.android.com/google/play/requirements/target-sdk)와 실제 Console 안내 원문을 root가 대조한다. 일반 웹 정책과 Console의 앱별 안내에 차이가 있으면 실제 요청 원문에 맞춰 target36 전환을 수행하고 앱별 적용을 보장하지 않는다.

## 최종 독립 QC

PM은 `build.gradle.kts`의 target36과 `pubspec.yaml`의 `1.1.0+15`, AAB manifest의 `apt.ev.service`/min24/target36/code15/name1.1.0을 직접 확인했다. 문서·Mermaid/JSON의 목표 SDK와 버전 메타데이터도 반영됐다. 카메라 관련 변경은 수행하지 않았다.

| 검증 | 근거와 결과 |
| --- | --- |
| Flutter 분석 | `D:/Temp/apt-api36-analyze.log`, `No issues found`, root 종료 코드 0, PM 로그 확인 |
| 전체 테스트 | `D:/Temp/apt-api36-tests.log`, `+85 All tests passed`, root 종료 코드 0, PM 로그 확인 |
| release AAB | `D:/Temp/apt-api36-build.log`, `bundleRelease` 151.7초/49.1MB 성공, root 종료 코드 0, PM 로그 확인 |
| AAB 구조 | `D:/Temp/apt-api36-bundle-manifest.xml` 실제 값 확인, `apt-api36-bundle-validate.log` bundletool 검증, root 종료 코드 0 |
| 16KB 정렬 | `apt-api36-bundle-config.json`의 `PAGE_ALIGNMENT_16K`, `apt-api36-elf.log` ARM64/x86_64 라이브러리 6개 PT_LOAD 정렬 확인 |
| 서명 | root의 jarsigner 검증 종료 코드 0, keytool로 Android Debug 인증서 아님 확인. PM shell PATH에 jarsigner가 없어 PM 재실행은 하지 않았음. Console 업로드 인증서 대조는 미수행 |
| debug APK | `D:/Temp/apt-api36-debug.log`, `assembleDebug` 25.8초 및 APK 성공 메시지, PM 로그 확인 |
| 보관/문서 | `build/symbols/api36` ARM/ARM64/x64 난독화 심볼 존재, release R8 mapping 보관 가이드 제공, `git diff --check` 종료 코드 0 |

PM이 실제 AAB에 `Get-FileHash`를 실행해 root 결과와 일치함을 확인했다. SHA256: `b8824cd8b81b4d68ffdf0c653ed32e7fea63cc2b5844392fbfc8729f25a62f94`. 생성 AAB는 기존 Env의 운영 기본값으로 빌드했으며 검증 중 서버 요청은 수행하지 않았다. 외부 validator bundletool 1.18.3과 AAB config의 producer 1.18.1은 별도 도구 역할이다.

## 최종 수락과 외부 잔여 단계

PM은 **API 36 전환 및 로컬 새 버전 배포 준비** 구현을 수락한다. 검토 범위 내 미해결 코드/빌드 결함은 없다. 실제 Play Console 최고 versionCode·업로드키 인증서 일치, Android 16/16KB 장치 동작, 내부 테스트/프로덕션 게시·심사 승인은 미수행이다. 빌드 검증은 이 외부 잔여 단계를 완료한 것으로 간주하지 않는다.

Android 16에서는 시스템 바/키보드 겹침, 뒤로가기, 큰 화면·가로화면과 로그인·사진·QR 링크·BLE를 기기에서 확인해야 한다. 생성 파일과 난독화 심볼을 보관하고 기존 업로드키를 유지한다. 최고 사용 code가 15 이상이면 새 code로 다시 빌드·검증해야 한다. 실제 게시 절차는 [릴리스 안내](../ANDROID_API36_RELEASE.md)에 있다. 사용자에게 받은 프로덕션 게시 요구 자체는 Console에서 새 릴리스를 게시하고 상태를 확인해야 해소된다.

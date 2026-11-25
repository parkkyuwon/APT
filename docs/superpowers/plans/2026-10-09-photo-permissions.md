# 사진·동영상 권한 정책 수정 계획

목표: 사용자가 제공한 Play Console 경고(버전 코드 14·15)에 대응할 새 버전 16 AAB를 준비한다.

구조: 기존 ProfileSetupScreen과 PhotoVerificationScreen의 image_picker 단일 사진 선택을 유지한다. 고정 버전 image_picker_android 0.8.13+16은 ACTION_GET_CONTENT 시스템 선택 도구를 사용하므로 전체 라이브러리 권한이 필요 없다. API·화면·사진 제출 계약은 변경하지 않는다.

- [x] 기존 사용자 변경, 아키텍처 platform/member-ui/build 구성요소와 사진 선택 소스, 플러그인 Android 구현을 확인한다.
- [x] AndroidManifest.xml에서 READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE를 tools:node="remove"로 차단한다. 기존 CAMERA와 BLE 권한은 유지한다.
- [x] pubspec.yaml을 1.1.0+16으로 변경한다. 실제 Console 최고 코드가 16 이상이면 추가 재빌드가 필요하다.
- [x] C:/src/flutter/bin/flutter.bat analyze --no-fatal-infos 및 flutter test --concurrency=2를 실행한다.
- [x] 운영 기본 설정과 기존 업로드 서명으로 flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/photo-permissions-v16을 실행한다. 서버 호출이나 배포 스크립트 실행은 하지 않는다.
- [x] bundletool validate와 dump manifest로 실제 AAB 버전·SDK·금지 권한 부재를 확인하고 jarsigner로 서명을 검증한다.
- [x] 새 AppBundle/releases 폴더에 AAB·symbols·mapping·릴리스 설명과 검증 기록을 보관한다. 이전 후보를 보존한다.
- [x] 문서에 새 후보와 Console의 모든 영향받는 트랙 업데이트 필요성, 실기기·심사·게시 미검증 범위를 기록한다.

이 변경은 manifest와 버전 설정에 한정된다. 최종 병합 AAB의 권한 검사가 정책 결함의 직접 검증이며 소스 문자열만 검사하는 새 단위 테스트는 추가하지 않는다. Android 실기기의 선택·취소·촬영 검증과 Play Console 심사 완료는 별도 근거가 필요하다.


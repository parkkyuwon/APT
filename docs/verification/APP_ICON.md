# 앱 아이콘 변경 (2026-10-09)

요청한 아파트 건물 배경과 충전기 표식을 새 아이콘에 적용했다. 파란색 건물, 초록색 충전기, 흰색 번개와 충전 케이블을 사용하며 글자는 넣지 않았다.

- 원본: `assets/branding/app-icon-master.png` (1254×1254). 이미지 생성 스킬로 제작했다.
- Android: 기존 `mipmap-*/ic_launcher.png` 5개를 48/72/96/144/192 크기로 교체했다. 기존 manifest 연결을 유지한다.
- iOS: 기존 AppIcon catalog의 모든 파일 15개를 등록 크기에 맞춰 교체했다. 1024 마케팅 아이콘을 포함해 PNG RGB/불투명 출력이다.
- 스토어용 512 이미지: `assets/branding/play-store-icon-512.png`.
- 재생성: 프로젝트 루트에서 `./scripts/update-app-icons.ps1`. Windows 기본 System.Drawing으로 크기 변환하며 새 Flutter 의존성은 추가하지 않는다. 원본 파일은 보존한다.

정적 분석과 Android debug 빌드·설치 검증 결과를 아래에 기록한다. iOS 빌드 및 스토어 아이콘 등록은 이번 작업에 포함되지 않는다. 회원·비회원 제한과 앱 기능 로직은 변경하지 않았다.

## 검증 결과

- `flutter analyze --no-pub`: No issues found.
- `flutter build apk --debug --no-pub`: 성공 (41.3초). APK의 5개 ic_launcher PNG 포함을 확인했다.
- iOS catalog 19개 등록 항목/15개 파일의 실제 픽셀 크기와 24bpp RGB/불투명을 확인했다. iOS 빌드는 Windows에서 수행하지 않았다.
- BlueStacks API 28에서 일반 앱 APK 설치 Success. [홈 화면](app-icon/launcher.png)에 새 아파트·충전기 아이콘이 표시된다. 이전 검증용 별도 앱은 데이터 정리 완료 후 제거했다.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `d8603ccdbef6397b02a7c31f55b88a0405538ab1bc61b8ee9742ee2123b17666`, package `apt.ev.service`, versionCode 15, targetSdk 36.
- PM(GPT-6.1 Sol) 독립 시각/리소스 검토 통과. 아이콘 변경만 수행했으므로 기능 테스트를 추가하거나 전체 테스트를 반복하지 않았다.

이후 새 아이콘과 최신 수정이 포함된 release AAB를 생성하고 검증했다. [배포 후보 검증 기록](PLAY_RELEASE_CANDIDATE.md)을 참고한다. Play/App Store 등록은 아직 수행하지 않았다.

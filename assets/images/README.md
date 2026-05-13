# 앱 아이콘 / 그래픽 자료

Play Store 등록 전에 이 폴더에 다음 파일을 준비하세요.

## 필수

| 파일명 | 크기 | 용도 |
| --- | --- | --- |
| `app_icon.png` | 1024×1024 | 앱 아이콘 원본 (사각 배경 포함) |
| `app_icon_foreground.png` | 1024×1024 | Adaptive icon 전경 (투명 배경, 중앙 60% 영역) |
| `feature_graphic.png` | 1024×500 | Play Store 피처 그래픽 |

## 권장 (스크린샷 자동 생성용)

| 파일명 | 크기 | 용도 |
| --- | --- | --- |
| `screenshot_login.png` | 1080×1920 | 로그인 화면 |
| `screenshot_home.png` | 1080×1920 | 홈 화면 (슬롯 그리드) |
| `screenshot_dialog.png` | 1080×1920 | 주차 등록 다이얼로그 |
| `screenshot_mypage.png` | 1080×1920 | 내 정보 화면 |
| `screenshot_chat.png` | 1080×1920 | 대화방 |
| `screenshot_admin.png` | 1080×1920 | 관리자 허브 |

## 디자인 가이드 — 아이콘

권장 구성:
```
┌─────────────────────┐
│ ● #2196F3 (파란색)   │  ← 배경 단색
│                     │
│      ⚡ 🔌          │  ← 중앙 60%: 번개 + 플러그 아이콘
│                     │
│                     │
└─────────────────────┘
```

- 색상: 앱 primary color `#2196F3` (Material Blue 500)
- 상징: 전기차 충전을 직관적으로 표현 (번개/플러그/EV 심볼)
- 여백: 중앙 60% 안에 모든 콘텐츠 배치 (Adaptive icon 대응)
- 폰트 포함 금지: "APT EV" 같은 문자는 피처 그래픽에만

## 디자인 가이드 — 피처 그래픽 (1024×500)

```
┌─────────────────────────────────────────────┐
│                                             │
│   APT EV 충전                               │
│   아파트 전기차 충전 주차 관리               │
│                                             │
│                          🔌  🅿  ⚡          │
│                                             │
└─────────────────────────────────────────────┘
```

- 왼쪽 텍스트, 오른쪽 이미지 구성
- 텍스트 대비 충분 (WCAG AA 이상)
- 광고 문구 금지 ("최고의 앱" 등)
- 앱 스크린 실제 캡처만 사용

## 자동 생성 플로우

1. `app_icon.png` + `app_icon_foreground.png` 준비
2. `pubspec_additions.txt` 참고하여 `flutter_launcher_icons` 설정
3. `flutter pub run flutter_launcher_icons` 실행
4. Android 모든 밀도 + iOS 모든 크기 아이콘 자동 생성됨

## 캔버스/피그마 템플릿

Material Design 아이콘 가이드: https://m3.material.io/styles/icons/designing-icons
Play Store 그래픽 사양: https://support.google.com/googleplay/android-developer/answer/9866151

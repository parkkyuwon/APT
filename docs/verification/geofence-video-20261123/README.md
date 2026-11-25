# 집 반경 진입 → 실내 지도 안내 영상

## 최종 요청 반영: 무음 UI 영상

- **`APT-EV-geofence-UI-silent.mp4`**: 최종 전달본. 30초, 세로 720×1280, 24fps, 음성·음악·오디오 트랙 없음. 설명 슬라이드를 줄이고 설정 스위치 ON → 백그라운드 이동 → 반경 진입 → 진행 중 알림 → 안내 알림 터치 → 실내 지도 화면 순서로 UI를 표현한다.
- `ui-poster.jpg`, `ui-contact-sheet.jpg`: 무음본 대표 이미지와 장면 미리보기.
- `render_ui_video.py`: 무음 UI 영상 재생성 소스. `python ./render_ui_video.py`로 실행한다.

아래 내레이션 포함 파일은 최초 제작본이며, 사용자의 후속 지시에 따라 최종본에서는 내레이션을 제거했다.

- `APT-EV-geofence-explainer-ko.mp4`: 한국어 내레이션·화면 자막이 포함된 1280×720, 24fps 설명 애니메이션. H.264/AAC, 웹 재생용 faststart.
- `geofence-explainer.ko.srt`: 한국어 자막 파일.
- `poster.jpg`, `contact-sheet.jpg`: 대표 이미지와 6개 장면 미리보기.
- `scenes.json`: 장면 구성과 실제 음성 대본.
- `create_narration.ps1`, `render_video.py`: 재생성 소스. Pillow, imageio-ffmpeg, Windows 한국어 Heami 음성이 필요하다.

## 표현 범위

사용자가 집 위치·반경을 설정하고 권한을 허용하여 감시를 켠 뒤, 구역 진입 감지 → 제한된 위치 관찰 → 지속된 신호 저하 시 실내 위치 안내 → 사용자가 알림을 눌러 실내 지도 열기로 연결한다. 백그라운드 시작 제한 시 재시도 알림을 통해 관찰을 시작한다는 설명도 포함한다. 감시 OFF는 설정에서 제공하며 영상은 이를 설명한다.

실제 Android 기기를 녹화한 것이 아니다. 반경, 이동 경로, 지도 위치 마커, OS 화면과 사건 간 시간은 설명용 예시다. 자동 화면 실행, 실기기 동작 검증, 심사 통과 또는 게시 완료를 의미하지 않는다. 실내 위치 추정에는 접근 가능한 관리자 공용 자료와 BLE 신호 등 실제 조건이 필요하다. 앱 소스 및 서버는 변경하지 않았다.

Google Play에 제출할 때에는 실제 Android 앱에서 활성화 단계와 권한 안내, 실제 알림 및 기능 결과를 보여주는 녹화본으로 보완해야 한다. 이 파일은 로컬 설명용 산출물이며 공유 URL을 생성하거나 외부에 업로드하지 않았다.

정책 참고: https://support.google.com/googleplay/android-developer/answer/13392821?hl=ko

## 재생성

```powershell
./create_narration.ps1
python ./render_video.py
```

최종 인코딩과 디코딩 검증 결과는 `validation.txt`에 기록한다.

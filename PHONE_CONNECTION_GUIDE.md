# 📱 Android 폰 연결 가이드

## ⚠️ 현재 상태
```
No supported devices connected
```
→ 폰이 연결되었지만 개발자 모드 설정이 필요합니다.

---

## 🔧 Android 폰 설정 (모두 필수!)

### 1단계: 개발자 모드 활성화

**방법:**
1. **설정** 앱 열기
2. **정보** 또는 **휴대폰 정보** 선택
3. **빌드 번호** 항목을 **7번** 연속 터치
   - "개발자가 되기 위해 XX번 더 탭하세요" 메시지 표시
   - 계속 탭하기
4. ✓ "개발자 모드가 활성화되었습니다" 메시지 표시

### 2단계: USB 디버깅 활성화

**방법:**
1. **설정** 다시 열기
2. **개발자 옵션** 또는 **개발자 옵션** 선택 (설정 하단)
3. **USB 디버깅** 찾기
4. **토글 켜기** (파란색으로 변함)
5. ✓ "USB 디버깅 허용" 메시지 표시

### 3단계: USB 선택 모드 설정 (중요!)

**방법:**
1. **설정** → **개발자 옵션**
2. **USB 선택 모드** 찾기
3. **MTP** (또는 **미디어 전송 프로토콜**) 선택
   - *또는* **파일 전송** 선택

### 4단계: 폰의 ADB 승인 (중요!)

**방법:**
1. USB 케이블로 PC와 폰 연결
2. 폰 화면에 **"USB 디버깅 허용"** 또는 **"이 컴퓨터를 신뢰하시겠습니까"** 팝업 표시
3. **항상 허용** 또는 **확인** 탭하기
4. ✓ 팝업이 사라지면 성공

---

## 🔍 PC 에서 확인

### 1. 디바이스 확인
```powershell
cd d:\vsCodeProg\APT-APP
C:\src\flutter\bin\flutter.bat devices
```

**성공하면 이렇게 표시:**
```
2 connected devices:

SM-XXXX (mobile) • xxxxxxxx • android-arm64 • Android 13 (or higher)
```

### 2. ADB 직접 확인
```powershell
# ADB 명령어 경로
$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe devices

# 또는 Android Studio 에뮬레이터 확인
$env:LOCALAPPDATA\Android\sdk\emulator\emulator.exe -list-avds
```

---

## ❌ 문제 해결

### "No devices found"
**해결방법:**
1. 폰의 USB 케이블을 다시 빼뺄
2. 개발자 옵션에서 USB 디버깅 다시 켜기
3. 폰 화면에서 **"USB 디버깅 허용"** 다시 탭핑
4. PC에서 다시 시도

### "Device offline"
**해결방법:**
```powershell
# ADB 재설정
$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe kill-server
$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe start-server
$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe devices
```

### USB 드라이버 문제
**해결방법:**
1. Device Manager (장치 관리자) 열기
2. 폰이 "Unknown device" 또는 "Android Device"로 표시되는지 확인
3. 우클릭 → "드라이버 업데이트"
4. "컴퓨터에서 드라이버를 찾아보기"
5. Android SDK 위치 선택: `C:\Users\{username}\AppData\Local\Android\sdk`

### "ANDROID_SDK_ROOT 설정 안 됨"
**해결방법:**
```powershell
$env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\sdk"
$env:PATH += ";$env:LOCALAPPDATA\Android\sdk\platform-tools"
```

---

## ✅ 설정 완료 확인 체크리스트

```
폰 설정:
□ 개발자 모드 활성화됨
□ USB 디버깅 활성화됨
□ USB 선택 모드: MTP 또는 파일 전송
□ "이 컴퓨터를 신뢰" 허용됨

PC 설정:
□ Android SDK 설치됨
□ ADB 드라이버 설치됨
□ ANDROID_SDK_ROOT 설정됨
□ flutter devices 실행 성공
```

---

## 🚀 설정 완료 후 실행

**1단계: 폰 연결 확인**
```powershell
C:\src\flutter\bin\flutter.bat devices
```

**2단계: 앱 실행**
```powershell
cd d:\vsCodeProg\APT-APP
C:\src\flutter\bin\flutter.bat run
```

**3단계: 앱 테스트**
- 폰 화면에서 APT EV Charging 앱이 실행됨
- Google 로그인으로 테스트
- 한글 텍스트 표시 확인

---

## 📞 추가 도움

**만약 여전히 안 된다면:**
1. 폰을 다시 시작 (전원 재부팅)
2. PC를 다시 시작
3. USB 케이블 교체 (defective cable일 수 있음)
4. 다른 USB 포트 시도

**공식 가이드:**
- [Flutter: Run on physical device](https://flutter.dev/docs/development/tools/devtools/android-studio#run-app-with-debugging)
- [Android: USB debugging](https://developer.android.com/studio/debug/am-logcat#Launching_a_Session)

---

## 💡 폰 화면에서 보일 메시지들

```
1단계 후:
"개발자가 되기 위해 7번 더 탭하세요"
↓
"개발자 모드가 활성화되었습니다"

2단계 후:
"개발자 옵션" 메뉴 표시

3단계 후:
USB 연결 시 선택 창 표시

4단계 후:
"USB 디버깅을 허용하시겠습니까?" 또는
"이 컴퓨터를 신뢰하시겠습니까?"
→ 허용/신뢰 선택
```

---

**현재 상태**: 폰 연결 중 (드라이버 인식 대기)  
**다음**: 폰 개발자 모드 설정 → flutter devices 확인 → flutter run 다시 실행

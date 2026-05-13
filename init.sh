#!/bin/bash

# APT EV Charging Mobile App - 초기 설정 가이드

echo "===== APT EV Charging Mobile App 초기 설정 ====="
echo ""

# 1. 의존성 설치
echo "[1/4] 의존성 설치 중..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ 의존성 설치 실패"
    exit 1
fi
echo "✅ 의존성 설치 완료"
echo ""

# 2. 코드 생성 (if needed)
echo "[2/4] 코드 생성 중..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "✅ 코드 생성 완료 (또는 필요 없음)"
echo ""

# 3. Flutter 분석
echo "[3/4] Flutter 분석 중..."
flutter analyze

echo "✅ Flutter 분석 완료"
echo ""

# 4. 테스트 실행 (선택사항)
echo "[4/4] 단위 테스트 실행 중..."
flutter test

echo ""
echo "===== 초기 설정 완료 ====="
echo ""
echo "다음 단계:"
echo "1. lib/config/app_config.dart 파일을 수정하여 API_BASE_URL 설정"
echo "2. Google OAuth 클라이언트 ID 설정"
echo "3. iOS와 Android 플랫폼 설정"
echo "4. 'flutter run' 명령어로 앱 실행"
echo ""

#!/bin/bash
# ============================================
# APT EV Charging - Environment-aware Build Script
# Usage:
#   ./build-env.sh dev       -> dev 환경으로 debug APK
#   ./build-env.sh prod      -> prod 환경으로 release appbundle
#   ./build-env.sh run-dev   -> dev 환경으로 flutter run
# ============================================

set -e

# --- 환경별 API_BASE_URL ---
# 안드로이드 에뮬레이터는 호스트 localhost를 10.0.2.2로 인식
DEV_API_BASE_URL="${DEV_API_BASE_URL:-http://10.0.2.2:3000}"
PROD_API_BASE_URL="${PROD_API_BASE_URL:-https://apt-ev-charging.vercel.app}"

# 웹 클라이언트 ID (APT-Prj/GOOGLE_CLIENT_ID 또는 README.md 참조)
GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com}"

mode="${1:-}"
case "$mode" in
    dev)
        echo "[DEV] debug APK 빌드..."
        flutter build apk --debug \
            --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
            --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
            --dart-define=APP_ENV=dev
        ;;
    prod)
        echo "[PROD] release App Bundle 빌드..."
        flutter build appbundle --release \
            --dart-define=API_BASE_URL="$PROD_API_BASE_URL" \
            --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
            --dart-define=APP_ENV=prod
        echo ""
        echo "완료: build/app/outputs/bundle/release/app-release.aab"
        ;;
    run-dev)
        echo "[DEV] flutter run (debug, dev API)..."
        flutter run \
            --dart-define=API_BASE_URL="$DEV_API_BASE_URL" \
            --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
            --dart-define=APP_ENV=dev
        ;;
    run-prod)
        echo "[PROD] flutter run (profile, prod API)..."
        flutter run --profile \
            --dart-define=API_BASE_URL="$PROD_API_BASE_URL" \
            --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
            --dart-define=APP_ENV=prod
        ;;
    *)
        echo "사용법: $0 <dev|prod|run-dev|run-prod>"
        exit 1
        ;;
esac

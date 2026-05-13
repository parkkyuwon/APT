#!/bin/bash

# ============================================
# APT-APP Android Quick Run Script
# ============================================

function show_menu() {
    echo
    echo "============================================================"
    echo "     APT EV Charging - Android Quick Run Tool"
    echo "============================================================"
    echo
    echo "=== Android Run Options ==="
    echo
    echo "1. Check connected devices and emulators"
    echo "2. Start emulator"
    echo "3. Run app in debug mode"
    echo "4. Run app in release mode"
    echo "5. Build debug APK"
    echo "6. Build release APK"
    echo "7. Build App Bundle (Play Store)"
    echo "8. Install APK on device"
    echo "9. View logs"
    echo "10. Full workflow (clean, build, run)"
    echo "11. Exit"
    echo
    read -p "Select: " choice
    
    case $choice in
        1) show_devices ;;
        2) start_emulator ;;
        3) run_debug ;;
        4) run_release ;;
        5) build_debug ;;
        6) build_release ;;
        7) build_bundle ;;
        8) install_apk ;;
        9) view_logs ;;
        10) full_workflow ;;
        11) exit 0 ;;
        *) echo "Invalid selection!" ;;
    esac
}

function show_devices() {
    echo
    echo "Checking connected devices..."
    flutter devices
    echo
    read -p "Press Enter to continue..."
}

function start_emulator() {
    echo
    echo "Available emulators:"
    emulator -list-avds
    echo
    read -p "Enter emulator name (default: Pixel_6_API_33): " emulator_name
    emulator_name=${emulator_name:-Pixel_6_API_33}
    
    echo
    echo "Starting emulator: $emulator_name"
    emulator -avd "$emulator_name" &
    echo "Emulator started. Please wait 30-60 seconds for boot..."
    sleep 5
    read -p "Press Enter when emulator is ready..."
}

function run_debug() {
    echo
    echo "Running app in debug mode..."
    cd /d/vsCodeProg/APT-APP
    flutter run
}

function run_release() {
    echo
    echo "Running app in release mode..."
    cd /d/vsCodeProg/APT-APP
    flutter run --release
}

function build_debug() {
    echo
    echo "Building debug APK..."
    cd /d/vsCodeProg/APT-APP
    flutter build apk --debug
    if [ $? -eq 0 ]; then
        echo
        echo "Build successful!"
        echo "APK: build/app/outputs/apk/debug/app-debug.apk"
    else
        echo
        echo "Build failed!"
    fi
    read -p "Press Enter to continue..."
}

function build_release() {
    echo
    echo "Building release APK..."
    cd /d/vsCodeProg/APT-APP
    flutter build apk --release
    if [ $? -eq 0 ]; then
        echo
        echo "Build successful!"
        echo "APK: build/app/outputs/apk/release/app-release.apk"
    else
        echo
        echo "Build failed!"
    fi
    read -p "Press Enter to continue..."
}

function build_bundle() {
    echo
    echo "Building App Bundle..."
    cd /d/vsCodeProg/APT-APP
    flutter build appbundle --release
    if [ $? -eq 0 ]; then
        echo
        echo "Build successful!"
        echo "AAB: build/app/outputs/bundle/release/app-release.aab"
    else
        echo
        echo "Build failed!"
    fi
    read -p "Press Enter to continue..."
}

function install_apk() {
    echo
    echo "Installing APK..."
    cd /d/vsCodeProg/APT-APP
    
    if [ -f "build/app/outputs/apk/release/app-release.apk" ]; then
        adb install -r build/app/outputs/apk/release/app-release.apk
    else
        adb install -r build/app/outputs/apk/debug/app-debug.apk
    fi
    read -p "Press Enter to continue..."
}

function view_logs() {
    echo
    echo "Viewing logs..."
    echo "(Press Ctrl+C to stop)"
    flutter logs
}

function full_workflow() {
    echo
    echo "=== Full Workflow ==="
    cd /d/vsCodeProg/APT-APP
    
    echo "[1/4] Cleaning..."
    flutter clean
    
    echo "[2/4] Getting dependencies..."
    flutter pub get
    
    echo "[3/4] Building..."
    flutter build apk --debug
    
    echo "[4/4] Running..."
    flutter run
}

# Main loop
while true; do
    show_menu
done

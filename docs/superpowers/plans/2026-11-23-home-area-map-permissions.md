# Home Area Map and Permissions Implementation Plan

> Execute inline with executing-plans; preserve the existing uncommitted implementation in this workspace.

**Goal:** Show a keyless OpenStreetMap home-radius preview and guide users through missing OS settings.

**Architecture:** A dedicated HomeAreaMap renders tiles, marker and metric circle. HomeAreaSettingsScreen owns an explicit, cancellable activation flow; IndoorLocationBridge opens Android settings via the existing channel. Settings return refreshes actual permissions before activation.

**Tech Stack:** Flutter, flutter_map 8.3.2, latlong2, permission_handler, Kotlin Android intents.

- [x] Add widget regressions to test/home_area_settings_test.dart: marker/circle follow coordinates; cancellation never opens settings; settings return cannot activate after admin disable. Run targeted tests and confirm missing behavior fails.
- [x] Add flutter_map and latlong2 dependencies. Create lib/widgets/home_area_map.dart with marker, meter circle, attribution, app User-Agent, default HTTP-aware cache, retryable tile errors and no bulk prefetch.
- [x] Extend lib/core/indoor_location_bridge.dart and Android IndoorLocationMonitor.kt with openSettings targets; read actual location service status through permission_handler. Route location services, app location and notification settings with fallback app details.
- [x] Update home_area_settings_screen.dart to show map, keep manual/current location selection, present disclosure before background access, use cancellable step dialogs, and resume the pending activation only after actual permissions are verified. Clear continuation on cancellation/disposal/admin disable; prevent duplicate prompts.
- [x] Run flutter test test/home_area_settings_test.dart test/indoor_location_bridge_test.dart and flutter analyze --no-fatal-infos; then full tests after changes settle.
- [x] Update Mermaid, JSON index, privacy provider documentation and verification record. Build a production-config APK for device verification; keep existing v24 artifacts immutable and use a new version code for new release artifacts.
- [x] Verify real Android map loading and settings navigation when the Wi-Fi device is available. Report permission choices requiring the device owner and any field behavior not observed.

User selected OpenStreetMap on 2026-11-23. No additional design approval required.

# Geofence explainer video production plan

**Goal:** Produce a Korean narrated MP4 showing the implemented home-area entry to app-opening flow.

**Scope:** Explanation animation only. Preserve all existing application and user changes. No upload or publication. User approved proceeding with the strongest possible depiction of location entry on 2026-11-23.

**Design:** 1280×720 H.264/AAC video, Korean captions and Windows Heami narration. Six scenes: configure radius and consent; background approach; perimeter entry; bounded foreground observation; indoor notification and user tap; indoor map and monitoring control. Persistent animation disclosure. Do not portray automatic Activity launch, exact location accuracy, or verified device behavior. Timings compressed and sample map/location labeled.

- [x] Create reproducible Pillow/FFmpeg renderer, scene script and Korean narration alongside the output in `docs/verification/geofence-video-20261123/`.
- [x] Generate initial narrated edition. User subsequently requested no narration and UI-focused output; final deliverable is the separate silent portrait edition.
- [x] Render animated radius crossing, service notification, tap and map scenes; encode MP4 and export previews.
- [x] Inspect scene images; decode the entire final MP4 and verify H.264, 720×1280, 24fps, 30.00 seconds, no audio stream. See `validation.txt`.

**Evidence:** `IndoorGeofenceReceiver.kt` handles ENTER; `IndoorLocationMonitor.kt` starts observation or offers retry; `IndoorLocationService.kt` shows ongoing notification, limits observation to 20 minutes and emits indoor-entry notification after sustained degraded location; PendingIntent opens MainActivity on user tap. No app source changes are required, so Flutter analysis/tests are outside this artifact-only change.

# Camera Data

**Camera reports, reimagined.**

Native iOS/iPadOS camera data logging, reporting, and collaboration for professional motion picture and television production.

> **Status:** MVP + Phase 2 + Phase 3 implemented — Xcode project builds, 25 unit tests pass, simulator launch verified.

---

## Vision

Camera Data delivers the perfect balance of form and function for crews who work 12–18 hour days on set.

- **Form** — Cinematic, calm, and fast. Built with SwiftUI and the iOS 26+ Liquid Glass material system.
- **Function** — Offline-first SwiftData logging, pipeline-grade exports, CloudKit sync architecture, and on-device intelligence.

Built for **1st ACs, 2nd ACs, and script supervisors** on features, episodics, commercials, and VFX-heavy productions.

---

## Project Structure

```
CameraData.xcodeproj      # Xcode 26 universal iOS/iPadOS project
Sources/
  Domain/                 # Pure logic: SmartFill, VES mapping, NLP, voice lexicon
  Data/                   # SwiftData models + repositories
  DesignSystem/           # Liquid Glass components, theme, haptics
  Services/               # Export, sync, audit, security, Frame.io hooks
  Features/               # Dashboard, Entry Editor, Reports, Settings, Slate
CameraDataApp/            # @main app + App Intents
Widgets/                  # Take count WidgetKit extension
Tests/CameraDataTests/    # 25 unit tests on real implementations
```

---

## Requirements

- Xcode 26+
- iOS 26 SDK
- iPhone/iPad simulator or device

---

## Build & Test

```bash
xcodegen generate
xcodebuild -scheme CameraData -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme CameraData -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## Implemented Features

### MVP (v1.0)
- SwiftData entities with sync metadata stubs
- Hero Entry Editor (glass keypad, SmartFill v1, Log & Next)
- Multi-camera dashboard with stats and pagination
- PDF / CSV / JSON export (VES-aware)
- Onboarding, settings, keyword + NLP search
- Cinematic dark + Night/Red theme modes

### Phase 2
- CloudKit sync engine (offline queue, conflict merge)
- Presence service with heartbeat
- Role-based filtering (Admin/Editor/Read-only/VFX)
- Conflict resolution UI
- Production template cloning
- Branded PDF + daily wrap
- Frame.io export hook
- WidgetKit extension + App Intents / Shortcuts

### Phase 3
- Voice-to-log with film terminology lexicon
- SmartSuggest 2.0 (frequency-based ML stub)
- Natural language search parser
- Digital Slate Mode
- GPS / gyro metadata capture service
- AuditEvent version history
- Biometric security service

---

## Documentation

See [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) for the full architecture plan.

---

## License

Copyright © 2026 VisionaryPOV. All rights reserved.
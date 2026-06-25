# Camera Data

**Camera reports, reimagined.**

Native iOS/iPadOS camera data logging, reporting, and collaboration for professional motion picture and television production.

> **Status:** MVP + Phase 2 + Phase 3 implemented — Xcode project builds, 74 unit tests pass, simulator launch verified.

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
Tests/CameraDataTests/    # 74 unit tests on real implementations
```

---

## Requirements

- Xcode 26+
- iOS 26 SDK
- iPhone/iPad simulator or device

### Code signing (paid Apple Developer Program)

Requires **paid** membership — Personal Team cannot provision iCloud or App Groups.

#### Portal setup (one time)

1. **App Group** → [App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup) → `group.com.visionarypov.cameradata`
2. **iCloud container** → [iCloud Containers](https://developer.apple.com/account/resources/identifiers/list/cloudContainer) → `iCloud.com.visionarypov.cameradata`
3. **App ID** → [App IDs](https://developer.apple.com/account/resources/identifiers/list) → `com.visionarypov.cameradata` → **iCloud** (CloudKit + container) + **App Groups**
4. **Widget App ID** → `com.visionarypov.cameradata.widget` → **App Groups** only

#### Xcode setup (critical)

1. Scheme: **`CameraData`**
2. Targets **CameraData** and **CameraDataWidget** → Signing → team must be your **paid** account
   - Must **NOT** say `(Personal Team)` in the build log
   - If you see two teams in the dropdown, pick the paid membership (full legal name)
3. Clear cached profiles: `./Scripts/reset-provisioning.sh`
4. **Xcode → Settings → Accounts** → **Download Manual Profiles**
5. **Product → Clean Build Folder** → build

If signing still fails, sign out/in of your Apple ID in Xcode Settings → Accounts, then repeat steps 3–5.

After changing `project.yml`, regenerate the project:

```bash
xcodegen generate
```

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
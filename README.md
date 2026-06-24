# Camera Data

**Camera reports, reimagined.**

Native iOS/iPadOS camera data logging, reporting, and collaboration for professional motion picture and television production.

> **Status:** Early development — repository placeholder. Source code coming soon.

---

## Vision

Camera Data delivers the perfect balance of form and function for crews who work 12–18 hour days on set.

- **Form** — Cinematic, calm, and fast. Built with SwiftUI and the iOS 26+ Liquid Glass material system. High contrast for low-light shoots, thoughtful haptics, zero visual fatigue.
- **Function** — Faster and more flexible than legacy tools. Offline-first, pipeline-friendly exports, and real-time collaboration when you need it.

Built for **1st ACs, 2nd ACs, and script supervisors** on features, episodics, commercials, and VFX-heavy productions.

---

## Why Camera Data

| Capability | Camera Data |
|---|---|
| Logging speed | Hero Entry Editor — one-thumb, haptic-rich, SmartFill |
| Customization | Unlimited custom fields per production + smart templates |
| Collaboration | CloudKit sync, presence, roles, conflict resolution *(Phase 2)* |
| Exports | Branded PDF, CSV/JSON, VES-aware fields, Frame.io hooks *(Phase 2)* |
| Intelligence | Voice logging, ML suggestions, natural language search *(Phase 3)* |

---

## Tech Stack

- **Platform:** iOS 26+ / iPadOS (universal)
- **UI:** SwiftUI, Liquid Glass, Observation framework
- **Architecture:** Clean MVVM, `@Observable`, protocol-based dependency injection
- **Persistence:** SwiftData + CloudKit
- **Concurrency:** Swift 6 strict concurrency

---

## Roadmap

### MVP — v1.0
- Offline-first logging with flexible schema
- Multi-camera support (local)
- Hero Entry Editor with SmartFill v1
- PDF / CSV / JSON export
- Cinematic dark theme + Liquid Glass UI

### Phase 2 — Collaboration & Exports
- CloudKit real-time sync + presence
- Role-based access (Admin, Editor, Read-only, VFX)
- Branded PDF reports, daily wrap summaries
- Widgets, Shortcuts, Siri App Intents
- Frame.io Camera to Cloud integration hooks

### Phase 3 — Intelligence & Polish
- Voice-to-log with film terminology
- ML-based SmartSuggest 2.0
- Digital Slate Mode
- GPS + device orientation metadata
- Audit / version history

See [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) for the full architecture and phased plan.

---

## Getting Started

*Not yet available.* This repository will host the Xcode project once scaffolding begins.

**Requirements (planned):**
- Xcode 26+
- iOS 26 SDK
- Apple Developer account (for CloudKit & TestFlight)

---

## Contributing

This project is in private early development. Contribution guidelines will be published before the first public beta.

---

## License

Copyright © 2026 VisionaryPOV. All rights reserved.

Source code license TBD prior to open beta.
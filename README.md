# DadaKnows

> An AI-powered Q&A companion for children (ages 2-12) built with SwiftUI, Supabase & StoreKit 2.

---

## 1  Features

| Area | Highlights |
|------|------------|
| AI Chat | Gemini-powered answers, age-adaptive language, streaming responses |
| Voice | Speech-to-text input, animated recording UI |
| Offline | Local caching & offline queue |
| Pro Subscription | Monthly / Yearly / Lifetime tiers via StoreKit 2 |
| Analytics | Progress charts, achievement badges |
| Notifications | Daily study reminders, goal streaks |

See `FEATURE_COMPLETION_SUMMARY.md` for the full delivered scope.

---

## 2  Architecture Overview

```
DadaKnows iOS
├── Core        # AI / Network / Storage / Subscription / Analytics
├── Features    # SwiftUI screens (Chat, Home, Profile, etc.)
├── Components  # Re-usable UI elements & animations
└── Resources   # Assets & Localizations
```

Backend is hosted on **Supabase Edge Functions** (Postgres, Storage, Auth). Detailed architecture: `docs/dada_low_cost_architecture.md`.

---

## 3  Getting Started

```bash
# Clone & install tools
brew install supabase/tap/supabase # CLI (backend)

# iOS App
open DadaKnows/DadaKnows.xcodeproj   # Build/run with Xcode 15+

# Backend (Edge Functions)
./deploy-supabase.sh                  # one-click deploy
```

Configuration keys are stored in `DadaKnows/Core/Config.swift` and `supabase/config.toml`.

---

## 4  Documentation Map

| Guide | Path |
|-------|------|
| Deployment (Edge Functions) | `docs/deployment.md` |
| Supabase Integration | `SUPABASE_INTEGRATION_GUIDE.md` |
| Manual DB setup | `DATABASE_SETUP_GUIDE.md` |
| In-App Purchase & Payment | `docs/iap_guide.md` |
| ChatView Integration (SDK) | `CHATVIEW_INTEGRATION_EXAMPLE.md` |
| Cloud Sync | `CLOUD_SYNC_INTEGRATION_GUIDE.md` |
| Low-cost Architecture | `docs/dada_low_cost_architecture.md` |

---

## 5  Contributing

Pull requests & issues are welcome! Please run `swiftlint` and include unit tests where relevant.

---

## 6  License

Copyright © 2024 DadaKnows. All rights reserved.

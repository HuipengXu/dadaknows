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

See [`docs/feature_completion_summary.md`](docs/feature_completion_summary.md) for the full delivered scope.

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
./scripts/deploy-supabase.sh         # one-click deploy
```

Configuration keys are stored in `DadaKnows/Core/Config.swift` and `supabase/config.toml`.

---

## 4  文档导航

> 📚 **查看完整文档导航**: [`docs/documentation_index.md`](docs/documentation_index.md)

### 🚀 快速开始
| 角色 | 必读文档 | 说明 |
|------|----------|------|
| **开发者** | [`docs/development_guide.md`](docs/development_guide.md) | 一站式开发指南 |
| **项目经理** | [`docs/project_status_and_todo.md`](docs/project_status_and_todo.md) | 项目状态和发布计划 |
| **架构师** | [`docs/dada_low_cost_architecture.md`](docs/dada_low_cost_architecture.md) | 系统架构设计 |
| **运维** | [`scripts/README.md`](scripts/README.md) | 自动化脚本工具 |

### 📁 核心文档 (已精简整合)
| 文档类型 | 文档 | 包含内容 |
|----------|------|----------|
| **开发指南** | [`development_guide.md`](docs/development_guide.md) | 技术架构 + 环境配置 + 部署流程 + 开发规范 |
| **问题解决** | [`troubleshooting_guide.md`](docs/troubleshooting_guide.md) | 常见问题 + 性能优化 + 调试技巧 |
| **项目状态** | [`project_status_and_todo.md`](docs/project_status_and_todo.md) | 95%完成度 + 发布计划 |
| **功能清单** | [`feature_completion_summary.md`](docs/feature_completion_summary.md) | 已完成功能详细说明 |
| **架构设计** | [`dada_low_cost_architecture.md`](docs/dada_low_cost_architecture.md) | 系统架构 (核心文档) |
| **产品需求** | [`dada-knows-prd.md`](docs/dada-knows-prd.md) | 产品定义 (核心文档) |
| **数据库** | [`data-knows-database.md`](docs/data-knows-database.md) | 数据结构 (核心文档) |
| **商店发布** | [`app_store_assets.md`](docs/app_store_assets.md) | 上架准备材料 |
| **支付配置** | [`in_app_purchase_guide.md`](docs/in_app_purchase_guide.md) | IAP集成指南 |
| **邮件配置** | [`smtp_configuration.md`](docs/smtp_configuration.md) | 邮件服务设置 |

### 🛠️ 开发工具
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| [`deploy-supabase.sh`](scripts/deploy-supabase.sh) | 一键部署后端 | 初始化部署 |
| [`build-ios.sh`](scripts/build-ios.sh) | iOS构建验证 | 开发测试 |
| [`test-ask-dada.sh`](scripts/test-ask-dada.sh) | 功能测试 | 部署验证 |
| [`clean-simulator.sh`](scripts/clean-simulator.sh) | 清理缓存 | 问题排查 |

---

## 5  Contributing

Pull requests & issues are welcome! Please run `swiftlint` and include unit tests where relevant.

---

## 6  License

Copyright © 2024 DadaKnows. All rights reserved.

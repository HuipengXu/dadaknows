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

### 📊 文档体系 v4.0 (已精简 66%)

**整理成果**: 从35+个文档精简到12个核心文档，消除所有重复内容

### 🚀 快速开始
| 角色 | 必读文档 | 说明 |
|------|----------|------|
| **开发者** | [`docs/development_guide.md`](docs/development_guide.md) | 一站式开发指南 |
| **MLX开发** | [`docs/mlx_troubleshooting.md`](docs/mlx_troubleshooting.md) | 本地AI故障排除 ⭐ 新增 |
| **项目经理** | [`docs/project_status_and_todo.md`](docs/project_status_and_todo.md) | 项目状态和发布计划 |
| **架构师** | [`docs/dadaknows_low_cost_architecture.md`](docs/dadaknows_low_cost_architecture.md) | 系统架构设计 |
| **运维** | [`scripts/README.md`](scripts/README.md) | 自动化脚本工具 |

### 📁 核心文档 (12个)

#### 开发文档 (5个)
| 文档 | 说明 |
|------|------|
| [`development_guide.md`](docs/development_guide.md) | 技术架构 + 环境配置 + 部署流程 |
| [`mlx_troubleshooting.md`](docs/mlx_troubleshooting.md) | MLX完整故障排除 ⭐ 新增 |
| [`mlx_implementation.md`](docs/mlx_implementation.md) | MLX完整实现文档 ⭐ 新增 |
| [`troubleshooting_guide.md`](docs/troubleshooting_guide.md) | 通用问题解决 |
| [`performance_report.md`](docs/performance_report.md) | 性能分析报告 |

#### 架构文档 (3个)
| 文档 | 说明 |
|------|------|
| [`dadaknows_low_cost_architecture.md`](docs/dadaknows_low_cost_architecture.md) | 系统架构设计 |
| [`dadaknows_database.md`](docs/dadaknows_database.md) | 数据库设计 |
| [`dadaknows_prd.md`](docs/dadaknows_prd.md) | 产品需求文档 |

#### 配置文档 (1个)
| 文档 | 说明 |
|------|------|
| [`security_and_configuration.md`](docs/security_and_configuration.md) | 安全审计 + Supabase + 邮件配置 ⭐ 新增 |

#### 发布文档 (2个)
| 文档 | 说明 |
|------|------|
| [`app_store_assets.md`](docs/app_store_assets.md) | 应用商店上架准备 |
| [`in_app_purchase_guide.md`](docs/in_app_purchase_guide.md) | 应用内购买配置 |

#### 项目管理 (1个)
| 文档 | 说明 |
|------|------|
| [`project_status_and_todo.md`](docs/project_status_and_todo.md) | 项目状态 + 发布计划 |

### 🛠️ 开发工具
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| [`deploy-supabase.sh`](scripts/deploy-supabase.sh) | 一键部署后端 | 初始化部署 |
| [`build-ios.sh`](scripts/build-ios.sh) | iOS构建验证 | 开发测试 |
| [`test-ask-dada.sh`](scripts/test-ask-dada.sh) | 功能测试 | 部署验证 |
| [`clean-simulator.sh`](scripts/clean-simulator.sh) | 清理缓存 | 问题排查 |
| [`verify-model-urls.sh`](scripts/verify-model-urls.sh) | 验证模型URL | MLX开发 |

---

## 5  Contributing

Pull requests & issues are welcome! Please run `swiftlint` and include unit tests where relevant.

---

## 6  License

Copyright © 2024 DadaKnows. All rights reserved.

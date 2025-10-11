# DadaKnows 文档索引

**最后更新**: 2025-10-10  
**文档版本**: 5.0 (精简优化版)

---

## 📊 文档统计

**总计**: 16个核心文档 (从35+个精简到16个，减少 55%)

| 类别 | 文档数 | 说明 |
|------|--------|------|
| 📖 开发指南 | 4个 | 技术架构、开发环境、问题排查 |
| 🏗️ 架构设计 | 3个 | 系统架构、数据库、产品需求 |
| 🔒 安全配置 | 1个 | 安全审计、Supabase、邮件配置 |
| 📱 发布文档 | 2个 | App Store、内购配置 |
| 💎 订阅功能 | 1个 | 订阅修复和优化总结 |
| 🎯 月度限制 | 2个 | Pro用户月度使用限制 |
| 📋 项目管理 | 2个 | 项目状态、性能报告 |
| 🔍 故障排查 | 1个 | 通用问题解决 |

---

## 🚀 快速开始

### 按角色查找

| 角色 | 必读文档 |
|------|----------|
| **新手开发者** | [开发指南](development_guide.md) → [故障排查](troubleshooting_guide.md) |
| **后端开发** | [系统架构](dadaknows_low_cost_architecture.md) → [数据库设计](dadaknows_database.md) |
| **MLX开发** | [MLX实现](mlx_implementation.md) → [MLX故障排查](mlx_troubleshooting.md) |
| **项目经理** | [项目状态](project_status_and_todo.md) → [产品需求](dadaknows_prd.md) |
| **运维人员** | [安全配置](security_and_configuration.md) → [性能报告](performance_report.md) |
| **发布人员** | [App Store资产](app_store_assets.md) → [内购指南](in_app_purchase_guide.md) |

---

## 📚 文档分类

### 📖 开发指南 (4个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [development_guide.md](development_guide.md) | 完整开发指南：架构、配置、部署 | ⭐⭐⭐ |
| [mlx_implementation.md](mlx_implementation.md) | MLX本地AI实现详解 | ⭐⭐⭐ |
| [mlx_troubleshooting.md](mlx_troubleshooting.md) | MLX故障排查和解决方案 | ⭐⭐ |
| [troubleshooting_guide.md](troubleshooting_guide.md) | 通用问题排查指南 | ⭐⭐ |

### 🏗️ 架构设计 (3个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [dadaknows_low_cost_architecture.md](dadaknows_low_cost_architecture.md) | 低成本系统架构设计 | ⭐⭐⭐ |
| [dadaknows_database.md](dadaknows_database.md) | 数据库设计和ER图 | ⭐⭐⭐ |
| [dadaknows_prd.md](dadaknows_prd.md) | 产品需求文档 | ⭐⭐ |

### 🔒 安全配置 (1个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [security_and_configuration.md](security_and_configuration.md) | 安全审计 + Supabase + 邮件配置 | ⭐⭐⭐ |

### 📱 发布文档 (2个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [app_store_assets.md](app_store_assets.md) | App Store上架准备 | ⭐⭐⭐ |
| [in_app_purchase_guide.md](in_app_purchase_guide.md) | 应用内购买配置 | ⭐⭐⭐ |

### 💎 订阅功能 (1个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [subscription_fixes_summary.md](subscription_fixes_summary.md) | 订阅bug修复和优化总结 | ⭐⭐ |

### 🎯 月度限制功能 (2个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [monthly_usage_index.md](monthly_usage_index.md) | 月度限制功能索引 | ⭐⭐⭐ |
| [monthly_usage_guide.md](monthly_usage_guide.md) | 完整实现和部署指南 | ⭐⭐⭐ |

### 📋 项目管理 (2个)

| 文档 | 说明 | 优先级 |
|------|------|--------|
| [project_status_and_todo.md](project_status_and_todo.md) | 项目状态和TODO清单 | ⭐⭐⭐ |
| [performance_report.md](performance_report.md) | 性能分析和优化报告 | ⭐⭐ |

---

## 🛠️ 开发工具

### 自动化脚本

| 脚本 | 功能 | 文档 |
|------|------|------|
| `deploy-supabase.sh` | 一键部署后端 | [开发指南](development_guide.md) |
| `deploy-monthly-usage.sh` | 部署月度限制功能 | [月度使用指南](monthly_usage_guide.md) |
| `build-ios.sh` | iOS构建验证 | [开发指南](development_guide.md) |
| `test-ask-dada.sh` | 功能测试 | [开发指南](development_guide.md) |
| `test-monthly-usage.sh` | 月度限制测试 | [月度使用指南](monthly_usage_guide.md) |
| `clean-simulator.sh` | 清理缓存 | [故障排查](troubleshooting_guide.md) |
| `verify-model-urls.sh` | 验证MLX模型 | [MLX故障排查](mlx_troubleshooting.md) |

---

## 📖 常见任务

### 环境搭建
1. 阅读 [开发指南](development_guide.md) 第1-3节
2. 运行 `./scripts/deploy-supabase.sh`
3. 在Xcode中打开项目

### 添加新功能
1. 查看 [项目状态](project_status_and_todo.md) 了解现有功能
2. 参考 [系统架构](dadaknows_low_cost_architecture.md) 设计方案
3. 按照 [开发指南](development_guide.md) 实施

### 问题排查
1. 通用问题 → [故障排查指南](troubleshooting_guide.md)
2. MLX问题 → [MLX故障排查](mlx_troubleshooting.md)
3. 订阅问题 → [订阅修复总结](subscription_fixes_summary.md)
4. 性能问题 → [性能报告](performance_report.md)

### 上线发布
1. [App Store资产准备](app_store_assets.md)
2. [内购配置](in_app_purchase_guide.md)
3. [安全配置检查](security_and_configuration.md)

---

## 🔗 外部资源

- **Supabase Dashboard**: https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj
- **Apple Developer**: https://developer.apple.com
- **MLX Swift**: https://github.com/ml-explore/mlx-swift
- **Gemini API**: https://ai.google.dev

---

## 📝 文档维护

### 命名规范
- 全小写，下划线分隔
- 避免缩写（除MLX等专有名词）
- 描述性命名

### 更新原则
1. 保持文档与代码同步
2. 删除过时内容
3. 合并重复文档
4. 添加最后更新日期

### 文档版本历史
- **v5.0** (2025-10-10): 大幅精简，从35+到16个文档
- **v4.0** (2025-10-09): 精简66%，整合重复内容
- **v3.0** (2024): 添加MLX和订阅文档
- **v2.0** (2024): 架构和开发指南
- **v1.0** (2024): 初始版本

---

## 📊 文档覆盖率

| 模块 | 文档状态 | 完整度 |
|------|----------|--------|
| 核心架构 | ✅ 完整 | 100% |
| AI功能 | ✅ 完整 | 100% |
| 订阅系统 | ✅ 完整 | 100% |
| 数据库 | ✅ 完整 | 100% |
| 安全配置 | ✅ 完整 | 100% |
| 发布流程 | ✅ 完整 | 100% |
| MLX集成 | ✅ 完整 | 100% |
| 测试指南 | ⚠️ 部分 | 60% |
| API文档 | ⚠️ 部分 | 50% |

---

**维护者**: DadaKnows Team  
**联系方式**: 见 [README.md](../README.md)

# Pro用户月度使用限制 - 文档索引

**状态**: ✅ 已完成并部署  
**日期**: 2025-10-10

---

## 📚 核心文档

### 主要文档
- **[完整指南](monthly_usage_guide.md)** ⭐ - 部署、测试、技术实现（推荐阅读）
- **[完成报告](monthly_usage_completion_report.md)** - 详细的完成状态和清单
- **[技术实施](monthly_usage_limit_implementation.md)** - 深入的技术文档
- **[代码变更](monthly_usage_changes.md)** - 所有代码变更说明

---

## 🚀 快速开始

### 部署（已完成）
```bash
./scripts/deploy-monthly-usage.sh
```

### 测试
```bash
./scripts/test-monthly-usage.sh
```

### iOS App
```bash
open DadaKnows/DadaKnows.xcodeproj
```

---

## 📊 功能概述

| 用户类型 | 模型类型 | 限制 |
|----------|----------|------|
| Pro 用户 | 云端模型 | **3000次/月** |
| Pro 用户 | 本地模型 | 无限制 |
| 免费用户 | 云端模型 | 2次/天 |
| 免费用户 | 本地模型 | 无限制 |

---

## ✅ 部署状态

- ✅ Edge Functions 已部署 (check-usage, increment-usage, ask-dada v9)
- ✅ 数据库迁移已完成
- ✅ iOS 代码已更新
- ⚠️ iOS 测试待验证

---

## 🔗 快速链接

- **Supabase Dashboard**: https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj
- **部署脚本**: `scripts/deploy-monthly-usage.sh`
- **测试脚本**: `scripts/test-monthly-usage.sh`
- **SQL测试**: `scripts/test-monthly-limit.sql`

---

**最后更新**: 2025-10-10

# Pro用户月度使用限制 - 完整指南

**版本**: 1.0.0  
**日期**: 2025-10-10  
**状态**: ✅ 已完成并部署

---

## 📋 快速概览

为订阅Pro的用户实施了**每月远程模型3000次问答限制**功能。

### 限制规则

| 用户类型 | 模型类型 | 限制 |
|----------|----------|------|
| Pro 用户 | 云端模型 (Gemini) | **3000次/月** |
| Pro 用户 | 本地模型 (MLX) | 无限制 |
| 免费用户 | 云端模型 (Gemini) | 2次/天 |
| 免费用户 | 本地模型 (MLX) | 无限制 |

### 核心特性

- ✅ 月度自动重置（每月1日）
- ✅ 实时追踪使用次数
- ✅ UI可视化显示（进度环+颜色编码）
- ✅ 达限后友好提示
- ✅ 灵活配置（Config.swift）

---

## 🚀 部署状态

### Edge Functions ✅
- `check-usage` - v1 ACTIVE
- `increment-usage` - v1 ACTIVE  
- `ask-dada` - v9 ACTIVE (已更新)

### 数据库 ✅
- 表 `user_usage_stats` 已创建
- 3个数据库函数已部署

### iOS 代码 ✅
- 6个核心文件已修改
- UI显示已完成

---

## 📦 快速部署

### 1. 部署 Edge Functions
```bash
./scripts/deploy-monthly-usage.sh
```

### 2. 执行数据库迁移
在 Supabase Dashboard SQL Editor 中执行：
```bash
# 访问 https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj/sql
# 复制并执行 supabase/migrations/004_add_usage_tracking.sql
```

### 3. 测试功能
```bash
./scripts/test-monthly-usage.sh
```

### 4. iOS App 测试
```bash
open DadaKnows/DadaKnows.xcodeproj
# ⌘ + B (Build)
# ⌘ + R (Run)
```

**验证步骤**:
1. Pro账号登录
2. 切换到云端模型
3. 进入"设置" → Pro会员区域
4. 验证显示: "本月剩余问答次数: 3000 / 3000"

---

## 🔧 技术实现

### 数据流

```
用户提问
  ↓
AIManager 检查配额
  ↓
SupabaseClient.checkMonthlyUsage()
  ↓
Edge Function: check-usage
  ↓
数据库: check_monthly_usage_limit()
  ↓
返回配额状态
  ↓
[允许] 调用 ask-dada
  ↓
increment_remote_usage() 增加计数
  ↓
生成AI回答
```

### 关键文件

**数据库**:
- `supabase/migrations/004_add_usage_tracking.sql`

**Edge Functions**:
- `supabase/functions/check-usage/index.ts` (新)
- `supabase/functions/increment-usage/index.ts` (新)
- `supabase/functions/ask-dada/index.ts` (更新)

**iOS 代码**:
- `Config.swift` - 添加 `monthlyProQuestionLimit = 3000`
- `SubscriptionManager.swift` - 月度统计管理
- `SupabaseClient.swift` - 网络请求支持
- `AIManager.swift` - 配额检查集成
- `ProfileView.swift` - UI显示使用情况
- `ProSubscriptionView.swift` - 订阅说明更新

---

## 🧪 测试说明

### 数据库测试
```sql
-- 检查表
SELECT * FROM user_usage_stats LIMIT 1;

-- 检查函数
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN (
    'check_monthly_usage_limit',
    'increment_remote_usage',
    'get_or_create_current_month_usage'
);
```

更多测试查询见: `scripts/test-monthly-limit.sql`

### API 测试
```bash
./scripts/test-monthly-usage.sh
```

### iOS 测试
使用真实Pro账号测试完整流程。

---

## 📊 监控建议

### 关键指标

1. **平均使用量**
```sql
SELECT AVG(remote_questions_count) 
FROM user_usage_stats 
WHERE year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());
```

2. **达限用户数**
```sql
SELECT COUNT(*) 
FROM user_usage_stats 
WHERE remote_questions_count >= 3000
  AND year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());
```

---

## ⚙️ 配置调整

修改月度限制（默认3000）：

```swift
// DadaKnows/DadaKnows/Core/Config.swift
static let monthlyProQuestionLimit = 3000  // 修改此值
```

---

## 🔗 相关链接

- **Supabase Dashboard**: https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj
- **部署脚本**: `scripts/deploy-monthly-usage.sh`
- **测试脚本**: `scripts/test-monthly-usage.sh`
- **SQL测试**: `scripts/test-monthly-limit.sql`

---

## 📝 变更清单

### 新增文件
- `supabase/migrations/004_add_usage_tracking.sql`
- `supabase/functions/check-usage/index.ts`
- `supabase/functions/increment-usage/index.ts`
- `scripts/deploy-monthly-usage.sh`
- `scripts/test-monthly-usage.sh`
- `scripts/test-monthly-limit.sql`

### 修改文件
- `supabase/functions/ask-dada/index.ts`
- `DadaKnows/DadaKnows/Core/Config.swift`
- `DadaKnows/DadaKnows/Core/Subscription/SubscriptionManager.swift`
- `DadaKnows/DadaKnows/Core/Network/SupabaseClient.swift`
- `DadaKnows/DadaKnows/Core/AI/AIManager.swift`
- `DadaKnows/DadaKnows/Features/Profile/ProfileView.swift`
- `DadaKnows/DadaKnows/Features/Subscription/ProSubscriptionView.swift`

---

## 🆘 故障排查

### 问题：使用次数不增加
- 检查 Edge Function 日志
- 确认 userId 正确传递
- 验证数据库函数权限

### 问题：客户端显示不正确
- 检查网络请求
- 查看 Xcode 控制台日志
- 确认用户已登录

### 问题：达到限制后仍可提问
- 检查配额检查逻辑
- 确认 isProMember 状态
- 查看 Edge Function 日志

---

**维护者**: DadaKnows Team  
**最后更新**: 2025-10-10


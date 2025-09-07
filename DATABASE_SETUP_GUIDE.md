# 🗄️ DadaKnows 数据库建表指南

## 📋 概述
本指南将帮你在Supabase云端创建DadaKnows应用的核心数据库表。

## 🚀 方法一：自动部署（推荐）

### 前置条件
```bash
# 1. 安装Supabase CLI
npm install -g supabase
# 或者使用Homebrew
brew install supabase/tap/supabase

# 2. 登录Supabase
supabase login
```

### 执行部署
```bash
# 在项目根目录执行
./deploy-database.sh
```

## 🔧 方法二：手动执行

### 1. 登录Supabase Dashboard
访问：https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj

### 2. 打开SQL编辑器
- 点击左侧菜单的 "SQL Editor"
- 点击 "New query"

### 3. 执行建表SQL
复制 `supabase/migrations/001_create_core_tables.sql` 文件的全部内容，粘贴到SQL编辑器中，然后点击 "Run" 执行。

## 📊 创建的表结构

### 1. `users` 表 - 用户配置文件
```sql
- id (UUID) - 关联auth.users
- nickname (TEXT) - 用户昵称  
- avatar_url (TEXT) - 头像URL
- preferred_language (VARCHAR) - 偏好语言
- subscription_status (TEXT) - 订阅状态
- stripe_customer_id (TEXT) - Stripe客户ID
- created_at/updated_at (TIMESTAMPTZ) - 时间戳
```

### 2. `chats` 表 - 聊天记录
```sql
- id (BIGINT) - 自增主键
- uuid (UUID) - 对外唯一标识
- user_id (UUID) - 关联用户
- parent_chat_id (BIGINT) - 父级对话（追问功能）
- question_text (TEXT) - 用户问题
- answer_text (TEXT) - AI回答
- target_age (SMALLINT) - 目标年龄
- language (VARCHAR) - 对话语言
- user_feedback (TEXT) - 用户反馈
- created_at (TIMESTAMPTZ) - 创建时间
```

### 3. `prompts` 表 - 提示词管理
```sql
- id (INTEGER) - 自增主键
- name (VARCHAR) - 提示词名称
- template_text (TEXT) - 模板内容
- version (INTEGER) - 版本号
- is_active (BOOLEAN) - 是否活跃
- notes (TEXT) - 备注说明
- created_at/updated_at (TIMESTAMPTZ) - 时间戳
```

## 🔒 安全特性

### 行级安全策略 (RLS)
- ✅ **用户隔离**: 每个用户只能访问自己的数据
- ✅ **提示词保护**: 只有服务角色可以管理提示词
- ✅ **认证检查**: 所有操作都需要有效的认证

### 数据完整性
- ✅ **外键约束**: 确保数据关联正确
- ✅ **检查约束**: 验证年龄范围、状态值等
- ✅ **唯一约束**: 防止重复数据

## ⚡ 性能优化

### 关键索引
- `idx_chats_user_id_created_at` - 用户聊天记录查询优化
- `idx_prompts_name_active` - 活跃提示词快速查找
- `idx_users_subscription_status` - 订阅状态查询优化

### 自动化功能
- ✅ **时间戳更新**: 自动更新 `updated_at` 字段
- ✅ **UUID生成**: 自动生成唯一标识符

## 📱 默认数据

### 预置提示词
系统会自动插入两个核心提示词：
1. `ask_dada` - 基础问答模板
2. `regenerate_answer` - 重新生成回答模板

## ✅ 验证部署

### 1. 检查表是否创建成功
在Supabase Dashboard的 "Table Editor" 中应该能看到：
- ✅ users
- ✅ chats  
- ✅ prompts

### 2. 检查RLS策略
在 "Authentication" > "Policies" 中应该能看到相应的安全策略。

### 3. 检查默认数据
在 `prompts` 表中应该有两条默认记录。

## 🔧 故障排除

### 常见问题

**问题1**: "relation already exists" 错误
```sql
-- 解决方案：删除现有表（谨慎操作）
DROP TABLE IF EXISTS public.chats CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;  
DROP TABLE IF EXISTS public.prompts CASCADE;
```

**问题2**: RLS策略冲突
```sql
-- 解决方案：先删除现有策略
DROP POLICY IF EXISTS "用户只能查看和修改自己的资料" ON public.users;
-- 然后重新创建
```

**问题3**: 索引创建失败
```sql
-- 解决方案：检查表是否存在，然后重新创建索引
DROP INDEX IF EXISTS idx_chats_user_id_created_at;
CREATE INDEX idx_chats_user_id_created_at ON public.chats(user_id, created_at DESC);
```

## 📞 支持

如果遇到问题，请检查：
1. Supabase项目ID是否正确
2. 是否有足够的数据库权限
3. SQL语法是否正确

---

🎉 **恭喜！** 数据库表创建完成后，你就可以开始实现iOS应用的云端数据同步功能了！

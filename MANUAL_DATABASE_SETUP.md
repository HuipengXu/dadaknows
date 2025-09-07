# 🔧 手动创建数据库表 - 详细步骤

由于网络连接问题，我们使用手动方式在Supabase Dashboard中创建数据库表。

## 📋 操作步骤

### 1. 打开Supabase Dashboard
访问：https://supabase.com/dashboard/project/fwvyrcekbngcpiudljpj

### 2. 进入SQL编辑器
- 点击左侧菜单的 **"SQL Editor"**
- 点击 **"New query"** 创建新查询

### 3. 执行建表SQL

将以下SQL代码复制粘贴到SQL编辑器中，然后点击 **"Run"** 执行：

```sql
-- DadaKnows 核心数据库表创建脚本
-- 创建时间: 2025-01-27

-- =============================================
-- 1. 用户配置表 (users)
-- =============================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nickname TEXT,
    avatar_url TEXT,
    preferred_language VARCHAR(5) NOT NULL DEFAULT 'zh-CN',
    subscription_status TEXT NOT NULL DEFAULT 'free' CHECK (subscription_status IN ('free', 'pro_active', 'pro_canceled', 'pro_expired')),
    stripe_customer_id TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 2. 聊天记录表 (chats)
-- =============================================
CREATE TABLE IF NOT EXISTS public.chats (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    parent_chat_id BIGINT REFERENCES public.chats(id) ON DELETE SET NULL,
    question_text TEXT NOT NULL,
    answer_text TEXT,
    target_age SMALLINT NOT NULL CHECK (target_age >= 2 AND target_age <= 12),
    language VARCHAR(5) NOT NULL DEFAULT 'zh-CN',
    user_feedback TEXT DEFAULT 'none' CHECK (user_feedback IN ('none', 'liked', 'disliked', 'regenerated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 3. 提示词管理表 (prompts)
-- =============================================
CREATE TABLE IF NOT EXISTS public.prompts (
    id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    template_text TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 4. 创建索引优化查询性能
-- =============================================

-- 用户表索引
CREATE INDEX IF NOT EXISTS idx_users_subscription_status ON public.users(subscription_status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);

-- 聊天表索引 (最重要的性能优化)
CREATE INDEX IF NOT EXISTS idx_chats_user_id_created_at ON public.chats(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chats_uuid ON public.chats(uuid);
CREATE INDEX IF NOT EXISTS idx_chats_parent_chat_id ON public.chats(parent_chat_id);
CREATE INDEX IF NOT EXISTS idx_chats_target_age ON public.chats(target_age);
CREATE INDEX IF NOT EXISTS idx_chats_language ON public.chats(language);

-- 提示词表索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_prompts_name_active ON public.prompts(name) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_prompts_name_version ON public.prompts(name, version DESC);

-- =============================================
-- 5. 设置行级安全策略 (RLS)
-- =============================================

-- 启用行级安全
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prompts ENABLE ROW LEVEL SECURITY;

-- 用户表RLS策略
CREATE POLICY "用户只能查看和修改自己的资料" ON public.users
    FOR ALL USING (auth.uid() = id);

-- 聊天表RLS策略
CREATE POLICY "用户只能访问自己的聊天记录" ON public.chats
    FOR ALL USING (auth.uid() = user_id);

-- 提示词表RLS策略 (只允许服务角色访问)
CREATE POLICY "只有服务角色可以管理提示词" ON public.prompts
    FOR ALL USING (auth.role() = 'service_role');

-- 允许认证用户读取活跃的提示词
CREATE POLICY "认证用户可以读取活跃提示词" ON public.prompts
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

-- =============================================
-- 6. 创建触发器自动更新时间戳
-- =============================================

-- 创建更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为用户表添加更新时间戳触发器
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON public.users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 为提示词表添加更新时间戳触发器
CREATE TRIGGER update_prompts_updated_at 
    BEFORE UPDATE ON public.prompts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 7. 插入默认提示词数据
-- =============================================

-- 插入默认的AI问答提示词
INSERT INTO public.prompts (name, template_text, version, is_active, notes) VALUES 
(
    'ask_dada',
    '你是"答答"，一个专为{age}岁儿童设计的AI知识伙伴。请用{language}回答以下问题：

问题：{question}

回答要求：
1. 使用适合{age}岁儿童理解的简单语言
2. 回答要准确、有趣且富有教育意义
3. 如果问题不适合儿童，请引导到更合适的话题
4. 保持友好、耐心的语调
5. 可以使用简单的比喻和例子帮助理解

请开始回答：',
    1,
    true,
    '默认的AI问答提示词模板'
),
(
    'regenerate_answer',
    '你是"答答"，刚才你已经回答了一个{age}岁儿童的问题。现在请用不同的方式重新回答同一个问题。

原问题：{question}
之前的回答：{previous_answer}

请用{language}提供一个全新的回答方式：
1. 使用不同的解释角度或例子
2. 保持适合{age}岁儿童的语言水平
3. 确保内容准确且有教育价值
4. 让回答更生动有趣

请开始重新回答：',
    1,
    true,
    '重新生成回答的提示词模板'
) ON CONFLICT (name) WHERE is_active = true DO NOTHING;

-- 完成提示
SELECT 'DadaKnows核心数据库表创建完成！' as message;
```

## ✅ 验证步骤

### 1. 检查表创建
执行SQL后，应该看到成功消息。然后：
- 点击左侧菜单的 **"Table Editor"**
- 确认能看到三张表：`users`、`chats`、`prompts`

### 2. 检查默认数据
- 点击 `prompts` 表
- 应该能看到两条记录：`ask_dada` 和 `regenerate_answer`

### 3. 检查安全策略
- 点击左侧菜单的 **"Authentication"** > **"Policies"**
- 应该能看到为每张表创建的RLS策略

## 🎉 完成！

数据库表创建完成后，你就可以：
1. 在iOS应用中集成云端数据同步
2. 实现用户配置文件管理
3. 支持聊天记录云端备份
4. 动态管理AI提示词

## 📱 下一步

建议更新iOS应用代码，添加：
1. 用户配置同步功能
2. 聊天记录云端存储
3. 离线数据同步机制

需要帮助实现这些功能吗？

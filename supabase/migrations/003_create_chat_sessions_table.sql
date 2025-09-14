-- Create chat_sessions table
-- 创建时间: 2025-09-14
-- 描述: 创建聊天会话表，用于组织和管理聊天记录

-- =============================================
-- 创建聊天会话表 (chat_sessions)
-- =============================================
-- 用于组织聊天记录，每个会话包含多个相关的问答
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

-- 聊天会话表注释
COMMENT ON TABLE public.chat_sessions IS '聊天会话表，用于组织和管理相关的聊天记录';
COMMENT ON COLUMN public.chat_sessions.id IS '内部自增ID';
COMMENT ON COLUMN public.chat_sessions.uuid IS '对外暴露的唯一标识符';
COMMENT ON COLUMN public.chat_sessions.user_id IS '关联的用户ID';
COMMENT ON COLUMN public.chat_sessions.title IS '会话标题';
COMMENT ON COLUMN public.chat_sessions.started_at IS '会话开始时间';
COMMENT ON COLUMN public.chat_sessions.ended_at IS '会话结束时间';

-- 为聊天表添加会话ID外键约束
ALTER TABLE public.chats 
ADD COLUMN IF NOT EXISTS session_id BIGINT REFERENCES public.chat_sessions(id) ON DELETE SET NULL;

-- 聊天会话表索引
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id_started_at ON public.chat_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_uuid ON public.chat_sessions(uuid);

-- 聊天表会话ID索引
CREATE INDEX IF NOT EXISTS idx_chats_session_id ON public.chats(session_id);

-- 启用行级安全
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

-- 创建 RLS 策略：用户只能访问自己的会话
CREATE POLICY "用户只能访问自己的聊天会话" ON public.chat_sessions
    FOR ALL USING (auth.uid() = user_id);

-- 完成提示
SELECT '✅ chat_sessions 表创建完成！' as message;

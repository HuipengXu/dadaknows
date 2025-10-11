-- Add usage tracking for remote model usage
-- 创建时间: 2025-01-27
-- 描述: 添加用户月度使用统计，用于追踪Pro用户的远程模型使用次数

-- =============================================
-- 1. 创建用户使用统计表 (user_usage_stats)
-- =============================================
CREATE TABLE IF NOT EXISTS public.user_usage_stats (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    remote_questions_count INTEGER NOT NULL DEFAULT 0,
    local_questions_count INTEGER NOT NULL DEFAULT 0,
    last_reset_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, year, month)
);

-- 用户使用统计表注释
COMMENT ON TABLE public.user_usage_stats IS '用户月度使用统计表，追踪远程和本地模型使用次数';
COMMENT ON COLUMN public.user_usage_stats.user_id IS '关联的用户ID';
COMMENT ON COLUMN public.user_usage_stats.year IS '统计年份';
COMMENT ON COLUMN public.user_usage_stats.month IS '统计月份 (1-12)';
COMMENT ON COLUMN public.user_usage_stats.remote_questions_count IS '该月使用远程模型的问答次数';
COMMENT ON COLUMN public.user_usage_stats.local_questions_count IS '该月使用本地模型的问答次数';
COMMENT ON COLUMN public.user_usage_stats.last_reset_at IS '最后一次重置时间';

-- =============================================
-- 2. 添加索引优化查询性能
-- =============================================
CREATE INDEX IF NOT EXISTS idx_user_usage_stats_user_id_year_month 
    ON public.user_usage_stats(user_id, year DESC, month DESC);
CREATE INDEX IF NOT EXISTS idx_user_usage_stats_year_month 
    ON public.user_usage_stats(year, month);

-- =============================================
-- 3. 启用行级安全策略 (RLS)
-- =============================================
ALTER TABLE public.user_usage_stats ENABLE ROW LEVEL SECURITY;

-- 用户只能查看自己的使用统计
CREATE POLICY "用户只能查看自己的使用统计" ON public.user_usage_stats
    FOR SELECT USING (auth.uid() = user_id);

-- 允许服务角色完全访问
CREATE POLICY "服务角色可以管理所有使用统计" ON public.user_usage_stats
    FOR ALL USING (auth.role() = 'service_role');

-- 允许认证用户插入和更新自己的统计（通过Edge Function）
CREATE POLICY "认证用户可以更新自己的使用统计" ON public.user_usage_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "认证用户可以修改自己的使用统计" ON public.user_usage_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================
-- 4. 创建触发器自动更新时间戳
-- =============================================
CREATE TRIGGER update_user_usage_stats_updated_at 
    BEFORE UPDATE ON public.user_usage_stats 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 5. 创建辅助函数：获取或创建当前月份的使用统计
-- =============================================
CREATE OR REPLACE FUNCTION get_or_create_current_month_usage(p_user_id UUID)
RETURNS public.user_usage_stats AS $$
DECLARE
    v_year INTEGER;
    v_month INTEGER;
    v_usage_stats public.user_usage_stats;
BEGIN
    -- 获取当前年月
    v_year := EXTRACT(YEAR FROM NOW());
    v_month := EXTRACT(MONTH FROM NOW());
    
    -- 尝试获取现有记录
    SELECT * INTO v_usage_stats
    FROM public.user_usage_stats
    WHERE user_id = p_user_id
      AND year = v_year
      AND month = v_month;
    
    -- 如果不存在，创建新记录
    IF NOT FOUND THEN
        INSERT INTO public.user_usage_stats (user_id, year, month)
        VALUES (p_user_id, v_year, v_month)
        RETURNING * INTO v_usage_stats;
    END IF;
    
    RETURN v_usage_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 允许认证用户调用此函数
GRANT EXECUTE ON FUNCTION get_or_create_current_month_usage(UUID) TO authenticated;

-- =============================================
-- 6. 创建辅助函数：增加远程模型使用次数
-- =============================================
CREATE OR REPLACE FUNCTION increment_remote_usage(p_user_id UUID)
RETURNS public.user_usage_stats AS $$
DECLARE
    v_year INTEGER;
    v_month INTEGER;
    v_usage_stats public.user_usage_stats;
BEGIN
    -- 获取当前年月
    v_year := EXTRACT(YEAR FROM NOW());
    v_month := EXTRACT(MONTH FROM NOW());
    
    -- 插入或更新使用统计
    INSERT INTO public.user_usage_stats (user_id, year, month, remote_questions_count)
    VALUES (p_user_id, v_year, v_month, 1)
    ON CONFLICT (user_id, year, month)
    DO UPDATE SET
        remote_questions_count = public.user_usage_stats.remote_questions_count + 1,
        updated_at = NOW()
    RETURNING * INTO v_usage_stats;
    
    RETURN v_usage_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 允许认证用户调用此函数
GRANT EXECUTE ON FUNCTION increment_remote_usage(UUID) TO authenticated;

-- =============================================
-- 7. 创建辅助函数：检查用户是否超过月度限额
-- =============================================
CREATE OR REPLACE FUNCTION check_monthly_usage_limit(
    p_user_id UUID,
    p_monthly_limit INTEGER DEFAULT 3000
)
RETURNS JSON AS $$
DECLARE
    v_year INTEGER;
    v_month INTEGER;
    v_current_usage INTEGER;
    v_is_pro BOOLEAN;
BEGIN
    -- 获取当前年月
    v_year := EXTRACT(YEAR FROM NOW());
    v_month := EXTRACT(MONTH FROM NOW());
    
    -- 检查用户是否为Pro会员
    SELECT subscription_status = 'pro_active' INTO v_is_pro
    FROM public.users
    WHERE id = p_user_id;
    
    -- 如果不是Pro会员，返回无限制（免费用户通过日限制控制）
    IF NOT v_is_pro THEN
        RETURN json_build_object(
            'allowed', true,
            'is_pro', false,
            'current_usage', 0,
            'limit', 0,
            'remaining', 0
        );
    END IF;
    
    -- 获取当前使用次数
    SELECT COALESCE(remote_questions_count, 0) INTO v_current_usage
    FROM public.user_usage_stats
    WHERE user_id = p_user_id
      AND year = v_year
      AND month = v_month;
    
    -- 如果没有记录，使用次数为0
    IF v_current_usage IS NULL THEN
        v_current_usage := 0;
    END IF;
    
    -- 返回检查结果
    RETURN json_build_object(
        'allowed', v_current_usage < p_monthly_limit,
        'is_pro', true,
        'current_usage', v_current_usage,
        'limit', p_monthly_limit,
        'remaining', GREATEST(0, p_monthly_limit - v_current_usage)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 允许认证用户调用此函数
GRANT EXECUTE ON FUNCTION check_monthly_usage_limit(UUID, INTEGER) TO authenticated;

-- 完成提示
SELECT '✅ 用户使用统计表和辅助函数创建完成！' as message;


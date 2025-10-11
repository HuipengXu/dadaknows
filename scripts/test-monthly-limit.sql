-- 测试Pro用户月度限制功能的SQL脚本
-- 作者: AI Assistant
-- 日期: 2025-01-27
-- 用途: 在开发和测试环境中验证月度限制功能

-- =============================================
-- 1. 查看当前用户的使用情况
-- =============================================
-- 使用方法: 替换 'your-user-id' 为实际的用户ID

-- 查看单个用户的使用统计
SELECT 
    u.id,
    u.nickname,
    u.subscription_status,
    uus.year,
    uus.month,
    uus.remote_questions_count,
    uus.local_questions_count,
    uus.created_at,
    uus.updated_at
FROM public.users u
LEFT JOIN public.user_usage_stats uus ON u.id = uus.user_id
WHERE u.id = 'your-user-id'  -- 替换为实际用户ID
ORDER BY uus.year DESC, uus.month DESC;

-- =============================================
-- 2. 测试数据库函数
-- =============================================

-- 测试检查配额（替换user-id）
SELECT check_monthly_usage_limit('your-user-id', 3000);

-- 测试增加使用次数（替换user-id）
SELECT increment_remote_usage('your-user-id');

-- 测试获取或创建当月统计（替换user-id）
SELECT * FROM get_or_create_current_month_usage('your-user-id');

-- =============================================
-- 3. 模拟测试场景
-- =============================================

-- 场景1: 设置用户接近限制（2900次）
UPDATE public.user_usage_stats
SET remote_questions_count = 2900
WHERE user_id = 'your-user-id'  -- 替换为实际用户ID
  AND year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());

-- 场景2: 设置用户刚好到达限制（3000次）
UPDATE public.user_usage_stats
SET remote_questions_count = 3000
WHERE user_id = 'your-user-id'  -- 替换为实际用户ID
  AND year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());

-- 场景3: 设置用户超过限制（3100次）- 用于测试错误处理
UPDATE public.user_usage_stats
SET remote_questions_count = 3100
WHERE user_id = 'your-user-id'  -- 替换为实际用户ID
  AND year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());

-- 场景4: 重置用户使用次数
UPDATE public.user_usage_stats
SET remote_questions_count = 0
WHERE user_id = 'your-user-id'  -- 替换为实际用户ID
  AND year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());

-- =============================================
-- 4. 查看所有Pro用户的使用情况
-- =============================================

-- 当月所有Pro用户使用统计
SELECT 
    u.id,
    u.nickname,
    u.subscription_status,
    COALESCE(uus.remote_questions_count, 0) as remote_count,
    COALESCE(uus.local_questions_count, 0) as local_count,
    3000 - COALESCE(uus.remote_questions_count, 0) as remaining
FROM public.users u
LEFT JOIN public.user_usage_stats uus ON u.id = uus.user_id
    AND uus.year = EXTRACT(YEAR FROM NOW())
    AND uus.month = EXTRACT(MONTH FROM NOW())
WHERE u.subscription_status = 'pro_active'
ORDER BY uus.remote_questions_count DESC NULLS LAST;

-- =============================================
-- 5. 统计分析
-- =============================================

-- 统计1: 达到限制的用户数
SELECT 
    COUNT(*) as users_at_limit,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public.users WHERE subscription_status = 'pro_active') as percentage
FROM public.user_usage_stats
WHERE year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW())
  AND remote_questions_count >= 3000;

-- 统计2: 使用情况分布
SELECT 
    CASE 
        WHEN remote_questions_count = 0 THEN '未使用'
        WHEN remote_questions_count < 1000 THEN '轻度使用 (< 1000)'
        WHEN remote_questions_count < 2000 THEN '中度使用 (1000-2000)'
        WHEN remote_questions_count < 3000 THEN '重度使用 (2000-3000)'
        ELSE '已达限制 (≥ 3000)'
    END as usage_category,
    COUNT(*) as user_count,
    AVG(remote_questions_count) as avg_usage
FROM public.user_usage_stats
WHERE year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW())
GROUP BY usage_category
ORDER BY MIN(remote_questions_count);

-- 统计3: 平均使用量
SELECT 
    AVG(remote_questions_count) as avg_usage,
    MIN(remote_questions_count) as min_usage,
    MAX(remote_questions_count) as max_usage,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY remote_questions_count) as median_usage,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY remote_questions_count) as p95_usage
FROM public.user_usage_stats
WHERE year = EXTRACT(YEAR FROM NOW())
  AND month = EXTRACT(MONTH FROM NOW());

-- =============================================
-- 6. 历史数据查看
-- =============================================

-- 查看用户的历史使用趋势（过去6个月）
SELECT 
    year,
    month,
    remote_questions_count,
    local_questions_count,
    created_at
FROM public.user_usage_stats
WHERE user_id = 'your-user-id'  -- 替换为实际用户ID
ORDER BY year DESC, month DESC
LIMIT 6;

-- 查看所有用户的月度趋势
SELECT 
    year,
    month,
    COUNT(*) as active_users,
    SUM(remote_questions_count) as total_remote_usage,
    AVG(remote_questions_count) as avg_remote_usage,
    SUM(local_questions_count) as total_local_usage,
    AVG(local_questions_count) as avg_local_usage
FROM public.user_usage_stats
GROUP BY year, month
ORDER BY year DESC, month DESC
LIMIT 12;

-- =============================================
-- 7. 数据清理（谨慎使用）
-- =============================================

-- 清理测试数据（仅在开发环境使用！）
-- 警告: 这将删除所有使用统计数据
-- DELETE FROM public.user_usage_stats WHERE user_id = 'your-user-id';

-- 清理超过12个月的旧数据（生产环境定期维护）
-- DELETE FROM public.user_usage_stats 
-- WHERE (year * 12 + month) < (EXTRACT(YEAR FROM NOW()) * 12 + EXTRACT(MONTH FROM NOW()) - 12);

-- =============================================
-- 8. 验证完整性
-- =============================================

-- 检查是否有重复的月度记录（不应该有）
SELECT user_id, year, month, COUNT(*)
FROM public.user_usage_stats
GROUP BY user_id, year, month
HAVING COUNT(*) > 1;

-- 检查是否有异常的使用次数（负数或超大值）
SELECT *
FROM public.user_usage_stats
WHERE remote_questions_count < 0 
   OR remote_questions_count > 10000
   OR local_questions_count < 0
   OR local_questions_count > 100000;

-- =============================================
-- 9. 性能测试
-- =============================================

-- 测试函数性能（执行100次检查配额）
DO $$
DECLARE
    i INTEGER;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration INTERVAL;
BEGIN
    start_time := clock_timestamp();
    
    FOR i IN 1..100 LOOP
        PERFORM check_monthly_usage_limit('your-user-id', 3000);
    END LOOP;
    
    end_time := clock_timestamp();
    duration := end_time - start_time;
    
    RAISE NOTICE '执行100次检查配额耗时: %', duration;
    RAISE NOTICE '平均每次耗时: %', duration / 100;
END $$;

-- =============================================
-- 10. 快速参考
-- =============================================

-- 快速查看某用户是否可以提问
SELECT 
    CASE 
        WHEN subscription_status = 'pro_active' THEN
            CASE 
                WHEN COALESCE(remote_questions_count, 0) < 3000 THEN '✅ 可以提问'
                ELSE '❌ 已达限制'
            END
        ELSE '✅ 免费用户不受月度限制'
    END as status,
    COALESCE(remote_questions_count, 0) as current_usage,
    3000 - COALESCE(remote_questions_count, 0) as remaining
FROM public.users u
LEFT JOIN public.user_usage_stats uus ON u.id = uus.user_id
    AND uus.year = EXTRACT(YEAR FROM NOW())
    AND uus.month = EXTRACT(MONTH FROM NOW())
WHERE u.id = 'your-user-id';  -- 替换为实际用户ID

-- =============================================
-- 使用说明
-- =============================================
-- 1. 将所有 'your-user-id' 替换为实际的用户UUID
-- 2. 在Supabase Dashboard的SQL编辑器中执行相应的查询
-- 3. 测试完成后记得重置测试数据
-- 4. 生产环境请谨慎使用UPDATE和DELETE语句


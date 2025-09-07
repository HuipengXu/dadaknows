#!/bin/bash

# DadaKnows 数据库部署脚本
# 用于在Supabase云端创建核心数据库表

set -e  # 遇到错误立即退出

echo "🚀 开始部署DadaKnows数据库表..."

# 检查是否安装了supabase CLI
if ! command -v supabase &> /dev/null; then
    echo "❌ 错误: 未找到supabase CLI"
    echo "请先安装: npm install -g supabase"
    echo "或者: brew install supabase/tap/supabase"
    exit 1
fi

# 检查是否在正确的目录
if [ ! -f "supabase/config.toml" ]; then
    echo "❌ 错误: 请在项目根目录运行此脚本"
    exit 1
fi

# 检查迁移文件是否存在
MIGRATION_FILE="supabase/migrations/001_create_core_tables.sql"
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ 错误: 迁移文件不存在: $MIGRATION_FILE"
    exit 1
fi

echo "📋 检查Supabase项目状态..."

# 检查是否已登录
if ! supabase projects list &> /dev/null; then
    echo "🔐 请先登录Supabase:"
    supabase login
fi

echo "🔗 链接到远程Supabase项目..."

# 链接到远程项目 (使用config.toml中的project_id)
PROJECT_ID=$(grep 'project_id' supabase/config.toml | cut -d'"' -f2)

if [ -z "$PROJECT_ID" ]; then
    echo "❌ 错误: 无法从config.toml获取project_id"
    echo "请检查supabase/config.toml文件"
    exit 1
fi

echo "📡 项目ID: $PROJECT_ID"

# 链接项目
supabase link --project-ref $PROJECT_ID

echo "📊 运行数据库迁移..."

# 推送迁移到远程数据库
supabase db push

echo "✅ 数据库表创建完成！"

echo ""
echo "🎉 部署成功！已创建以下表："
echo "  ✅ users - 用户配置文件"
echo "  ✅ chats - 聊天记录"  
echo "  ✅ prompts - 提示词管理"
echo ""
echo "🔒 安全策略已启用："
echo "  ✅ 行级安全 (RLS)"
echo "  ✅ 用户数据隔离"
echo "  ✅ 提示词访问控制"
echo ""
echo "⚡ 性能优化已完成："
echo "  ✅ 查询索引"
echo "  ✅ 自动时间戳更新"
echo ""
echo "🔧 下一步："
echo "  1. 在Supabase Dashboard验证表结构"
echo "  2. 更新iOS应用代码以使用新表"
echo "  3. 实现数据同步功能"
echo ""
echo "📱 Supabase Dashboard: https://supabase.com/dashboard/project/$PROJECT_ID"

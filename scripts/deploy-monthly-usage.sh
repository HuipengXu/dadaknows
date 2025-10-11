#!/bin/bash

# 🚀 部署月度使用限制功能
# 部署新的Edge Functions和数据库迁移

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_REF="fwvyrcekbngcpiudljpj"
PROJECT_NAME="DadaKnows"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 标题
echo -e "${BLUE}"
echo "=============================================="
echo "🚀 DadaKnows 月度使用限制功能部署"
echo "=============================================="
echo -e "${NC}"

# 1. 检查项目目录
log_info "检查项目结构..."
if [ ! -d "supabase" ]; then
    log_error "找不到 supabase 目录，请确保在项目根目录运行此脚本"
    exit 1
fi

if [ ! -d "supabase/functions" ]; then
    log_error "找不到 supabase/functions 目录"
    exit 1
fi

log_success "项目结构检查通过"

# 2. 检查 Supabase CLI
log_info "检查 Supabase CLI..."
if ! command -v supabase &> /dev/null; then
    log_error "未找到 Supabase CLI，请先安装: brew install supabase/tap/supabase"
    exit 1
fi

SUPABASE_VERSION=$(supabase --version)
log_info "Supabase CLI 版本: $SUPABASE_VERSION"

# 3. 检查登录状态
log_info "检查 Supabase 登录状态..."
if ! supabase projects list &> /dev/null; then
    log_warning "未登录 Supabase，正在登录..."
    echo ""
    echo "请在浏览器中完成登录，然后返回终端继续..."
    supabase login
    log_success "Supabase 登录成功"
else
    log_info "已登录 Supabase"
fi

# 4. 验证新函数存在
log_info "验证新函数文件..."
NEW_FUNCTIONS=("check-usage" "increment-usage")
UPDATED_FUNCTIONS=("ask-dada")

for func in "${NEW_FUNCTIONS[@]}"; do
    if [ ! -d "supabase/functions/$func" ]; then
        log_error "找不到函数目录: supabase/functions/$func"
        exit 1
    fi
    if [ ! -f "supabase/functions/$func/index.ts" ]; then
        log_error "找不到函数文件: supabase/functions/$func/index.ts"
        exit 1
    fi
    log_info "✅ 函数 $func 文件存在"
done

log_success "函数文件验证通过"

# 5. 部署新的 Edge Functions
echo ""
log_info "开始部署 Edge Functions..."

# 部署新函数
for func in "${NEW_FUNCTIONS[@]}"; do
    echo ""
    log_info "部署新函数: $func"
    
    # 显示部署进度
    echo -n "部署中"
    for i in {1..3}; do
        echo -n "."
        sleep 0.5
    done
    echo ""
    
    # 执行部署（不验证JWT，因为是新函数）
    if supabase functions deploy $func --project-ref $PROJECT_REF --no-verify-jwt; then
        log_success "✅ 函数 $func 部署成功"
    else
        log_error "❌ 函数 $func 部署失败"
        log_warning "请检查网络连接或手动在 Dashboard 部署"
        exit 1
    fi
done

# 更新现有函数
for func in "${UPDATED_FUNCTIONS[@]}"; do
    echo ""
    log_info "更新现有函数: $func"
    
    # 显示部署进度
    echo -n "更新中"
    for i in {1..3}; do
        echo -n "."
        sleep 0.5
    done
    echo ""
    
    # 执行部署
    if supabase functions deploy $func --project-ref $PROJECT_REF --no-verify-jwt; then
        log_success "✅ 函数 $func 更新成功"
    else
        log_error "❌ 函数 $func 更新失败"
        log_warning "请检查网络连接或手动在 Dashboard 更新"
        exit 1
    fi
done

# 6. 验证部署
echo ""
log_info "验证部署结果..."

# 获取函数列表
log_info "获取已部署的函数列表..."
if supabase functions list --project-ref $PROJECT_REF 2>/dev/null; then
    log_success "函数列表获取成功"
else
    log_warning "无法获取函数列表，但部署可能已成功"
fi

# 7. 测试函数可访问性
echo ""
log_info "测试函数可访问性..."

BASE_URL="https://$PROJECT_REF.supabase.co/functions/v1"

for func in "${NEW_FUNCTIONS[@]}"; do
    FUNCTION_URL="$BASE_URL/$func"
    log_info "测试: $FUNCTION_URL"
    
    if curl -s -X OPTIONS "$FUNCTION_URL" -o /dev/null -w "%{http_code}" | grep -q "200\|204"; then
        log_success "✅ 函数 $func 响应正常"
    else
        log_warning "⚠️ 函数 $func 可能需要时间初始化"
    fi
done

# 8. 数据库迁移说明
echo ""
echo -e "${YELLOW}"
echo "=============================================="
echo "⚠️  重要：数据库迁移"
echo "=============================================="
echo -e "${NC}"
echo ""
log_warning "Edge Functions 已部署，但数据库迁移需要手动执行："
echo ""
echo "方法1: 使用 Supabase Dashboard (推荐)"
echo "  1. 访问: https://supabase.com/dashboard/project/$PROJECT_REF/sql"
echo "  2. 打开文件: supabase/migrations/004_add_usage_tracking.sql"
echo "  3. 复制全部内容到 SQL Editor"
echo "  4. 点击 Run 执行"
echo ""
echo "方法2: 使用 SQL 文件"
echo "  cat supabase/migrations/004_add_usage_tracking.sql"
echo ""

# 9. 生成测试脚本
echo ""
log_info "生成测试脚本..."
cat > scripts/test-monthly-usage.sh << 'TESTEOF'
#!/bin/bash

# 测试月度使用限制功能

PROJECT_REF="fwvyrcekbngcpiudljpj"
BASE_URL="https://$PROJECT_REF.supabase.co/functions/v1"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MzQ4ODYsImV4cCI6MjA3MjMxMDg4Nn0.c62pXLg1sU8ZAz2bETNdtIKqBXnwGMzhj6M7cMIeUCg"

echo "🧪 测试月度使用限制功能"
echo "=================================="
echo ""

# 测试 check-usage
echo "1️⃣ 测试 check-usage 函数..."
echo "URL: $BASE_URL/check-usage"
echo ""

RESPONSE=$(curl -s -X POST "$BASE_URL/check-usage" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{"userId": "test-user-123"}')

echo "响应: $RESPONSE"
echo ""

# 测试 increment-usage
echo "2️⃣ 测试 increment-usage 函数..."
echo "URL: $BASE_URL/increment-usage"
echo ""

RESPONSE=$(curl -s -X POST "$BASE_URL/increment-usage" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{"userId": "test-user-123"}')

echo "响应: $RESPONSE"
echo ""

# 测试 ask-dada（带userId）
echo "3️⃣ 测试更新后的 ask-dada 函数..."
echo "URL: $BASE_URL/ask-dada"
echo ""

curl -X POST "$BASE_URL/ask-dada" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{
    "question": "测试问题",
    "age": 5,
    "language": "zh-CN",
    "apiKey": "AIzaSyD-YSyKmhc4d23ybooPBbJJaskhZshOV20",
    "userId": "test-user-123"
  }'

echo ""
echo ""
echo "=================================="
echo "✅ 测试完成！"
TESTEOF

chmod +x scripts/test-monthly-usage.sh
log_success "测试脚本生成完成: scripts/test-monthly-usage.sh"

# 10. 完成
echo ""
echo -e "${GREEN}"
echo "=============================================="
echo "🎉 Edge Functions 部署完成！"
echo "=============================================="
echo -e "${NC}"
echo ""
echo "✅ 已部署的函数:"
echo "   • check-usage (新)"
echo "   • increment-usage (新)"
echo "   • ask-dada (已更新)"
echo ""
echo "🔗 函数 URLs:"
echo "   • check-usage: https://$PROJECT_REF.supabase.co/functions/v1/check-usage"
echo "   • increment-usage: https://$PROJECT_REF.supabase.co/functions/v1/increment-usage"
echo "   • ask-dada: https://$PROJECT_REF.supabase.co/functions/v1/ask-dada"
echo ""
echo "📋 下一步操作:"
echo "   1. ⚠️  执行数据库迁移（见上方说明）"
echo "   2. 运行测试: ./scripts/test-monthly-usage.sh"
echo "   3. 在 iOS App 中测试完整功能"
echo ""
echo "📚 相关文档:"
echo "   • docs/monthly_usage_quick_deploy.md"
echo "   • docs/monthly_usage_manual_deployment.md"
echo "   • docs/monthly_usage_limit_implementation.md"
echo ""

log_success "部署脚本执行完成！"


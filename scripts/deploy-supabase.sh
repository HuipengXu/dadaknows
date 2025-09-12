#!/bin/bash

# 🚀 DadaKnows Supabase自动化部署脚本
# 自动部署Edge Functions和配置Supabase项目

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
echo "=================================="
echo "🚀 DadaKnows Supabase 部署脚本"
echo "=================================="
echo -e "${NC}"

# 1. 检查操作系统
log_info "检查操作系统..."
OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    log_info "检测到 macOS 系统"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"  
    log_info "检测到 Linux 系统"
else
    log_error "不支持的操作系统: $OSTYPE"
    exit 1
fi

# 2. 检查并安装 Homebrew (macOS only)
if [[ "$OS" == "macos" ]]; then
    if ! command -v brew &> /dev/null; then
        log_warning "未找到 Homebrew，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew 安装完成"
    else
        log_info "Homebrew 已安装"
    fi
fi

# 3. 检查并安装 Node.js 和 npm
log_info "检查 Node.js..."
if ! command -v node &> /dev/null; then
    log_warning "未找到 Node.js，正在安装..."
    if [[ "$OS" == "macos" ]]; then
        brew install node
    elif [[ "$OS" == "linux" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    log_success "Node.js 安装完成"
else
    NODE_VERSION=$(node --version)
    log_info "Node.js 已安装: $NODE_VERSION"
fi

# 4. 检查并安装 Supabase CLI
log_info "检查 Supabase CLI..."
if ! command -v supabase &> /dev/null; then
    log_warning "未找到 Supabase CLI，正在安装..."
    if [[ "$OS" == "macos" ]]; then
        brew install supabase/tap/supabase
    elif [[ "$OS" == "linux" ]]; then
        npm install -g supabase
    fi
    log_success "Supabase CLI 安装完成"
else
    SUPABASE_VERSION=$(supabase --version)
    log_info "Supabase CLI 已安装: $SUPABASE_VERSION"
fi

# 5. 检查登录状态
log_info "检查 Supabase 登录状态..."
if ! supabase projects list &> /dev/null; then
    log_warning "未登录 Supabase，请登录..."
    echo ""
    echo "请在浏览器中完成登录，然后返回终端继续..."
    supabase login
    log_success "Supabase 登录成功"
else
    log_info "已登录 Supabase"
fi

# 6. 检查项目目录
if [ ! -d "supabase" ]; then
    log_error "找不到 supabase 目录，请确保在项目根目录运行此脚本"
    exit 1
fi

# # 7. 链接项目
# log_info "链接 Supabase 项目..."
# cd supabase
# if supabase status &> /dev/null; then
#     log_info "项目已链接"
# else
#     log_info "正在链接项目: $PROJECT_REF"
#     supabase link --project-ref $PROJECT_REF
#     log_success "项目链接成功"
# fi

# 8. 验证Edge Functions结构
log_info "验证 Edge Functions 结构..."
FUNCTIONS_DIR="functions"
REQUIRED_FUNCTIONS=("ask-dada")
REQUIRED_SHARED_FILES=("_shared/cors.ts" "_shared/gemini.ts" "_shared/prompts.ts")

# 检查functions目录
if [ ! -d "$FUNCTIONS_DIR" ]; then
    log_error "找不到 functions 目录"
    exit 1
fi

# 检查必需的函数
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if [ ! -d "$FUNCTIONS_DIR/$func" ]; then
        log_error "找不到函数目录: $func"
        exit 1
    fi
    if [ ! -f "$FUNCTIONS_DIR/$func/index.ts" ]; then
        log_error "找不到函数入口文件: $func/index.ts"
        exit 1
    fi
    log_info "✅ 函数 $func 结构正确"
done

# 检查共享文件
for file in "${REQUIRED_SHARED_FILES[@]}"; do
    if [ ! -f "$FUNCTIONS_DIR/$file" ]; then
        log_error "找不到共享文件: $file"
        exit 1
    fi
    log_info "✅ 共享文件 $file 存在"
done

log_success "Edge Functions 结构验证通过"

# 9. 部署 Edge Functions
echo ""
log_info "开始部署 Edge Functions..."

for func in "${REQUIRED_FUNCTIONS[@]}"; do
    echo ""
    log_info "部署函数: $func"
    
    # 显示部署进度
    echo -n "部署中"
    for i in {1..3}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    # 执行部署
    if supabase functions deploy $func --no-verify-jwt; then
        log_success "✅ 函数 $func 部署成功"
    else
        log_error "❌ 函数 $func 部署失败"
        exit 1
    fi
done

# 10. 验证部署
echo ""
log_info "验证部署结果..."

# 获取函数列表
log_info "获取已部署的函数列表..."
if supabase functions list; then
    log_success "函数列表获取成功"
else
    log_warning "无法获取函数列表，但这不影响部署"
fi

# 11. 测试函数可访问性
echo ""
log_info "测试函数可访问性..."

FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/ask-dada"
log_info "函数URL: $FUNCTION_URL"

# 简单的健康检查
echo ""
log_info "执行健康检查..."
if curl -s -X OPTIONS "$FUNCTION_URL" > /dev/null; then
    log_success "✅ 函数响应正常"
else
    log_warning "⚠️ 函数可能需要时间来初始化，请稍后测试"
fi

# 12. 生成测试脚本
echo ""
log_info "生成测试脚本..."
cat > ../test-ask-dada.sh << 'EOF'
#!/bin/bash

# DadaKnows Edge Function 测试脚本
PROJECT_REF="fwvyrcekbngcpiudljpj"
FUNCTION_URL="https://$PROJECT_REF.supabase.co/functions/v1/ask-dada"
API_KEY="AIzaSyD-YSyKmhc4d23ybooPBbJJaskhZshOV20"

echo "🧪 测试 ask-dada 函数..."
echo "URL: $FUNCTION_URL"
echo ""

# 测试请求
curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3dnlyY2VrYm5nY3BpdWRsanBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MzQ4ODYsImV4cCI6MjA3MjMxMDg4Nn0.c62pXLg1sU8ZAz2bETNdtIKqBXnwGMzhj6M7cMIeUCg" \
  -d '{
    "question": "为什么天空是蓝色的？",
    "age": 5,
    "language": "zh-CN",
    "apiKey": "'$API_KEY'"
  }'

echo ""
echo ""
echo "测试完成！如果看到流式响应，说明部署成功 ✅"
EOF

chmod +x ../test-ask-dada.sh
log_success "测试脚本生成完成: test-ask-dada.sh"

# 13. 完成部署
echo ""
echo -e "${GREEN}"
echo "🎉 部署完成！"
echo "=================================="
echo ""
echo "✅ 已部署的Edge Functions:"
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    echo "   • $func"
done
echo ""
echo "🔗 函数URLs:"
echo "   • ask-dada: https://$PROJECT_REF.supabase.co/functions/v1/ask-dada"
echo ""
echo "🧪 测试命令:"
echo "   ./test-ask-dada.sh"
echo ""
echo "📱 iOS应用现在可以连接到真实的AI服务了！"
echo ""
echo "📋 后续步骤:"
echo "   1. 运行测试脚本验证函数工作正常"
echo "   2. 在iOS应用中测试完整功能"
echo "   3. 根据需要调整Prompt模板"
echo -e "${NC}"

# 返回原目录
cd ..

log_success "部署脚本执行完成！"

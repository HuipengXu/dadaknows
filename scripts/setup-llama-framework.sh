#!/bin/bash

# setup-llama-framework.sh
# 设置llama.cpp XCFramework集成的脚本

set -e

echo "🦙 Setting up llama.cpp XCFramework integration..."

# 检查必要的工具
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed"
    exit 1
fi

# 定义版本和URL
LLAMA_VERSION="b6548"
FRAMEWORK_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-xcframework.zip"
TEMP_DIR="$(mktemp -d)"
FRAMEWORK_ZIP="${TEMP_DIR}/llama-framework.zip"

echo "📥 Downloading llama.cpp XCFramework..."
echo "URL: ${FRAMEWORK_URL}"

# 下载XCFramework
curl -L -o "${FRAMEWORK_ZIP}" "${FRAMEWORK_URL}"

if [ ! -f "${FRAMEWORK_ZIP}" ]; then
    echo "❌ Error: Failed to download XCFramework"
    exit 1
fi

echo "🔍 Calculating checksum..."
# 计算校验和
CHECKSUM=$(swift package compute-checksum "${FRAMEWORK_ZIP}")
echo "✅ Checksum: ${CHECKSUM}"

# 显示集成信息（不再创建Package.swift）
echo "📝 XCFramework information for Xcode integration:"

# 清理临时文件
rm -rf "${TEMP_DIR}"

echo ""
echo "🎉 llama.cpp XCFramework information ready!"
echo ""
echo "✅ MyLlamaPackage 本地包已准备完毕！"
echo ""
echo "📋 集成步骤（3步完成）："
echo "1. 打开 Xcode 项目：DadaKnows/DadaKnows.xcodeproj"
echo "2. 拖拽 MyLlamaPackage 文件夹到 Xcode 项目导航器中"
echo "3. 在 Target → General → Frameworks 中添加 LlamaFramework"
echo ""
echo "📦 Framework Details:"
echo "  Version: ${LLAMA_VERSION}"
echo "  Checksum: ${CHECKSUM}"
echo "  URL: ${FRAMEWORK_URL}"
echo ""
echo "📂 项目结构："
echo "  /Users/xuhuipeng/Code/dada-knows/"
echo "  ├── DadaKnows/           # 主App项目"
echo "  └── MyLlamaPackage/      # 独立本地包"
echo ""
echo "📖 详细文档: LLAMA_CORRECT_INTEGRATION.md"

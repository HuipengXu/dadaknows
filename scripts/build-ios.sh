#!/bin/bash

# iOS构建验证脚本
# 用于在每次修改iOS代码后验证构建是否成功

set -e

echo "🚀 开始iOS构建验证..."

# 进入iOS项目目录
cd "$(dirname "$0")/DadaKnows"

# 清理构建缓存（可选，如果构建失败时使用）
if [ "$1" = "clean" ]; then
    echo "🧹 清理构建缓存..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/DadaKnows-*
    rm -rf .build
    rm -rf DadaKnows.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
fi

# 检查可用的模拟器
echo "📱 检查可用的iOS模拟器..."
SIMULATOR=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed 's/.*(\([A-Z0-9-]*\)).*/\1/')

if [ -z "$SIMULATOR" ]; then
    echo "⚠️  未找到iPhone 16模拟器，使用通用iOS模拟器..."
    DESTINATION="platform=iOS Simulator,name=Any iOS Simulator Device"
else
    echo "📱 使用模拟器: $SIMULATOR"
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR"
fi

# 执行构建
echo "🔨 开始构建..."
xcodebuild -project DadaKnows.xcodeproj \
           -scheme DadaKnows \
           -destination "$DESTINATION" \
           clean build

if [ $? -eq 0 ]; then
    echo "✅ iOS构建成功！"
    echo "📝 构建完成时间: $(date)"
else
    echo "❌ iOS构建失败！"
    exit 1
fi

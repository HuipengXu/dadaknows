#!/bin/bash

# iOS模拟器清理脚本
# 用于清理模拟器缓存和重置状态，解决一些系统级错误

set -e

echo "🧹 开始清理iOS模拟器..."

# 关闭所有模拟器
echo "📱 关闭所有模拟器..."
xcrun simctl shutdown all

# 清理设备数据
echo "🗑️  清理设备数据..."
xcrun simctl erase all

# 清理Xcode缓存
echo "🧹 清理Xcode缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 清理模拟器缓存
echo "📱 清理模拟器缓存..."
rm -rf ~/Library/Developer/CoreSimulator/Caches
rm -rf ~/Library/Caches/com.apple.CoreSimulator.*

# 重置键盘设置（有助于解决键盘约束问题）
echo "⌨️  重置键盘设置..."
defaults delete com.apple.iphonesimulator KeyboardLastUsed 2>/dev/null || true

echo "✅ 模拟器清理完成！"
echo "💡 提示: 现在重新运行您的应用，应该会减少约束错误和系统级警告"

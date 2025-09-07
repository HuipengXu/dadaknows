# iOS构建验证指南

## 概述

本指南说明如何在每次修改iOS代码后进行构建验证，确保代码变更不会破坏项目的构建。

## 构建脚本

项目根目录下的 `build-ios.sh` 脚本提供了自动化的构建验证功能。

### 使用方法

#### 基本构建验证
```bash
./build-ios.sh
```

#### 清理缓存后构建（当遇到构建问题时）
```bash
./build-ios.sh clean
```

### 脚本功能

1. **自动检测模拟器**: 优先使用iPhone 16模拟器，如果不可用则使用通用iOS模拟器
2. **清理选项**: 支持清理Xcode派生数据和Swift Package Manager缓存
3. **构建验证**: 执行完整的clean build过程
4. **状态报告**: 显示构建结果和完成时间

### 输出说明

- ✅ **构建成功**: 代码变更没有破坏构建
- ❌ **构建失败**: 需要检查并修复构建错误

## 构建问题排查

### 常见问题及解决方案

1. **重复GUID引用错误**
   ```bash
   ./build-ios.sh clean
   ```

2. **Swift Package依赖问题**
   - 删除 `DerivedData` 目录
   - 重新解析包依赖

3. **模拟器不可用**
   - 脚本会自动回退到通用模拟器
   - 检查Xcode模拟器设置

### 手动清理步骤

如果自动清理不够，可以手动执行：

```bash
# 清理Xcode派生数据
rm -rf ~/Library/Developer/Xcode/DerivedData/DadaKnows-*

# 清理Swift Package缓存
cd DadaKnows
rm -rf .build
rm -rf DadaKnows.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
```

## 最佳实践

1. **每次代码变更后运行构建验证**
2. **提交代码前确保构建成功**
3. **遇到构建问题时先尝试清理缓存**
4. **定期更新依赖包版本**

## 构建环境要求

- Xcode 16.4+
- iOS 17.0+ 部署目标
- 可用的iOS模拟器

## 故障排除

如果构建脚本本身有问题，可以直接使用xcodebuild命令：

```bash
cd DadaKnows
xcodebuild -project DadaKnows.xcodeproj \
           -scheme DadaKnows \
           -destination 'platform=iOS Simulator,name=Any iOS Simulator Device' \
           clean build
```

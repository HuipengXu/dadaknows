# DadaKnows 脚本工具集

## 📁 脚本概览

本文件夹包含DadaKnows项目开发和部署所需的所有Shell脚本工具。

## 🛠️ 开发脚本

### `build-ios.sh`
**功能**: iOS应用构建验证
**用途**: 验证iOS代码修改后的构建状态
**使用方法**:
```bash
# 普通构建验证
./scripts/build-ios.sh

# 清理后重新构建
./scripts/build-ios.sh clean
```

### `clean-simulator.sh`
**功能**: iOS模拟器清理
**用途**: 清理模拟器缓存，解决系统级错误
**使用方法**:
```bash
./scripts/clean-simulator.sh
```
**适用场景**:
- 键盘约束冲突错误
- 模拟器卡顿或异常
- eligibility.plist系统错误

## 🚀 部署脚本

### `deploy-supabase.sh`
**功能**: Supabase完整部署
**用途**: 一键部署Edge Functions和配置Supabase项目
**使用方法**:
```bash
./scripts/deploy-supabase.sh
```
**包含功能**:
- 自动安装依赖 (Node.js, Supabase CLI)
- 部署ask-dada Edge Function
- 验证部署结果
- 生成测试脚本

## 🧪 测试脚本

### `test-ask-dada.sh`
**功能**: Edge Function测试
**用途**: 测试ask-dada函数是否正常工作
**使用方法**:
```bash
./scripts/test-ask-dada.sh
```
**测试内容**:
- API端点可访问性
- 流式响应功能
- 中文AI回答

## 📋 使用流程

### 开发阶段
1. 修改iOS代码后 → 运行 `build-ios.sh` 验证构建
2. 遇到模拟器问题 → 运行 `clean-simulator.sh` 清理
3. 代码提交前 → 再次运行 `build-ios.sh` 确保稳定

### 部署阶段
1. 初次部署 → 运行 `deploy-supabase.sh` 完整部署
2. 部署验证 → 运行 `test-ask-dada.sh` 测试功能
3. 后续更新 → 重复部署和测试流程

## ⚠️ 注意事项

### 权限设置
所有脚本都需要执行权限，如果遇到权限问题：
```bash
chmod +x scripts/*.sh
```

### 环境要求
- **macOS**: 所有脚本在macOS上测试通过
- **Xcode**: build-ios.sh需要Xcode环境
- **网络**: 部署脚本需要网络连接

### 错误处理
- 所有脚本都设置了 `set -e`，遇到错误会立即退出
- 查看错误信息，根据提示进行修复
- 如需帮助，参考相关文档或联系开发团队

## 📚 相关文档

- [部署指南](../docs/deployment.md)
- [Supabase集成指南](../docs/supabase_integration_guide.md)
- [键盘问题修复](../docs/keyboard_fixes_summary.md)

## 🔄 更新记录

- **2025-01-27**: 初始脚本整理，统一命名规范
- **功能完整**: 已删除过时脚本，保留核心开发工具

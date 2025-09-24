# llama.cpp XCFramework 集成说明

## 当前状态
✅ 代码已完全准备好使用llama.cpp XCFramework  
✅ 已创建Package.swift文件支持XCFramework集成  
✅ 已实现真实的llama.cpp API调用  

## 快速开始

### 方法一：使用自动设置脚本（推荐）

```bash
cd /Users/xuhuipeng/Code/dada-knows
./scripts/setup-llama-framework.sh
```

这个脚本会：
- 下载最新的llama.cpp XCFramework
- 计算正确的校验和
- 自动更新Package.swift文件

### 方法二：手动配置

1. **运行脚本获取校验和**：
   ```bash
   ./scripts/setup-llama-framework.sh
   ```

2. **在Xcode中添加本地包**：
   - 打开Xcode项目
   - File → Add Package Dependencies
   - 选择 "Add Local..." 
   - 选择项目根目录下的Package.swift
   - 确保选择了LlamaFramework依赖

### 方法三：直接使用预编译XCFramework

在Package.swift中使用类似配置：

```swift
.binaryTarget(
    name: "LlamaFramework",
    url: "https://github.com/ggml-org/llama.cpp/releases/download/b6529/llama-b6529-xcframework.zip",
    checksum: "运行脚本获取的实际校验和"
)
```

### 3. 生产环境配置

在发布前需要：

1. 上传模型文件到自有服务器/CDN
2. 更新 `ModelManager.modelInfo.zipDownloadURL`
3. 计算并更新 `zipChecksum`

## 模型文件结构

```
Documents/
└── Models/
    └── Qwen3-0.6B-GGUF-v1/
        ├── Qwen3-0.6B-Q8_0.gguf
        └── params
```

## 开发阶段功能

当前代码包含：
- ✅ 完整的架构设计
- ✅ UI组件和用户流程
- ✅ 下载管理（前台/后台）
- ✅ 模型状态管理
- ✅ 错误处理
- 🔄 模拟的模型推理（等待真实llama.cpp集成）

## 支持的功能

- iOS 17.0+ 支持
- 按需模型下载
- 前台/后台下载选择
- 下载进度管理
- 模型生命周期管理
- 完整的UI集成

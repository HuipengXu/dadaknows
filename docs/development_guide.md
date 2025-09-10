# 🚀 DadaKnows 开发指南

## 📋 项目概述

DadaKnows（问问答答）是一款专为 2-12岁儿童父母设计的AI知识伙伴应用，基于现代化技术栈构建。

### 技术架构
- **前端**: SwiftUI + Combine + MVVM架构
- **后端**: Supabase (认证 + 数据库 + Edge Functions)  
- **AI服务**: Google Gemini API
- **支付**: StoreKit 2.0
- **本地存储**: CoreData

## 🏗️ 项目结构

```
DadaKnows/
├── Core/                    # 核心功能模块
│   ├── AI/                 # AI管理
│   ├── Network/            # 网络和认证
│   ├── Storage/            # 数据存储
│   ├── Speech/             # 语音识别
│   ├── Notifications/      # 通知管理
│   ├── Subscription/       # 订阅管理
│   └── Analytics/          # 分析统计
├── Features/               # 功能界面
│   ├── Authentication/     # 认证界面
│   ├── Home/              # 主页
│   ├── Chat/              # 聊天界面
│   ├── Profile/           # 个人中心
│   ├── Subscription/      # 订阅界面
│   └── Analytics/         # 分析界面
├── Components/            # 可复用组件
├── Models/               # CoreData模型
└── Resources/            # 资源文件
```

## 🛠️ 开发环境配置

### 前置要求
- Xcode 15+
- iOS 17+
- Swift 5.9+
- Node.js (用于Supabase CLI)

### 1. 克隆项目
```bash
git clone <repository-url>
cd dada-knows
```

### 2. 安装开发工具
```bash
# 安装Supabase CLI
brew install supabase/tap/supabase

# 或使用npm
npm install -g supabase
```

### 3. 项目配置
```bash
# 给脚本添加执行权限
chmod +x scripts/*.sh

# 一键部署后端服务
./scripts/deploy-supabase.sh

# 验证iOS构建
./scripts/build-ios.sh
```

## 🔧 核心模块详解

### AI服务集成 (AIManager)

**功能**: 管理与Gemini AI的交互
**位置**: `DadaKnows/Core/AI/AIManager.swift`

```swift
// 主要功能
- askQuestion(question: String, age: Int) -> 年龄适配的AI回答
- generateResponse() -> 流式响应处理
- handleError() -> 错误处理和降级
```

**Gemini API集成示例**:
```typescript
// Supabase Edge Function实现
const response = await gemini.generateContentStream({
  model: 'gemini-2.0-flash-exp',
  contents: [{
    parts: [{
      text: `你是"答答"，专门为${age}岁儿童回答问题：${question}`
    }]
  }]
});
```

### 认证系统 (AuthManager)

**功能**: 用户认证和会话管理
**位置**: `DadaKnows/Core/Network/AuthManager.swift`

**支持的认证方式**:
- ✅ 邮箱/密码注册登录
- ✅ Google社交登录  
- ✅ Apple ID登录
- ✅ 密码重置功能

**配置要求**:
```xml
<!-- Info.plist 配置 -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
            <string>dadaknows</string>
        </array>
    </dict>
</array>
```

### 订阅系统 (SubscriptionManager)

**功能**: 应用内购买和订阅管理
**位置**: `DadaKnows/Core/Subscription/SubscriptionManager.swift`

**产品配置**:
```swift
// 产品ID配置
static let monthlyProductID = "com.dadaknows.pro.monthly"
static let yearlyProductID = "com.dadaknows.pro.yearly"  
static let lifetimeProductID = "com.dadaknows.pro.lifetime"
```

**StoreKit 2.0集成**:
- ✅ 产品加载和购买
- ✅ 订阅状态管理
- ✅ 交易验证
- ✅ 恢复购买

### 数据存储 (DataManager)

**功能**: 本地和云端数据同步
**位置**: `DadaKnows/Core/Storage/DataManager.swift`

**存储层次**:
1. **本地存储**: CoreData (聊天记录、用户设置)
2. **云端存储**: Supabase PostgreSQL
3. **缓存层**: 内存缓存 + 磁盘缓存

## 🚀 Supabase后端部署

### 1. 自动化部署
```bash
# 一键部署所有服务
./scripts/deploy-supabase.sh
```

### 2. 手动部署步骤

#### 2.1 登录和链接项目
```bash
# 登录Supabase
supabase login

# 链接到项目
cd supabase
supabase link --project-ref fwvyrcekbngcpiudljpj
```

#### 2.2 部署Edge Functions
```bash
# 部署ask-dada AI服务函数
supabase functions deploy ask-dada --no-verify-jwt

# 设置环境变量
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
```

#### 2.3 数据库迁移
```bash
# 创建数据库表
supabase db push
```

### 3. 验证部署
```bash
# 测试Edge Function
./scripts/test-ask-dada.sh
```

## 🔐 安全配置

### API密钥管理
**位置**: `DadaKnows/Core/Config.swift`

```swift
struct Config {
    static let supabaseURL = "https://fwvyrcekbngcpiudljpj.supabase.co"
    static let supabaseAnonKey = "your_anon_key"
    // 其他配置...
}
```

### 安全最佳实践
- ✅ 所有网络请求使用HTTPS
- ✅ 敏感数据存储在iOS Keychain
- ✅ 实施行级安全策略(RLS)
- ✅ 输入验证和内容过滤

## 🧪 测试和调试

### 1. 构建验证
```bash
# 验证iOS构建
./scripts/build-ios.sh

# 清理构建(如果需要)
./scripts/build-ios.sh clean
```

### 2. 模拟器问题
```bash
# 清理模拟器缓存
./scripts/clean-simulator.sh
```

### 3. 常见问题解决

#### Google登录问题
**错误**: `Custom scheme URLs are not allowed for 'WEB' client type`
**解决**: 确保使用iOS客户端ID，不是Web客户端ID

#### 键盘约束冲突
**错误**: `SystemInputAssistantView`约束冲突
**解决**: 使用自定义TextField样式，避免`RoundedBorderTextFieldStyle()`

#### Core Data问题
**解决**: 确保`.xcdatamodeld`文件正确添加到Xcode项目中

## 🎨 UI/UX开发规范

### 设计系统
```swift
// 颜色规范
extension Color {
    static let creamBackground = Color("CreamBackground")   // #FFF8E1
    static let vibrantOrange = Color("VibrantOrange")      // #FFB347
    static let textPrimary = Color("TextPrimary")          // #333333
    static let skyBlue = Color("SkyBlue")                  // #B3E5FC
}

// 字体规范
.font(.title2)      // 标题
.font(.body)        // 正文
.font(.headline)    // 按钮
```

### 动画库使用
**位置**: `DadaKnows/Components/AnimatedComponents.swift`

```swift
// 可用动画组件
FloatingView()      // 浮动动画
PulseView()         // 脉冲动画
ShimmerView()       // 闪光效果
BounceView()        // 弹跳动画
TypingIndicator()   // 打字指示器
```

## 📱 应用商店发布

### 1. 准备材料
- **应用截图**: 5张功能展示图
- **预览视频**: 15-30秒演示视频
- **应用描述**: 中英文版本
- **关键词**: kids,children,AI,education,learning

### 2. 合规要求
- **年龄分级**: 4+ (儿童应用)
- **隐私政策**: 必须提供可访问的隐私政策
- **COPPA合规**: 儿童隐私保护认证

### 3. 构建提交
```bash
# 生成生产构建
xcodebuild archive -project DadaKnows.xcodeproj \
                   -scheme DadaKnows \
                   -archivePath DadaKnows.xcarchive

# 导出ipa文件
xcodebuild -exportArchive -archivePath DadaKnows.xcarchive \
                          -exportPath ./build \
                          -exportOptionsPlist ci/ExportOptions.plist
```

## 🔄 开发工作流

### 1. 功能开发
1. 创建功能分支: `git checkout -b feature/new-feature`
2. 开发和测试: `./scripts/build-ios.sh`
3. 提交代码: `git commit -m "Add new feature"`
4. 合并主分支: `git merge main`

### 2. 部署更新
1. 更新后端: `./scripts/deploy-supabase.sh`
2. 测试功能: `./scripts/test-ask-dada.sh`
3. 发布iOS应用: 通过Xcode或CI/CD

### 3. 问题排查
1. 查看应用日志: Xcode Console
2. 检查后端日志: `supabase functions logs ask-dada`
3. 性能监控: Supabase Dashboard

## 📚 相关资源

### 官方文档
- [Supabase文档](https://supabase.com/docs)
- [SwiftUI指南](https://developer.apple.com/swiftui/)
- [StoreKit文档](https://developer.apple.com/storekit/)

### 项目文档
- **架构设计**: `dada_low_cost_architecture.md`
- **产品需求**: `dada-knows-prd.md`
- **数据库设计**: `data-knows-database.md`

---

**最后更新**: 2025年1月27日  
**适用版本**: DadaKnows v1.0  
**维护团队**: DadaKnows开发团队

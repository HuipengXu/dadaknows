# 🔧 DadaKnows 技术问题解决指南

## 📋 常见问题索引

- [Google登录问题](#google登录问题)
- [键盘界面问题](#键盘界面问题)  
- [Supabase集成问题](#supabase集成问题)
- [iOS构建问题](#ios构建问题)
- [性能优化建议](#性能优化建议)

---

## 🔐 Google登录问题

### 问题描述
在使用Google第三方登录时遇到错误：
- 错误消息：`Custom scheme URLs are not allowed for 'WEB' client type`
- 错误代码：`400: invalid_request`

### 问题原因
当前使用的Google OAuth客户端ID是为Web应用创建的，而iOS应用需要使用专门的iOS客户端ID。

### 解决方案

#### 1. 在Google Cloud Console中创建iOS客户端
1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 选择项目：`dada-knows`
3. 导航到 **APIs & Services** → **Credentials**
4. 点击 **+ CREATE CREDENTIALS** → **OAuth client ID**
5. 选择应用程序类型：**iOS**
6. 填写配置信息：
   - **Name**: `DadaKnows iOS`
   - **Bundle ID**: `com.dadaknows.DadaKnows`

#### 2. 更新项目配置

**更新 GoogleService-Info.plist**:
```xml
<key>CLIENT_ID</key>
<string>YOUR_NEW_IOS_CLIENT_ID.apps.googleusercontent.com</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.YOUR_NEW_IOS_CLIENT_ID</string>
```

**更新 Info.plist**:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.YOUR_NEW_IOS_CLIENT_ID</string>
</array>
```

#### 3. 验证配置
确保以下配置一致：
- Xcode项目设置中的Bundle Identifier
- GoogleService-Info.plist中的BUNDLE_ID  
- Google Cloud Console中配置的Bundle ID

---

## ⌨️ 键盘界面问题

### 问题描述
在Xcode调试区域出现以下错误：
1. **键盘约束冲突**: `SystemInputAssistantView` 的高度约束与其他键盘相关约束冲突
2. **键盘通知问题**: 收到键盘状态变化通知，但键盘实际不存在
3. **eligibility.plist 错误**: 模拟器系统文件错误

### 解决方案

#### 1. 修复键盘约束冲突
**问题根因**: `RoundedBorderTextFieldStyle()` 与系统键盘辅助视图之间的约束冲突

**解决方案**: 替换为自定义样式
```swift
// 修改前
.textFieldStyle(RoundedBorderTextFieldStyle())

// 修改后
.textFieldStyle(.plain)
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(Color(UIColor.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
        )
)
```

#### 2. 优化键盘行为
**添加SwiftUI内置键盘避让**:
```swift
// 在聊天界面添加
.ignoresSafeArea(.keyboard, edges: .bottom)
```

#### 3. 系统配置优化
**在 Info.plist 中添加**:
```xml
<key>UIViewControllerBasedStatusBarAppearance</key>
<true/>
<key>UIKeyboardDismissMode</key>
<string>interactive</string>
```

#### 4. 清理模拟器缓存
```bash
# 使用清理脚本
./scripts/clean-simulator.sh
```

---

## 🚀 Supabase集成问题

### 问题1: 编译错误 "Cannot find 'SupabaseClient' in scope"
**解决方案**: 确保已正确添加Supabase Swift SDK依赖
1. 在Xcode中: File → Add Package Dependencies
2. URL: `https://github.com/supabase/supabase-swift`
3. 选择所需的库: Supabase, Auth, Functions, PostgREST

### 问题2: 运行时错误 "配置验证失败"
**解决方案**: 检查 `Config.swift` 中的API密钥
```swift
// 确保所有密钥正确配置
struct Config {
    static let supabaseURL = "https://fwvyrcekbngcpiudljpj.supabase.co"
    static let supabaseAnonKey = "your_correct_anon_key"
    static let geminiAPIKey = "your_gemini_api_key"
}
```

### 问题3: Edge Function调用失败
**解决方案**:
1. 确认函数已正确部署: `supabase functions list`
2. 检查Supabase项目设置
3. 验证Gemini API密钥有效性
4. 查看函数日志: `supabase functions logs ask-dada`

### 问题4: 认证失败
**解决方案**:
1. 检查Supabase项目的认证设置
2. 确认邮箱验证配置
3. 查看Supabase Dashboard中的用户管理
4. 验证重定向URL配置: `dadaknows://auth`

---

## 🏗️ iOS构建问题

### 问题1: Core Data模型文件错误
**错误信息**: `Failed to load model named 'DadaKnowsModel'`

**解决方案**:
1. 确保 `.xcdatamodeld` 文件在项目导航器中可见
2. 检查文件的Target Membership设置
3. 验证模型文件路径正确

```bash
# 使用修复脚本(已废弃，问题已解决)
# ./scripts/fix-coredata.sh
```

### 问题2: 依赖包解析失败
**解决方案**:
```bash
# 清理Swift Package缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/DadaKnows-*
rm -rf DadaKnows.xcodeproj/project.xcworkspace/xcshareddata/swiftpm

# 重新解析依赖
# 在Xcode中: File → Packages → Reset Package Caches
```

### 问题3: 构建缓存问题
**解决方案**:
```bash
# 使用构建验证脚本清理构建
./scripts/build-ios.sh clean
```

---

## ⚡ 性能优化建议

### 内存管理
**问题**: 长时间聊天后内存使用过高

**优化方案**:
```swift
// 在ChatView中实现消息限制
func limitMessageHistory() {
    if messages.count > 100 {
        messages.removeFirst(50) // 保留最近50条消息
    }
}

// 在AIManager中清理长响应
func cleanupLongResponses() {
    if currentResponse.count > 10000 {
        // 截断过长的响应
        currentResponse = String(currentResponse.suffix(5000))
    }
}
```

### 网络优化
**问题**: 频繁API调用导致流量消耗大

**优化方案**:
```swift
// 实现请求去重
private var pendingRequests: Set<String> = []

func askQuestion(_ question: String) {
    let requestKey = question.lowercased().trimmingCharacters(in: .whitespaces)
    
    guard !pendingRequests.contains(requestKey) else {
        return // 避免重复请求
    }
    
    pendingRequests.insert(requestKey)
    // 执行请求...
}
```

### 启动优化
**问题**: 应用启动时间较长

**优化方案**:
```swift
// 在AppState中实现懒加载
class AppState: ObservableObject {
    lazy var aiManager = AIManager.shared
    lazy var subscriptionManager = SubscriptionManager.shared
    
    func initializeServices() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.aiManager.initialize() }
            group.addTask { await self.subscriptionManager.loadProducts() }
        }
    }
}
```

---

## 🛠️ 调试工具和技巧

### 1. 日志管理
```swift
// 在Config.swift中添加调试配置
struct Config {
    static let isDebugMode = true
    
    static func debugLog(_ message: String) {
        if isDebugMode {
            print("🐛 Debug: \(message)")
        }
    }
}
```

### 2. 网络请求调试
```swift
// 在APIClient中添加请求日志
private func logRequest(_ request: URLRequest) {
    Config.debugLog("🌐 Request: \(request.url?.absoluteString ?? "unknown")")
    Config.debugLog("📤 Method: \(request.httpMethod ?? "GET")")
}
```

### 3. 性能监控
```swift
// 添加性能测量
func measureTime<T>(_ operation: () throws -> T) rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    Config.debugLog("⏱️ Operation took: \(timeElapsed) seconds")
    return result
}
```

---

## 🆘 获取帮助

### 1. 查看日志
- **iOS应用日志**: Xcode Console输出
- **后端日志**: `supabase functions logs ask-dada`
- **构建日志**: Xcode Build Navigator

### 2. 验证服务状态
```bash
# 检查Supabase服务状态
supabase status

# 测试Edge Function
./scripts/test-ask-dada.sh

# 验证iOS构建
./scripts/build-ios.sh
```

### 3. 重置环境
```bash
# 完整重置开发环境
./scripts/clean-simulator.sh          # 清理模拟器
./scripts/build-ios.sh clean          # 清理iOS构建
supabase functions deploy ask-dada    # 重新部署后端
```

### 4. 联系支持
如果问题仍然无法解决：
1. 收集详细错误信息和日志
2. 记录复现步骤
3. 查看相关技术文档
4. 提交Issue或联系开发团队

---

**最后更新**: 2025年1月27日  
**适用版本**: DadaKnows v1.0  
**问题反馈**: 请通过项目Issue跟踪系统报告新问题

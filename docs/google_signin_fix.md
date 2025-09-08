# Google第三方登录错误修复指南

## 问题描述
在使用Google第三方登录时遇到错误：
- 错误消息：`Custom scheme URLs are not allowed for 'WEB' client type`
- 错误代码：`400: invalid_request`

## 问题原因
当前使用的Google OAuth客户端ID是为Web应用创建的，而iOS应用需要使用专门的iOS客户端ID。

## 解决方案

### 步骤1：在Google Cloud Console中创建iOS客户端

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 选择项目：`dada-knows`
3. 导航到 **APIs & Services** → **Credentials**
4. 点击 **+ CREATE CREDENTIALS** → **OAuth client ID**
5. 选择应用程序类型：**iOS**
6. 填写配置信息：
   - **Name**: `DadaKnows iOS`
   - **Bundle ID**: `com.dadaknows.DadaKnows`

### 步骤2：更新项目配置

#### 2.1 更新 GoogleService-Info.plist
将新创建的iOS客户端信息更新到 `GoogleService-Info.plist` 文件中：

```xml
<key>CLIENT_ID</key>
<string>YOUR_NEW_IOS_CLIENT_ID.apps.googleusercontent.com</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.YOUR_NEW_IOS_CLIENT_ID</string>
```

#### 2.2 更新 Info.plist
更新URL Scheme配置：

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.YOUR_NEW_IOS_CLIENT_ID</string>
</array>
```

### 步骤3：验证配置

确保以下配置正确：

1. **Bundle ID一致性**：
   - Xcode项目设置中的Bundle Identifier
   - GoogleService-Info.plist中的BUNDLE_ID
   - Google Cloud Console中配置的Bundle ID
   
2. **URL Scheme正确性**：
   - Info.plist中的CFBundleURLSchemes
   - 应该匹配REVERSED_CLIENT_ID的值

### 步骤4：测试登录功能

重新编译并运行应用，测试Google登录功能。

## 当前代码实现

你的代码实现是正确的：

### AuthManager.swift
```swift
func signInWithGoogle() async throws {
    // 获取presenting view controller
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let presentingViewController = windowScene.windows.first?.rootViewController else {
        throw AuthError.noViewController
    }
    
    // 使用Google Sign-In
    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
    
    // 获取ID Token
    guard let idToken = result.user.idToken?.tokenString else {
        throw AuthError.noGoogleToken
    }
    
    // 使用ID Token登录Supabase
    let session = try await supabase.supabase.auth.signInWithIdToken(
        credentials: .init(
            provider: .google,
            idToken: idToken
        )
    )
    // ...
}
```

### DadaKnowsApp.swift
```swift
// Google Sign-In配置
private func configureGoogleSignIn() {
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path),
          let clientId = plist["CLIENT_ID"] as? String else {
        print("⚠️ GoogleService-Info.plist not found or CLIENT_ID missing")
        return
    }
    
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
}

// URL处理
.onOpenURL { url in
    GIDSignIn.sharedInstance.handle(url)
}
```

## 注意事项

1. **测试环境与生产环境**：开发和生产环境可能需要不同的客户端ID
2. **证书匹配**：确保应用签名证书与Google Console中配置的一致
3. **Bundle ID唯一性**：Bundle ID必须与Google Console中注册的完全一致
4. **网络环境**：确保设备能够正常访问Google服务

## 故障排除

如果问题仍然存在，检查：

1. **Google Cloud Console项目设置**：
   - APIs是否已启用（Google Sign-In API）
   - OAuth同意屏幕是否配置完成

2. **Xcode项目设置**：
   - Team和签名配置
   - Bundle Identifier设置

3. **网络连接**：
   - 设备网络连接
   - 防火墙设置

4. **日志检查**：
   - Xcode控制台输出
   - Google Sign-In相关日志

## 相关文档

- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)
- [Supabase Auth with Google](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [iOS URL Schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)

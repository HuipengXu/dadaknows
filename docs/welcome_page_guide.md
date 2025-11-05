### **第一部分：UI/UX 设计方案**

我们的核心目标是：**移除“登录”和“注册”的明确区分，让用户通过同一个入口无缝进入应用。**

#### **改造前 (您当前的界面):**
*   顶部有 "Sign In" / "Sign Up" 切换器。
*   下方有明确的 "Sign in with Google" 和 "Sign in with Apple"。

#### **改造后 (建议方案):**

我们将从上到下重新设计元素布局：

1.  **移除顶部切换器**: 这是最重要的一步。删除顶部的 "Sign In" / "Sign Up" 分段控件。
2.  **保留品牌信息**: “Welcome to Dada Knows” 和 App 图标保持不变，它们很棒。
3.  **统一入口 - 邮箱**:
    *   只保留一个 **Email** 输入框。
    *   将下方的 "Sign In" 按钮的文字改为 **"Continue with Email"**。
4.  **视觉分隔**: 保留 "or" 分隔线，它能很好地区分不同类型的登录方式。
5.  **统一入口 - 第三方**:
    *   **Google 按钮**:
        *   使用您准备好的正确 SVG 资源 (`ios_dark_sq_ctn.svg`GoogleSignInButton)。
        *   文字明确改为 **"Continue with Google"**。
    *   **Apple 按钮**:
        *   使用 SwiftUI 原生组件。
        *   文字同样选择 **"Continue with Apple"** (`SignInWithAppleButton(.continue, ...)`).

#### **视觉模拟 (改造后的样子):**

```
      [App Icon]

  Welcome to Dada Knows
You bring the love, we'll bring the answers

+-------------------------------------+
| Email                               |
| youremail@example.com               |
+-------------------------------------+

+-------------------------------------+
|       Continue with Email           |
+-------------------------------------+

      ──────── or ────────

+-------------------------------------+
| G    Continue with Google           |
+-------------------------------------+

+-------------------------------------+
|     Continue with Apple            |
+-------------------------------------+

      Forgot Password? (可选，可放在流程之后)
```

---

### **第二部分：核心逻辑流程**

这个新界面的美妙之处在于其背后的智能逻辑。

#### **1. 当用户点击 "Continue with Google" 或 "Continue with Apple":**

*   **流程**: 这是最简单的流程。
*   **逻辑**: 调用 Supabase 对应的第三方登录方法。
    *   **如果该用户是第一次使用 Google/Apple 登录**: Supabase 会在 `auth.users` 表中自动为他创建一个新用户，并返回登录凭证。
    *   **如果该用户之前已经用 Google/Apple 登录过**: Supabase 会识别出这是老用户，直接返回登录凭证。
*   **用户体验**: 无论是新是老，用户点击后都会直接进入App主界面，体验完全无缝。

#### **2. 当用户输入邮箱，点击 "Continue with Email":**

这是流程的关键，需要您在App端和后端做一些判断。

*   **步骤 1: 检查邮箱是否存在**
    *   当用户点击 "Continue with Email" 后，您的App应该立即将输入的邮箱地址发送到您的后端（或通过 Supabase 的函数/RPC 调用）。
    *   后端查询 `auth.users` 表，检查这个邮箱是否已经注册。

*   **步骤 2: 根据结果动态展示下一步UI**

    *   **情况 A: 邮箱已存在 (老用户)**
        *   **UI变化**: 在 "Continue with Email" 按钮下方，**动态地滑出 "Password" 输入框**。
        *   **按钮文字变化**: "Continue with Email" 按钮的文字变为 **"Sign In"**。
        *   **用户体验**: 用户看到密码框后，自然明白这是在进行登录操作。

    *   **情况 B: 邮箱不存在 (新用户)**
        *   **UI变化**: 动态地滑出 **"Create Password"** 和 **"Confirm Password"** 两个输入框（也可以加上“姓名”等其他注册所需信息）。
        *   **按钮文字变化**: "Continue with Email" 按钮的文字变为 **"Sign Up"** 或 **"Create Account"**。
        *   **用户体验**: 用户看到创建密码的输入框，就知道这是在注册新账户。

*   **（更优选择）Magic Link 魔法链接流程**:
    *   这是一个更现代、更丝滑的无密码流程。
    *   当用户输入邮箱点击 "Continue" 后，您直接调用Supabase的 `signInWith(otp:)` 方法。
    *   界面提示用户：“Check your email for a magic link to sign in.” (请检查您的邮箱以通过魔法链接登录)。
    *   用户无需输入密码，点击邮件中的链接即可完成登录/注册。**这个流程的用户体验摩擦最小。**

---

### **第三部分：SwiftUI 代码实现示例**

这里提供一个基于“情况A/情况B”逻辑的 SwiftUI 代码框架。

```swift
import SwiftUI
import AuthenticationServices

struct UnifiedLoginView: View {

    // --- State Management ---
    // Enum to manage the flow state based on email check
    enum AuthFlowState {
        case initial, signingIn, signingUp
    }

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = "" // For sign up
    
    @State private var authFlowState: AuthFlowState = .initial
    
    // --- UI Layout ---
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Dark background

            VStack(spacing: 20) {
                // 1. Header
                Spacer()
                Image(systemName: "brain.head.profile") // Replace with your app icon
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                Text("Welcome to Dada Knows")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)
                Text("You bring the love, we'll bring the answers")
                    .foregroundColor(.gray)

                // 2. Email Input and Action Button
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color(.darkGray))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    // Dynamically show password fields
                    if authFlowState == .signingIn {
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.darkGray))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    } else if authFlowState == .signingUp {
                        SecureField("Create Password", text: $password)
                            .padding()
                            .background(Color(.darkGray))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(Color(.darkGray))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    // Dynamic Action Button
                    Button(action: handleEmailContinue) {
                        Text(buttonText())
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 30)

                // 3. Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.gray)
                    Text("or").foregroundColor(.gray)
                    Rectangle().frame(height: 1).foregroundColor(.gray)
                }

                // 4. Social Logins
                // --- CORRECT GOOGLE BUTTON IMPLEMENTATION ---
                Button(action: { /* Your Google Sign In Logic */ }) {
                    Image("GoogleSignInButton") // Use your correctly configured SVG asset name
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(height: 50)

                // --- CORRECT APPLE BUTTON IMPLEMENTATION ---
                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in /* Configure request */ },
                    onCompletion: { result in /* Handle result */ }
                )
                .signInWithAppleButtonStyle(.white) // Use .white for dark backgrounds
                .frame(height: 50)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
    }

    // --- Logic ---
    func handleEmailContinue() {
        if authFlowState == .initial {
            // **TODO: Call Supabase to check if email exists**
            // For demonstration, we'll simulate the result
            let emailExists = checkIfEmailExists(email) // This is a placeholder for your API call
            
            withAnimation {
                if emailExists {
                    authFlowState = .signingIn
                } else {
                    authFlowState = .signingUp
                }
            }
        } else if authFlowState == .signingIn {
            // TODO: Perform Sign In with email and password
        } else if authFlowState == .signingUp {
            // TODO: Perform Sign Up with email and password
        }
    }
    
    func buttonText() -> String {
        switch authFlowState {
        case .initial:
            return "Continue with Email"
        case .signingIn:
            return "Sign In"
        case .signingUp:
            return "Create Account"
        }
    }
    
    // Placeholder function for backend call
    func checkIfEmailExists(_ email: String) -> Bool {
        // In a real app, you would make a network request to your backend/Supabase here.
        // For example, if email is "test@test.com", we pretend it exists.
        return email == "test@test.com"
    }
}```

这个方案将为您提供一个设计现代、逻辑清晰、体验流畅的全新登录注册流程。
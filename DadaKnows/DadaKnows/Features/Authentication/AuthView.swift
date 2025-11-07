//
//  AuthView.swift
//  DadaKnows
//
//  认证页面 - 登录注册界面
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSecurePassword = true
    @State private var isSecureConfirmPassword = true
    @State private var showAlert = false
    @State private var showSuccessAlert = false
    @State private var showForgotPassword = false
    @State private var passwordValidationMessage = ""

    // Unified auth flow state
    enum AuthFlowState {
        case initial, signingIn, signingUp
    }
    @State private var authFlowState: AuthFlowState = .initial

    var onAuthSuccess: () -> Void
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Header - 我们的 logo 和 slogan
                    VStack(spacing: 24) {
                        // Logo - DadaKnows 品牌标识
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appPrimary)
                                .frame(width: 64, height: 64)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                            Text("D")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 8) {
                            Text("DadaKnows")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)

                            Text("welcome_subtitle")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer().frame(height: 80)

                    // Social login buttons - 放在前面
                    VStack(spacing: 12) {
                        // Google Sign In Button
                        Button(action: handleGoogleSignIn) {
                            HStack(spacing: 8) {
                                if authManager.isGoogleLoading {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .foregroundColor(.black)
                                } else {
                                    Image("GoogleLogo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                }

                                Text("continue_with_google")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.8)
                            )
                        }
                        .disabled(authManager.isGoogleLoading)
                        .opacity(authManager.isGoogleLoading ? 0.6 : 1.0)

                        // Apple Sign In Button
                        if #available(iOS 13.0, *) {
                            SignInWithAppleButton(
                                .continue,
                                onRequest: { request in
                                    request.requestedScopes = [.fullName, .email]
                                },
                                onCompletion: { result in
                                    handleAppleSignInResult(result)
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 25)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.separator)
                            .frame(height: 1)

                        Text(NSLocalizedString("或", comment: ""))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 15)

                        Rectangle()
                            .fill(Color.separator)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 24)

                    // Email input section - 带右箭头按钮
                    VStack(spacing: 16) {
                        Text("email_input_title")
                            .font(.headline)
                            .foregroundColor(.textPrimary)

                        HStack(spacing: 0) {
                            TextField("email_placeholder", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .foregroundColor(.textPrimary)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.fillSecondary)
                                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                                )

                            // Right arrow button inside input field
                            Button(action: handleEmailContinue) {
                                Group {
                                    if authManager.isEmailLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.appPrimary)
                                    } else {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(isEmailValid ? .white : .textSecondary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isEmailValid ? Color.appPrimary : Color.clear)
                                )
                            }
                            .disabled(authManager.isEmailLoading || !isEmailValid)
                            .buttonStyle(.plain)
                            .opacity(isEmailValid ? 1.0 : 0.6)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.fillSecondary)
                                .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 25)

                    // Password fields - 动态显示
                    if authFlowState == .signingIn {
                        VStack(spacing: 20) {
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("password_title")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)

                                HStack {
                                    Group {
                                        if isSecurePassword {
                                            SecureField("password_placeholder", text: $password)
                                        } else {
                                            TextField("password_placeholder", text: $password)
                                        }
                                    }
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    Button(action: {
                                        isSecurePassword.toggle()
                                    }) {
                                        Image(systemName: isSecurePassword ? "eye.slash" : "eye")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.trailing, 16)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.fillSecondary)
                                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                                )

                                // Sign in button
                                Button(action: handleEmailSignIn) {
                                    HStack {
                                        if authManager.isEmailLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        }
                                        Text("sign_in_button")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                                }
                                .disabled(authManager.isEmailLoading || !password.isEmpty)
                                .buttonStyle(.plain)

                                // Forgot password
                                HStack {
                                    Spacer()
                                    Button("forgot_password") {
                                        showForgotPassword = true
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 24)
                    } else if authFlowState == .signingUp {
                        VStack(spacing: 20) {
                            // Password field for signup
                            VStack(alignment: .leading, spacing: 8) {
                                Text("create_password_title")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)

                                HStack {
                                    Group {
                                        if isSecurePassword {
                                            SecureField("create_password_placeholder", text: $password)
                                        } else {
                                            TextField("create_password_placeholder", text: $password)
                                        }
                                    }
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    Button(action: {
                                        isSecurePassword.toggle()
                                    }) {
                                        Image(systemName: isSecurePassword ? "eye.slash" : "eye")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.trailing, 16)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.fillSecondary)
                                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                                )

                                if !password.isEmpty {
                                    PasswordStrengthView(password: password)
                                }

                                // Confirm password field
                                HStack {
                                    Group {
                                        if isSecureConfirmPassword {
                                            SecureField("confirm_password_placeholder", text: $confirmPassword)
                                        } else {
                                            TextField("confirm_password_placeholder", text: $confirmPassword)
                                        }
                                    }
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    Button(action: {
                                        isSecureConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: isSecureConfirmPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.trailing, 16)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.fillSecondary)
                                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                                )

                                // Sign up button
                                Button(action: handleEmailSignUp) {
                                    HStack {
                                        if authManager.isEmailLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        }
                                        Text("sign_up_button")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                                }
                                .disabled(authManager.isEmailLoading || !isSignupFormValid)
                                .buttonStyle(.plain)
                                .opacity(isSignupFormValid ? 1.0 : 0.8)
                            }
                        }
                        .padding(.horizontal, 25)
                        .padding(.top, 24)
                    }

                    Spacer().frame(height: 50)
                }
            }
        }
        .alert(NSLocalizedString("错误", comment: ""), isPresented: $showAlert) {
            Button(NSLocalizedString("确定", comment: "")) { 
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        .alert(NSLocalizedString("成功", comment: ""), isPresented: $showSuccessAlert) {
            Button(NSLocalizedString("确定", comment: "")) { 
                authManager.successMessage = nil
            }
        } message: {
            Text(authManager.successMessage ?? "")
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: authManager.errorMessage) { _, errorMessage in
            showAlert = errorMessage != nil
        }
        .onChange(of: authManager.successMessage) { _, successMessage in
            showSuccessAlert = successMessage != nil
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                onAuthSuccess()
            }
        }
        .onChange(of: authFlowState) { _, _ in
            // 切换流程状态时重置错误和成功状态
            authManager.errorMessage = nil
            authManager.successMessage = nil
        }
    }
    
    private var isEmailValid: Bool {
        return !email.isEmpty && email.contains("@")
    }

    private var isSignupFormValid: Bool {
        return isEmailValid && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword && isPasswordStrong
    }
    
    private var isPasswordStrong: Bool {
        return validatePasswordStrength(password)
    }
    
    private func validatePasswordStrength(_ password: String) -> Bool {
        // 匹配Supabase要求：大写字母、小写字母、数字、符号
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigits = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        let hasMinLength = password.count >= 8
        
        return hasLowercase && hasUppercase && hasDigits && hasSymbols && hasMinLength
    }
    
    private func buttonText() -> String {
        switch authFlowState {
        case .initial:
            return NSLocalizedString("继续", comment: "")
        case .signingIn:
            return NSLocalizedString("登录", comment: "")
        case .signingUp:
            return NSLocalizedString("注册", comment: "")
        }
    }

    private func handleEmailContinue() {
        guard isEmailValid else { return }

        // Check if email exists to determine flow
        Task {
            await checkEmailExists(email: email)
        }
    }

    private func handleEmailSignIn() {
        guard !password.isEmpty else { return }

        Task {
            do {
                try await authManager.signInWithEmail(email: email, password: password)
            } catch {
                // 错误已在AuthManager中处理，UI会自动更新
            }
        }
    }

    private func handleEmailSignUp() {
        guard isSignupFormValid else { return }

        Task {
            do {
                try await authManager.signUpWithEmail(email: email, password: password)
            } catch {
                // 错误已在AuthManager中处理，UI会自动更新
            }
        }
    }

    private func checkEmailExists(email: String) async {
        do {
            let emailExists = try await authManager.checkEmailExists(email)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if emailExists {
                        authFlowState = .signingIn
                    } else {
                        authFlowState = .signingUp
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.authManager.errorMessage = NSLocalizedString("检查邮箱失败，请重试", comment: "")
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                // 错误已在AuthManager中处理
            }
        }
    }
    
    private func handleAppleSignIn() {
        Task {
            do {
                try await authManager.signInWithApple()
            } catch {
                // 错误已在AuthManager中处理
            }
        }
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        // 这里需要将Apple ID credential传递给AuthManager
                        // 但当前的AuthManager.signInWithApple()方法有自己的Apple Sign In实现
                        // 所以我们暂时还是调用原来的方法
                        try await authManager.signInWithApple()
                    } catch {
                        // 错误已在AuthManager中处理
                    }
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error)")
        }
    }
}

// MARK: - Supporting Views
struct CustomTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let keyboardType: UIKeyboardType
    
    init(title: LocalizedStringKey, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
            
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fillSecondary)
                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

struct CustomSecureField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.textPrimary)
            
            HStack {
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Button(action: {
                    isSecure.toggle()
                }) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.trailing, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
    }
}

struct SocialLoginButton: View {
    let title: LocalizedStringKey
    let icon: String
    let backgroundColor: Color
    let textColor: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(textColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Text(title)
                    .fontWeight(.medium)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .stroke(Color.separator, lineWidth: 0.5)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

struct PasswordStrengthView: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 密码强度指示器
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(strengthColor(index: index))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
            }
            
            // 强度文本
            Text(strengthText)
                .font(.caption)
                .foregroundColor(strengthTextColor)
                .animation(.easeInOut(duration: 0.2), value: password)
            
            // 密码要求清单
            if !password.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    PasswordRequirement(
                        text: NSLocalizedString("至少8位字符", comment: ""),
                        isMet: password.count >= 8
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("包含小写字母 (a-z)", comment: ""),
                        isMet: password.range(of: "[a-z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("包含大写字母 (A-Z)", comment: ""),
                        isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("包含数字 (0-9)", comment: ""),
                        isMet: password.range(of: "[0-9]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("包含特殊符号 (!@#$%等)", comment: ""),
                        isMet: password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 2)
    }
    
    private func strengthColor(index: Int) -> Color {
        let strength = passwordStrength
        switch strength {
        case 0: return .gray.opacity(0.3)
        case 1: return index == 0 ? .red : .gray.opacity(0.3)
        case 2: return index <= 1 ? .orange : .gray.opacity(0.3)
        case 3: return index <= 2 ? .yellow : .gray.opacity(0.3)
        case 4: return .green
        default: return .gray.opacity(0.3)
        }
    }
    
    private var strengthText: String {
        switch passwordStrength {
        case 0: return ""
        case 1: return NSLocalizedString("密码强度：弱", comment: "")
        case 2: return NSLocalizedString("密码强度：一般", comment: "")
        case 3: return NSLocalizedString("密码强度：较强", comment: "")
        case 4: return NSLocalizedString("密码强度：强", comment: "")
        default: return ""
        }
    }
    
    private var strengthTextColor: Color {
        switch passwordStrength {
        case 0: return .clear
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }
    
    private var passwordStrength: Int {
        var strength = 0
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigits = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        let hasMinLength = password.count >= 8
        
        if hasMinLength { strength += 1 }
        if hasLowercase { strength += 1 }
        if hasUppercase { strength += 1 }
        if hasDigits && hasSymbols { strength += 1 }
        
        return strength
    }
}

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isMet ? .green : .gray.opacity(0.5))
            
            Text(text)
                .font(.caption2)
                .foregroundColor(isMet ? .green : .gray)
        }
        .animation(.easeInOut(duration: 0.2), value: isMet)
    }
}

#Preview {
    AuthView {
        print("Auth success")
    }
}

//
//  AuthView.swift
//  DadaKnows
//
//  认证页面 - 登录注册界面
//

import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isSignIn = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var showSuccessAlert = false
    @State private var showForgotPassword = false
    @State private var passwordValidationMessage = ""
    
    var onAuthSuccess: () -> Void
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 60)
                    
                    // Header
                    VStack(spacing: 15) {
                        // Logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appPrimary)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Text("welcome_title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("welcome_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    
                    // Auth form
                    VStack(spacing: 20) {
                        // Mode selector - iOS native segmented control style
                        Picker(NSLocalizedString("认证模式", comment: ""), selection: $isSignIn) {
                            Text(NSLocalizedString("登录", comment: "")).tag(true)
                            Text(NSLocalizedString("注册", comment: "")).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .animation(.easeInOut(duration: 0.3), value: isSignIn)
                        
                        // Email field
                        CustomTextField(
                            title: "email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            CustomSecureField(
                                title: "password",
                                text: $password
                            )
                            
                            if !isSignIn && !password.isEmpty {
                                PasswordStrengthView(password: password)
                            }
                        }
                        
                        // Confirm password (only for sign up)
                        if !isSignIn {
                            CustomSecureField(
                                title: "confirm_password",
                                text: $confirmPassword
                            )
                        }
                        
                        // Forgot password (only for sign in)
                        if isSignIn {
                            HStack {
                                Spacer()
                                Button("forgot_password") {
                                    showForgotPassword = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.appPrimary)
                            }
                        }
                        
                        // Submit button - iOS native style
                        Button(action: handleAuth) {
                            HStack {
                                if authManager.isEmailLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text(isSignIn ? "sign_in" : "sign_up")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(isFormValid ? .white : .textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isFormValid ? Color.appPrimary : Color.fillSecondary)
                                    .stroke(isFormValid ? Color.clear : Color.separator.opacity(0.5), lineWidth: 0.5)
                            )
                        }
                        .disabled(authManager.isEmailLoading || !isFormValid)
                        .buttonStyle(.plain)
                        .opacity(isFormValid ? 1.0 : 0.8)
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
                    
                    // Social login buttons
                    VStack(spacing: 15) {
                        SocialLoginButton(
                            title: "sign_in_with_google",
                            icon: "g.circle.fill",
                            backgroundColor: .cardBackground,
                            textColor: .textPrimary,
                            isLoading: authManager.isGoogleLoading
                        ) {
                            handleGoogleSignIn()
                        }
                        
                        SocialLoginButton(
                            title: "sign_in_with_apple",
                            icon: "applelogo",
                            backgroundColor: .textPrimary,
                            textColor: .backgroundPrimary,
                            isLoading: authManager.isAppleLoading
                        ) {
                            handleAppleSignIn()
                        }
                    }
                    .padding(.horizontal, 25)
                    
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
        .onChange(of: isSignIn) { _, _ in
            // 切换登录/注册模式时重置错误和成功状态
            authManager.errorMessage = nil
            authManager.successMessage = nil
        }
    }
    
    private var isFormValid: Bool {
        if isSignIn {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword && isPasswordStrong
        }
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
    
    private func handleAuth() {
        guard isFormValid else { return }
        
        Task {
            do {
                if isSignIn {
                    try await authManager.signInWithEmail(email: email, password: password)
                } else {
                    try await authManager.signUpWithEmail(email: email, password: password)
                }
            } catch {
                // 错误已在AuthManager中处理，UI会自动更新
                // 确保按钮状态正确恢复
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 小延迟确保loading状态已更新
                }
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

//
//  AuthView.swift
//  DadaKnows
//
//  认证页面 - 登录注册界面
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject private var authManager = AuthManager.shared
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
        case initial            // 初始状态
        case passwordInput      // 密码输入（所有用户）
        case signingIn          // 登录中
        case signingUp          // 注册中
    }
    @State private var authFlowState: AuthFlowState = .initial

    // 新增状态变量
    @State private var confirmedEmail = ""
    @State private var isExistingUser = false
    @State private var showRegistrationGuide = false

    var onAuthSuccess: () -> Void
    
    @ViewBuilder
    var body: some View {
        mainContent
            .onAppear(perform: setupAuthHandlers)
    }

    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    contentStack(geometry: geometry)
                }
                .padding(ResponsiveLayoutHelper.getContentPadding(geometry))
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(NSLocalizedString("error", comment: "")),
                  message: Text(authManager.errorMessage ?? ""),
                  dismissButton: .default(Text(NSLocalizedString("ok", comment: ""))) {
                authManager.clearError()
            })
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(title: Text(NSLocalizedString("success", comment: "")),
                  message: Text(authManager.successMessage ?? ""),
                  dismissButton: .default(Text(NSLocalizedString("ok", comment: ""))) {
                authManager.successMessage = nil
            })
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(isPresented: .constant(authFlowState == .passwordInput)) {
            PasswordInputView(
                email: confirmedEmail,
                isExistingUser: $isExistingUser,
                password: $password,
                onCancel: {
                    authFlowState = .initial
                    clearForm()
                },
                onAuthSuccess: onAuthSuccess,
                onRegistrationSuccess: nil
            )
        }
    }

    private func contentStack(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 40))
            headerView(geometry: geometry)
            Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 60))
            socialLoginButtonsView(geometry: geometry)
            dividerView(geometry: geometry)
            emailInputView(geometry: geometry)
            Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 40))
        }
        .frame(maxWidth: .infinity)
    }

    private func setupAuthHandlers() {
        // These handlers are set up on appear to avoid complex modifier chains
    }

    // MARK: - View Components

    private func headerView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 24)) {
            DLogoView.responsive(size: ResponsiveLayoutHelper.getLogoSize(geometry))

            VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 8)) {
                Text("DadaKnows")
                    .font(.system(size: ResponsiveLayoutHelper.getTitleFontSize(geometry), weight: .bold))
                    .foregroundColor(.textPrimary)

                Text("welcome_subtitle")
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry), weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func socialLoginButtonsView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 12)) {
            googleSignInButton(geometry: geometry)
            appleSignInButton(geometry: geometry)
            
            Button(action: {
                AppState.shared.enterGuestMode()
            }) {
                Text(NSLocalizedString("continue_as_guest", comment: ""))
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .underline()
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: ResponsiveLayoutHelper.getContentMaxWidth(geometry))
    }

    private func googleSignInButton(geometry: GeometryProxy) -> some View {
        Button(action: handleGoogleSignIn) {
            HStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 8)) {
                if authManager.isGoogleLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.black)
                } else {
                    Image("GoogleLogo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 18),
                               height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 18))
                }

                Text("continue_with_google")
                    .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry), weight: .medium))
                    .foregroundColor(.black)
            }
            .responsiveButtonSize(geometry)
            .background(Color.white)
            .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 8))
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 8))
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .disabled(authManager.isGoogleLoading)
        .opacity(authManager.isGoogleLoading ? 0.6 : 1.0)
    }

    @ViewBuilder
    private func appleSignInButton(geometry: GeometryProxy) -> some View {
        if #available(iOS 13.0, *) {
            Button(action: handleAppleSignIn) {
                HStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 8)) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry) + 3, weight: .medium))
                        .foregroundColor(.black)

                    Text("continue_with_apple")
                        .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry), weight: .medium))
                        .foregroundColor(.black)
                }
                .responsiveButtonSize(geometry)
                .background(Color.white)
                .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 8))
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func dividerView(geometry: GeometryProxy) -> some View {
        HStack {
            Rectangle()
                .fill(Color.separator)
                .frame(height: 1)

            Text(NSLocalizedString("or", comment: ""))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 15))

            Rectangle()
                .fill(Color.separator)
                .frame(height: 1)
        }
        .frame(maxWidth: ResponsiveLayoutHelper.getContentMaxWidth(geometry))
        .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 24))
    }

    private func emailInputView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16)) {
            HStack(spacing: 0) {
                TextField(NSLocalizedString("email_placeholder", comment: ""), text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
                    .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 14))
                    .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
                    .foregroundColor(.textPrimary)
                    .background(Color.clear)

                Button(action: handleEmailContinue) {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.appPrimary)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry), weight: .semibold))
                                .foregroundColor(isEmailValid ? .white : .textSecondary)
                        }
                    }
                    .frame(width: ResponsiveLayoutHelper.getButtonHeight(geometry),
                           height: ResponsiveLayoutHelper.getButtonHeight(geometry))
                    .background(
                        RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                            .fill(isEmailValid ? Color.appPrimary : Color.fillSecondary)
                    )
                }
                .disabled(authManager.isLoading || !isEmailValid)
                .buttonStyle(.plain)
                .opacity(isEmailValid ? 1.0 : 0.6)
            }
            .padding(.horizontal, 1)
            .background(
                RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
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
            return NSLocalizedString("continue", comment: "")
        case .passwordInput:
            return NSLocalizedString("login", comment: "")
        case .signingIn:
            return NSLocalizedString("login", comment: "")
        case .signingUp:
            return NSLocalizedString("sign_up", comment: "")
        }
    }

    private func handleEmailContinue() {
        guard isEmailValid else { return }

        // 直接检查邮箱是否存在，不显示确认弹窗
        checkEmailAndProceed(email: email)
    }

    private func checkEmailAndProceed(email: String) {
        Task {
            do {
                let emailExists = try await authManager.checkEmailExists(email)

                await MainActor.run {
                    isExistingUser = emailExists
                    confirmedEmail = email
                    authFlowState = .passwordInput
                }

            } catch {
                await MainActor.run {
                    self.authManager.errorMessage = NSLocalizedString("error_email_check_failed", comment: "")
                }
            }
        }
    }

    private func clearForm() {
        email = ""
        confirmedEmail = ""
        password = ""
        confirmPassword = ""
        isExistingUser = false
    }

    private func handleEmailSignIn() {
        guard !password.isEmpty else { return }

        // Clear previous errors before starting new authentication
        authManager.clearError()
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

        // Clear previous errors before starting new authentication
        authManager.clearError()
        Task {
            do {
                try await authManager.signUpWithEmail(email: email, password: password)
            } catch {
                // 错误已在AuthManager中处理，UI会自动更新
            }
        }
    }

        
    private func handleGoogleSignIn() {
        // Clear previous errors before starting new authentication
        authManager.clearError()
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                // 错误已在AuthManager中处理
            }
        }
    }
    
    private func handleAppleSignIn() {
        // Clear previous errors before starting new authentication
        authManager.clearError()
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
            // 检查是否为 Apple ID 凭据
            if authorization.credential is ASAuthorizationAppleIDCredential {
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
                        text: NSLocalizedString("password_requirement_length", comment: ""),
                        isMet: password.count >= 8
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("password_requirement_lowercase", comment: ""),
                        isMet: password.range(of: "[a-z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("password_requirement_uppercase", comment: ""),
                        isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("password_requirement_number", comment: ""),
                        isMet: password.range(of: "[0-9]", options: .regularExpression) != nil
                    )
                    PasswordRequirement(
                        text: NSLocalizedString("password_requirement_special", comment: ""),
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
        case 1: return NSLocalizedString("password_strength_weak", comment: "")
        case 2: return NSLocalizedString("password_strength_fair", comment: "")
        case 3: return NSLocalizedString("password_strength_good", comment: "")
        case 4: return NSLocalizedString("password_strength_strong", comment: "")
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

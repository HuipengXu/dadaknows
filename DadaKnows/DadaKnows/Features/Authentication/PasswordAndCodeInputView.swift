//
//  PasswordInputView.swift
//  DadaKnows
//
//  密码输入弹窗 - 处理登录和注册的密码输入
//

import SwiftUI

struct PasswordInputView: View {
    let email: String
    @Binding var isExistingUser: Bool
    @Binding var password: String

    let onCancel: () -> Void
    let onAuthSuccess: () -> Void
    let onRegistrationSuccess: (() -> Void)?

    @StateObject private var authManager = AuthManager.shared
    @State private var isSecurePassword = true
    @State private var isSecureConfirmPassword = true
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var showSuccessAlert = false
    @State private var isLoading = false
    @State private var showForgotPassword = false

    // 验证码相关状态
    @State private var verificationCode = ""
    @State private var showVerificationInput = false
    @State private var otpExpirationTime: Date?
    @State private var countdownTimer: Timer?
    @State private var remainingTime: TimeInterval = 0

    // 重新发送倒计时状态
    @State private var resendCountdownTimer: Timer?
    @State private var resendCooldownTime: TimeInterval = 0

    // MARK: - Password Match State

    private enum PasswordMatchState {
        case empty
        case matching
        case notMatching

        var iconName: String {
            switch self {
            case .empty: return ""
            case .matching: return "checkmark.circle.fill"
            case .notMatching: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .empty: return .clear
            case .matching: return .green
            case .notMatching: return .red
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                VStack(spacing: 0) {
                    Spacer()

                    headerView(geometry: geometry)

                    Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 30))

                    emailDisplayView(geometry: geometry)

                    Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 20))

                    inputSectionView(geometry: geometry)

                    Spacer()

                    actionButtonsView(geometry: geometry)

                    Spacer().frame(height: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 40))
                }
                .background(Color.backgroundPrimary)
                .navigationBarHidden(true)
                .padding(ResponsiveLayoutHelper.getContentPadding(geometry))
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: email)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: email)
        }
        // 使用 Toast 替代 Alert 显示错误，停留时间更长 (5秒)
        .toast(message: $authManager.errorMessage, type: .error, duration: 5.0)
        .alert(NSLocalizedString("success", comment: ""), isPresented: $showSuccessAlert) {
            Button(NSLocalizedString("ok", comment: "")) {
                authManager.successMessage = nil
            }
        } message: {
            Text(authManager.successMessage ?? "")
        }
        .onChange(of: authManager.successMessage) { _, successMessage in
            showSuccessAlert = successMessage != nil
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && !showForgotPassword {
                stopCountdownTimer() // 验证成功后停止计时器
                onAuthSuccess()
            }
        }
        .onChange(of: confirmPassword) { _, _ in
            // 确认密码变化时，状态会自动更新
        }
        .onChange(of: password) { _, _ in
            // 原密码变化时，确认密码状态也需要更新
        }
        .onDisappear {
            stopCountdownTimer() // 视图消失时停止计时器
            stopResendCountdownTimer() // 视图消失时停止重新发送计时器
        }
    }

    // MARK: - Timer Management

    private func startCountdownTimer() {
        // 设置10分钟的过期时间
        otpExpirationTime = Date().addingTimeInterval(10 * 60)
        remainingTime = 10 * 60

        // 停止之前的计时器
        stopCountdownTimer()

        // 启动新的计时器
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdown() {
        guard let expirationTime = otpExpirationTime else { return }

        let now = Date()
        remainingTime = expirationTime.timeIntervalSince(now)

        if remainingTime <= 0 {
            stopCountdownTimer()
            remainingTime = 0
        }
    }

    private var countdownText: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60

        if remainingTime <= 0 {
            return NSLocalizedString("verification_code_expired", comment: "")
        } else if remainingTime <= 120 {
            return String.localizedStringWithFormat(NSLocalizedString("verification_code_expires_soon", comment: ""), minutes, seconds)
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("verification_time_remaining", comment: ""), minutes, seconds)
        }
    }

    private var isCountdownUrgent: Bool {
        return remainingTime <= 120 && remainingTime > 0
    }

    // MARK: - Resend Timer Management

    private func startResendCountdownTimer(duration: TimeInterval = 60) {
        // 设置冷却时间（默认60秒，或根据服务器返回的时间）
        resendCooldownTime = duration
        
        // 停止之前的计时器
        stopResendCountdownTimer()
        
        // 启动新的计时器
        resendCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateResendCountdown()
        }
    }

    private func stopResendCountdownTimer() {
        resendCountdownTimer?.invalidate()
        resendCountdownTimer = nil
    }

    private func updateResendCountdown() {
        resendCooldownTime -= 1

        if resendCooldownTime <= 0 {
            stopResendCountdownTimer()
            resendCooldownTime = 0
        }
    }

    private var canResendOTP: Bool {
        return resendCooldownTime <= 0
    }

    private var resendButtonText: String {
        if resendCooldownTime > 0 {
            return String.localizedStringWithFormat(NSLocalizedString("resend_code_cooldown", comment: ""), Int(resendCooldownTime))
        } else {
            return NSLocalizedString("resend_verification_code", comment: "")
        }
    }

    private var passwordMatchState: PasswordMatchState {
        if confirmPassword.isEmpty {
            return .empty
        }
        if password == confirmPassword {
            return .matching
        }
        return .notMatching
    }

    // MARK: - View Components

    private func headerView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 20)) {
            DLogoView.responsive(size: ResponsiveLayoutHelper.getLogoSize(geometry))

            VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 8)) {
                Text(isExistingUser ? NSLocalizedString("welcome_back", comment: "") : NSLocalizedString("create_account", comment: ""))
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry) + 4, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text(isExistingUser ? NSLocalizedString("enter_password_to_login", comment: "") : NSLocalizedString("set_password_to_register", comment: ""))
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry), weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func emailDisplayView(geometry: GeometryProxy) -> some View {
        HStack {
            Image(systemName: "envelope.fill")
                .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
                .foregroundColor(.appPrimary)

            Text(email)
                .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
        .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 14))
        .background(
            RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                .fill(Color.fillSecondary)
                .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
    }

      @ViewBuilder
    private func inputSectionView(geometry: GeometryProxy) -> some View {
        if showVerificationInput {
            verificationCodeInputView(geometry: geometry)
        } else {
            passwordInputView(geometry: geometry)
        }
    }

    private func passwordInputView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16)) {
            HStack {
                Group {
                    if isSecurePassword {
                        SecureField(NSLocalizedString("password_placeholder", comment: ""), text: $password)
                    } else {
                        TextField(NSLocalizedString("password_placeholder", comment: ""), text: $password)
                    }
                }
                .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
                .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 14))

                Button(action: {
                    isSecurePassword.toggle()
                }) {
                    Image(systemName: isSecurePassword ? "eye.slash" : "eye")
                        .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry), weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.trailing, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
            }
            .background(
                RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
            )
            .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
            
            // 忘记密码链接 - 仅对已存在用户显示
            if isExistingUser {
                HStack {
                    Spacer()
                    Button(action: { showForgotPassword = true }) {
                        Text(NSLocalizedString("forgot_password", comment: ""))
                            .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry) - 1))
                            .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
            }

            if !isExistingUser && !password.isEmpty {
                PasswordStrengthView(password: password)
                    .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
            }

            if !isExistingUser {
                confirmPasswordInputView(geometry: geometry)
            }
        }
    }

    private func confirmPasswordInputView(geometry: GeometryProxy) -> some View {
        HStack {
            Group {
                if isSecureConfirmPassword {
                    SecureField(NSLocalizedString("confirm_password_placeholder", comment: ""), text: $confirmPassword)
                } else {
                    TextField(NSLocalizedString("confirm_password_placeholder", comment: ""), text: $confirmPassword)
                }
            }
            .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
            .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 14))

            // 状态指示器
            if !confirmPassword.isEmpty {
                Image(systemName: passwordMatchState.iconName)
                    .foregroundColor(passwordMatchState.color)
                    .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry), weight: .medium))
                    .animation(.easeInOut(duration: 0.3), value: passwordMatchState)
            }

            Button(action: {
                isSecureConfirmPassword.toggle()
            }) {
                Image(systemName: isSecureConfirmPassword ? "eye.slash" : "eye")
                    .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry), weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            .padding(.trailing, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
        }
        .background(
            RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                .fill(Color.fillSecondary)
                .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))
    }

    private func verificationCodeInputView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16)) {
            HStack {
                TextField(NSLocalizedString("verification_code_placeholder", comment: ""), text: $verificationCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: ResponsiveLayoutHelper.getInputFieldFontSize(geometry)))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16))
                    .padding(.vertical, ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 14))
                    .onChange(of: verificationCode) { _, newValue in
                        // 限制验证码最多6位数字
                        let filtered = newValue.filter { $0.isNumber }
                        verificationCode = String(filtered.prefix(6))
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: ResponsiveLayoutHelper.getCornerRadius(geometry, base: 10))
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
            )
            .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))

            HStack {
                Text(NSLocalizedString("verification_code_sent", comment: ""))
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry) - 2))
                    .foregroundColor(.textSecondary)

                Spacer()

                Text(countdownText)
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry) - 2))
                    .fontWeight(.medium)
                    .foregroundColor(isCountdownUrgent ? .red : .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: ResponsiveLayoutHelper.getInputFieldMaxWidth(geometry))

            Button(action: {
                guard canResendOTP else { return }

                Task {
                    do {
                        try await authManager.resendOTP(email: email)
                        // 重新发送成功后重启计时器和冷却计时器
                        await MainActor.run {
                            startCountdownTimer()
                            startResendCountdownTimer()
                        }
                    } catch {
                        // 错误已在AuthManager中处理
                        await MainActor.run {
                            // 如果是速率限制错误，自动重新开始倒计时
                            if let authError = error as? AuthError,
                               case .rateLimitExceeded(let waitTime) = authError,
                               let time = waitTime {
                                startResendCountdownTimer(duration: TimeInterval(time))
                            }
                        }
                    }
                }
            }) {
                Text(resendButtonText)
                    .font(.system(size: ResponsiveLayoutHelper.getSubtitleFontSize(geometry)))
                    .foregroundColor(canResendOTP ? .appPrimary : .gray)
            }
            .buttonStyle(.plain)
            .disabled(!canResendOTP || authManager.isLoading)
        }
    }

    private func verificationCodeButtonsView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16)) {
            Button(action: handleVerifyCode) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(NSLocalizedString("verify", comment: ""))
                        .fontWeight(.semibold)
                        .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry)))
                }
                .foregroundColor(.white)
                .responsiveButtonSize(geometry)
                .background(canVerifyCode ? Color.appPrimary : Color.gray)
                .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 12))
            }
            .disabled(!canVerifyCode || isLoading)
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text(NSLocalizedString("cancel", comment: ""))
                    .fontWeight(.medium)
                    .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry)))
                    .foregroundColor(.textPrimary)
                    .responsiveButtonSize(geometry)
                    .background(Color.fillSecondary)
                    .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 12))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func actionButtonsView(geometry: GeometryProxy) -> some View {
        if showVerificationInput {
            verificationCodeButtonsView(geometry: geometry)
        } else {
            passwordButtonsView(geometry: geometry)
        }
    }

    private func passwordButtonsView(geometry: GeometryProxy) -> some View {
        VStack(spacing: ResponsiveLayoutHelper.getVerticalSpacing(geometry, base: 16)) {
            Button(action: handleSubmit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isExistingUser ? NSLocalizedString("login", comment: "") : NSLocalizedString("sign_up", comment: ""))
                        .fontWeight(.semibold)
                        .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry)))
                }
                .foregroundColor(.white)
                .responsiveButtonSize(geometry)
                .background(canSubmit ? Color.appPrimary : Color.gray)
                .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 12))
            }
            .disabled(!canSubmit || isLoading)
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text(NSLocalizedString("cancel", comment: ""))
                    .fontWeight(.medium)
                    .font(.system(size: ResponsiveLayoutHelper.getButtonFontSize(geometry)))
                    .foregroundColor(.textPrimary)
                    .responsiveButtonSize(geometry)
                    .background(Color.fillSecondary)
                    .cornerRadius(ResponsiveLayoutHelper.getCornerRadius(geometry, base: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var canVerifyCode: Bool {
        // 限制验证码长度为6位且未过期
        return verificationCode.count == 6 && remainingTime > 0
    }

    private var canSubmit: Bool {
        // 密码不能为空
        guard !password.isEmpty else { return false }

        // 新用户需要确认密码
        if !isExistingUser {
            guard password == confirmPassword else { return false }
            guard isPasswordStrong else { return false }
        }

        return true
    }

    private var isPasswordStrong: Bool {
        return validatePasswordStrength(password)
    }

    private func validatePasswordStrength(_ password: String) -> Bool {
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigits = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        let hasMinLength = password.count >= 8

        return hasLowercase && hasUppercase && hasDigits && hasSymbols && hasMinLength
    }

    private func handleSubmit() {
        guard canSubmit else { return }

        isLoading = true
        authManager.clearError()

        Task {
            do {
                if isExistingUser {
                    // 已注册用户直接登录
                    try await authManager.signInWithEmail(email: email, password: password)
                } else {
                    // 新用户注册
                    try await authManager.signUpWithEmail(email: email, password: password)

                    await MainActor.run {
                        isLoading = false
                        // 注册成功后显示验证码输入界面并启动计时器
                        showVerificationInput = true
                        startCountdownTimer()
                        startResendCountdownTimer() // 启动重新发送冷却计时器
                    }
                }
            } catch {
                // 错误已在AuthManager中处理
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func handleVerifyCode() {
        guard canVerifyCode else { return }

        isLoading = true
        authManager.clearError()

        Task {
            do {
                try await authManager.verifyOTP(email: email, token: verificationCode)

                await MainActor.run {
                    isLoading = false
                    onAuthSuccess()
                }
            } catch {
                // 错误已在AuthManager中处理
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

}

#Preview {
    PasswordInputView(
        email: "user@example.com",
        isExistingUser: .constant(true),
        password: .constant(""),
        onCancel: {},
        onAuthSuccess: {},
        onRegistrationSuccess: nil
    )
}
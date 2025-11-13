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

    // 验证码相关状态
    @State private var verificationCode = ""
    @State private var showVerificationInput = false
    @State private var otpExpirationTime: Date?
    @State private var countdownTimer: Timer?
    @State private var remainingTime: TimeInterval = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()

                headerView

                Spacer().frame(height: 40)

                emailDisplayView

                Spacer().frame(height: 24)

                inputSectionView

                Spacer()

                actionButtonsView

                Spacer().frame(height: 50)
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("错误", isPresented: $showAlert) {
            Button("确定") {
                authManager.clearError()
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        .alert("成功", isPresented: $showSuccessAlert) {
            Button("确定") {
                authManager.successMessage = nil
            }
        } message: {
            Text(authManager.successMessage ?? "")
        }
        .onChange(of: authManager.errorMessage) { _, errorMessage in
            showAlert = errorMessage != nil && authManager.authErrorType != .userCancelled
        }
        .onChange(of: authManager.successMessage) { _, successMessage in
            showSuccessAlert = successMessage != nil
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                stopCountdownTimer() // 验证成功后停止计时器
                onAuthSuccess()
            }
        }
        .onDisappear {
            stopCountdownTimer() // 视图消失时停止计时器
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
            return "验证码已过期"
        } else if remainingTime <= 120 {
            return "验证码将在 \(minutes):\(String(format: "%02d", seconds)) 后过期"
        } else {
            return "剩余时间: \(minutes):\(String(format: "%02d", seconds))"
        }
    }

    private var isCountdownUrgent: Bool {
        return remainingTime <= 120 && remainingTime > 0
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(spacing: 24) {
            DLogoView.medium

            VStack(spacing: 8) {
                Text(isExistingUser ? "欢迎回来" : "创建账户")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text(isExistingUser ? "请输入密码登录" : "请设置密码完成注册")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var emailDisplayView: some View {
        HStack {
            Image(systemName: "envelope.fill")
                .font(.system(size: 16))
                .foregroundColor(.appPrimary)

            Text(email)
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.fillSecondary)
                .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: 300)
    }

      @ViewBuilder
    private var inputSectionView: some View {
        if showVerificationInput {
            verificationCodeInputView
        } else {
            passwordInputView
        }
    }

    private var passwordInputView: some View {
        VStack(spacing: 16) {
            HStack {
                Group {
                    if isSecurePassword {
                        SecureField("请输入密码", text: $password)
                    } else {
                        TextField("请输入密码", text: $password)
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
            .frame(maxWidth: 300)

            if !isExistingUser && !password.isEmpty {
                PasswordStrengthView(password: password)
                    .frame(maxWidth: 300)
            }

            if !isExistingUser {
                confirmPasswordInputView
            }
        }
    }

    private var confirmPasswordInputView: some View {
        HStack {
            Group {
                if isSecureConfirmPassword {
                    SecureField("请再次输入密码", text: $confirmPassword)
                } else {
                    TextField("请再次输入密码", text: $confirmPassword)
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
        .frame(maxWidth: 300)
    }

    private var verificationCodeInputView: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("请输入6位验证码", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .onChange(of: verificationCode) { _, newValue in
                        // 限制验证码最多6位数字
                        let filtered = newValue.filter { $0.isNumber }
                        verificationCode = String(filtered.prefix(6))
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fillSecondary)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
            )
            .frame(maxWidth: 300)

            HStack {
                Text("验证码已发送到您的邮箱")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text(countdownText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isCountdownUrgent ? .red : .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: 300)

            Button(action: {
                Task {
                    do {
                        try await authManager.resendOTP(email: email)
                        // 重新发送成功后重启计时器
                        await MainActor.run {
                            startCountdownTimer()
                        }
                    } catch {
                        // 错误已在AuthManager中处理
                    }
                }
            }) {
                Text("重新发送验证码")
                    .font(.subheadline)
                    .foregroundColor(.appPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private var verificationCodeButtonsView: some View {
        VStack(spacing: 16) {
            Button(action: handleVerifyCode) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text("验证")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .frame(height: 50)
                .background(canVerifyCode ? Color.appPrimary : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canVerifyCode || isLoading)
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("取消")
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: 300)
                    .frame(height: 50)
                    .background(Color.fillSecondary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var actionButtonsView: some View {
        if showVerificationInput {
            verificationCodeButtonsView
        } else {
            passwordButtonsView
        }
    }

    private var passwordButtonsView: some View {
        VStack(spacing: 16) {
            Button(action: handleSubmit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isExistingUser ? "登录" : "注册")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .frame(height: 50)
                .background(canSubmit ? Color.appPrimary : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canSubmit || isLoading)
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text("取消")
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: 300)
                    .frame(height: 50)
                    .background(Color.fillSecondary)
                    .cornerRadius(12)
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
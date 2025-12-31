//
//  ForgotPasswordView.swift
//  DadaKnows
//
//  忘记密码视图
//

import SwiftUI

struct ForgotPasswordView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var showVerificationInput = false
    @State private var otpExpirationTime: Date?
    @State private var countdownTimer: Timer?
    @State private var remainingTime: TimeInterval = 0
    @State private var resendCountdownTimer: Timer?
    @State private var resendCooldownTime: TimeInterval = 0
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var isSecureNewPassword = true
    @State private var isSecureConfirmNewPassword = true
    @State private var isLoading = false
    @State private var isResendingOTP = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var isOTPVerified = false

    init(prefilledEmail: String? = nil) {
        _email = State(initialValue: prefilledEmail ?? "")
    }

    // MARK: - Password Reset Steps
    private enum ResetStep {
        case enterEmail
        case verifyCode
        case setNewPassword
    }
    
    @State private var currentStep: ResetStep = .enterEmail

    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.vibrantOrange)
                        
                        Text(NSLocalizedString("forgot_password_title", comment: ""))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.darkGray)
                        
                        Text(stepDescription)
                            .font(.subheadline)
                            .foregroundColor(.lightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 8)
                    
                    // Step Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index <= stepIndex ? Color.vibrantOrange : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 16)
                    
                    // Content based on current step
                    Group {
                        switch currentStep {
                        case .enterEmail:
                            emailStepView
                        case .verifyCode:
                            verificationStepView
                        case .setNewPassword:
                            passwordStepView
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.vibrantOrange)
                }
            }
            .alert(NSLocalizedString("成功", comment: ""), isPresented: $showSuccessAlert) {
                Button(NSLocalizedString("确定", comment: "")) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("password_reset_success", comment: ""))
            }
            .alert(NSLocalizedString("成功", comment: ""), isPresented: $showSuccessAlert) {
                Button(NSLocalizedString("确定", comment: "")) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("password_reset_success", comment: ""))
            }
            // 使用 Toast 替代 Alert 显示错误，停留时间更长 (5秒)
            .toast(message: $authManager.errorMessage, type: .error, duration: 5.0)
            .onDisappear {
                stopCountdownTimer()
                stopResendCountdownTimer()
            }
        }
    }
    
    // MARK: - Step Views
    
    private var emailStepView: some View {
        VStack(spacing: 20) {
            TextField(NSLocalizedString("email_address_placeholder", comment: ""), text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fillSecondary)
                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                )
                .frame(maxWidth: 320)

            Button(action: handleSendOTP) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(NSLocalizedString("send_verification_code", comment: ""))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 320)
                .frame(height: 50)
                .background(email.isEmpty || isLoading ? Color.gray : Color.vibrantOrange)
                .cornerRadius(25)
            }
            .disabled(isLoading || email.isEmpty)
            .opacity(email.isEmpty ? 0.6 : 1.0)
            
            // 剩余尝试次数提示
            if !email.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.lightGray)
                    Text(rateLimitInfoText)
                        .font(.caption)
                        .foregroundColor(.lightGray)
                }
            }
        }
    }
    
    private var verificationStepView: some View {
        VStack(spacing: 20) {
            // Email display
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.vibrantOrange)
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.darkGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fillSecondary.opacity(0.5))
            )
            .frame(maxWidth: 320)
            
            TextField(NSLocalizedString("verification_code_placeholder", comment: ""), text: $verificationCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fillSecondary)
                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                )
                .frame(maxWidth: 320)
                .onChange(of: verificationCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    verificationCode = String(filtered.prefix(6))
                }

            VStack(spacing: 8) {
                Text(countdownText)
                    .font(.caption)
                    .foregroundColor(isCountdownUrgent ? .red : .lightGray)
                
                Button(action: handleResendOTP) {
                    HStack(spacing: 4) {
                        if isResendingOTP {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.vibrantOrange)
                        }
                        Text(resendButtonText)
                    }
                    .font(.subheadline)
                    .foregroundColor(canResendOTP && !isResendingOTP ? .vibrantOrange : .gray)
                }
                .disabled(!canResendOTP || isResendingOTP)
            }
            .frame(maxWidth: 320)

            Button(action: handleVerifyRecoveryCode) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(NSLocalizedString("verify_and_continue", comment: ""))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 320)
                .frame(height: 50)
                .background(canVerifyCode ? Color.vibrantOrange : Color.gray)
                .cornerRadius(25)
            }
            .disabled(!canVerifyCode || isLoading)
        }
    }
    
    private var passwordStepView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Group {
                        if isSecureNewPassword {
                            SecureField(NSLocalizedString("new_password_placeholder", comment: ""), text: $newPassword)
                        } else {
                            TextField(NSLocalizedString("new_password_placeholder", comment: ""), text: $newPassword)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    
                    Button(action: { isSecureNewPassword.toggle() }) {
                        Image(systemName: isSecureNewPassword ? "eye.slash" : "eye")
                            .foregroundColor(.lightGray)
                    }
                    .padding(.trailing, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fillSecondary)
                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                )
                .frame(maxWidth: 320)

                HStack {
                    Group {
                        if isSecureConfirmNewPassword {
                            SecureField(NSLocalizedString("confirm_new_password_placeholder", comment: ""), text: $confirmNewPassword)
                        } else {
                            TextField(NSLocalizedString("confirm_new_password_placeholder", comment: ""), text: $confirmNewPassword)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    
                    Button(action: { isSecureConfirmNewPassword.toggle() }) {
                        Image(systemName: isSecureConfirmNewPassword ? "eye.slash" : "eye")
                            .foregroundColor(.lightGray)
                    }
                    .padding(.trailing, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.fillSecondary)
                        .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                )
                .frame(maxWidth: 320)
            }
            
            // Password requirements
            if !newPassword.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    passwordRequirementRow(NSLocalizedString("password_req_min_chars", comment: ""), met: newPassword.count >= 8)
                    passwordRequirementRow(NSLocalizedString("password_req_uppercase", comment: ""), met: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                    passwordRequirementRow(NSLocalizedString("password_req_lowercase", comment: ""), met: newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                    passwordRequirementRow(NSLocalizedString("password_req_number", comment: ""), met: newPassword.range(of: "[0-9]", options: .regularExpression) != nil)
                    passwordRequirementRow(NSLocalizedString("password_req_special", comment: ""), met: newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil)
                }
                .font(.caption)
                .padding(.horizontal)
                .frame(maxWidth: 320)
            }

            Button(action: handleUpdatePassword) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(NSLocalizedString("update_password", comment: ""))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 320)
                .frame(height: 50)
                .background(canUpdatePassword ? Color.vibrantOrange : Color.gray)
                .cornerRadius(25)
            }
            .disabled(!canUpdatePassword || isLoading)
        }
    }
    
    private func passwordRequirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .gray.opacity(0.5))
                .font(.system(size: 12))
            Text(text)
                .foregroundColor(met ? .darkGray : .lightGray)
        }
    }
    
    // MARK: - Computed Properties
    
    private var stepIndex: Int {
        switch currentStep {
        case .enterEmail: return 0
        case .verifyCode: return 1
        case .setNewPassword: return 2
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .enterEmail:
            return NSLocalizedString("forgot_password_step1_desc", comment: "")
        case .verifyCode:
            return NSLocalizedString("forgot_password_step2_desc", comment: "")
        case .setNewPassword:
            return NSLocalizedString("forgot_password_step3_desc", comment: "")
        }
    }
    
    private var rateLimitInfoText: String {
        let remaining = OTPRateLimiter.shared.getRemainingAttempts(for: email)
        if remaining == 3 {
            return NSLocalizedString("rate_limit_info_full", comment: "")
        } else if remaining > 0 {
            return String.localizedStringWithFormat(NSLocalizedString("rate_limit_info_remaining", comment: ""), remaining)
        } else {
            return NSLocalizedString("rate_limit_info_exceeded", comment: "")
        }
    }
    
    private var canVerifyCode: Bool {
        return verificationCode.count == 6 && remainingTime > 0
    }

    private var canResendOTP: Bool {
        return resendCooldownTime <= 0
    }

    private var resendButtonText: String {
        if resendCooldownTime > 0 { return String.localizedStringWithFormat(NSLocalizedString("resend_code_cooldown", comment: ""), Int(resendCooldownTime)) } else { return NSLocalizedString("resend_verification_code", comment: "") }
    }

    private var countdownText: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        if remainingTime <= 0 { return NSLocalizedString("verification_code_expired", comment: "") }
        if remainingTime <= 120 { return String.localizedStringWithFormat(NSLocalizedString("verification_code_expires_soon", comment: ""), minutes, seconds) }
        return String.localizedStringWithFormat(NSLocalizedString("verification_time_remaining", comment: ""), minutes, seconds)
    }

    private var isCountdownUrgent: Bool {
        return remainingTime <= 120 && remainingTime > 0
    }

    private var canUpdatePassword: Bool {
        guard !newPassword.isEmpty && newPassword == confirmNewPassword else { return false }
        return validatePasswordStrength(newPassword)
    }

    private func validatePasswordStrength(_ password: String) -> Bool {
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigits = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        let hasMinLength = password.count >= 8
        return hasLowercase && hasUppercase && hasDigits && hasSymbols && hasMinLength
    }

    private func startCountdownTimer() {
        otpExpirationTime = Date().addingTimeInterval(10 * 60)
        remainingTime = 10 * 60
        stopCountdownTimer()
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

    private func startResendCountdownTimer(duration: TimeInterval = 60) {
        resendCooldownTime = duration
        stopResendCountdownTimer()
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

    private var isVerifiedStage: Bool {
        return isOTPVerified
    }

    private func handleSendOTP() {
        guard !email.isEmpty else { return }
        isLoading = true
        authManager.clearError()
        Task {
            do {
                try await authManager.resetPassword(email: email)
                await MainActor.run {
                    isLoading = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .verifyCode
                    }
                    showVerificationInput = true
                    startCountdownTimer()
                    startResendCountdownTimer()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func handleResendOTP() {
        guard canResendOTP else { return }
        isResendingOTP = true
        authManager.clearError()
        Task {
            do {
                try await authManager.resetPassword(email: email)
                await MainActor.run {
                    isResendingOTP = false
                    startCountdownTimer()
                    startResendCountdownTimer()
                }
            } catch {
                await MainActor.run {
                    isResendingOTP = false
                    
                    // 如果是速率限制错误，自动重新开始倒计时
                    if let authError = error as? AuthError, 
                       case .rateLimitExceeded(let waitTime) = authError,
                       let time = waitTime {
                        startResendCountdownTimer(duration: TimeInterval(time))
                    }
                }
            }
        }
    }

    private func handleVerifyRecoveryCode() {
        guard canVerifyCode else { return }
        isLoading = true
        authManager.clearError()
        Task {
            do {
                try await authManager.verifyRecoveryOTP(email: email, token: verificationCode)
                await MainActor.run {
                    isLoading = false
                    isOTPVerified = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .setNewPassword
                    }
                    showVerificationInput = false
                    stopCountdownTimer()
                    stopResendCountdownTimer()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func handleUpdatePassword() {
        guard canUpdatePassword else { return }
        isLoading = true
        authManager.clearError()
        Task {
            do {
                try await authManager.updatePassword(newPassword: newPassword)
                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView(prefilledEmail: "user@example.com")
}

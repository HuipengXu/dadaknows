//
//  AuthManager.swift
//  DadaKnows
//
//  认证管理器 - 处理用户认证相关功能
//

import Foundation
import Supabase
import AuthenticationServices
import GoogleSignIn
import Combine
import ObjectiveC

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var isGoogleLoading = false
    @Published var isAppleLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var authErrorType: AuthErrorType?
    @Published var isRecoveryInProgress = false
    
    private let supabase = SupabaseClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAuthStateListener()
        checkCurrentUser()
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        // 监听认证状态变化
        Task {
            for await state in supabase.supabase.auth.authStateChanges {
                await handleAuthStateChange(state.event, session: state.session)
            }
        }
    }
    
    private func handleAuthStateChange(_ event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            // 恢复流程中仅同步用户，不触发全局登录
            if isRecoveryInProgress {
                if let session = session {
                    self.currentUser = session.user
                } else {
                    do {
                        let currentSession = try await supabase.supabase.auth.session
                        self.currentUser = currentSession.user
                    } catch {
                        print("获取session失败: \(error)")
                    }
                }
            } else {
                // 非恢复流程：正常登录
                if let session = session {
                    self.currentUser = session.user
                    self.isAuthenticated = true
                    AppState.shared.signIn()
                } else {
                    do {
                        let currentSession = try await supabase.supabase.auth.session
                        self.currentUser = currentSession.user
                        self.isAuthenticated = true
                        AppState.shared.signIn()
                    } catch {
                        print("获取session失败: \(error)")
                    }
                }
            }
            
        case .signedOut:
            self.currentUser = nil
            self.isAuthenticated = false
            AppState.shared.signOut()
            
        case .tokenRefreshed:
            // 使用传入的session或获取刷新后的session
            if let session = session {
                self.currentUser = session.user
            } else {
                do {
                    let currentSession = try await supabase.supabase.auth.session
                    self.currentUser = currentSession.user
                } catch {
                    print("获取刷新后的session失败: \(error)")
                }
            }
            
        default:
            break
        }
    }
    
    private func checkCurrentUser() {
        Task {
            do {
                let session = try await supabase.supabase.auth.session
                // session.user is not optional in newer Supabase versions
                self.currentUser = session.user
                self.isAuthenticated = true
                AppState.shared.signIn()
            } catch {
                // 用户未登录或session已过期
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Email Authentication
    
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        clearError()

        defer {
            isLoading = false
        }
        
        do {
            let session = try await supabase.supabase.auth.signIn(
                email: email,
                password: password
            )
            
            self.currentUser = session.user
            self.isAuthenticated = true
            AppState.shared.signIn()
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        isLoading = true
        clearError()

        defer {
            isLoading = false
        }

        do {
            if Config.isDebug {
                print("📧 开始注册邮箱: \(email)")
            }

            // 使用邮箱和密码注册，注册后需要用户输入邮件中的6位验证码
            let session = try await supabase.supabase.auth.signUp(
                email: email,
                password: password
            )

            if Config.isDebug {
                print("✅ 注册API调用成功，检查邮箱验证状态")
            }

            // 检查是否需要邮箱验证
            let user = session.user
            if user.emailConfirmedAt == nil {
                // 需要邮箱验证 - 使用验证码方式
                self.successMessage = NSLocalizedString("signup_success_otp_sent", comment: "")

                if Config.isDebug {
                    print("📧 验证码邮件已发送，用户ID: \(user.id)")
                }
            } else {
                // 无需邮箱验证，直接登录
                self.currentUser = user
                self.isAuthenticated = true
                self.successMessage = NSLocalizedString("signup_success_welcome", comment: "")
                AppState.shared.signIn()

                if Config.isDebug {
                    print("✅ 邮箱已验证，直接登录成功")
                }
            }

        } catch {
            // 增强的错误处理
            let detailedError = handleSignUpError(error, email: email)
            self.errorMessage = detailedError.message
            self.authErrorType = detailedError.type

            if Config.isDebug {
                print("❌ 注册失败: \(detailedError.message)")
                print("❌ 原始错误: \(error)")
            }

            throw error
        }
    }

    // MARK: - OTP Verification

    func verifyOTP(email: String, token: String) async throws {
        isLoading = true
        clearError()

        defer {
            isLoading = false
        }

        do {
            if Config.isDebug {
                print("🔢 开始验证OTP: \(email)")
            }

            // 使用OTP验证邮箱
            let session = try await supabase.supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .signup
            )

            // 验证成功，设置用户状态
            self.currentUser = session.user
            self.isAuthenticated = true
            self.successMessage = NSLocalizedString("verify_otp_success", comment: "")
            AppState.shared.signIn()

            if Config.isDebug {
                print("✅ OTP验证成功，用户ID: \(session.user.id)")
            }

        } catch {
            self.errorMessage = handleAuthError(error)
            if Config.isDebug {
                print("❌ OTP验证失败: \(error)")
            }
            throw error
        }
    }

    func resendOTP(email: String) async throws {
        isLoading = true
        clearError()

        defer {
            isLoading = false
        }
        
        // 检查发送频率限制
        let rateLimitCheck = await OTPRateLimiter.shared.canSendOTP(for: email)
        guard rateLimitCheck.canSend else {
            self.errorMessage = rateLimitCheck.message
            self.errorMessage = rateLimitCheck.message
            throw AuthError.rateLimitExceeded(waitTime: Int(rateLimitCheck.remainingTime))
        }

        do {
            if Config.isDebug {
                print("📧 重新发送OTP: \(email)")
            }

            // 重新发送OTP验证邮件
            try await supabase.supabase.auth.resend(
                email: email,
                type: .signup
            )
            
            // 成功发送后记录到频率限制器
            await OTPRateLimiter.shared.recordSend(for: email)

            self.successMessage = NSLocalizedString("resend_otp_success", comment: "")

            if Config.isDebug {
                print("✅ OTP重新发送成功")
            }

        } catch {
            let result = handleResendOTPError(error)
            self.errorMessage = result.message
            
            if let waitTime = result.waitTime {
                await OTPRateLimiter.shared.updateCooldown(for: email, seconds: waitTime)
                throw AuthError.rateLimitExceeded(waitTime: waitTime)
            }
            
            if Config.isDebug {
                print("❌ OTP重新发送失败: \(error)")
            }
            throw error
        }
    }

    func verifyRecoveryOTP(email: String, token: String) async throws {
        isLoading = true
        clearError()

        defer { isLoading = false }

        do {
            isRecoveryInProgress = true
            let session = try await supabase.supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .recovery
            )
            if Config.isDebug {
                print("✅ verifyRecoveryOTP success. User: \(session.user.id)")
            }
            self.currentUser = session.user
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }

    func updatePassword(newPassword: String) async throws {
        guard !newPassword.isEmpty else { throw AuthError.weakPassword }
        isLoading = true
        clearError()

        defer { isLoading = false }

        do {
            // 检查当前会话状态
            if Config.isDebug {
                let session = try? await supabase.supabase.auth.session
                print("🔐 updatePassword - Current Session: \(session?.user.id.uuidString ?? "nil")")
            }

            let updatedUser = try await supabase.supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            self.currentUser = updatedUser
            self.successMessage = NSLocalizedString("password_updated", comment: "")
            isRecoveryInProgress = false
        } catch {
            print("❌ updatePassword error: \(error)")
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }

    func resetPassword(email: String) async throws {
        isLoading = true
        clearError()

        defer {
            isLoading = false
        }
        
        // 检查发送频率限制
        let rateLimitCheck = await OTPRateLimiter.shared.canSendOTP(for: email)
        guard rateLimitCheck.canSend else {
            self.errorMessage = rateLimitCheck.message
            self.errorMessage = rateLimitCheck.message
            throw AuthError.rateLimitExceeded(waitTime: Int(rateLimitCheck.remainingTime))
        }
        
        do {
            try await supabase.supabase.auth.resetPasswordForEmail(email)
            // 成功发送重置邮件，记录到频率限制器
            await OTPRateLimiter.shared.recordSend(for: email)
        } catch {
        } catch {
            let result = handleResendOTPError(error)
            self.errorMessage = result.message
            
            if let waitTime = result.waitTime {
                await OTPRateLimiter.shared.updateCooldown(for: email, seconds: waitTime)
                throw AuthError.rateLimitExceeded(waitTime: waitTime)
            }
            
            throw error
        }
    }
    
    // MARK: - Social Authentication
    
    func signInWithGoogle() async throws {
        isGoogleLoading = true
        clearError()

        defer {
            isGoogleLoading = false
        }
        
        do {
            // 配置Google Sign-In
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let presentingViewController = windowScene.windows.first?.rootViewController else {
                throw AuthError.noViewController
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.noGoogleToken
            }
            
            // 使用Google ID Token登录Supabase
            let session = try await supabase.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )
            
            self.currentUser = session.user
            self.isAuthenticated = true
            AppState.shared.signIn()
            
        } catch {
            // 检查是否是用户主动取消登录
            let errorDesc = error.localizedDescription
            if errorDesc.contains("canceled") || 
               errorDesc.contains("cancelled") || 
               errorDesc.contains("User cancelled") ||
               errorDesc.contains("The user canceled the sign-in flow") {
                // 用户取消是正常操作，不设置错误消息
                return
            }
            
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    func signInWithApple() async throws {
        isAppleLoading = true
        clearError()

        defer {
            isAppleLoading = false
        }
        
        do {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            // 使用async/await包装Apple Sign In，确保正确处理continuation
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                let delegate = AppleSignInDelegate { result in
                    switch result {
                    case .success(let credential):
                        continuation.resume(returning: credential)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                // 保持对delegate的强引用直到授权完成
                authorizationController.delegate = delegate
                authorizationController.presentationContextProvider = delegate
                
                // 将delegate存储在controller中以保持引用
                objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                authorizationController.performRequests()
            }
            
            guard let identityToken = result.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                throw AuthError.noAppleToken
            }
            
            // 使用Apple ID Token登录Supabase
            let session = try await supabase.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )
            
            self.currentUser = session.user
            self.isAuthenticated = true
            AppState.shared.signIn()
            
        } catch {
            // 如果用户主动取消登录，不显示错误提示
            if let authError = error as? AuthError, case .userCanceled = authError {
                // 用户取消是正常操作，不设置错误消息
                return
            }
            
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await supabase.supabase.auth.signOut()
            
            self.currentUser = nil
            self.isAuthenticated = false
            AppState.shared.signOut()
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Email Validation

    func checkEmailExists(_ email: String) async throws -> Bool {
        do {
            // 尝试使用RPC函数查询邮箱是否存在
            struct EmailCheckParams: Encodable {
                let user_email: String
            }

            let params = EmailCheckParams(user_email: email.lowercased())

            // 使用Supabase RPC函数检查邮箱是否存在
            let exists: Bool = try await supabase.supabase.rpc(
                "check_email_exists",
                params: params
            ).execute().value

            return exists

        } catch {
            // 如果RPC函数不存在（数据库中未创建），使用备用方案
            print("⚠️ RPC函数失败，使用备用方案: \(error)")

            // 备用方案：尝试注册该邮箱，如果返回"email already registered"错误则说明邮箱已存在
            let testPassword = "TestPassword123!@#"

            do {
                // 尝试注册一个临时用户
                _ = try await supabase.supabase.auth.signUp(
                    email: email,
                    password: testPassword
                )

                // 如果注册成功，说明邮箱不存在，但会发送验证邮件
                // 我们不需要这个测试用户，直接返回false
                return false

            } catch {
                let errorDescription = error.localizedDescription.lowercased()

                // 如果错误信息包含"already registered"或类似内容，说明邮箱已存在
                if errorDescription.contains("already") ||
                   errorDescription.contains("registered") ||
                   errorDescription.contains("taken") {
                    return true
                }

                // 其他错误情况，抛出原始错误
                throw error
            }
        }
    }

    // MARK: - User Profile

    func updateProfile(fullName: String? = nil, avatarUrl: String? = nil) async throws {
        guard currentUser != nil else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            var updates: [String: AnyJSON] = [:]
            
            if let fullName = fullName {
                updates["full_name"] = AnyJSON.string(fullName)
            }
            
            if let avatarUrl = avatarUrl {
                updates["avatar_url"] = AnyJSON.string(avatarUrl)
            }
            
            let updatedUser = try await supabase.supabase.auth.update(
                user: UserAttributes(data: updates)
            )
            
            self.currentUser = updatedUser
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        successMessage = nil
        authErrorType = nil
    }

    private func handleSignUpError(_ error: Error, email: String) -> (message: String, type: AuthErrorType) {
        let errorDescription = error.localizedDescription.lowercased()

        // 邮箱已存在错误
        if errorDescription.contains("already") && errorDescription.contains("registered") {
            return (
                NSLocalizedString("signup_error_email_already_exists", comment: ""),
                .authenticationFailed
            )
        }

        if errorDescription.contains("user_already_exists") {
            return (
                NSLocalizedString("signup_error_user_already_exists", comment: ""),
                .authenticationFailed
            )
        }

        // 密码强度错误
        if errorDescription.contains("password") && errorDescription.contains("weak") {
            return (
                NSLocalizedString("signup_error_password_weak", comment: ""),
                .authenticationFailed
            )
        }

        // 邮箱格式错误
        if errorDescription.contains("email") && (errorDescription.contains("invalid") || errorDescription.contains("malformed")) {
            return (
                NSLocalizedString("signup_error_email_invalid", comment: ""),
                .authenticationFailed
            )
        }

        // 网络相关错误
        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("timeout") ||
           errorDescription.contains("unreachable") {
            return (
                NSLocalizedString("signup_error_network_failed", comment: ""),
                .networkError
            )
        }

        // 邮件发送相关错误
        if errorDescription.contains("smtp") ||
           errorDescription.contains("mail") ||
           errorDescription.contains("email") && errorDescription.contains("failed") {
            return (
                NSLocalizedString("signup_error_email_send_failed", comment: ""),
                .unknownError
            )
        }

        // 速率限制错误
        if errorDescription.contains("too") && errorDescription.contains("many") ||
           errorDescription.contains("rate") && errorDescription.contains("limit") {
            return (
                NSLocalizedString("signup_error_rate_limit", comment: ""),
                .unknownError
            )
        }

        // 服务器错误
        if errorDescription.contains("server") && errorDescription.contains("error") ||
           errorDescription.contains("internal") && errorDescription.contains("error") {
            return (
                NSLocalizedString("signup_error_server_error", comment: ""),
                .unknownError
            )
        }

        // 通用错误处理
        if let authError = error as? AuthError {
            return (handleAuthError(authError), .authenticationFailed)
        }

        // 默认错误信息
        return (
            String(format: NSLocalizedString("signup_error_unknown", comment: ""), error.localizedDescription),
            .unknownError
        )
    }

    /// 从错误消息中提取等待时间（秒）
    /// 从错误消息中提取等待时间（秒）
    private func extractWaitTimeFromError(_ error: Error) -> Int? {
        // 检查 localizedDescription 和 debugDescription
        let errorString = error.localizedDescription
        let debugString = String(describing: error)
        
        // 匹配 "after X seconds" 或 "after X second" 模式
        let pattern = "after\\s+(\\d+)\\s+seconds?"
        
        // 尝试从 localizedDescription 提取
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = errorString as NSString
            let results = regex.matches(in: errorString, range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                let numberString = nsString.substring(with: numberRange)
                return Int(numberString)
            }
        }
        
        // 尝试从 debugDescription 提取
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = debugString as NSString
            let results = regex.matches(in: debugString, range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                let numberString = nsString.substring(with: numberRange)
                return Int(numberString)
            }
        }
        
        return nil
    }
    
    private func handleResendOTPError(_ error: Error) -> (message: String, waitTime: Int?) {
        let errorDescription = error.localizedDescription.lowercased()
        let debugDescription = String(describing: error).lowercased()

        // 处理速率限制错误，尝试提取实际等待时间
        // 检查 localizedDescription 和 debugDescription
        if errorDescription.contains("over_email_send_rate_limit") ||
           debugDescription.contains("over_email_send_rate_limit") ||
           (errorDescription.contains("rate") && errorDescription.contains("limit")) ||
           (errorDescription.contains("security") && errorDescription.contains("purposes") && errorDescription.contains("after")) {

            if let waitTime = extractWaitTimeFromError(error) {
                return (String(format: NSLocalizedString("rate_limit_wait_seconds", comment: ""), waitTime), waitTime)
            }
            return (NSLocalizedString("rate_limit_try_again_later", comment: ""), nil)
        }

        if errorDescription.contains("too") && errorDescription.contains("many") {
            if let waitTime = extractWaitTimeFromError(error) {
                return (String(format: NSLocalizedString("rate_limit_wait_seconds", comment: ""), waitTime), waitTime)
            }
            return (NSLocalizedString("rate_limit_try_again_shortly", comment: ""), nil)
        }

        // 对于其他错误，使用通用的错误处理
        return (handleAuthError(error), nil)
    }

    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case .invalidCredentials:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_invalid_credentials", comment: "")
            case .emailNotConfirmed:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_email_not_confirmed", comment: "")
            case .userNotFound:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_user_not_found", comment: "")
            case .weakPassword:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_password_weak", comment: "")
            case .emailAlreadyRegistered:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_email_already_registered", comment: "")
            case .notAuthenticated:
                authErrorType = .authenticationFailed
                return NSLocalizedString("auth_error_not_authenticated", comment: "")
            case .noViewController:
                authErrorType = .unknownError
                return NSLocalizedString("auth_error_no_view_controller", comment: "")
            case .noGoogleToken:
                authErrorType = .authenticationFailed
                return NSLocalizedString("error_google_sign_in_failed", comment: "")
            case .noAppleToken:
                authErrorType = .authenticationFailed
                return NSLocalizedString("error_apple_sign_in_failed", comment: "")
            case .userCanceled:
                authErrorType = .userCancelled
                return NSLocalizedString("auth_error_user_cancelled", comment: "")
            case .authorizationFailed:
                authErrorType = .authenticationFailed
                return NSLocalizedString("error_apple_authorization_failed", comment: "")
            case .invalidResponse:
                authErrorType = .authenticationFailed
                return NSLocalizedString("error_apple_invalid_response", comment: "")
            case .notHandled:
                authErrorType = .authenticationFailed
                return NSLocalizedString("error_apple_not_handled", comment: "")
            case .rateLimitExceeded(let waitTime):
                authErrorType = .authenticationFailed
                if let time = waitTime {
                    return String(format: NSLocalizedString("rate_limit_wait_seconds", comment: ""), time)
                }
                return NSLocalizedString("rate_limit_try_again_later", comment: "")
            case .unknownError:
                authErrorType = .unknownError
                return NSLocalizedString("error_apple_unknown_error", comment: "")
            }
        }

        // Handle Google Sign-In cancellation
        if error.localizedDescription.contains("canceled") ||
           error.localizedDescription.contains("cancelled") ||
           error.localizedDescription.contains("User cancelled") ||
           error.localizedDescription.contains("The user canceled the sign-in flow") {
            authErrorType = .userCancelled
            return NSLocalizedString("auth_error_user_cancelled", comment: "")
        }

        // 处理Supabase特定错误
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("password") && errorDescription.contains("weak") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_password_weak", comment: "")
        }

        if errorDescription.contains("email") && errorDescription.contains("already") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_email_already_registered", comment: "")
        }

        if errorDescription.contains("invalid") && errorDescription.contains("credentials") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_invalid_credentials", comment: "")
        }

        if errorDescription.contains("email") && errorDescription.contains("not") && errorDescription.contains("confirmed") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_email_not_confirmed", comment: "")
        }

        // Handle OTP expired error
        if errorDescription.contains("token has expired") && errorDescription.contains("invalid") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_otp_expired", comment: "")
        }

        if errorDescription.contains("otp_expired") {
            authErrorType = .authenticationFailed
            return NSLocalizedString("auth_error_otp_expired", comment: "")
        }

        // Handle network errors
        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("timeout") {
            authErrorType = .networkError
        } else {
            authErrorType = .unknownError
        }

        return NSLocalizedString("auth_error_unknown", comment: "")
    }
}

// MARK: - Supporting Types

enum AuthErrorType {
    case userCancelled
    case authenticationFailed
    case networkError
    case unknownError
}

enum AuthError: Error {
    case invalidCredentials
    case emailNotConfirmed
    case userNotFound
    case weakPassword
    case emailAlreadyRegistered
    case notAuthenticated
    case noViewController
    case noGoogleToken
    case noAppleToken
    case userCanceled
    case authorizationFailed
    case invalidResponse
    case notHandled
    case rateLimitExceeded(waitTime: Int?)
    case unknownError
}

// MARK: - Apple Sign In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(AuthError.noAppleToken))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Debug logging to track actual error codes
        print("Apple Sign-In error: \(error.localizedDescription)")
        if let authError = error as? ASAuthorizationError {
            print("ASAuthorizationError code: \(authError.code.rawValue)")
        }

        // 检查用户是否取消了授权
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                completion(.failure(AuthError.userCanceled))
            case .failed:
                completion(.failure(AuthError.authorizationFailed))
            case .invalidResponse:
                completion(.failure(AuthError.invalidResponse))
            case .notHandled:
                completion(.failure(AuthError.notHandled))
            case .unknown:
                // This often occurs when user dismisses the dialog, treat as cancellation
                print("Treating ASAuthorizationError.unknown as user cancellation")
                completion(.failure(AuthError.userCanceled))
            case .notInteractive:
                // This occurs when the flow cannot be completed interactively, treat as cancellation
                print("Treating ASAuthorizationError.notInteractive as user cancellation")
                completion(.failure(AuthError.userCanceled))
            case .matchedExcludedCredential:
                // This occurs when the credential is excluded by the app configuration
                print("Treating ASAuthorizationError.matchedExcludedCredential as cancellation")
                completion(.failure(AuthError.userCanceled))
            case .credentialImport:
                print("ASAuthorizationError.credentialImport")
                completion(.failure(AuthError.userCanceled))
            case .credentialExport:
                print("ASAuthorizationError.credentialExport")
                completion(.failure(AuthError.userCanceled))
            case .preferSignInWithApple:
                print("ASAuthorizationError.preferSignInWithApple")
                completion(.failure(AuthError.userCanceled))
            case .deviceNotConfiguredForPasskeyCreation:
                print("ASAuthorizationError.deviceNotConfiguredForPasskeyCreation")
                completion(.failure(AuthError.userCanceled))
            @unknown default:
                completion(.failure(error))
            }
        } else {
            completion(.failure(error))
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // 如果无法找到key window，尝试获取第一个window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                return window
            }
            // 最后的备选方案
            return UIWindow()
        }
        return window
    }
}

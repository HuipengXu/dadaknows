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
    @Published var isEmailLoading = false
    @Published var isGoogleLoading = false
    @Published var isAppleLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var authErrorType: AuthErrorType?
    
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
            // 使用传入的session或获取当前session
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
        isEmailLoading = true
        clearError()

        defer {
            isEmailLoading = false
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
        isEmailLoading = true
        clearError()

        defer {
            isEmailLoading = false
        }
        
        do {
            let session = try await supabase.supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // 检查是否需要邮箱验证
            let user = session.user
            if user.emailConfirmedAt == nil {
                // 需要邮箱验证 - 这是成功的情况
                self.successMessage = "注册成功！请检查您的邮箱并点击验证链接完成注册。"
            } else {
                // 无需邮箱验证，直接登录
                self.currentUser = user
                self.isAuthenticated = true
                self.successMessage = "注册成功！欢迎使用DadaKnows！"
                AppState.shared.signIn()
            }
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
    }
    
    func resetPassword(email: String) async throws {
        isEmailLoading = true
        clearError()

        defer {
            isEmailLoading = false
        }
        
        do {
            try await supabase.supabase.auth.resetPasswordForEmail(email)
            // 成功发送重置邮件
        } catch {
            self.errorMessage = handleAuthError(error)
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
        // This method checks if an email already exists in the auth.users table

        // Note: In a production environment, you would create a Supabase
        // Edge Function or RPC call to properly check email existence

        // For demonstration, we'll use a simple pattern to simulate email existence
        // In a real app, replace this with actual backend check
        let commonPatterns = ["test@", "demo@", "admin@", "user@", "john@", "jane@"]
        let emailLower = email.lowercased()

        // Check if email starts with common test patterns
        for pattern in commonPatterns {
            if emailLower.hasPrefix(pattern) {
                return true // Existing user
            }
        }

        // Otherwise, assume it's a new user
        return false
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

    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case .invalidCredentials:
                authErrorType = .authenticationFailed
                return "邮箱或密码错误"
            case .emailNotConfirmed:
                authErrorType = .authenticationFailed
                return "请先验证您的邮箱"
            case .userNotFound:
                authErrorType = .authenticationFailed
                return "用户不存在"
            case .weakPassword:
                authErrorType = .authenticationFailed
                return "密码强度不够，需要包含大写字母、小写字母、数字和符号，且至少8位"
            case .emailAlreadyRegistered:
                authErrorType = .authenticationFailed
                return "该邮箱已被注册"
            case .notAuthenticated:
                authErrorType = .authenticationFailed
                return "请先登录"
            case .noViewController:
                authErrorType = .unknownError
                return "无法获取视图控制器"
            case .noGoogleToken:
                authErrorType = .authenticationFailed
                return "Google登录失败"
            case .noAppleToken:
                authErrorType = .authenticationFailed
                return "Apple登录失败"
            case .userCanceled:
                authErrorType = .userCancelled
                return "用户取消了登录"
            case .authorizationFailed:
                authErrorType = .authenticationFailed
                return "Apple登录授权失败"
            case .invalidResponse:
                authErrorType = .authenticationFailed
                return "Apple登录响应无效"
            case .notHandled:
                authErrorType = .authenticationFailed
                return "Apple登录请求未处理"
            case .unknownError:
                authErrorType = .unknownError
                return "Apple登录发生未知错误"
            }
        }

        // Handle Google Sign-In cancellation
        if error.localizedDescription.contains("canceled") ||
           error.localizedDescription.contains("cancelled") ||
           error.localizedDescription.contains("User cancelled") ||
           error.localizedDescription.contains("The user canceled the sign-in flow") {
            authErrorType = .userCancelled
            return "用户取消了登录"
        }

        // 处理Supabase特定错误
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("password") && errorDescription.contains("weak") {
            authErrorType = .authenticationFailed
            return "密码强度不够，需要包含大写字母、小写字母、数字和符号，且至少8位"
        }

        if errorDescription.contains("email") && errorDescription.contains("already") {
            authErrorType = .authenticationFailed
            return "该邮箱已被注册"
        }

        if errorDescription.contains("invalid") && errorDescription.contains("credentials") {
            authErrorType = .authenticationFailed
            return "邮箱或密码错误"
        }

        if errorDescription.contains("email") && errorDescription.contains("not") && errorDescription.contains("confirmed") {
            authErrorType = .authenticationFailed
            return "请先验证您的邮箱"
        }

        // Handle network errors
        if errorDescription.contains("network") ||
           errorDescription.contains("connection") ||
           errorDescription.contains("timeout") {
            authErrorType = .networkError
        } else {
            authErrorType = .unknownError
        }

        return error.localizedDescription
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

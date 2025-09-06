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

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        isLoading = true
        errorMessage = nil
        
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
        
        isLoading = false
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // 检查是否需要邮箱验证
            let user = session.user
            if user.emailConfirmedAt == nil {
                // 需要邮箱验证
                self.errorMessage = "请检查您的邮箱并点击验证链接"
            } else {
                self.currentUser = user
                self.isAuthenticated = true
                AppState.shared.signIn()
            }
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.supabase.auth.resetPasswordForEmail(email)
            // 成功发送重置邮件
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Social Authentication
    
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        
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
        
        isLoading = false
    }
    
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            // 使用async/await包装Apple Sign In
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                let delegate = AppleSignInDelegate { result in
                    continuation.resume(with: result)
                }
                authorizationController.delegate = delegate
                authorizationController.presentationContextProvider = delegate
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
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        
        do {
            try await supabase.supabase.auth.signOut()
            
            self.currentUser = nil
            self.isAuthenticated = false
            AppState.shared.signOut()
            
        } catch {
            self.errorMessage = handleAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - User Profile
    
    func updateProfile(fullName: String? = nil, avatarUrl: String? = nil) async throws {
        guard currentUser != nil else {
            throw AuthError.notAuthenticated
        }
        
        isLoading = true
        
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
        
        isLoading = false
    }
    
    // MARK: - Error Handling
    
    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case .invalidCredentials:
                return "邮箱或密码错误"
            case .emailNotConfirmed:
                return "请先验证您的邮箱"
            case .userNotFound:
                return "用户不存在"
            case .weakPassword:
                return "密码强度不够"
            case .emailAlreadyRegistered:
                return "该邮箱已被注册"
            case .notAuthenticated:
                return "请先登录"
            case .noViewController:
                return "无法获取视图控制器"
            case .noGoogleToken:
                return "Google登录失败"
            case .noAppleToken:
                return "Apple登录失败"
            }
        }
        
        return error.localizedDescription
    }
}

// MARK: - Supporting Types

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
}

// MARK: - Apple Sign In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(AuthError.noAppleToken))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first { $0.isKeyWindow } ?? UIWindow()
        }
        return UIWindow()
    }
}

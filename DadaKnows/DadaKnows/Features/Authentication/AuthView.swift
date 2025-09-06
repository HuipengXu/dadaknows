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
    @State private var showForgotPassword = false
    
    var onAuthSuccess: () -> Void
    
    var body: some View {
        ZStack {
            Color.creamYellow
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 60)
                    
                    // Header
                    VStack(spacing: 15) {
                        // Logo
                        ZStack {
                            Circle()
                                .fill(Color.tenderYellow)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.vibrantOrange)
                        }
                        
                        Text("welcome_title")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.darkGray)
                        
                        Text("welcome_subtitle")
                            .font(.subheadline)
                            .foregroundColor(.lightGray)
                    }
                    
                    // Auth form
                    VStack(spacing: 20) {
                        // Mode selector
                        HStack(spacing: 0) {
                            Button(action: { isSignIn = true }) {
                                Text("sign_in")
                                    .font(.headline)
                                    .foregroundColor(isSignIn ? .white : .lightGray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .fill(isSignIn ? Color.vibrantOrange : Color.clear)
                                    )
                            }
                            
                            Button(action: { isSignIn = false }) {
                                Text("sign_up")
                                    .font(.headline)
                                    .foregroundColor(!isSignIn ? .white : .lightGray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .fill(!isSignIn ? Color.vibrantOrange : Color.clear)
                                    )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white.opacity(0.3))
                        )
                        .animation(.easeInOut(duration: 0.3), value: isSignIn)
                        
                        // Email field
                        CustomTextField(
                            title: "email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        // Password field
                        CustomSecureField(
                            title: "password",
                            text: $password
                        )
                        
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
                                .foregroundColor(.vibrantOrange)
                            }
                        }
                        
                        // Submit button
                        Button(action: handleAuth) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(isSignIn ? "sign_in" : "sign_up")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.vibrantOrange)
                            .cornerRadius(25)
                        }
                        .disabled(authManager.isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                    }
                    .padding(.horizontal, 25)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.lightGray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("或")
                            .foregroundColor(.lightGray)
                            .padding(.horizontal, 15)
                        
                        Rectangle()
                            .fill(Color.lightGray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 25)
                    
                    // Social login buttons
                    VStack(spacing: 15) {
                        SocialLoginButton(
                            title: "sign_in_with_google",
                            icon: "globe",
                            backgroundColor: .white,
                            textColor: .darkGray,
                            isLoading: authManager.isLoading
                        ) {
                            handleGoogleSignIn()
                        }
                        
                        SocialLoginButton(
                            title: "sign_in_with_apple",
                            icon: "applelogo",
                            backgroundColor: .black,
                            textColor: .white,
                            isLoading: authManager.isLoading
                        ) {
                            handleAppleSignIn()
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    Spacer().frame(height: 50)
                }
            }
        }
        .alert("错误", isPresented: $showAlert) {
            Button("确定") { 
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: authManager.errorMessage) { errorMessage in
            showAlert = errorMessage != nil
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                onAuthSuccess()
            }
        }
    }
    
    private var isFormValid: Bool {
        if isSignIn {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
        }
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
                // 错误已在AuthManager中处理
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
                .foregroundColor(.darkGray)
            
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lightGray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct CustomSecureField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.darkGray)
            
            SecureField("", text: $text)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lightGray.opacity(0.3), lineWidth: 1)
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
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.lightGray.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

#Preview {
    AuthView {
        print("Auth success")
    }
}

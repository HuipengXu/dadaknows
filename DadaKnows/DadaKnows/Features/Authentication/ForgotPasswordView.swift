//
//  ForgotPasswordView.swift
//  DadaKnows
//
//  忘记密码视图
//

import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer().frame(height: 40)
                    
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.vibrantOrange)
                        
                        Text("重置密码")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.darkGray)
                        
                        Text("输入您的邮箱地址，我们将发送重置密码的链接")
                            .font(.subheadline)
                            .foregroundColor(.lightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Email input
                    VStack(spacing: 20) {
                        CustomTextField(
                            title: "邮箱地址",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        // Send button
                        Button(action: handleResetPassword) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text("发送重置链接")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.vibrantOrange)
                            .cornerRadius(25)
                        }
                        .disabled(authManager.isLoading || email.isEmpty)
                        .opacity(email.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 25)
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.vibrantOrange)
                }
            }
            .alert("发送成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("重置密码的链接已发送到您的邮箱，请查收")
            }
            .alert("发送失败", isPresented: $showErrorAlert) {
                Button("确定") {
                    authManager.errorMessage = nil
                }
            } message: {
                Text(authManager.errorMessage ?? "")
            }
            .onChange(of: authManager.errorMessage) {
                showErrorAlert = authManager.errorMessage != nil
            }
        }
    }
    
    private func handleResetPassword() {
        guard !email.isEmpty else { return }
        
        Task {
            do {
                try await authManager.resetPassword(email: email)
                showSuccessAlert = true
            } catch {
                // 错误已在AuthManager中处理
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
}

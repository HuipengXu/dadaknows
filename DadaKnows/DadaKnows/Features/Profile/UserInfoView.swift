//
//  UserInfoView.swift
//  DadaKnows
//
//  Created by DadaKnows Team.
//

import SwiftUI

struct UserInfoView: View {
    @StateObject private var userService = UserService.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var aiManager = AIManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingUsername = false
    @State private var editingUsername = ""
    @State private var showProSubscription = false
    
    var body: some View {
        List {
            // 头像和基本信息部分
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 头像
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appPrimary.opacity(0.8), Color.appPrimary.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // 昵称编辑
                        if isEditingUsername {
                            HStack {
                                TextField("请输入昵称", text: $editingUsername)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 150)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: saveUsername) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Text(userService.currentUsername)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)
                                
                                Button(action: {
                                    editingUsername = userService.currentUsername
                                    isEditingUsername = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.appPrimary)
                                        .font(.title3)
                                }
                            }
                        }
                        
                        // 邮箱显示
                        if let email = authManager.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }
            
            // 会员状态部分
            Section(header: Text("会员状态")) {
                HStack {
                    Text("当前版本")
                    Spacer()
                    if subscriptionManager.isProMember {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.appAccent)
                            Text("Pro会员")
                                .fontWeight(.medium)
                                .foregroundColor(.appAccent)
                        }
                    } else {
                        Text("免费版")
                            .foregroundColor(.textSecondary)
                    }
                }

                // 仅对Pro用户显示详细信息和管理功能
                if subscriptionManager.isProMember {
                    if let expirationDate = subscriptionManager.expirationDate {
                        HStack {
                            Text("到期时间")
                            Spacer()
                            Text(expirationDate.formatted(date: .long, time: .shortened))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    // 仅对使用云端模型的Pro用户显示剩余次数
                    if aiManager.useGeminiModel {
                        HStack {
                            Text("本月已用")
                            Spacer()
                            Text("\(subscriptionManager.monthlyUsageCount) / 3000")
                                .foregroundColor(subscriptionManager.monthlyRemaining > 500 ? .textSecondary : .orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProSubscription) {
                ProSubscriptionView()
            }
            

        }
        .navigationTitle("个人信息")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveUsername() {
        let newName = editingUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty {
            userService.updateUsername(newName)
        }
        isEditingUsername = false
    }
}

#Preview {
    NavigationView {
        UserInfoView()
    }
}

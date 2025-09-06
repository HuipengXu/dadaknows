//
//  ProfileView.swift
//  DadaKnows
//
//  个人中心页面
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var showSettings = false
    @State private var showProSubscription = false
    
    var body: some View {
        ZStack {
            Color.creamYellow
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header section
                    headerSection
                    
                    // Growth statistics
                    growthStatsSection
                    
                    // Pro membership card
                    proMembershipSection
                    
                    // Features list
                    featuresSection
                    
                    Spacer().frame(height: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // User avatar and info
            VStack(spacing: 15) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.vibrantOrange)
                }
                
                VStack(spacing: 5) {
                    Text("用户昵称")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.darkGray)
                    
                    Text(subscriptionManager.isProMember ? "Pro会员" : "免费用户")
                        .font(.subheadline)
                        .foregroundColor(subscriptionManager.isProMember ? .vibrantOrange : .lightGray)
                }
            }
        }
    }
    
    private var growthStatsSection: some View {
        VStack(spacing: 15) {
            Text("成长统计")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.darkGray)
            
            HStack(spacing: 15) {
                // Questions count
                ProfileStatCard(
                    title: "已提问题数",
                    value: "\(analyticsManager.learningStats.totalQuestions)个",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .vibrantOrange
                )
                
                // Time spent
                ProfileStatCard(
                    title: "陪伴时长",
                    value: formatLearningTime(analyticsManager.learningStats.totalLearningTime),
                    icon: "clock.fill",
                    color: .skyBlue
                )
            }
        }
    }
    
    private func formatLearningTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private var proMembershipSection: some View {
        VStack(spacing: 0) {
            if !subscriptionManager.isProMember {
                // Free user - upgrade card
                Button(action: {
                    showProSubscription = true
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.proFreeGradient)
                            .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 5)
                        
                        VStack(spacing: 15) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("升级到Pro会员")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.darkGray)
                                    
                                    Text("解锁全部功能，享受完整体验")
                                        .font(.subheadline)
                                        .foregroundColor(.darkGray.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.vibrantOrange)
                            }
                            
                            // Pro features
                            VStack(alignment: .leading, spacing: 8) {
                                ProFeatureRow(icon: "infinity", text: "无限次提问")
                                ProFeatureRow(icon: "rectangle.slash", text: "纯净无广告体验")
                                ProFeatureRow(icon: "book.fill", text: "好奇心日志")
                                ProFeatureRow(icon: "rectangle.portrait.and.arrow.right", text: "知识卡片")
                            }
                        }
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // Pro user - status card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.proActiveGradient)
                        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 5)
                    
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pro会员")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("享受完整功能体验")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("有效期至：2024年12月31日")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 15) {
            // Curiosity log
            FeatureButton(
                icon: "book.fill",
                title: "好奇心日志",
                description: subscriptionManager.isProMember ? "查看所有问答记录" : "Pro功能 - 升级后可用",
                isProFeature: !subscriptionManager.isProMember,
                action: {
                    // TODO: Navigate to curiosity log
                }
            )
            
            // Settings
            FeatureButton(
                icon: "gearshape.fill",
                title: "设置",
                description: "语言、通知、账号安全",
                isProFeature: false,
                action: {
                    showSettings = true
                }
            )
            
            // Rate app
            FeatureButton(
                icon: "star.fill",
                title: "给我们评分",
                description: "您的评价是我们前进的动力",
                isProFeature: false,
                action: {
                    // TODO: Open App Store rating
                }
            )
            
            // Feedback
            FeatureButton(
                icon: "envelope.fill",
                title: "意见反馈",
                description: "告诉我们您的想法和建议",
                isProFeature: false,
                action: {
                    // TODO: Open feedback form
                }
            )
        }
    }
}

// MARK: - Supporting Views
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.lightGray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.darkGray.opacity(0.8))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.darkGray.opacity(0.8))
            
            Spacer()
        }
    }
}

struct FeatureButton: View {
    let icon: String
    let title: String
    let description: String
    let isProFeature: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isProFeature ? Color.lightGray.opacity(0.3) : Color.vibrantOrange.opacity(0.2))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isProFeature ? .lightGray : .vibrantOrange)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isProFeature ? .lightGray : .darkGray)
                        
                        if isProFeature {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.vibrantOrange)
                        }
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.lightGray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.lightGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .disabled(isProFeature)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                VStack {
                    Text("设置页面正在开发中...")
                        .font(.headline)
                        .foregroundColor(.lightGray)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.vibrantOrange)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}

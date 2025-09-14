//
//  ProfileView.swift
//  DadaKnows
//
//  个人中心页面
//

import SwiftUI
import StoreKit
import MessageUI

struct ProfileView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var aiManager = AIManager.shared
    @State private var showSettings = false
    @State private var showProSubscription = false
    @State private var showingMailComposer = false
    @State private var showingMailAlert = false
    @State private var showingFeedbackOptions = false
    @State private var showAnalytics = false
    
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
                    
                    // 🔄 新增：同步状态部分
                    // syncStatusSection
                    
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
        .sheet(isPresented: $showingMailComposer) {
            MailComposeView()
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView()
        }
        .actionSheet(isPresented: $showingFeedbackOptions) {
            ActionSheet(
                title: Text("选择反馈方式"),
                message: Text("您的设备未配置邮件账户，请选择其他反馈方式"),
                buttons: [
                    .default(Text("复制邮箱地址")) {
                        UIPasteboard.general.string = Config.feedbackEmail
                        // 显示复制成功的提示
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    },
                    .default(Text("前往App Store评价")) {
                        if let url = URL(string: Config.appStoreURL) {
                            UIApplication.shared.open(url)
                        }
                    },
                    .cancel(Text("取消"))
                ]
            )
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
                                    
                                    Text("无限次提问，支持我们持续改进")
                                        .font(.subheadline)
                                        .foregroundColor(.darkGray.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.vibrantOrange)
                            }
                            
                            // Pro benefits
                            VStack(alignment: .leading, spacing: 8) {
                                ProFeatureRow(icon: "infinity", text: "无限次提问")
                                ProFeatureRow(icon: "heart.fill", text: "支持开发团队")
                                ProFeatureRow(icon: "sparkles", text: "优先获得新功能")
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
                description: "查看所有问答记录",
                isProFeature: false,
                action: {
                    showAnalytics = true
                }
            )
            
            // On-device model toggle
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.vibrantOrange.opacity(0.2))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "cpu")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.vibrantOrange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("端侧模型")
                        .font(.headline)
                        .foregroundColor(.darkGray)
                    
                    Text(aiManager.isUsingOnDeviceModel ? "已启用 - 无使用限制" : "使用云端模型")
                        .font(.subheadline)
                        .foregroundColor(.lightGray)
                }
                
                Spacer()
                
                Toggle("", isOn: $aiManager.isUsingOnDeviceModel)
                    .toggleStyle(SwitchToggleStyle(tint: .vibrantOrange))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            
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
                    requestAppStoreReview()
                }
            )
            
            // Feedback
            FeatureButton(
                icon: "envelope.fill",
                title: "意见反馈",
                description: "告诉我们您的想法和建议",
                isProFeature: false,
                action: {
                    openFeedback()
                }
            )
        }
    }
    
    // 🔄 新增：同步状态部分
    /*
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.vibrantOrange)
                
                Text("数据同步")
                    .font(.headline)
                    .foregroundColor(.darkGray)
                
                Spacer()
            }
            
            // 使用我们创建的OfflineIndicator组件
            OfflineIndicator()
            
            // 简化的同步状态显示
            VStack(alignment: .leading, spacing: 8) {
                Text("用户配置")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.darkGray)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("昵称: 用户")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("语言: 中文")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("订阅: 免费版")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.white.opacity(0.5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    */
    
    // MARK: - Helper Functions
    
    private func requestAppStoreReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    private func openFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            showingFeedbackOptions = true
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
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Account section
                        settingsSection(title: "账号设置") {
                            VStack(spacing: 12) {
                                if authManager.isAuthenticated {
                                    SettingsRow(
                                        icon: "person.circle",
                                        title: "账号信息",
                                        subtitle: authManager.currentUser?.email ?? "未知",
                                        action: nil
                                    )
                                    
                                    SettingsRow(
                                        icon: "arrow.right.square",
                                        title: "退出登录",
                                        subtitle: "退出当前账号",
                                        action: {
                                            showingLogoutAlert = true
                                        }
                                    )
                                } else {
                                    SettingsRow(
                                        icon: "person.badge.plus",
                                        title: "登录账号",
                                        subtitle: "登录以同步数据",
                                        action: {
                                            // TODO: Navigate to login
                                        }
                                    )
                                }
                            }
                        }
                        
                        // App settings section
                        settingsSection(title: "应用设置") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "bell",
                                    title: "通知设置",
                                    subtitle: "管理推送通知",
                                    action: {
                                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(settingsUrl)
                                        }
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "globe",
                                    title: "语言设置",
                                    subtitle: "中文（简体）",
                                    action: {
                                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(settingsUrl)
                                        }
                                    }
                                )
                            }
                        }
                        
                        // About section
                        settingsSection(title: "关于") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    icon: "info.circle",
                                    title: "版本信息",
                                    subtitle: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                                    action: nil
                                )
                                
                                SettingsRow(
                                    icon: "doc.text",
                                    title: "隐私政策",
                                    subtitle: "查看隐私政策",
                                    action: {
                                        // TODO: Open privacy policy
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "doc.plaintext",
                                    title: "服务条款",
                                    subtitle: "查看服务条款",
                                    action: {
                                        // TODO: Open terms of service
                                    }
                                )
                            }
                        }
                        
                        // Danger zone
                        if authManager.isAuthenticated {
                            settingsSection(title: "危险操作") {
                                SettingsRow(
                                    icon: "trash",
                                    title: "删除账号",
                                    subtitle: "永久删除账号和所有数据",
                                    isDestructive: true,
                                    action: {
                                        showingDeleteAccountAlert = true
                                    }
                                )
                            }
                        }
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
            .alert("退出登录", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task {
                        do {
                            try await authManager.signOut()
                            presentationMode.wrappedValue.dismiss()
                        } catch {
                            // Handle sign out error if needed
                            print("Sign out error: \(error)")
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
            .alert("删除账号", isPresented: $showingDeleteAccountAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    // TODO: Implement account deletion
                }
            } message: {
                Text("此操作将永久删除您的账号和所有数据，且无法恢复。确定要继续吗？")
            }
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.darkGray)
                .padding(.horizontal, 16)
            
            VStack(spacing: 1) {
                content()
            }
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isDestructive: Bool
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, isDestructive: Bool = false, action: (() -> Void)?) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 15) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDestructive ? Color.red.opacity(0.2) : Color.vibrantOrange.opacity(0.2))
                        .frame(width: 35, height: 35)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDestructive ? .red : .vibrantOrange)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .darkGray)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.lightGray)
                }
                
                Spacer()
                
                // Arrow (only if action is available)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.lightGray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .disabled(action == nil)
    }
}

// MARK: - Mail Compose View
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject("DadaKnows 意见反馈")
        composer.setToRecipients([Config.feedbackEmail])
        
        let deviceInfo = """
        
        
        ---
        设备信息：
        iOS版本: \(UIDevice.current.systemVersion)
        设备型号: \(UIDevice.current.model)
        应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")
        """
        
        composer.setMessageBody("请在此处输入您的意见和建议：\(deviceInfo)", isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ProfileView()
}

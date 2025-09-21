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
    @State private var showProSubscription = false
    @State private var showingMailComposer = false
    @State private var showingMailAlert = false
    @State private var showingFeedbackOptions = false
    @State private var showQAHistory = false
    @State private var showingEditProfile = false
    @State private var editingUsername = ""
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingLogoutAlert = false
    @State private var showingLanguageSelector = false
    @State private var showingLanguageChangedAlert = false
    @State private var showingRatingDialog = false
    @State private var showingUpgradeAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User profile section with email
                userProfileSection
                
                // Pro membership section
                proMembershipSection
                    
                // App settings section
                appSettingsSection
                
                // Privacy & Legal section
                privacyLegalSection
                
                // About section
                aboutSection
                
                // Support section
                supportSection
                
                // Logout section (if authenticated)
                if authManager.isAuthenticated {
                    logoutSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("设置", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposeView()
        }
        .sheet(isPresented: $showingLanguageSelector) {
            LanguageSelectorView(onLanguageChanged: { language in
                changeLanguage(to: language)
            })
        }
        .alert(NSLocalizedString("language_changed", comment: ""), isPresented: $showingLanguageChangedAlert) {
            Button(NSLocalizedString("i_understand", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("language_changed_message", comment: ""))
        }
        .confirmationDialog(NSLocalizedString("选择反馈方式", comment: ""), isPresented: $showingFeedbackOptions, titleVisibility: .visible) {
            Button(NSLocalizedString("复制邮箱地址", comment: "")) {
                UIPasteboard.general.string = Config.feedbackEmail
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            Button(NSLocalizedString("前往App Store评价", comment: "")) {
                if let url = URL(string: Config.appStoreURL) {
                    UIApplication.shared.open(url)
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("您的设备未配置邮件账户，请选择其他反馈方式", comment: ""))
        }
    }
    
    // MARK: - User Profile Section
    private var userProfileSection: some View {
        Section {
            // User info with edit button
            Button(action: { 
                editingUsername = userService.currentUsername
                showingEditProfile = true 
            }) {
                HStack(spacing: 16) {
                    // Avatar
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.appPrimary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userService.currentUsername.isEmpty ? NSLocalizedString("用户", comment: "") : userService.currentUsername)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text(subscriptionManager.isProMember ? NSLocalizedString("Pro会员", comment: "") : NSLocalizedString("免费用户", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Login email (if authenticated)
            if authManager.isAuthenticated {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.appPrimary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("登录邮箱", comment: ""))
                            .foregroundColor(.textPrimary)
                        
                        Text(authManager.currentUser?.email ?? NSLocalizedString("未知", comment: ""))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(username: $editingUsername) { newUsername in
                userService.updateUsername(newUsername)
            }
        }
    }
    
    
    // MARK: - Pro Membership Section
    private var proMembershipSection: some View {
        Section {
            if !subscriptionManager.isProMember {
                Button(action: { showProSubscription = true }) {
                    HStack {
                        Image(systemName: "crown")
                            .foregroundColor(.appAccent)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("升级到Pro", comment: ""))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                            
                            Text(NSLocalizedString("无限次提问，更多功能", comment: ""))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                                
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.appAccent)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("Pro会员", comment: ""))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary)
                                
                                Text(NSLocalizedString("享受完整功能体验", comment: ""))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                    Text(NSLocalizedString("已激活", comment: ""))
                        .font(.caption)
                        .foregroundColor(.statusSuccess)
                }
            }
        }
    }
    
    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        Section(NSLocalizedString("应用设置", comment: "")) {
            // AI Model Selection
            aiModelSelectionView
            
            // Notifications
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.appAccent)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("通知设置", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            // Language
            Button(action: { showingLanguageSelector = true }) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.appSecondary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("语言设置", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Text(currentLanguageDisplayName())
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Privacy & Legal Section
    private var privacyLegalSection: some View {
        Section(NSLocalizedString("隐私与法律", comment: "")) {
            Button(action: { showingPrivacyPolicy = true }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.appSecondary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("隐私政策", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: { showingTermsOfService = true }) {
                HStack {
                    Image(systemName: "doc.plaintext")
                        .foregroundColor(.appSecondary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("服务条款", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section(NSLocalizedString("关于", comment: "")) {
            // Version info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                Text(NSLocalizedString("版本信息", comment: ""))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section(NSLocalizedString("支持", comment: "")) {
            Button(action: { showingRatingDialog = true }) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.appAccent)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("给我们评分", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: { openFeedback() }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.appPrimary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("意见反馈", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Logout Section
    private var logoutSection: some View {
        Section {
            Button(action: { showingLogoutAlert = true }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(.statusError)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("退出登录", comment: ""))
                        .foregroundColor(.statusError)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .alert(NSLocalizedString("退出登录", comment: ""), isPresented: $showingLogoutAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("退出", comment: ""), role: .destructive) {
                Task {
                    do {
                        try await authManager.signOut()
                    } catch {
                        print("Sign out error: \(error)")
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("确定要退出登录吗？", comment: ""))
        }
        .alert(NSLocalizedString("rate_app_title", comment: ""), isPresented: $showingRatingDialog) {
            Button(NSLocalizedString("rate_on_app_store", comment: "")) {
                openAppStore()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("rate_app_message", comment: ""))
        }
    }
    
    // 🔄 新增：同步状态部分
    /*
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "icloud.and.arrow.up.and.arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.appPrimary)
                
                Text(NSLocalizedString("数据同步", comment: ""))
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            // 使用我们创建的OfflineIndicator组件
            OfflineIndicator()
            
            // 简化的同步状态显示
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("用户配置", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("昵称: 用户", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(NSLocalizedString("语言: 中文", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(NSLocalizedString("订阅: 免费版", comment: ""))
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
    
    // MARK: - AI Model Selection View
    private var aiModelSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Gemini Model Toggle
            HStack {
                Image(systemName: "cloud")
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("使用云端模型", comment: ""))
                        .font(.body)
                        .foregroundColor(.textPrimary)
                    
                    Text(aiManager.useGeminiModel ? NSLocalizedString("云端AI，功能更强大", comment: "") : NSLocalizedString("使用本地设备模型", comment: ""))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { aiManager.useGeminiModel },
                    set: { newValue in
                        let success = aiManager.switchToGemini(newValue)
                        if !success {
                            // 如果切换失败，显示提示
                            showingUpgradeAlert = true
                        }
                    }
                ))
                .tint(.appPrimary)
            }
            
            // Status Information for unsupported devices
            let localStatus = aiManager.getLocalModelStatus()
            if !localStatus.isSupported && !aiManager.useGeminiModel {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(NSLocalizedString("本地模型需要iOS 26.0+，当前使用云端模型", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .alert(NSLocalizedString("系统版本不支持", comment: ""), isPresented: $showingUpgradeAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("本地模型需要iOS 26.0或更高版本，请升级系统以使用此功能", comment: ""))
        }
    }
    
    // MARK: - Helper Functions
    
    private func requestAppStoreReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    private func openAppStore() {
        if let url = URL(string: Config.appStoreURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            showingFeedbackOptions = true
        }
    }
    
    // MARK: - Language Methods
    private func currentLanguageDisplayName() -> String {
        let currentLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? ["en"]
        let currentLanguage = currentLanguages.first ?? "en"
        switch currentLanguage {
        case "zh-Hans":
            return NSLocalizedString("中文（简体）", comment: "")
        default:
            return NSLocalizedString("english", comment: "")
        }
    }
    
    private func changeLanguage(to language: String) {
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Update DataManager
        Task {
            await DataManager.shared.saveUserSettingsWithSync(
                language: language,
                subscriptionStatus: subscriptionManager.isProMember ? "pro" : "free"
            )
        }
        
        showingLanguageChangedAlert = true
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
                    .foregroundColor(.textPrimary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
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
                .foregroundColor(.textPrimary.opacity(0.8))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textPrimary.opacity(0.8))
            
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
                        .fill(isProFeature ? Color.textSecondary.opacity(0.3) : Color.appPrimary.opacity(0.2))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isProFeature ? .textSecondary : .appPrimary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isProFeature ? .textSecondary : .textPrimary)
                        
                        if isProFeature {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.appPrimary)
                        }
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
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
                        .fill(isDestructive ? Color.red.opacity(0.2) : Color.appPrimary.opacity(0.2))
                        .frame(width: 35, height: 35)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDestructive ? .red : .appPrimary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Arrow (only if action is available)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
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
    @Environment(\.dismiss) var dismiss
    
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
            parent.dismiss()
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var username: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Avatar section
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.appPrimary)
                        )
                    
                    Text(NSLocalizedString("编辑个人信息", comment: ""))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }
                .padding(.top, 20)
                
                // Username input
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("用户名", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                    
                    TextField(NSLocalizedString("请输入用户名", comment: ""), text: $username)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.fillSecondary)
                                .stroke(Color.separator.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(NSLocalizedString("编辑资料", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("保存", comment: "")) {
                        onSave(username)
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .fontWeight(.semibold)
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


#Preview {
    ProfileView()
}

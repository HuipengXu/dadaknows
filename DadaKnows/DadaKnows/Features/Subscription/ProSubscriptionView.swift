//
//  ProSubscriptionView.swift
//  DadaKnows
//
//  Pro会员订阅界面
//

import SwiftUI
import StoreKit

struct ProSubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProduct: Product?
    @State private var isShowingPurchaseFlow = false
    
    private var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 渐变背景
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Hero Section
                        heroSection
                        
                        // Subscription Plans
                        if !subscriptionManager.availableProducts.isEmpty {
                            subscriptionPlansSection
                        } else {
                            loadingPlansSection
                        }
                        
                        // Features Highlight
                        featuresSection
                        
                        // Benefits
                        benefitsSection
                        
                        // Terms and Support
                        footerSection
                        
                        Spacer().frame(height: 100) // Space for purchase button
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                // Fixed Purchase Button
                if selectedProduct != nil {
                    VStack {
                        Spacer()
                        purchaseButtonSection
                    }
                }
            }
            .navigationTitle(NSLocalizedString("dadaknows_pro", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("恢复购买", comment: "")) {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.appPrimary)
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .onAppear {
                Task {
                    await subscriptionManager.loadProducts()
                    // 默认选择年付订阅
                    if let annualProduct = subscriptionManager.availableProducts.first(where: { $0.id.contains("annual") }) {
                        selectedProduct = annualProduct
                    }
                }
            }
            .sheet(isPresented: $isShowingPurchaseFlow) {
                purchaseConfirmationSheet
            }
            .alert(NSLocalizedString("错误", comment: ""), isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Button(NSLocalizedString("确定", comment: "")) {
                    subscriptionManager.errorMessage = nil
                }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 24) {
            // Animated Pro Badge
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.appPrimary, .purple, .blue, .appPrimary],
                            center: .center
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.1)
                
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 100, height: 100)
                
                VStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(NSLocalizedString("PRO", comment: ""))
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.appPrimary)
                }
            }
            .shadow(color: .appPrimary.opacity(0.3), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 12) {
                Text(NSLocalizedString("unlimited_exploration", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .appPrimary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(NSLocalizedString("let_curiosity_fly", comment: ""))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(NSLocalizedString("选择订阅计划", comment: ""))
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // 按价值排序：年付 -> 半年付 -> 月付
            let sortedProducts = subscriptionManager.availableProducts.sorted { product1, product2 in
                if product1.id.contains("annual") { return true }
                if product2.id.contains("annual") { return false }
                if product1.id.contains("biannual") { return true }
                if product2.id.contains("biannual") { return false }
                return false
            }
            
            LazyVStack(spacing: 12) {
                ForEach(sortedProducts, id: \.id) { product in
                    ModernSubscriptionCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProduct = product
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Loading Plans Section
    private var loadingPlansSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(NSLocalizedString("Loading subscription plans...", comment: ""))
                    .font(.title2)
                .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 100)
                        .redacted(reason: .placeholder)
                }
            }
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(NSLocalizedString("pro_member_benefits", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(
                    icon: "infinity",
                    title: NSLocalizedString("unlimited_questions", comment: ""),
                    description: NSLocalizedString("break_daily_limits", comment: ""),
                    color: .blue
                )
                
                FeatureCard(
                    icon: "brain.head.profile",
                    title: NSLocalizedString("smart_answers", comment: ""),
                    description: NSLocalizedString("quality_ai_content", comment: ""),
                    color: .purple
                )
                
                FeatureCard(
                    icon: "star.fill",
                    title: NSLocalizedString("priority_access", comment: ""),
                    description: NSLocalizedString("early_features", comment: ""),
                    color: .orange
                )
                
                FeatureCard(
                    icon: "heart.fill",
                    title: NSLocalizedString("support_development", comment: ""),
                    description: NSLocalizedString("help_us_grow", comment: ""),
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(NSLocalizedString("为什么选择Pro？", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ModernBenefitRow(
                    icon: "sparkles",
                    iconColor: .yellow,
                    title: isEnglish ? "Unlock Your Child's Potential" : "释放孩子的潜能",
                    description: isEnglish ? "Let children freely explore the ocean of knowledge and develop lifelong learning habits" : "让孩子自由探索知识的海洋，培养终身学习的习惯"
                )
                
                ModernBenefitRow(
                    icon: "globe.asia.australia.fill",
                    iconColor: .blue,
                    title: isEnglish ? "Global Quality Content" : "全球优质内容",
                    description: isEnglish ? "Access the most advanced AI models for accurate and interesting answers" : "访问最先进的AI模型，获得准确有趣的回答"
                )
                
                ModernBenefitRow(
                    icon: "shield.checkered",
                    iconColor: .green,
                    title: isEnglish ? "Safe and Reliable" : "安全可靠",
                    description: isEnglish ? "Strict content filtering provides a safe learning environment for children" : "严格的内容过滤为孩子提供安全的学习环境"
                )
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("Subscription Terms", comment: ""))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("• Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period", comment: ""))
                Text(NSLocalizedString("• You can cancel your subscription anytime in App Store account settings", comment: ""))
                Text(NSLocalizedString("• Subscription takes effect immediately after activation", comment: ""))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            
            HStack(spacing: 20) {
                Button(NSLocalizedString("Terms of Service", comment: "")) {
                    // 打开服务条款
                }
                .font(.caption)
                .foregroundColor(.appPrimary)
                
                Button(NSLocalizedString("Privacy Policy", comment: "")) {
                    // 打开隐私政策
                }
                .font(.caption)
                .foregroundColor(.appPrimary)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Purchase Button Section
    private var purchaseButtonSection: some View {
        VStack(spacing: 0) {
            // 毛玻璃效果背景
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 100)
                .overlay(
                    VStack(spacing: 12) {
                        if let product = selectedProduct {
                            Button {
                                isShowingPurchaseFlow = true
                            } label: {
                                HStack {
                                    if subscriptionManager.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                            .tint(.white)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text(NSLocalizedString("start_subscription", comment: ""))
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                        Text(product.displayPrice + " / " + planDuration(for: product))
                                            .font(.caption)
                                            .opacity(0.9)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [.appPrimary, .appPrimary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                                .shadow(color: .appPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(subscriptionManager.isLoading)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 10)
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Purchase Confirmation Sheet
    private var purchaseConfirmationSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let product = selectedProduct {
                    // Product details
                    VStack(spacing: 16) {
                        Text(NSLocalizedString("confirm_subscription", comment: ""))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text(planTitle(for: product))
                                .font(.headline)
                            
                            Text(product.displayPrice + " / " + planDuration(for: product))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.appPrimary)
                            
                            if let savings = savingsText(for: product) {
                                Text(savings)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Purchase button
                    Button {
                        Task {
                            await subscriptionManager.purchase(product)
                            if subscriptionManager.errorMessage == nil {
                                isShowingPurchaseFlow = false
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            }
                            Text(NSLocalizedString("confirm_purchase", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appPrimary)
                        .cornerRadius(25)
                    }
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .padding(20)
            .navigationTitle(NSLocalizedString("confirm_subscription", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        isShowingPurchaseFlow = false
                    }
                }
            }
        }
        .presentationDetents([.height(400)])
    }
    
    // MARK: - Helper Methods
    private func planTitle(for product: Product) -> String {
        if product.id.contains("monthly") {
            return NSLocalizedString("subscription_monthly_plan", comment: "")
        } else if product.id.contains("biannual") {
            return NSLocalizedString("subscription_biannual_plan", comment: "")
        } else if product.id.contains("annual") {
            return NSLocalizedString("subscription_annual_plan", comment: "")
        }
        return "Subscription Plan"
    }
    
    private func planDuration(for product: Product) -> String {
        if product.id.contains("monthly") {
            return "month"
        } else if product.id.contains("biannual") {
            return "6 months"
        } else if product.id.contains("annual") {
            return "year"
        }
        return ""
    }
    
    private func savingsText(for product: Product) -> String? {
        if product.id.contains("annual") {
            return "相比月度订阅节省33%"
        } else if product.id.contains("biannual") {
            return "相比月度订阅节省17%"
        }
        return nil
    }
}

// MARK: - Supporting Views

struct ModernSubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appPrimary : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 12, height: 12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(planTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isPopular {
                            Text(NSLocalizedString("recommended", comment: ""))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                        }
                    }
                    
                    HStack(alignment: .bottom, spacing: 8) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                    
                        Text("/ " + planDuration)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                
                Spacer()
                
                        if let savings = savingsText {
                            VStack(alignment: .trailing) {
                                Text(savings)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appPrimary.opacity(0.05) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.appPrimary : Color(.systemGray5),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? Color.appPrimary.opacity(0.2) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var planTitle: String {
        if product.id.contains("monthly") {
            return NSLocalizedString("subscription_monthly_plan", comment: "")
        } else if product.id.contains("biannual") {
            return NSLocalizedString("subscription_biannual_plan", comment: "")
        } else if product.id.contains("annual") {
            return NSLocalizedString("subscription_annual_plan", comment: "")
        }
        return "Subscription Plan"
    }
    
    private var planDuration: String {
        if product.id.contains("monthly") {
            return "month"
        } else if product.id.contains("biannual") {
            return "6 months"
        } else if product.id.contains("annual") {
            return "year"
        }
        return ""
    }
    
    private var isPopular: Bool {
        product.id.contains("annual")
    }
    
    private var savingsText: String? {
        if product.id.contains("annual") {
            return String(format: NSLocalizedString("save_percentage", comment: ""), "33%")
        } else if product.id.contains("biannual") {
            return String(format: NSLocalizedString("save_percentage", comment: ""), "17%")
        }
        return nil
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct ModernBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProSubscriptionView()
}

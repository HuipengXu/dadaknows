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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerSection
                        
                        // Subscription Plans
                        if !subscriptionManager.availableProducts.isEmpty {
                            subscriptionPlansSection
                        }
                        
                        // Benefits
                        benefitsSection
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("升级到Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(.vibrantOrange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("恢复购买") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.vibrantOrange)
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .onAppear {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
            .alert("错误", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Button("确定") {
                    subscriptionManager.errorMessage = nil
                }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Pro Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.vibrantOrange, .tenderYellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                VStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .shadow(color: Color.vibrantOrange.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("升级到Pro，无限次提问")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Text("移除每日使用限制，尽情探索知识")
                    .font(.subheadline)
                    .foregroundColor(.lightGray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var subscriptionPlansSection: some View {
        VStack(spacing: 20) {
            Text("选择订阅计划")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.darkGray)
            
            VStack(spacing: 12) {
                ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                    SubscriptionPlanCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        onSelect: {
                            selectedProduct = product
                        },
                        onPurchase: {
                            Task {
                                await subscriptionManager.purchase(product)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            Text("为什么选择Pro？")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.darkGray)
            
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "infinity",
                    title: "无限制使用",
                    description: "每天可以问无限个问题，满足孩子的好奇心"
                )
                
                BenefitRow(
                    icon: "sparkles",
                    title: "支持我们",
                    description: "您的支持能帮助我们持续改进，提供更好的服务"
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(planTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.darkGray)
                        
                        if isPopular {
                            Text("最受欢迎")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.vibrantOrange)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.vibrantOrange)
                    
                    if let savings = savingsText {
                        Text(savings)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Button(action: onPurchase) {
                        HStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("购买")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.vibrantOrange)
                        .cornerRadius(20)
                    }
                    .disabled(subscriptionManager.isLoading)
                }
            }
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.vibrantOrange : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var planTitle: String {
        if product.id.contains("monthly") {
            return "月度订阅"
        } else if product.id.contains("yearly") {
            return "年度订阅"
        } else if product.id.contains("lifetime") {
            return "终身会员"
        }
        return "订阅计划"
    }
    
    private var isPopular: Bool {
        product.id.contains("yearly")
    }
    
    private var savingsText: String? {
        if product.id.contains("yearly") {
            return "相比月度订阅节省20%"
        } else if product.id.contains("lifetime") {
            return "一次购买，终身享用"
        }
        return nil
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.vibrantOrange.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.vibrantOrange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.darkGray)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.lightGray)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProSubscriptionView()
}

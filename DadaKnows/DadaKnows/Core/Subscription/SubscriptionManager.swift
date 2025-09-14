//
//  SubscriptionManager.swift
//  DadaKnows
//
//  订阅管理器 - 处理Pro会员订阅
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isProMember = false
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var availableProducts: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 产品ID
    private let productIDs = [
        "com.dadaknows.pro.monthly",
        "com.dadaknows.pro.yearly",
        "com.dadaknows.pro.lifetime"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        updateListenerTask = listenForTransactions()
        loadStoredSubscriptionStatus()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIDs)
            self.availableProducts = products.sorted { $0.price < $1.price }
            
            await checkSubscriptionStatus()
        } catch {
            self.errorMessage = "加载产品失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try await checkVerified(verification)
                await updateSubscriptionStatus(for: transaction)
                await transaction.finish()
                
            case .userCancelled:
                // 用户取消购买
                break
                
            case .pending:
                // 购买待处理（例如需要家长批准）
                self.errorMessage = "购买正在处理中，请稍后查看"
                
            @unknown default:
                self.errorMessage = "未知的购买结果"
            }
        } catch {
            self.errorMessage = "购买失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            self.errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    
    private func checkSubscriptionStatus() async {
        var hasActiveSubscription = false
        var currentProducts: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                
                if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
                    currentProducts.append(product)
                    
                    // 检查订阅是否仍然有效
                    if transaction.productType == .autoRenewable {
                        hasActiveSubscription = true
                    } else if transaction.productType == .nonConsumable {
                        // 终身会员
                        hasActiveSubscription = true
                    }
                }
            } catch {
                print("❌ 验证交易失败: \(error)")
            }
        }
        
        self.purchasedProducts = currentProducts
        self.isProMember = hasActiveSubscription
        self.subscriptionStatus = hasActiveSubscription ? .active : .inactive
        
        // 保存订阅状态
        saveSubscriptionStatus()
    }
    
    private func updateSubscriptionStatus(for transaction: Transaction) async {
        if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
            if !purchasedProducts.contains(product) {
                purchasedProducts.append(product)
            }
            
            isProMember = true
            subscriptionStatus = .active
            saveSubscriptionStatus()
        }
    }
    
    // MARK: - Transaction Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("❌ 处理交易更新失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveSubscriptionStatus() {
        UserDefaults.standard.set(isProMember, forKey: "isProMember")
        UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
    }
    
    private func loadStoredSubscriptionStatus() {
        isProMember = UserDefaults.standard.bool(forKey: "isProMember")
        
        if let statusRawValue = UserDefaults.standard.object(forKey: "subscriptionStatus") as? String,
           let status = SubscriptionStatus(rawValue: statusRawValue) {
            subscriptionStatus = status
        }
    }
    
    // MARK: - Pro Features
    
    func canUseFeature() -> Bool {
        return true
    }

    // MARK: - Usage Tracking
    
    private var dailyQuestionCount: Int {
        get {
            let today = Calendar.current.startOfDay(for: Date())
            let lastResetDate = UserDefaults.standard.object(forKey: "lastQuestionCountReset") as? Date ?? Date.distantPast
            
            if Calendar.current.startOfDay(for: lastResetDate) < today {
                // 新的一天，重置计数
                UserDefaults.standard.set(0, forKey: "dailyQuestionCount")
                UserDefaults.standard.set(today, forKey: "lastQuestionCountReset")
                return 0
            }
            
            return UserDefaults.standard.integer(forKey: "dailyQuestionCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "dailyQuestionCount")
        }
    }
    
    func canAskQuestion() -> Bool {
        if isProMember {
            return true
        }
        
        // 如果正在使用端侧模型，则不限制使用次数
        if AIManager.shared.isUsingOnDeviceModel {
            return true
        }
        
        return dailyQuestionCount < 20
    }
    
    func incrementQuestionCount() {
        if !isProMember {
            dailyQuestionCount += 1
        }
    }
    
    func getRemainingQuestions() -> Int? {
        if isProMember {
            return nil // 无限制
        }
        
        let limit = 20
        return max(0, limit - dailyQuestionCount)
    }
}

// MARK: - Supporting Types

enum SubscriptionStatus: String, CaseIterable {
    case unknown = "unknown"
    case active = "active"
    case inactive = "inactive"
    case expired = "expired"
    case inGracePeriod = "inGracePeriod"
}

enum SubscriptionError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "购买验证失败"
        case .productNotFound:
            return "产品未找到"
        case .purchaseFailed:
            return "购买失败"
        }
    }
}

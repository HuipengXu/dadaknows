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
    
    // 产品ID - 与App Store Connect配置保持一致
    private let productIDs = [
        "com.dadaknows.DadaKnows.monthly",    // 高级会员-月付
        "com.dadaknows.DadaKnows.biannual",   // 高级会员-半年付
        "com.dadaknows.DadaKnows.annual"      // 高级会员-年付
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 延迟启动交易监听，避免模拟器或未登录账号时报错
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
            // 按推荐优先级排序：年付 -> 半年付 -> 月付
            self.availableProducts = products.sorted { product1, product2 in
                if product1.id.contains("annual") { return true }
                if product2.id.contains("annual") { return false }
                if product1.id.contains("biannual") { return true }
                if product2.id.contains("biannual") { return false }
                return product1.price > product2.price
            }
            
            await checkSubscriptionStatus()
            // 在成功加载产品后启动交易监听（仅一次；模拟器跳过）
            #if !targetEnvironment(simulator)
            if updateListenerTask == nil {
                updateListenerTask = listenForTransactions()
            }
            #endif
        } catch {
            self.errorMessage = "加载产品失败: \(error.localizedDescription)"
            print("❌ StoreKit 产品加载失败: \(error)")
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
        #if targetEnvironment(simulator)
        // 模拟器环境没有 App Store 账户，跳过交易枚举以避免 ASDErrorDomain 509 噪音
        self.purchasedProducts = []
        self.isProMember = false
        self.subscriptionStatus = .inactive
        saveSubscriptionStatus()
        #else
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
        #endif
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
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self = self else { return }
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
    
    @Published var monthlyRemaining: Int = Config.monthlyProQuestionLimit
    @Published var monthlyUsageCount: Int = 0
    private let monthlyLimit = Config.monthlyProQuestionLimit
    
    private var dailyQuestionCount: Int {
        get {
            // 检查是否需要重置（24小时后重置逻辑）
            checkAndResetDailyCountIfNeeded()
            return UserDefaults.standard.integer(forKey: "dailyQuestionCount")
        }
        set {
            let oldValue = dailyQuestionCount
            UserDefaults.standard.set(newValue, forKey: "dailyQuestionCount")

            // 如果用户刚刚达到每日限制（2次），记录限制到达时间
            if newValue >= Config.dailyFreeQuestionLimit && oldValue < Config.dailyFreeQuestionLimit {
                UserDefaults.standard.set(Date(), forKey: "lastDailyLimitReachedTime")
                if Config.isDebug {
                    print("📊 SubscriptionManager: 用户达到每日限制，记录限制到达时间")
                }
            }

            if Config.isDebug {
                print("📊 SubscriptionManager: 每日计数更新 \(oldValue) -> \(newValue)")
            }
        }
    }

    /// 检查并重置每日计数（如果距离上次限制达到已超过24小时）
    private func checkAndResetDailyCountIfNeeded() {
        guard let limitReachedTime = UserDefaults.standard.object(forKey: "lastDailyLimitReachedTime") as? Date else {
            // 如果从未达到过限制，使用旧的午夜重置逻辑
            let today = Calendar.current.startOfDay(for: Date())
            let lastResetDate = UserDefaults.standard.object(forKey: "lastQuestionCountReset") as? Date ?? Date.distantPast

            if Calendar.current.startOfDay(for: lastResetDate) < today {
                UserDefaults.standard.set(0, forKey: "dailyQuestionCount")
                UserDefaults.standard.set(today, forKey: "lastQuestionCountReset")
            }
            return
        }

        // 24小时后重置逻辑
        let resetTime = Calendar.current.date(byAdding: .hour, value: 24, to: limitReachedTime) ?? limitReachedTime
        if Date() >= resetTime {
            UserDefaults.standard.set(0, forKey: "dailyQuestionCount")
            UserDefaults.standard.removeObject(forKey: "lastDailyLimitReachedTime")
            if Config.isDebug {
                print("📊 SubscriptionManager: 24小时限制已过期，重置每日计数")
            }
        }
    }

    /// 获取下次重置时间（24小时后）
    func getNextResetTime() -> Date? {
        guard let limitReachedTime = UserDefaults.standard.object(forKey: "lastDailyLimitReachedTime") as? Date else {
            // 如果从未达到限制，返回今天午夜
            return Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        }

        // 返回24小时后的时间
        return Calendar.current.date(byAdding: .hour, value: 24, to: limitReachedTime)
    }
    
    /// 检查是否可以提问（考虑日限制和月限制）
    func canAskQuestion() async -> Bool {
        // 如果正在使用端侧模型，则不限制使用次数
        if AIManager.shared.isUsingOnDeviceModel {
            return true
        }
        
        // Pro用户需要检查月度限制
        if isProMember {
            await fetchMonthlyUsage()
            return monthlyUsageCount < monthlyLimit
        }
        
        // 免费用户检查日限制
        return dailyQuestionCount < Config.dailyFreeQuestionLimit
    }
    
    /// 同步版本的检查（用于快速UI判断）
    func canAskQuestionSync() -> Bool {
        // 如果正在使用端侧模型，则不限制使用次数
        if AIManager.shared.isUsingOnDeviceModel {
            return true
        }
        
        // Pro用户检查月度限制（使用缓存值）
        if isProMember {
            return monthlyUsageCount < monthlyLimit
        }
        
        // 免费用户检查日限制
        return dailyQuestionCount < Config.dailyFreeQuestionLimit
    }
    
    private var lastIncrementTime: Date?
    
    /// 增加使用次数（仅用于免费用户的日计数）
    func incrementQuestionCount() {
        if !isProMember {
            // 防止重复计数（1秒内多次调用只算一次）
            if let lastTime = lastIncrementTime, Date().timeIntervalSince(lastTime) < 1.0 {
                if Config.isDebug {
                    print("⚠️ SubscriptionManager: 忽略重复计数调用")
                }
                return
            }
            
            dailyQuestionCount += 1
            lastIncrementTime = Date()
        }
    }
    
    /// 获取剩余提问次数
    func getRemainingQuestions() -> Int? {
        // 如果正在使用端侧模型，返回无限制
        if AIManager.shared.isUsingOnDeviceModel {
            return nil
        }
        
        if isProMember {
            // Pro用户返回月度剩余次数
            return max(0, monthlyLimit - monthlyUsageCount)
        }
        
        // 免费用户返回日剩余次数
        let limit = Config.dailyFreeQuestionLimit
        return max(0, limit - dailyQuestionCount)
    }
    
    /// 从服务器获取月度使用情况
    func fetchMonthlyUsage() async {
        guard isProMember else { return }
        
        // 获取当前用户ID
        guard let userId = SupabaseClient.shared.getCurrentUserId() else {
            if Config.isDebug {
                print("⚠️ SubscriptionManager: 无法获取用户ID")
            }
            return
        }
        
        do {
            let result = try await SupabaseClient.shared.checkMonthlyUsage(userId: userId)
            
            await MainActor.run {
                self.monthlyUsageCount = result.currentUsage
                self.monthlyRemaining = result.remaining
            }
            
            if Config.isDebug {
                print("📊 SubscriptionManager: 月度使用情况 - \(result.currentUsage)/\(monthlyLimit) (剩余: \(result.remaining))")
            }
        } catch {
            if Config.isDebug {
                print("❌ SubscriptionManager: 获取月度使用情况失败 - \(error)")
            }
        }
    }
    
    // MARK: - Product Helper Methods
    
    /// 获取指定类型的产品
    func getProduct(for type: SubscriptionType) -> Product? {
        return availableProducts.first { product in
            switch type {
            case .monthly:
                return product.id.contains("monthly")
            case .biannual:
                return product.id.contains("biannual")
            case .annual:
                return product.id.contains("annual")
            }
        }
    }
    
    /// 获取推荐的订阅产品（年付）
    var recommendedProduct: Product? {
        return getProduct(for: .annual) ?? availableProducts.first
    }
    
    /// 获取当前活跃的订阅产品
    var activeSubscriptionProduct: Product? {
        return purchasedProducts.first
    }
    
    /// 计算年付相比月付的节省比例
    func calculateAnnualSavings() -> Double? {
        guard let monthlyProduct = getProduct(for: .monthly),
              let annualProduct = getProduct(for: .annual) else {
            return nil
        }
        
        let monthlyYearCost = monthlyProduct.price * Decimal(12)
        let annualCost = annualProduct.price
        
        if monthlyYearCost == 0 {
            return nil
        }
        
        let savings = (monthlyYearCost - annualCost) as NSDecimalNumber
        let total = monthlyYearCost as NSDecimalNumber
        
        return savings.doubleValue / total.doubleValue
    }
    
    /// 计算半年付相比月付的节省比例
    func calculateBiannualSavings() -> Double? {
        guard let monthlyProduct = getProduct(for: .monthly),
              let biannualProduct = getProduct(for: .biannual) else {
            return nil
        }
        
        let monthlySixMonthCost = monthlyProduct.price * Decimal(6)
        let biannualCost = biannualProduct.price
        
        if monthlySixMonthCost == 0 {
            return nil
        }
        
        let savings = (monthlySixMonthCost - biannualCost) as NSDecimalNumber
        let total = monthlySixMonthCost as NSDecimalNumber
        
        return savings.doubleValue / total.doubleValue
    }
}

// MARK: - Supporting Types

enum SubscriptionType: String, CaseIterable {
    case monthly = "monthly"
    case biannual = "biannual"
    case annual = "annual"
    
    var displayName: String {
        switch self {
        case .monthly:
            return "高级会员-月付"
        case .biannual:
            return "高级会员-半年付"
        case .annual:
            return "高级会员-年付"
        }
    }
    
    var duration: String {
        switch self {
        case .monthly:
            return "月"
        case .biannual:
            return "半年"
        case .annual:
            return "年"
        }
    }
}

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

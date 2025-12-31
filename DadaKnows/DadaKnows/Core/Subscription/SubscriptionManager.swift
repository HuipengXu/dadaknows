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
    @Published var errorDetails: String?  // 详细的错误诊断信息
    
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
        print("🔵 开始加载产品...")
        print("🔵 产品 ID: \(productIDs)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔵 正在调用 Product.products(for:)...")
            let products = try await Product.products(for: productIDs)
            print("🔵 成功获取到 \(products.count) 个产品")
            
            for product in products {
                print("🔵 产品: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
            
            // 按推荐优先级排序：年付 -> 半年付 -> 月付
            // 按推荐优先级排序：年付 -> 半年付 -> 月付
            self.availableProducts = products.sorted { product1, product2 in
                let isProduct1Annual = product1.id.contains("annual") && !product1.id.contains("biannual")
                let isProduct2Annual = product2.id.contains("annual") && !product2.id.contains("biannual")
                
                if isProduct1Annual { return true }
                if isProduct2Annual { return false }
                if product1.id.contains("biannual") { return true }
                if product2.id.contains("biannual") { return false }
                return product1.price > product2.price
            }
            
            print("🔵 已排序产品，共 \(self.availableProducts.count) 个")
            
            // 在成功加载产品后启动交易监听
            if updateListenerTask == nil {
                updateListenerTask = listenForTransactions()
            }
        } catch {
            self.errorMessage = "加载产品失败: \(error.localizedDescription)"
            let nsError = error as NSError
            self.errorDetails = """
错误类型: \(type(of: error))
Domain: \(nsError.domain)
Code: \(nsError.code)
UserInfo: \(nsError.userInfo)

请求的产品ID: \(productIDs.joined(separator: ", "))
已加载的产品数量: \(availableProducts.count)
"""
            print("❌ StoreKit 产品加载失败: \(error)")
            print("❌ 错误详情: \(error)")
            print("❌ 详细诊断: \(errorDetails ?? "")")
        }
        
        isLoading = false
        print("🔵 加载完成，isLoading = false, 产品数量 = \(self.availableProducts.count)")
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        errorDetails = nil

        // 验证产品是否已加载
        if availableProducts.isEmpty {
            self.errorMessage = "产品信息未加载，请稍后重试"
            self.errorDetails = """
错误: availableProducts.count = 0
已加载的产品数量为0，请检查：
1. 网络连接是否正常
2. App Store Connect中产品是否已配置
3. 产品ID是否正确: \(product.id)
"""
            print("❌ 产品未加载: \(errorDetails ?? "")")
            isLoading = false
            return
        }

        // 验证购买的产品是否在已加载列表中
        guard availableProducts.contains(where: { $0.id == product.id }) else {
            self.errorMessage = "购买的产品不可用：\(product.id)"
            self.errorDetails = """
请求的产品ID: \(product.id)
已加载的产品: \(availableProducts.map { $0.id }.joined(separator: ", "))
产品可能在App Store Connect中未配置或状态不可用
"""
            print("❌ 产品不可用: \(errorDetails ?? "")")
            isLoading = false
            return
        }

        // 添加详细日志
        print("💰 [SubscriptionManager] 开始购买流程")
        print("💰 产品ID: \(product.id)")
        print("💰 产品价格: \(product.displayPrice)")
        print("💰 当前订阅状态: \(subscriptionStatus.rawValue)")
        print("💰 是否为Pro会员: \(isProMember)")

        do {
            let result = try await product.purchase()

            print("💰 购买结果: \(result)")

            switch result {
            case .success(let verification):
                print("✅ 购买成功，开始验证交易...")

                let transaction = try await checkVerified(verification)
                print("✅ 交易验证成功")
                print("✅ 交易ID: \(transaction.id)")
                print("✅ 产品ID: \(transaction.productID)")
                print("✅ 产品类型: \(transaction.productType.rawValue)")
                print("✅ 购买时间: \(transaction.purchaseDate)")
                print("✅ 原始购买时间: \(transaction.originalPurchaseDate)")
                if let expirationDate = transaction.expirationDate {
                    print("✅ 过期时间: \(expirationDate)")
                    let duration = expirationDate.timeIntervalSince(transaction.purchaseDate)
                    print("✅ 订阅时长(秒): \(duration) = \(duration / 60)分钟 = \(duration / 3600)小时")
                } else {
                    print("✅ 无过期时间（可能是终身购买）")
                }

                await transaction.finish()
                print("✅ 交易已finish")

                // 等待StoreKit处理完成
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟

                // 重新检查所有订阅状态
                print("🔄 重新检查订阅状态...")
                await checkSubscriptionStatus()
                print("🔄 订阅状态更新完成: isPro=\(isProMember), status=\(subscriptionStatus.rawValue)")

            case .userCancelled:
                print("❌ 用户取消购买")
                // 用户取消购买
                break

            case .pending:
                print("⏳ 购买待处理")
                // 购买待处理（例如需要家长批准）
                self.errorMessage = "购买正在处理中,请稍后查看"

            @unknown default:
                print("⚠️ 未知的购买结果")
                self.errorMessage = "未知的购买结果"
            }
        } catch let error as StoreKitError {
            // 详细的StoreKit错误处理
            print("❌ StoreKit错误: \(error)")
            print("❌ 错误描述: \(error.localizedDescription)")

            let nsError = error as NSError
            self.errorDetails = """
StoreKit错误
错误类型: \(type(of: error))
Domain: \(nsError.domain)
Code: \(nsError.code)
描述: \(error.localizedDescription)
UserInfo: \(nsError.userInfo)

产品ID: \(product.id)
产品价格: \(product.displayPrice)
已加载的产品: \(availableProducts.map { "\($0.id) - \($0.displayPrice)" }.joined(separator: "\n"))
"""

            switch error {
            case .userCancelled:
                print("❌ 用户取消（StoreKitError）")
                // User cancelled, do nothing
                break

            case .networkError(let urlError):
                print("❌ 网络错误: \(urlError)")
                print("❌ URL错误代码: \(urlError.code.rawValue)")
                let urlNsError = urlError as NSError
                print("❌ URL错误域: \(urlNsError.domain)")
                self.errorMessage = "网络连接失败，请检查网络后重试"

            case .systemError(let systemError):
                print("❌ 系统错误: \(systemError)")

                // 检查是否是App Store配置问题
                let systemNsError = systemError as NSError
                print("❌ NSError domain: \(systemNsError.domain)")
                print("❌ NSError code: \(systemNsError.code)")
                print("❌ NSError userInfo: \(systemNsError.userInfo)")

                if systemNsError.domain == "NSCocoaErrorDomain" {
                    switch systemNsError.code {
                    case 1002: // NSURLErrorCancelled
                        self.errorMessage = "购买已取消"
                    case 4...1000: // 网络相关错误
                        self.errorMessage = "网络连接不稳定，请重试"
                    default:
                        self.errorMessage = "系统错误: \(systemError.localizedDescription)"
                    }
                } else {
                    self.errorMessage = "系统错误: \(systemError.localizedDescription)"
                }

            case .notAvailableInStorefront:
                print("❌ 当前商店不可用")
                self.errorMessage = "当前商店不可用，请检查Apple ID设置"

            @unknown default:
                print("❌ 未知的StoreKit错误: \(error)")
                self.errorMessage = "购买失败: \(error.localizedDescription)"
            }

        } catch {
            // 捕获所有其他错误
            print("❌ 通用错误: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            print("❌ 错误描述: \(error.localizedDescription)")

            // 检查是否是特定错误类型
            let nsError = error as NSError
            print("❌ NSError domain: \(nsError.domain)")
            print("❌ NSError code: \(nsError.code)")
            print("❌ NSError userInfo: \(nsError.userInfo)")

            self.errorDetails = """
通用错误
错误类型: \(type(of: error))
Domain: \(nsError.domain)
Code: \(nsError.code)
描述: \(error.localizedDescription)
UserInfo: \(nsError.userInfo)

产品ID: \(product.id)
产品价格: \(product.displayPrice)
"""

            self.errorMessage = "购买失败: \(error.localizedDescription)"
        }

        isLoading = false
        print("💰 购买流程结束")
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        var syncError: Error?
        
        do {
            try await AppStore.sync()
        } catch {
            syncError = error
            print("⚠️ 恢复购买时 AppStore.sync 失败: \(error)")
        }
        
        // 无论 sync 是否成功，都检查当前的 entitlements
        await checkSubscriptionStatus()
        
        // 只有当 sync 失败且用户仍然不是会员时，才显示错误
        if let error = syncError, !isProMember {
            self.errorMessage = "恢复购买失败: \(error.localizedDescription)"
        } else if syncError != nil && isProMember {
            // 如果 sync 失败但我们发现了有效的订阅（可能来自本地缓存），则不向用户报错，只是打印日志
            print("✅ 虽然 AppStore.sync 失败，但成功检测到有效订阅")
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Status

    func checkSubscriptionStatus() async {
        // 移除模拟器限制，允许在模拟器中使用 StoreKit 配置文件进行测试
        var hasActiveSubscription = false
        var currentProducts: [Product] = []
        
        var latestExpirationDate: Date?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)

                if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
                    currentProducts.append(product)

                    // 检查订阅是否仍然有效
                    if transaction.productType == .autoRenewable {
                        hasActiveSubscription = true
                        print("📅 [checkSubscriptionStatus] 交易ID: \(transaction.id)")
                        print("📅 [checkSubscriptionStatus] 购买时间: \(transaction.purchaseDate)")
                        print("📅 [checkSubscriptionStatus] 过期时间: \(transaction.expirationDate?.description ?? "nil")")
                        // 记录最晚的过期时间
                        if let date = transaction.expirationDate {
                            if latestExpirationDate == nil || date > latestExpirationDate! {
                                latestExpirationDate = date
                                print("📅 [checkSubscriptionStatus] 更新最新过期时间为: \(date)")
                            }
                        }
                    } else if transaction.productType == .nonConsumable {
                        // 终身会员
                        hasActiveSubscription = true
                        latestExpirationDate = nil // 终身会员无过期时间
                    }
                }
            } catch {
                print("❌ 验证交易失败: \(error)")
            }
        }

        self.expirationDate = latestExpirationDate
        
        self.purchasedProducts = currentProducts
        self.isProMember = hasActiveSubscription
        self.subscriptionStatus = hasActiveSubscription ? .active : .inactive
        
        // 保存订阅状态
        saveSubscriptionStatus()
    }
    
    @Published var expirationDate: Date?
    
    private func updateSubscriptionStatus(for transaction: Transaction) async {
        if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
            if !purchasedProducts.contains(product) {
                purchasedProducts.append(product)
            }
            
            isProMember = true
            subscriptionStatus = .active
            expirationDate = transaction.expirationDate
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

    // 防抖相关属性
    private var lastIncrementTime: Date?
    private var lastFetchTime: Date?
    
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
    
    /// 增加Pro用户的月度使用次数（本地乐观更新）
    func incrementMonthlyUsage() {
        guard isProMember else { return }

        // 防止重复计数（1秒内多次调用只算一次）
        if let lastTime = lastIncrementTime, Date().timeIntervalSince(lastTime) < 1.0 {
            if Config.isDebug {
                print("⚠️ SubscriptionManager: 忽略重复月度计数调用")
            }
            return
        }

        monthlyUsageCount += 1
        monthlyRemaining = max(0, monthlyLimit - monthlyUsageCount)
        lastIncrementTime = Date()

        if Config.isDebug {
            print("📊 SubscriptionManager: 本地更新月度使用计数 -> \(monthlyUsageCount)")
        }
    }
    
    /// 获取当前日使用次数（供外部访问）
    func getCurrentDailyCount() -> Int {
        return dailyQuestionCount
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

        // 防抖：如果最近刚刚获取过数据，跳过本次请求
        let now = Date()
        if let lastFetch = lastFetchTime, now.timeIntervalSince(lastFetch) < 2.0 {
            if Config.isDebug {
                print("⚠️ SubscriptionManager: 防抖跳过月度使用情况获取")
            }
            return
        }
        lastFetchTime = now

        // 获取当前用户ID
        guard let userId = SupabaseClient.shared.getCurrentUserId() else {
            if Config.isDebug {
                print("⚠️ SubscriptionManager: 无法获取用户ID")
            }
            return
        }

        // 延迟获取，避免立即覆盖本地乐观更新
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟

        do {
            let result = try await SupabaseClient.shared.checkMonthlyUsage(userId: userId)

            await MainActor.run {
                // 检查服务器返回的使用次数是否比本地当前次数少
                // 如果服务器数据更少，可能是由于网络延迟导致的数据不一致
                // 在这种情况下，保持本地的乐观更新
                if result.currentUsage >= self.monthlyUsageCount {
                    // 服务器数据不小于本地数据，使用服务器数据
                    let oldCount = self.monthlyUsageCount
                    self.monthlyUsageCount = result.currentUsage
                    self.monthlyRemaining = result.remaining

                    if Config.isDebug {
                        print("📊 SubscriptionManager: 服务器同步月度使用情况 \(oldCount) -> \(result.currentUsage)/\(monthlyLimit) (剩余: \(result.remaining))")
                    }
                } else {
                    // 服务器数据小于本地数据，保持本地乐观更新
                    if Config.isDebug {
                        print("📊 SubscriptionManager: 保持本地乐观更新，本地: \(self.monthlyUsageCount), 服务器: \(result.currentUsage)")
                    }
                }
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
                return product.id.contains("annual") && !product.id.contains("biannual")
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

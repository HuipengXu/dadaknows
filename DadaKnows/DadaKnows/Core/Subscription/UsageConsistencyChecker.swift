//
//  UsageConsistencyChecker.swift
//  DadaKnows
//
//  数据一致性检查工具
//

import Foundation

/// 使用情况数据一致性检查器
class UsageConsistencyChecker {
    static let shared = UsageConsistencyChecker()

    private init() {}

    /// 检查并修复Pro用户使用数据的一致性
    func checkAndFixProUsageConsistency() async {
        let subscriptionManager = await SubscriptionManager.shared

        guard await subscriptionManager.isProMember else {
            if Config.isDebug {
                print("🔍 UsageConsistencyChecker: 非Pro用户，跳过一致性检查")
            }
            return
        }

        do {
            // 获取当前用户ID
            guard let userId = await SupabaseClient.shared.getCurrentUserId() else {
                if Config.isDebug {
                    print("⚠️ UsageConsistencyChecker: 无法获取用户ID")
                }
                return
            }

            // 获取服务器数据
            let serverUsage = try await SupabaseClient.shared.checkMonthlyUsage(userId: userId)
            let localUsage = await subscriptionManager.monthlyUsageCount

            await MainActor.run {
                let difference = serverUsage.currentUsage - localUsage

                if abs(difference) > 1 {
                    // 数据差异较大，需要修复
                    if Config.isDebug {
                        print("🔧 UsageConsistencyChecker: 检测到数据不一致 - 本地: \(localUsage), 服务器: \(serverUsage.currentUsage), 差异: \(difference)")
                    }

                    // 选择较大的值作为正确值（通常服务器数据更可靠，但本地可能有未同步的更新）
                    let correctedUsage = max(localUsage, serverUsage.currentUsage)
                    subscriptionManager.monthlyUsageCount = correctedUsage
                    subscriptionManager.monthlyRemaining = max(0, Config.monthlyProQuestionLimit - correctedUsage)

                    if Config.isDebug {
                        print("🔧 UsageConsistencyChecker: 已修复使用次数 - 设为: \(correctedUsage)")
                    }
                } else {
                    if Config.isDebug {
                        print("✅ UsageConsistencyChecker: 数据一致性检查通过 - 本地: \(localUsage), 服务器: \(serverUsage.currentUsage)")
                    }
                }
            }

        } catch {
            if Config.isDebug {
                print("❌ UsageConsistencyChecker: 一致性检查失败 - \(error)")
            }
        }
    }

    /// 检查免费用户使用数据的一致性
    func checkAndFixFreeUsageConsistency() async {
        let subscriptionManager = await SubscriptionManager.shared

        guard await !subscriptionManager.isProMember else {
            if Config.isDebug {
                print("🔍 UsageConsistencyChecker: Pro用户，跳过免费用户一致性检查")
            }
            return
        }

        // 免费用户的本地计数通常不需要服务器同步
        // 这里主要检查计数是否合理（例如：异常的大数值）
        let dailyCount = await subscriptionManager.getCurrentDailyCount()

        if dailyCount > Config.dailyFreeQuestionLimit + 10 {
            // 异常情况，重置计数
            if Config.isDebug {
                print("🔧 UsageConsistencyChecker: 检测到异常的免费用户计数: \(dailyCount)，重置为限制值")
            }

            await MainActor.run {
                UserDefaults.standard.set(Config.dailyFreeQuestionLimit, forKey: "dailyQuestionCount")
            }
        } else {
            if Config.isDebug {
                print("✅ UsageConsistencyChecker: 免费用户计数正常: \(dailyCount)/\(Config.dailyFreeQuestionLimit)")
            }
        }
    }

    /// 执行完整的一致性检查
    func performConsistencyCheck() async {
        if Config.isDebug {
            print("🔍 UsageConsistencyChecker: 开始执行一致性检查...")
        }

        if await SubscriptionManager.shared.isProMember {
            await checkAndFixProUsageConsistency()
        } else {
            await checkAndFixFreeUsageConsistency()
        }

        if Config.isDebug {
            print("🔍 UsageConsistencyChecker: 一致性检查完成")
        }
    }

    /// 定期执行一致性检查（可在应用启动时调用）
    func schedulePeriodicCheck() {
        Task {
            // 延迟5秒执行，避免应用启动时的网络拥塞
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await performConsistencyCheck()
        }
    }
}
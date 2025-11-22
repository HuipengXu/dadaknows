//
//  OTPRateLimiter.swift
//  DadaKnows
//
//  验证码发送频率限制器 - 防止恶意攻击
//

import Foundation

@MainActor
class OTPRateLimiter {
    static let shared = OTPRateLimiter()
    
    // MARK: - Configuration
    
    /// 时间窗口（秒）
    private let timeWindowSeconds: TimeInterval = 300 // 5分钟
    
    /// 时间窗口内最大发送次数
    private let maxAttemptsInWindow = 3
    
    /// 达到限制后的冷却时间（秒）
    private let cooldownSeconds: TimeInterval = 900 // 15分钟
    
    // MARK: - Storage Keys
    
    private let storageKey = "com.dadaknows.otp.sendhistory"
    private let cooldownKey = "com.dadaknows.otp.cooldown"
    
    // MARK: - Data Models
    
    private struct SendRecord: Codable {
        let email: String
        let timestamp: Date
    }
    
    private struct CooldownRecord: Codable {
        let email: String
        let endTime: Date
    }
    
    private init() {
        cleanupExpiredRecords()
    }
    
    // MARK: - Public Methods
    
    /// 检查是否可以发送验证码
    /// - Parameter email: 邮箱地址
    /// - Returns: (canSend: 是否可以发送, remainingTime: 剩余等待时间秒数, message: 错误消息)
    func canSendOTP(for email: String) -> (canSend: Bool, remainingTime: TimeInterval, message: String?) {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 1. 检查是否在冷却期
        if let cooldownEnd = getCooldownEndTime(for: normalizedEmail) {
            let remaining = cooldownEnd.timeIntervalSinceNow
            if remaining > 0 {
                let minutes = Int(ceil(remaining / 60))
                return (false, remaining, "发送次数过多，请在 \(minutes) 分钟后再试")
            } else {
                // 冷却期已过，清除记录
                removeCooldown(for: normalizedEmail)
            }
        }
        
        // 2. 检查时间窗口内的发送次数
        let recentSends = getRecentSends(for: normalizedEmail)
        
        if recentSends.count >= maxAttemptsInWindow {
            // 达到限制，设置冷却期
            setCooldown(for: normalizedEmail)
            let minutes = Int(ceil(cooldownSeconds / 60))
            return (false, cooldownSeconds, "发送过于频繁，请 \(minutes) 分钟后再试")
        }
        
        // 3. 检查最小发送间隔（60秒，与通常的邮件服务限制保持一致）
        if let lastSend = recentSends.last {
            let timeSinceLastSend = Date().timeIntervalSince(lastSend.timestamp)
            if timeSinceLastSend < 60 {
                let remaining = 60 - timeSinceLastSend
                return (false, remaining, "请等待 \(Int(ceil(remaining))) 秒后重试")
            }
        }
        
        return (true, 0, nil)
    }
    
    /// 记录验证码发送
    /// - Parameter email: 邮箱地址
    func recordSend(for email: String) {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 添加新记录
        var records = getAllRecords()
        records.append(SendRecord(email: normalizedEmail, timestamp: Date()))
        saveRecords(records)
        
        // 清理过期记录
        cleanupExpiredRecords()
    }
    
    /// 重置指定邮箱的发送记录（仅用于测试或管理）
    func reset(for email: String) {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 移除发送记录
        var records = getAllRecords()
        records.removeAll { $0.email == normalizedEmail }
        saveRecords(records)
        
        // 移除冷却记录
        removeCooldown(for: normalizedEmail)
    }
    
    /// 更新指定邮箱的冷却时间（用于同步服务器限制）
    func updateCooldown(for email: String, seconds: Int) {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        var cooldowns = getAllCooldowns()
        
        // 移除旧记录
        cooldowns.removeAll { $0.email == normalizedEmail }
        
        // 添加新记录
        let endTime = Date().addingTimeInterval(TimeInterval(seconds))
        cooldowns.append(CooldownRecord(email: normalizedEmail, endTime: endTime))
        
        saveCooldowns(cooldowns)
    }
    
    /// 获取剩余尝试次数
    func getRemainingAttempts(for email: String) -> Int {
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let recentSends = getRecentSends(for: normalizedEmail)
        return max(0, maxAttemptsInWindow - recentSends.count)
    }
    
    // MARK: - Private Methods
    
    private func getRecentSends(for email: String) -> [SendRecord] {
        let allRecords = getAllRecords()
        let cutoffTime = Date().addingTimeInterval(-timeWindowSeconds)
        
        return allRecords.filter { record in
            record.email == email && record.timestamp > cutoffTime
        }
    }
    
    private func getAllRecords() -> [SendRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([SendRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func saveRecords(_ records: [SendRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func getCooldownEndTime(for email: String) -> Date? {
        guard let data = UserDefaults.standard.data(forKey: cooldownKey),
              let cooldowns = try? JSONDecoder().decode([CooldownRecord].self, from: data) else {
            return nil
        }
        
        return cooldowns.first { $0.email == email }?.endTime
    }
    
    private func setCooldown(for email: String) {
        var cooldowns = getAllCooldowns()
        
        // 移除该邮箱的旧冷却记录
        cooldowns.removeAll { $0.email == email }
        
        // 添加新的冷却记录
        let endTime = Date().addingTimeInterval(cooldownSeconds)
        cooldowns.append(CooldownRecord(email: email, endTime: endTime))
        
        saveCooldowns(cooldowns)
    }
    
    private func removeCooldown(for email: String) {
        var cooldowns = getAllCooldowns()
        cooldowns.removeAll { $0.email == email }
        saveCooldowns(cooldowns)
    }
    
    private func getAllCooldowns() -> [CooldownRecord] {
        guard let data = UserDefaults.standard.data(forKey: cooldownKey),
              let cooldowns = try? JSONDecoder().decode([CooldownRecord].self, from: data) else {
            return []
        }
        return cooldowns
    }
    
    private func saveCooldowns(_ cooldowns: [CooldownRecord]) {
        if let data = try? JSONEncoder().encode(cooldowns) {
            UserDefaults.standard.set(data, forKey: cooldownKey)
        }
    }
    
    private func cleanupExpiredRecords() {
        // 清理过期的发送记录
        let cutoffTime = Date().addingTimeInterval(-timeWindowSeconds)
        var records = getAllRecords()
        records.removeAll { $0.timestamp < cutoffTime }
        saveRecords(records)
        
        // 清理过期的冷却记录
        var cooldowns = getAllCooldowns()
        cooldowns.removeAll { $0.endTime < Date() }
        saveCooldowns(cooldowns)
    }
}

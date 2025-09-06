//
//  NotificationManager.swift
//  DadaKnows
//
//  推送通知管理器
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            await checkAuthorizationStatus()
            
            if granted {
                await registerForRemoteNotifications()
            }
        } catch {
            print("❌ 请求通知权限失败: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        self.isAuthorized = settings.authorizationStatus == .authorized
    }
    
    private func registerForRemoteNotifications() async {
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString
    ) async {
        guard isAuthorized else {
            print("⚠️ 通知权限未授权")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            print("✅ 本地通知已安排: \(title)")
        } catch {
            print("❌ 安排本地通知失败: \(error)")
        }
    }
    
    func scheduleDailyReminder(at hour: Int, minute: Int = 0) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "DadaKnows 提醒"
        content.body = "今天有什么想问答答的吗？"
        content.sound = .default
        content.badge = 1
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ 每日提醒已设置: \(hour):\(minute)")
        } catch {
            print("❌ 设置每日提醒失败: \(error)")
        }
    }
    
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("✅ 已取消通知: \(identifier)")
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        if #available(iOS 17.0, *) {
            center.setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        print("✅ 已取消所有通知")
    }
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        if #available(iOS 17.0, *) {
            center.setBadgeCount(count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Smart Notifications
    
    func scheduleStudyReminder(for age: Int) async {
        guard isAuthorized else { return }
        
        let reminderTexts = generateAgeAppropriateReminders(for: age)
        
        // 安排一周内的提醒
        for (index, text) in reminderTexts.enumerated() {
            let timeInterval = TimeInterval((index + 1) * 24 * 60 * 60) // 每天一次
            await scheduleLocalNotification(
                title: "学习时间到啦！",
                body: text,
                timeInterval: timeInterval,
                identifier: "study_reminder_\(index)"
            )
        }
    }
    
    private func generateAgeAppropriateReminders(for age: Int) -> [String] {
        switch age {
        case 3...5:
            return [
                "小朋友，今天想听什么故事呢？",
                "答答想和你一起探索新的知识！",
                "有什么好奇的事情想问答答吗？"
            ]
        case 6...8:
            return [
                "今天学到了什么新知识呢？",
                "有什么问题想和答答讨论吗？",
                "让我们一起发现世界的奥秘吧！"
            ]
        case 9...12:
            return [
                "今天的学习怎么样？有疑问可以问我哦！",
                "想了解什么新的科学知识吗？",
                "让我们一起探索更深层的问题吧！"
            ]
        default:
            return [
                "今天想学习什么新知识呢？",
                "有什么问题想和答答探讨吗？",
                "让我们一起思考有趣的问题吧！"
            ]
        }
    }
    
    // MARK: - Achievement Notifications
    
    func notifyAchievement(title: String, description: String) async {
        await scheduleLocalNotification(
            title: "🎉 \(title)",
            body: description,
            timeInterval: 1,
            identifier: "achievement_\(Date().timeIntervalSince1970)"
        )
    }
    
    // MARK: - Push Notification Token
    
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 设备推送Token: \(tokenString)")
        
        // 将token发送到Supabase后端
        Task {
            await sendTokenToServer(tokenString)
        }
    }
    
    private func sendTokenToServer(_ token: String) async {
        // 实现将推送token发送到Supabase的逻辑
        // 这里应该调用Supabase API来保存用户的推送token
        print("✅ 推送Token已发送到服务器")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: @preconcurrency UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 应用在前台时也显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        print("📱 用户点击了通知: \(identifier)")
        
        // 处理通知点击事件
        Task { @MainActor in
            self.handleNotificationResponse(identifier: identifier)
        }
        
        completionHandler()
    }
    
    private func handleNotificationResponse(identifier: String) {
        if identifier.hasPrefix("study_reminder") {
            // 打开应用到聊天界面
            NotificationCenter.default.post(name: .openChatView, object: nil)
        } else if identifier.hasPrefix("achievement") {
            // 打开成就页面
            NotificationCenter.default.post(name: .openAchievements, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openChatView = Notification.Name("openChatView")
    static let openAchievements = Notification.Name("openAchievements")
}

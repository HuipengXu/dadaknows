//
//  AnalyticsManager.swift
//  DadaKnows
//
//  使用统计和分析管理器
//

import Foundation
import Combine
import CoreData

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var learningStats: LearningStats = LearningStats()
    @Published var weeklyProgress: [DailyProgress] = []
    @Published var topCategories: [CategoryStats] = []
    @Published var achievements: [Achievement] = []
    
    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current
    
    private init() {
        loadStoredData()
        reconcileWithChatHistory()
        generateWeeklyProgress()
        updateTopCategories()
        checkAchievements()
    }
    
    // MARK: - Event Tracking
    
    func trackQuestionAsked(question: String, category: String, targetAge: Int) {
        let event = LearningEvent(
            type: .questionAsked,
            question: question,
            answer: nil,
            category: category,
            targetAge: targetAge,
            responseTime: nil,
            timestamp: Date()
        )
        
        recordEvent(event)
        updateStats(for: event)
        checkAchievements()
    }
    
    func trackAnswerReceived(question: String, answer: String, category: String, targetAge: Int, responseTime: TimeInterval) {
        let event = LearningEvent(
            type: .answerReceived,
            question: question,
            answer: answer,
            category: category,
            targetAge: targetAge,
            responseTime: responseTime,
            timestamp: Date()
        )
        
        recordEvent(event)
        updateStats(for: event)
    }
    
    func trackVoiceInputUsed() {
        learningStats.voiceInputCount += 1
        saveStats()
    }
    
    func trackOfflineModeUsed() {
        learningStats.offlineModeUsageCount += 1
        saveStats()
    }
    
    func trackSessionStart() {
        learningStats.totalSessions += 1
        learningStats.lastSessionDate = Date()
        saveStats()
    }
    
    func trackSessionEnd(duration: TimeInterval) {
        learningStats.totalLearningTime += duration
        saveStats()
    }
    
    // MARK: - Statistics Updates
    
    private func updateStats(for event: LearningEvent) {
        switch event.type {
        case .questionAsked:
            learningStats.totalQuestions += 1
            learningStats.questionsToday += 1
            
            // 更新连续学习天数
            updateLearningStreak()
            
        case .answerReceived:
            learningStats.totalAnswers += 1
            
            if let responseTime = event.responseTime {
                learningStats.averageResponseTime = (learningStats.averageResponseTime * Double(learningStats.totalAnswers - 1) + responseTime) / Double(learningStats.totalAnswers)
            }
        }
        
        saveStats()
    }
    
    private func updateLearningStreak() {
        let today = calendar.startOfDay(for: Date())
        let lastLearningDate = calendar.startOfDay(for: learningStats.lastLearningDate ?? Date.distantPast)
        
        if lastLearningDate == today {
            // 今天已经学习过了
            return
        } else if calendar.dateInterval(of: .day, for: lastLearningDate)?.end == today {
            // 连续学习
            learningStats.currentStreak += 1
        } else {
            // 中断了连续学习
            learningStats.currentStreak = 1
        }
        
        learningStats.lastLearningDate = Date()
        learningStats.longestStreak = max(learningStats.longestStreak, learningStats.currentStreak)
    }
    
    // MARK: - Weekly Progress（基于聊天记录）
    private func generateWeeklyProgress() {
        let today = calendar.startOfDay(for: Date())
        var progress: [DailyProgress] = []
        let context = DataManager.shared.context
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@",
                                        sevenDaysAgo as NSDate,
                                        calendar.date(byAdding: .day, value: 1, to: today)! as NSDate)
        do {
            let chats = try context.fetch(request)
            for offset in stride(from: 6, through: 0, by: -1) {
                let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                let start = calendar.startOfDay(for: date)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                let count = chats.filter { chat in
                    let created = chat.createdAt ?? .distantPast
                    return created >= start && created < end
                }.count
                let daily = DailyProgress(date: start,
                                          questionCount: count,
                                          learningTime: Double(count) * 120,
                                          categories: [])
                progress.append(daily)
            }
        } catch {
            // 失败时回退为空数据
            progress = (0..<7).map { i in
                let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
                return DailyProgress(date: date, questionCount: 0, learningTime: 0, categories: [])
            }.reversed()
        }
        weeklyProgress = progress
    }
    
    private func extractCategories(from events: [LearningEvent]) -> Set<String> {
        return Set(events.map { $0.category })
    }
    
    // MARK: - Category Statistics
    
    private func updateTopCategories() {
        let events = getAllEvents()
        let categoryGroups = Dictionary(grouping: events) { $0.category }
        
        topCategories = categoryGroups.map { category, events in
            CategoryStats(
                name: category,
                questionCount: events.filter { $0.type == .questionAsked }.count,
                averageResponseTime: events.compactMap { $0.responseTime }.reduce(0, +) / Double(max(1, events.count)),
                lastUsed: events.map { $0.timestamp }.max() ?? Date.distantPast
            )
        }
        .sorted { $0.questionCount > $1.questionCount }
        .prefix(10)
        .map { $0 }
    }
    
    // MARK: - Achievements
    
    private func checkAchievements() {
        var newAchievements: [Achievement] = []
        
        // 首次提问
        if learningStats.totalQuestions == 1 && !hasAchievement(.firstQuestion) {
            newAchievements.append(.firstQuestion)
        }
        
        // 连续学习
        if learningStats.currentStreak >= 7 && !hasAchievement(.weekStreak) {
            newAchievements.append(.weekStreak)
        }
        
        if learningStats.currentStreak >= 30 && !hasAchievement(.monthStreak) {
            newAchievements.append(.monthStreak)
        }
        
        // 问题里程碑
        if learningStats.totalQuestions >= 100 && !hasAchievement(.hundredQuestions) {
            newAchievements.append(.hundredQuestions)
        }
        
        if learningStats.totalQuestions >= 1000 && !hasAchievement(.thousandQuestions) {
            newAchievements.append(.thousandQuestions)
        }
        
        // 语音使用
        if learningStats.voiceInputCount >= 10 && !hasAchievement(.voiceExplorer) {
            newAchievements.append(.voiceExplorer)
        }
        
        // 学习时间
        if learningStats.totalLearningTime >= 3600 && !hasAchievement(.oneHourLearning) { // 1小时
            newAchievements.append(.oneHourLearning)
        }
        
        // 添加新成就
        for achievement in newAchievements {
            if !achievements.contains(achievement) {
                achievements.append(achievement)
                
                // 发送成就通知
                Task {
                    await NotificationManager.shared.notifyAchievement(
                        title: achievement.title,
                        description: achievement.description
                    )
                }
            }
        }
        
        saveAchievements()
    }
    
    private func hasAchievement(_ achievement: Achievement) -> Bool {
        achievements.contains(achievement)
    }
    
    // MARK: - Data Persistence
    
    private func recordEvent(_ event: LearningEvent) {
        var events = getAllEvents()
        events.append(event)
        
        // 只保留最近30天的事件
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        events = events.filter { $0.timestamp >= thirtyDaysAgo }
        
        saveEvents(events)
    }
    
    private func getAllEvents() -> [LearningEvent] {
        guard let data = userDefaults.data(forKey: "learningEvents"),
              let events = try? JSONDecoder().decode([LearningEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    private func getEvents(for date: Date) -> [LearningEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return getAllEvents().filter { event in
            event.timestamp >= startOfDay && event.timestamp < endOfDay
        }
    }
    
    private func saveEvents(_ events: [LearningEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: "learningEvents")
        }
    }
    
    private func loadStoredData() {
        // 加载学习统计
        if let data = userDefaults.data(forKey: "learningStats"),
           let stats = try? JSONDecoder().decode(LearningStats.self, from: data) {
            learningStats = stats
        }
        
        // 加载成就
        if let data = userDefaults.data(forKey: "achievements"),
           let savedAchievements = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = savedAchievements
        }
        
        // 重置今日问题计数（如果是新的一天）
        resetDailyCountIfNeeded()
    }

    // MARK: - Reconcile with Core Data Chat History
    private func reconcileWithChatHistory() {
        let context = DataManager.shared.context
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        do {
            let chats = try context.fetch(request)
            let chatCount = chats.count
            learningStats.totalQuestions = chatCount
            
            // 今日计数
            let startOfToday = calendar.startOfDay(for: Date())
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            let todayCount = chats.filter { chat in
                let created = chat.createdAt ?? .distantPast
                return created >= startOfToday && created < endOfToday
            }.count
            learningStats.questionsToday = todayCount
            
            // 以聊天记录重算连续天数和最长连击
            let activeDays: Set<Date> = Set(chats.compactMap { chat in
                guard let created = chat.createdAt else { return nil }
                return calendar.startOfDay(for: created)
            })
            learningStats.currentStreak = computeCurrentStreak(from: activeDays)
            learningStats.longestStreak = computeLongestStreak(from: activeDays)
            learningStats.lastLearningDate = activeDays.max()
            
            // 每次对齐后也刷新周统计
            generateWeeklyProgress()
            saveStats()
        } catch {
            // Ignore reconciliation errors silently
        }
    }

    private func computeCurrentStreak(from activeDays: Set<Date>) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return max(streak, streak > 0 ? streak : 0)
    }
    
    private func computeLongestStreak(from activeDays: Set<Date>) -> Int {
        // 扫描最近90天
        var longest = 0
        var current = 0
        var day = calendar.startOfDay(for: Date())
        for _ in 0..<90 {
            if activeDays.contains(day) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return longest
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(learningStats) {
            userDefaults.set(data, forKey: "learningStats")
        }
    }
    
    private func saveAchievements() {
        if let data = try? JSONEncoder().encode(achievements) {
            userDefaults.set(data, forKey: "achievements")
        }
    }
    
    private func resetDailyCountIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        let lastResetDate = userDefaults.object(forKey: "lastDailyReset") as? Date ?? Date.distantPast
        
        if calendar.startOfDay(for: lastResetDate) < today {
            learningStats.questionsToday = 0
            userDefaults.set(today, forKey: "lastDailyReset")
            saveStats()
        }
    }
    
    // MARK: - Export Data
    
    func exportLearningData() -> LearningDataExport {
        return LearningDataExport(
            stats: learningStats,
            weeklyProgress: weeklyProgress,
            topCategories: topCategories,
            achievements: achievements,
            exportDate: Date()
        )
    }
}

// MARK: - Supporting Types

struct LearningStats: Codable {
    var totalQuestions: Int = 0
    var totalAnswers: Int = 0
    var questionsToday: Int = 0
    var totalSessions: Int = 0
    var totalLearningTime: TimeInterval = 0
    var averageResponseTime: TimeInterval = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var voiceInputCount: Int = 0
    var offlineModeUsageCount: Int = 0
    var lastLearningDate: Date?
    var lastSessionDate: Date?
}

struct LearningEvent: Codable {
    let id: UUID
    let type: EventType
    let question: String
    let answer: String?
    let category: String
    let targetAge: Int
    let responseTime: TimeInterval?
    let timestamp: Date
    
    init(type: EventType, question: String, answer: String?, category: String, targetAge: Int, responseTime: TimeInterval?, timestamp: Date) {
        self.id = UUID()
        self.type = type
        self.question = question
        self.answer = answer
        self.category = category
        self.targetAge = targetAge
        self.responseTime = responseTime
        self.timestamp = timestamp
    }
    
    enum EventType: String, Codable {
        case questionAsked
        case answerReceived
    }
}

struct DailyProgress: Identifiable, Codable {
    let id: UUID
    let date: Date
    let questionCount: Int
    let learningTime: TimeInterval
    let categories: Set<String>
    
    init(date: Date, questionCount: Int, learningTime: TimeInterval, categories: Set<String>) {
        self.id = UUID()
        self.date = date
        self.questionCount = questionCount
        self.learningTime = learningTime
        self.categories = categories
    }
}

struct CategoryStats: Identifiable, Codable {
    let id: UUID
    let name: String
    let questionCount: Int
    let averageResponseTime: TimeInterval
    let lastUsed: Date
    
    init(name: String, questionCount: Int, averageResponseTime: TimeInterval, lastUsed: Date) {
        self.id = UUID()
        self.name = name
        self.questionCount = questionCount
        self.averageResponseTime = averageResponseTime
        self.lastUsed = lastUsed
    }
}

enum Achievement: String, Codable, CaseIterable {
    case firstQuestion = "first_question"
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case hundredQuestions = "hundred_questions"
    case thousandQuestions = "thousand_questions"
    case voiceExplorer = "voice_explorer"
    case oneHourLearning = "one_hour_learning"
    
    var title: String {
        switch self {
        case .firstQuestion:
            return "初次探索"
        case .weekStreak:
            return "学习达人"
        case .monthStreak:
            return "学习专家"
        case .hundredQuestions:
            return "好奇宝宝"
        case .thousandQuestions:
            return "知识探索者"
        case .voiceExplorer:
            return "语音达人"
        case .oneHourLearning:
            return "时间管理者"
        }
    }
    
    var description: String {
        switch self {
        case .firstQuestion:
            return "提出了第一个问题"
        case .weekStreak:
            return "连续学习7天"
        case .monthStreak:
            return "连续学习30天"
        case .hundredQuestions:
            return "累计提问100个问题"
        case .thousandQuestions:
            return "累计提问1000个问题"
        case .voiceExplorer:
            return "使用语音输入10次"
        case .oneHourLearning:
            return "累计学习时间达到1小时"
        }
    }
    
    var icon: String {
        switch self {
        case .firstQuestion:
            return "star.fill"
        case .weekStreak:
            return "flame.fill"
        case .monthStreak:
            return "crown.fill"
        case .hundredQuestions:
            return "questionmark.circle.fill"
        case .thousandQuestions:
            return "brain.head.profile"
        case .voiceExplorer:
            return "mic.fill"
        case .oneHourLearning:
            return "clock.fill"
        }
    }
}

struct LearningDataExport: Codable {
    let stats: LearningStats
    let weeklyProgress: [DailyProgress]
    let topCategories: [CategoryStats]
    let achievements: [Achievement]
    let exportDate: Date
}

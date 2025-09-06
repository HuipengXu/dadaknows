//
//  OfflineManager.swift
//  DadaKnows
//
//  离线模式管理器
//

import Foundation
import Network
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOnline = true
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var offlineQueueCount = 0
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // 离线队列
    private var offlineQueue: [OfflineRequest] = []
    private let offlineQueueKey = "offline_request_queue"
    
    // 缓存的回答
    private var cachedAnswers: [String: CachedAnswer] = [:]
    private let cachedAnswersKey = "cached_answers"
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineData()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    self?.processOfflineQueue()
                }
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Offline Queue Management
    
    func addToOfflineQueue(question: String, targetAge: Int, language: String) {
        let request = OfflineRequest(
            id: UUID().uuidString,
            question: question,
            targetAge: targetAge,
            language: language,
            timestamp: Date()
        )
        
        offlineQueue.append(request)
        offlineQueueCount = offlineQueue.count
        saveOfflineQueue()
    }
    
    private func processOfflineQueue() {
        guard isOnline && !offlineQueue.isEmpty else { return }
        
        Task {
            for request in offlineQueue {
                do {
                    // 处理离线请求
                    try await processOfflineRequest(request)
                    
                    // 从队列中移除已处理的请求
                    if let index = offlineQueue.firstIndex(where: { $0.id == request.id }) {
                        offlineQueue.remove(at: index)
                    }
                } catch {
                    print("❌ 处理离线请求失败: \(error)")
                    // 保留失败的请求，稍后重试
                }
            }
            
            offlineQueueCount = offlineQueue.count
            saveOfflineQueue()
        }
    }
    
    private func processOfflineRequest(_ request: OfflineRequest) async throws {
        // 调用AI服务处理请求
        _ = AIManager.shared
        
        // 这里可以实现批量处理或后台处理逻辑
        print("✅ 处理离线请求: \(request.question)")
    }
    
    // MARK: - Answer Caching
    
    func cacheAnswer(question: String, answer: String, targetAge: Int, language: String) {
        let cacheKey = generateCacheKey(question: question, targetAge: targetAge, language: language)
        let cachedAnswer = CachedAnswer(
            question: question,
            answer: answer,
            targetAge: targetAge,
            language: language,
            timestamp: Date()
        )
        
        cachedAnswers[cacheKey] = cachedAnswer
        saveCachedAnswers()
    }
    
    func getCachedAnswer(question: String, targetAge: Int, language: String) -> String? {
        let cacheKey = generateCacheKey(question: question, targetAge: targetAge, language: language)
        
        guard let cachedAnswer = cachedAnswers[cacheKey] else {
            return nil
        }
        
        // 检查缓存是否过期（7天）
        let expirationDate = cachedAnswer.timestamp.addingTimeInterval(7 * 24 * 60 * 60)
        if Date() > expirationDate {
            cachedAnswers.removeValue(forKey: cacheKey)
            saveCachedAnswers()
            return nil
        }
        
        return cachedAnswer.answer
    }
    
    private func generateCacheKey(question: String, targetAge: Int, language: String) -> String {
        let normalizedQuestion = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedQuestion)_\(targetAge)_\(language)".data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    // MARK: - Offline Content
    
    func getOfflineContent(for age: Int) -> [OfflineContent] {
        // 返回预缓存的离线内容
        return generateOfflineContent(for: age)
    }
    
    private func generateOfflineContent(for age: Int) -> [OfflineContent] {
        switch age {
        case 2...4:
            return [
                OfflineContent(
                    question: "什么是颜色？",
                    answer: "颜色就像彩虹一样美丽！红色像苹果，蓝色像天空，绿色像小草。我们的世界因为有了颜色变得更加美丽和有趣！",
                    category: "基础认知"
                ),
                OfflineContent(
                    question: "动物怎么说话？",
                    answer: "动物们有自己的语言哦！小狗汪汪叫，小猫喵喵叫，小鸟叽叽喳喳。虽然我们听不懂，但它们在用自己的方式交流呢！",
                    category: "动物世界"
                )
            ]
        case 5...7:
            return [
                OfflineContent(
                    question: "为什么会下雨？",
                    answer: "下雨就像天空在洗澡！太阳把水变成看不见的水蒸气，水蒸气飞到天空变成云朵，云朵太重了就变成雨滴落下来，给大地洗个澡！",
                    category: "自然现象"
                ),
                OfflineContent(
                    question: "植物怎么长大？",
                    answer: "植物就像小朋友一样需要吃饭！它们喝水，晒太阳，从土里吸收营养，慢慢长高长大。阳光就是它们的食物，水就是它们的饮料！",
                    category: "植物世界"
                )
            ]
        default:
            return [
                OfflineContent(
                    question: "什么是友谊？",
                    answer: "友谊是世界上最珍贵的宝藏！好朋友会在你开心时和你一起笑，在你难过时安慰你，一起分享快乐和秘密。真正的朋友就像星星，即使看不见也一直在那里！",
                    category: "情感认知"
                )
            ]
        }
    }
    
    // MARK: - Data Persistence
    
    private func loadOfflineData() {
        loadOfflineQueue()
        loadCachedAnswers()
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: offlineQueueKey),
           let queue = try? JSONDecoder().decode([OfflineRequest].self, from: data) {
            offlineQueue = queue
            offlineQueueCount = queue.count
        }
    }
    
    private func saveOfflineQueue() {
        if let data = try? JSONEncoder().encode(offlineQueue) {
            UserDefaults.standard.set(data, forKey: offlineQueueKey)
        }
    }
    
    private func loadCachedAnswers() {
        if let data = UserDefaults.standard.data(forKey: cachedAnswersKey),
           let answers = try? JSONDecoder().decode([String: CachedAnswer].self, from: data) {
            cachedAnswers = answers
        }
    }
    
    private func saveCachedAnswers() {
        if let data = try? JSONEncoder().encode(cachedAnswers) {
            UserDefaults.standard.set(data, forKey: cachedAnswersKey)
        }
    }
    
    // MARK: - Cache Management
    
    func clearExpiredCache() {
        let now = Date()
        let expirationInterval: TimeInterval = 7 * 24 * 60 * 60 // 7天
        
        cachedAnswers = cachedAnswers.filter { _, cachedAnswer in
            now.timeIntervalSince(cachedAnswer.timestamp) < expirationInterval
        }
        
        saveCachedAnswers()
    }
    
    func clearAllCache() {
        cachedAnswers.removeAll()
        offlineQueue.removeAll()
        offlineQueueCount = 0
        
        saveCachedAnswers()
        saveOfflineQueue()
    }
    
    func getCacheSize() -> String {
        let cacheCount = cachedAnswers.count
        let queueCount = offlineQueue.count
        return "缓存答案: \(cacheCount)条，待处理: \(queueCount)条"
    }
}

// MARK: - Supporting Types

struct OfflineRequest: Codable, Identifiable {
    let id: String
    let question: String
    let targetAge: Int
    let language: String
    let timestamp: Date
}

struct CachedAnswer: Codable {
    let question: String
    let answer: String
    let targetAge: Int
    let language: String
    let timestamp: Date
}

struct OfflineContent: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let category: String
}

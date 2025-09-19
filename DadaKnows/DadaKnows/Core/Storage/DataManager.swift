//
//  DataManager.swift
//  DadaKnows
//
//  本地数据存储管理器 - 集成CoreData和Supabase云端同步
//

import Foundation
import CoreData
import Combine

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    
    lazy var persistentContainer: NSPersistentContainer = {
        // 首先检查模型文件是否存在
        guard let modelURL = Bundle.main.url(forResource: "DadaKnowsModel", withExtension: "momd") else {
            print("❌ Core Data model file not found in bundle")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
            print("📁 Available resources: \(Bundle.main.paths(forResourcesOfType: "momd", inDirectory: nil))")
            
            // 创建一个临时的内存存储作为fallback
            return createInMemoryContainer()
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("❌ Failed to create NSManagedObjectModel from URL: \(modelURL)")
            return createInMemoryContainer()
        }
        
        let container = NSPersistentContainer(name: "DadaKnowsModel", managedObjectModel: model)
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("❌ Core Data error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                // 尝试删除损坏的数据库文件并重新创建
                self?.handleCoreDataError(error, container: container)
            } else {
                print("✅ Core Data loaded successfully")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private func createInMemoryContainer() -> NSPersistentContainer {
        print("🔧 Creating in-memory Core Data store as fallback")
        
        // 创建一个简单的内存模型
        let model = NSManagedObjectModel()
        
        // Chat实体
        let chatEntity = NSEntityDescription()
        chatEntity.name = "Chat"
        chatEntity.managedObjectClassName = "Chat"
        
        let chatIdAttribute = NSAttributeDescription()
        chatIdAttribute.name = "id"
        chatIdAttribute.attributeType = .UUIDAttributeType
        chatIdAttribute.isOptional = true
        
        let questionAttribute = NSAttributeDescription()
        questionAttribute.name = "question"
        questionAttribute.attributeType = .stringAttributeType
        questionAttribute.isOptional = true
        
        let answerAttribute = NSAttributeDescription()
        answerAttribute.name = "answer"
        answerAttribute.attributeType = .stringAttributeType
        answerAttribute.isOptional = true
        
        let targetAgeAttribute = NSAttributeDescription()
        targetAgeAttribute.name = "targetAge"
        targetAgeAttribute.attributeType = .integer16AttributeType
        targetAgeAttribute.defaultValue = 0
        
        let languageAttribute = NSAttributeDescription()
        languageAttribute.name = "language"
        languageAttribute.attributeType = .stringAttributeType
        languageAttribute.isOptional = true
        
        let userFeedbackAttribute = NSAttributeDescription()
        userFeedbackAttribute.name = "userFeedback"
        userFeedbackAttribute.attributeType = .stringAttributeType
        userFeedbackAttribute.isOptional = true
        
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = true
        
        chatEntity.properties = [chatIdAttribute, questionAttribute, answerAttribute, targetAgeAttribute, languageAttribute, userFeedbackAttribute, createdAtAttribute]
        
        // UserSettings实体
        let userSettingsEntity = NSEntityDescription()
        userSettingsEntity.name = "UserSettings"
        userSettingsEntity.managedObjectClassName = "UserSettings"
        
        let preferredLanguageAttribute = NSAttributeDescription()
        preferredLanguageAttribute.name = "preferredLanguage"
        preferredLanguageAttribute.attributeType = .stringAttributeType
        preferredLanguageAttribute.isOptional = true
        
        let subscriptionStatusAttribute = NSAttributeDescription()
        subscriptionStatusAttribute.name = "subscriptionStatus"
        subscriptionStatusAttribute.attributeType = .stringAttributeType
        subscriptionStatusAttribute.isOptional = true
        
        let settingsCreatedAtAttribute = NSAttributeDescription()
        settingsCreatedAtAttribute.name = "createdAt"
        settingsCreatedAtAttribute.attributeType = .dateAttributeType
        settingsCreatedAtAttribute.isOptional = true
        
        let updatedAtAttribute = NSAttributeDescription()
        updatedAtAttribute.name = "updatedAt"
        updatedAtAttribute.attributeType = .dateAttributeType
        updatedAtAttribute.isOptional = true
        
        userSettingsEntity.properties = [preferredLanguageAttribute, subscriptionStatusAttribute, settingsCreatedAtAttribute, updatedAtAttribute]
        
        model.entities = [chatEntity, userSettingsEntity]
        
        let container = NSPersistentContainer(name: "DadaKnowsModel", managedObjectModel: model)
        
        // 配置为内存存储
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Failed to create in-memory store: \(error)")
            } else {
                print("✅ In-memory Core Data store created successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // 云端同步服务 - 使用lazy var避免循环依赖
    private lazy var chatService = ChatService.shared
    private var offlineManager: OfflineManager {
        OfflineManager.shared
    }
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSyncObservers()
    }
    
    // MARK: - Core Data Error Handling
    
    private func handleCoreDataError(_ error: Error, container: NSPersistentContainer) {
        print("🔧 Attempting to recover from Core Data error...")
        
        // 获取应用程序支持目录
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                                   in: .userDomainMask).first else {
            print("❌ Could not find application support directory")
            return
        }
        
        let storeURL = applicationSupportURL.appendingPathComponent("DadaKnowsModel.sqlite")
        let shmURL = applicationSupportURL.appendingPathComponent("DadaKnowsModel.sqlite-shm")
        let walURL = applicationSupportURL.appendingPathComponent("DadaKnowsModel.sqlite-wal")
        
        do {
            // 删除损坏的数据库文件
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
                print("🗑️ Removed corrupted database file")
            }
            if FileManager.default.fileExists(atPath: shmURL.path) {
                try FileManager.default.removeItem(at: shmURL)
            }
            if FileManager.default.fileExists(atPath: walURL.path) {
                try FileManager.default.removeItem(at: walURL)
            }
            
            // 重新加载持久化存储
            container.loadPersistentStores { _, newError in
                if let newError = newError {
                    print("❌ Failed to recreate Core Data store: \(newError)")
                } else {
                    print("✅ Successfully recreated Core Data store")
                }
            }
            
        } catch {
            print("❌ Failed to remove corrupted database files: \(error)")
        }
    }
    
    // MARK: - Sync Observers
    
    private func setupSyncObservers() {
        // 监听认证状态变化
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.performInitialSync()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听网络状态变化
        offlineManager.$isOnline
            .sink { [weak self] isOnline in
                Task {
                    guard let self = self else { return }
                    if isOnline {
                        let shouldSync = self.offlineManager.shouldAutoSync()
                        if shouldSync {
                            await self.syncWithCloud()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performInitialSync() async {
        let isAuthenticated = AuthManager.shared.isAuthenticated
        let isOnline = offlineManager.isOnline
        guard isAuthenticated && isOnline else { return }
        
        isSyncing = true
        lastSyncError = nil
        
        // 同步聊天记录
        await chatService.syncChatsFromCloud()
        await chatService.syncAllChatsToCloud()
        
        if Config.isDebug {
            print("✅ 初始数据同步完成")
        }
        
        isSyncing = false
    }
    
    func syncWithCloud() async {
        let isAuthenticated = AuthManager.shared.isAuthenticated
        let isOnline = offlineManager.isOnline
        guard isAuthenticated && isOnline else { return }
        
        isSyncing = true
        lastSyncError = nil
        
        await chatService.syncAllChatsToCloud()
        await chatService.syncChatsFromCloud()
        
        if Config.isDebug {
            print("✅ 云端同步完成")
        }
        
        isSyncing = false
    }
    
    // MARK: - Core Data Operations
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    func delete<T: NSManagedObject>(_ object: T) {
        context.delete(object)
        save()
    }
    
    // MARK: - Enhanced Chat Operations
    func createChat(question: String, answer: String, targetAge: Int, language: String) -> Chat {
        let chat = Chat(context: context)
        chat.id = UUID()
        chat.question = question
        chat.answer = answer
        chat.targetAge = Int16(targetAge)
        chat.language = language
        chat.createdAt = Date()
        chat.userFeedback = "none"
        
        save()
        
        return chat
    }
    
    // 分离的同步方法，避免在createChat中直接调用ChatService
    func syncChatToCloudAsync(_ chat: Chat) {
        Task {
            await chatService.syncChatToCloud(chat)
        }
    }
    
    
    func fetchChats() -> [Chat] {
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Chat.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    func updateChatFeedback(_ chat: Chat, feedback: String) {
        chat.userFeedback = feedback
        save()
    }
    
    // MARK: - Enhanced User Settings
    func saveUserSettings(language: String, subscriptionStatus: String) {
        let settings = fetchOrCreateUserSettings()
        settings.preferredLanguage = language
        settings.subscriptionStatus = subscriptionStatus
        settings.updatedAt = Date()
        save()
        
        // 异步同步到云端
        Task {
            await UserService.shared.updateUserProfile(
                nickname: nil,
                avatarUrl: nil,
                preferredLanguage: language,
                subscriptionStatus: subscriptionStatus
            )
        }
    }
    
    func saveUserSettingsWithSync(language: String, subscriptionStatus: String, nickname: String? = nil, avatarUrl: String? = nil) async {
        // 保存本地设置并同步到云端
        let settings = fetchOrCreateUserSettings()
        settings.preferredLanguage = language
        settings.subscriptionStatus = subscriptionStatus
        settings.updatedAt = Date()
        save()
        
        // 同步到云端
        await UserService.shared.updateUserProfile(
            nickname: nickname,
            avatarUrl: avatarUrl,
            preferredLanguage: language,
            subscriptionStatus: subscriptionStatus
        )
    }
    
    func fetchOrCreateUserSettings() -> UserSettings {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        
        do {
            let settings = try context.fetch(request)
            if let existingSettings = settings.first {
                return existingSettings
            }
        } catch {
            print("Fetch settings error: \(error)")
        }
        
        // Create new settings
        let newSettings = UserSettings(context: context)
        newSettings.preferredLanguage = "en"
        newSettings.subscriptionStatus = "free"
        newSettings.createdAt = Date()
        save()
        
        return newSettings
    }
}

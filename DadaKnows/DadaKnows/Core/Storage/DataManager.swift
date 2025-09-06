//
//  DataManager.swift
//  DadaKnows
//
//  本地数据存储管理器
//

import Foundation
import CoreData

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DadaKnowsModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {}
    
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
    
    // MARK: - Chat Operations
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
    
    // MARK: - User Settings
    func saveUserSettings(language: String, subscriptionStatus: String) {
        let settings = fetchOrCreateUserSettings()
        settings.preferredLanguage = language
        settings.subscriptionStatus = subscriptionStatus
        save()
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
        newSettings.preferredLanguage = "zh-CN"
        newSettings.subscriptionStatus = "free"
        newSettings.createdAt = Date()
        save()
        
        return newSettings
    }
}

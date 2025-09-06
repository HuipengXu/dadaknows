//
//  Chat+CoreDataClass.swift
//  DadaKnows
//

import Foundation
import CoreData

@objc(Chat)
public class Chat: NSManagedObject {
    
}

extension Chat {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chat> {
        return NSFetchRequest<Chat>(entityName: "Chat")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var question: String?
    @NSManaged public var answer: String?
    @NSManaged public var targetAge: Int16
    @NSManaged public var language: String?
    @NSManaged public var userFeedback: String?
    @NSManaged public var createdAt: Date?
}

extension Chat : Identifiable {
    
}

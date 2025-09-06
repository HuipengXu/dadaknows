//
//  UserSettings+CoreDataClass.swift
//  DadaKnows
//

import Foundation
import CoreData

@objc(UserSettings)
public class UserSettings: NSManagedObject {
    
}

extension UserSettings {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserSettings> {
        return NSFetchRequest<UserSettings>(entityName: "UserSettings")
    }

    @NSManaged public var preferredLanguage: String?
    @NSManaged public var subscriptionStatus: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension UserSettings : Identifiable {
    
}

import Foundation
import SwiftUI

/// Simple chat message model used by ChatView for rendering.
public struct ChatMessage: Identifiable {
    public let id: UUID
    public var message: String
    public let isFromUser: Bool
    public let timestamp: Date
    public var isError: Bool = false

    public init(id: UUID = UUID(), message: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.message = message
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

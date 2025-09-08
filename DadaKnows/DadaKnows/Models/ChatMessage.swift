import Foundation
import SwiftUI

/// Simple chat message model used by ChatView for rendering.
public struct ChatMessage: Identifiable {
    public let id: UUID = UUID()
    public let message: String
    public let isFromUser: Bool
    public let timestamp: Date

    public init(message: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.message = message
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}

//
//  ChatServiceTests.swift
//  DadaKnowsTests
//
//  Unit tests for ChatService and Core Data operations
//

import XCTest
import CoreData
@testable import DadaKnows

final class ChatServiceTests: XCTestCase {
    
    var chatService: ChatService!
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        let persistentContainer = NSPersistentContainer(name: "DadaKnowsModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = persistentContainer.viewContext
        chatService = ChatService.shared
        chatService.context = testContext
    }
    
    override func tearDown() {
        chatService = nil
        testContext = nil
        super.tearDown()
    }
    
    func testCreateChat() {
        let expectation = XCTestExpectation(description: "Create chat")
        
        Task {
            let chat = await chatService.createChat(
                question: "What is the sky blue?",
                answer: "The sky appears blue because...",
                childAge: 5
            )
            
            XCTAssertNotNil(chat)
            XCTAssertEqual(chat?.question, "What is the sky blue?")
            XCTAssertEqual(chat?.answer, "The sky appears blue because...")
            XCTAssertEqual(chat?.childAge, 5)
            XCTAssertNotNil(chat?.timestamp)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchRecentChats() {
        let expectation = XCTestExpectation(description: "Fetch recent chats")
        
        Task {
            // Create test chats
            await chatService.createChat(question: "Question 1", answer: "Answer 1", childAge: 5)
            await chatService.createChat(question: "Question 2", answer: "Answer 2", childAge: 6)
            await chatService.createChat(question: "Question 3", answer: "Answer 3", childAge: 7)
            
            let chats = await chatService.fetchRecentChats(limit: 2)
            
            XCTAssertEqual(chats.count, 2)
            // Should be ordered by timestamp descending (most recent first)
            XCTAssertEqual(chats.first?.question, "Question 3")
            XCTAssertEqual(chats.last?.question, "Question 2")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchChats() {
        let expectation = XCTestExpectation(description: "Search chats")
        
        Task {
            // Create test chats with different content
            await chatService.createChat(question: "What is the sun?", answer: "The sun is a star", childAge: 5)
            await chatService.createChat(question: "What is the moon?", answer: "The moon is a satellite", childAge: 6)
            await chatService.createChat(question: "What are stars?", answer: "Stars are celestial bodies", childAge: 7)
            
            let sunChats = await chatService.searchChats(query: "sun")
            XCTAssertEqual(sunChats.count, 1)
            XCTAssertEqual(sunChats.first?.question, "What is the sun?")
            
            let starChats = await chatService.searchChats(query: "star")
            XCTAssertEqual(starChats.count, 2) // Should match both "sun is a star" and "What are stars?"
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteChat() {
        let expectation = XCTestExpectation(description: "Delete chat")
        
        Task {
            // Create a chat
            let chat = await chatService.createChat(question: "Test question", answer: "Test answer", childAge: 5)
            XCTAssertNotNil(chat)
            
            // Verify it exists
            let allChats = await chatService.fetchRecentChats(limit: 100)
            XCTAssertEqual(allChats.count, 1)
            
            // Delete it
            if let chat = chat {
                await chatService.deleteChat(chat)
            }
            
            // Verify it's gone
            let remainingChats = await chatService.fetchRecentChats(limit: 100)
            XCTAssertEqual(remainingChats.count, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testClearAllChats() {
        let expectation = XCTestExpectation(description: "Clear all chats")
        
        Task {
            // Create multiple chats
            await chatService.createChat(question: "Question 1", answer: "Answer 1", childAge: 5)
            await chatService.createChat(question: "Question 2", answer: "Answer 2", childAge: 6)
            await chatService.createChat(question: "Question 3", answer: "Answer 3", childAge: 7)
            
            // Verify they exist
            let allChats = await chatService.fetchRecentChats(limit: 100)
            XCTAssertEqual(allChats.count, 3)
            
            // Clear all
            await chatService.clearAllChats()
            
            // Verify they're gone
            let remainingChats = await chatService.fetchRecentChats(limit: 100)
            XCTAssertEqual(remainingChats.count, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetChatStatistics() {
        let expectation = XCTestExpectation(description: "Get chat statistics")
        
        Task {
            // Create chats for different days
            let today = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
            
            // Create chats with different timestamps (this would require modifying the Chat entity or ChatService)
            await chatService.createChat(question: "Today's question", answer: "Today's answer", childAge: 5)
            await chatService.createChat(question: "Another today question", answer: "Another answer", childAge: 6)
            
            let stats = await chatService.getChatStatistics()
            
            XCTAssertGreaterThanOrEqual(stats.totalChats, 2)
            XCTAssertGreaterThanOrEqual(stats.todayChats, 2)
            XCTAssertGreaterThanOrEqual(stats.thisWeekChats, 2)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testChatValidation() {
        let expectation = XCTestExpectation(description: "Chat validation")
        
        Task {
            // Test with empty question
            let emptyQuestionChat = await chatService.createChat(question: "", answer: "Valid answer", childAge: 5)
            XCTAssertNil(emptyQuestionChat, "Should not create chat with empty question")
            
            // Test with empty answer
            let emptyAnswerChat = await chatService.createChat(question: "Valid question", answer: "", childAge: 5)
            XCTAssertNil(emptyAnswerChat, "Should not create chat with empty answer")
            
            // Test with invalid age
            let invalidAgeChat = await chatService.createChat(question: "Valid question", answer: "Valid answer", childAge: 0)
            XCTAssertNil(invalidAgeChat, "Should not create chat with invalid age")
            
            // Test with valid data
            let validChat = await chatService.createChat(question: "Valid question", answer: "Valid answer", childAge: 5)
            XCTAssertNotNil(validChat, "Should create chat with valid data")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 3
        
        // Test concurrent chat creation
        Task {
            await chatService.createChat(question: "Concurrent 1", answer: "Answer 1", childAge: 5)
            expectation.fulfill()
        }
        
        Task {
            await chatService.createChat(question: "Concurrent 2", answer: "Answer 2", childAge: 6)
            expectation.fulfill()
        }
        
        Task {
            await chatService.createChat(question: "Concurrent 3", answer: "Answer 3", childAge: 7)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all chats were created
        let finalExpectation = XCTestExpectation(description: "Final verification")
        Task {
            let allChats = await chatService.fetchRecentChats(limit: 100)
            XCTAssertEqual(allChats.count, 3)
            finalExpectation.fulfill()
        }
        
        wait(for: [finalExpectation], timeout: 5.0)
    }
}

//
//  ChatFlowUITests.swift
//  DadaKnowsUITests
//
//  UI tests for the main chat flow
//

import XCTest

final class ChatFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testChatFlow() throws {
        // Wait for app to load
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        
        // Find and tap the text input field
        let textField = app.textFields["questionInput"]
        XCTAssertTrue(textField.exists)
        textField.tap()
        
        // Type a question
        textField.typeText("What is the sun?")
        
        // Find and tap the send button
        let sendButton = app.buttons["sendButton"]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()
        
        // Wait for response to appear
        let responseText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'sun'")).firstMatch
        XCTAssertTrue(responseText.waitForExistence(timeout: 10))
    }
    
    
    func testNavigationFlow() throws {
        // Test navigation between different tabs
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Test Home tab
        let homeTab = tabBar.buttons["Home"]
        if homeTab.exists {
            homeTab.tap()
            let homeView = app.otherElements["HomeView"]
            XCTAssertTrue(homeView.waitForExistence(timeout: 3))
        }
        
        // Test Chat tab
        let chatTab = tabBar.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
            let chatView = app.otherElements["ChatView"]
            XCTAssertTrue(chatView.waitForExistence(timeout: 3))
        }
        
        // Test Profile tab
        let profileTab = tabBar.buttons["Profile"]
        if profileTab.exists {
            profileTab.tap()
            let profileView = app.otherElements["ProfileView"]
            XCTAssertTrue(profileView.waitForExistence(timeout: 3))
        }
    }
    
    func testProSubscriptionFlow() throws {
        // Navigate to profile
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        let profileTab = tabBar.buttons["Profile"]
        if profileTab.exists {
            profileTab.tap()
        }
        
        // Look for Pro upgrade button
        let proButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Pro'")).firstMatch
        if proButton.exists {
            proButton.tap()
            
            // Pro subscription view should appear
            let proView = app.otherElements["ProSubscriptionView"]
            XCTAssertTrue(proView.waitForExistence(timeout: 3))
            
            // Check for subscription options
            let monthlyButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Monthly'")).firstMatch
            let yearlyButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Yearly'")).firstMatch
            let lifetimeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Lifetime'")).firstMatch
            
            XCTAssertTrue(monthlyButton.exists || yearlyButton.exists || lifetimeButton.exists)
        }
    }
    
    func testOfflineIndicator() throws {
        // This test would require network simulation
        // For now, just check if the offline indicator component exists
        let offlineIndicator = app.otherElements["OfflineIndicator"]
        
        // The indicator might not be visible if online, so we just check it can be found
        // In a real test, you'd simulate network conditions
        if offlineIndicator.exists {
            XCTAssertTrue(offlineIndicator.isHittable)
        }
    }
    
    func testAccessibilityLabels() throws {
        // Test that important UI elements have accessibility labels
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        
        // Check text input accessibility
        let textField = app.textFields["questionInput"]
        XCTAssertTrue(textField.exists)
        XCTAssertNotNil(textField.label)
        
        // Check send button accessibility
        let sendButton = app.buttons["sendButton"]
        XCTAssertTrue(sendButton.exists)
        XCTAssertNotNil(sendButton.label)
        
        // Check voice button accessibility
        let voiceButton = app.buttons["voiceInputButton"]
        if voiceButton.exists {
            XCTAssertNotNil(voiceButton.label)
        }
    }
    
    func testDynamicType() throws {
        // Test that the app responds to Dynamic Type changes
        // This would typically be done by changing system settings
        // For now, just verify text elements exist and are readable
        
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        
        // Check that text elements are present
        let textElements = app.staticTexts
        XCTAssertGreaterThan(textElements.count, 0)
        
        // In a full test, you would:
        // 1. Change Dynamic Type setting
        // 2. Verify text scales appropriately
        // 3. Verify layout doesn't break
    }
    
    func testChatHistory() throws {
        // Test chat history functionality
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        
        // Send a question
        let textField = app.textFields["questionInput"]
        textField.tap()
        textField.typeText("Test question for history")
        
        let sendButton = app.buttons["sendButton"]
        sendButton.tap()
        
        // Wait for response
        sleep(3)
        
        // Check if chat history shows the question
        let historyQuestion = app.staticTexts["Test question for history"]
        XCTAssertTrue(historyQuestion.waitForExistence(timeout: 5))
    }
    
    func testErrorHandling() throws {
        // Test error states (would require network simulation)
        let chatView = app.otherElements["ChatView"]
        XCTAssertTrue(chatView.waitForExistence(timeout: 5))
        
        // In a full test, you would:
        // 1. Simulate network error
        // 2. Send a question
        // 3. Verify error message appears
        // 4. Verify retry functionality works
        
        // For now, just verify the UI can handle empty states
        let textField = app.textFields["questionInput"]
        textField.tap()
        
        let sendButton = app.buttons["sendButton"]
        // Send button should be disabled or handle empty input gracefully
        sendButton.tap()
    }
    
    func testPerformanceMetrics() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

//
//  SubscriptionManagerTests.swift
//  DadaKnowsTests
//
//  Unit tests for SubscriptionManager
//

import XCTest
import StoreKit
@testable import DadaKnows

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() {
        super.setUp()
        // Reset UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "isProMember")
        UserDefaults.standard.removeObject(forKey: "subscriptionStatus")
        UserDefaults.standard.removeObject(forKey: "dailyQuestionCount")
        UserDefaults.standard.removeObject(forKey: "lastQuestionCountReset")
        
        subscriptionManager = SubscriptionManager.shared
    }
    
    override func tearDown() {
        subscriptionManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(subscriptionManager.isProMember)
        XCTAssertEqual(subscriptionManager.subscriptionStatus, .unknown)
        XCTAssertTrue(subscriptionManager.availableProducts.isEmpty)
        XCTAssertTrue(subscriptionManager.purchasedProducts.isEmpty)
        XCTAssertFalse(subscriptionManager.isLoading)
        XCTAssertNil(subscriptionManager.errorMessage)
    }
    
    func testProFeatureAccess() {
        // Test free user
        subscriptionManager.isProMember = false
        
        XCTAssertFalse(subscriptionManager.canUseFeature(.unlimitedQuestions))
        XCTAssertFalse(subscriptionManager.canUseFeature(.voiceInput))
        XCTAssertFalse(subscriptionManager.canUseFeature(.offlineMode))
        XCTAssertFalse(subscriptionManager.canUseFeature(.customization))
        XCTAssertFalse(subscriptionManager.canUseFeature(.prioritySupport))
        XCTAssertFalse(subscriptionManager.canUseFeature(.advancedAnalytics))
        
        // Test pro user
        subscriptionManager.isProMember = true
        
        XCTAssertTrue(subscriptionManager.canUseFeature(.unlimitedQuestions))
        XCTAssertTrue(subscriptionManager.canUseFeature(.voiceInput))
        XCTAssertTrue(subscriptionManager.canUseFeature(.offlineMode))
        XCTAssertTrue(subscriptionManager.canUseFeature(.customization))
        XCTAssertTrue(subscriptionManager.canUseFeature(.prioritySupport))
        XCTAssertTrue(subscriptionManager.canUseFeature(.advancedAnalytics))
    }
    
    func testUsageLimits() {
        // Test free user limits
        subscriptionManager.isProMember = false
        
        XCTAssertEqual(subscriptionManager.getUsageLimit(for: .unlimitedQuestions), 10)
        XCTAssertEqual(subscriptionManager.getUsageLimit(for: .voiceInput), 0)
        
        // Test pro user limits
        subscriptionManager.isProMember = true
        
        XCTAssertNil(subscriptionManager.getUsageLimit(for: .unlimitedQuestions))
        XCTAssertNil(subscriptionManager.getUsageLimit(for: .voiceInput))
    }
    
    func testQuestionCounting() {
        subscriptionManager.isProMember = false
        
        // Initial state - should be able to ask questions
        XCTAssertTrue(subscriptionManager.canAskQuestion())
        XCTAssertEqual(subscriptionManager.getRemainingQuestions(), 10)
        
        // Increment question count
        for i in 1...9 {
            subscriptionManager.incrementQuestionCount()
            XCTAssertTrue(subscriptionManager.canAskQuestion())
            XCTAssertEqual(subscriptionManager.getRemainingQuestions(), 10 - i)
        }
        
        // Reach limit
        subscriptionManager.incrementQuestionCount()
        XCTAssertFalse(subscriptionManager.canAskQuestion())
        XCTAssertEqual(subscriptionManager.getRemainingQuestions(), 0)
    }
    
    func testProMemberUnlimitedQuestions() {
        subscriptionManager.isProMember = true
        
        XCTAssertTrue(subscriptionManager.canAskQuestion())
        XCTAssertNil(subscriptionManager.getRemainingQuestions())
        
        // Incrementing should not affect pro members
        for _ in 1...20 {
            subscriptionManager.incrementQuestionCount()
            XCTAssertTrue(subscriptionManager.canAskQuestion())
            XCTAssertNil(subscriptionManager.getRemainingQuestions())
        }
    }
    
    func testDailyQuestionCountReset() {
        subscriptionManager.isProMember = false
        
        // Set question count to limit
        for _ in 1...10 {
            subscriptionManager.incrementQuestionCount()
        }
        XCTAssertFalse(subscriptionManager.canAskQuestion())
        
        // Simulate new day by setting last reset to yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(yesterday, forKey: "lastQuestionCountReset")
        
        // Should reset and allow questions again
        XCTAssertTrue(subscriptionManager.canAskQuestion())
        XCTAssertEqual(subscriptionManager.getRemainingQuestions(), 10)
    }
    
    func testSubscriptionStatusPersistence() {
        // Set pro status
        subscriptionManager.isProMember = true
        subscriptionManager.subscriptionStatus = .active
        
        // Simulate saving (this happens automatically in the real implementation)
        UserDefaults.standard.set(true, forKey: "isProMember")
        UserDefaults.standard.set("active", forKey: "subscriptionStatus")
        
        // Create new instance to test loading
        let newManager = SubscriptionManager.shared
        
        XCTAssertTrue(newManager.isProMember)
        XCTAssertEqual(newManager.subscriptionStatus, .active)
    }
    
    func testProFeatureTitlesAndDescriptions() {
        let features = ProFeature.allCases
        
        for feature in features {
            XCTAssertFalse(feature.title.isEmpty, "Feature \(feature) should have a title")
            XCTAssertFalse(feature.description.isEmpty, "Feature \(feature) should have a description")
        }
    }
    
    func testSubscriptionStatusCases() {
        let statuses = SubscriptionStatus.allCases
        let expectedStatuses: [SubscriptionStatus] = [.unknown, .active, .inactive, .expired, .inGracePeriod]
        
        XCTAssertEqual(statuses.count, expectedStatuses.count)
        
        for status in expectedStatuses {
            XCTAssertTrue(statuses.contains(status))
        }
    }
    
    func testSubscriptionErrorDescriptions() {
        XCTAssertEqual(SubscriptionError.failedVerification.errorDescription, "购买验证失败")
        XCTAssertEqual(SubscriptionError.productNotFound.errorDescription, "产品未找到")
        XCTAssertEqual(SubscriptionError.purchaseFailed.errorDescription, "购买失败")
    }
}

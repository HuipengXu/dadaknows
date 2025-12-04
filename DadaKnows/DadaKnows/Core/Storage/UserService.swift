//
//  UserService.swift
//  DadaKnows
//
//  用户配置服务 - 处理用户资料的本地和云端同步
//

import Foundation
import Supabase
import Combine

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()
    
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var currentUsername: String {
        return userProfile?.nickname ?? "momo"
    }
    
    private let supabase = SupabaseClient.shared
    // Use lazy initialization to break potential circular dependency between UserService and DataManager during their singleton initialization.
    private lazy var dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAuthListener()
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthListener() {
        // 监听认证状态变化
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        await self?.loadUserProfile()
                    }
                } else {
                    self?.clearUserProfile()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Profile Management
    
    func loadUserProfile() async {
        guard AuthManager.shared.isAuthenticated,
              let currentUser = AuthManager.shared.currentUser else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 首先尝试从云端获取用户配置
            let cloudProfile = try await fetchUserProfileFromCloud(userId: currentUser.id.uuidString)
            
            if let profile = cloudProfile {
                // 云端有数据，更新本地
                userProfile = profile
                await updateLocalUserSettings(from: profile)
            } else {
                // 云端没有数据，从本地创建并同步到云端
                let localSettings = dataManager.fetchOrCreateUserSettings()
                let nickname: String? = {
                    if case .string(let value) = currentUser.userMetadata["nickname"] {
                        return value
                    }
                    return nil
                }()
                
                let avatarUrl: String? = {
                    if case .string(let value) = currentUser.userMetadata["avatar_url"] {
                        return value
                    }
                    return nil
                }()
                
                let newProfile = UserProfile(
                    id: currentUser.id.uuidString,
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    preferredLanguage: localSettings.preferredLanguage ?? "zh-CN",
                    subscriptionStatus: localSettings.subscriptionStatus ?? "free"
                )
                
                userProfile = newProfile
                try await createUserProfileInCloud(profile: newProfile)
            }
            
        } catch {
            errorMessage = "加载用户配置失败: \(error.localizedDescription)"
            print("加载用户配置失败: \(error)")
            
            // 如果云端失败，使用本地数据
            let localSettings = dataManager.fetchOrCreateUserSettings()
            userProfile = UserProfile(
                id: currentUser.id.uuidString,
                nickname: "momo",
                avatarUrl: nil,
                preferredLanguage: localSettings.preferredLanguage ?? "zh-CN",
                subscriptionStatus: localSettings.subscriptionStatus ?? "free"
            )
        }
        
        isLoading = false
    }
    
    func updateUserProfile(nickname: String?, avatarUrl: String?, preferredLanguage: String, subscriptionStatus: String) async {
        guard let currentProfile = userProfile else { return }
        
        isLoading = true
        errorMessage = nil
        
        let updatedProfile = UserProfile(
            id: currentProfile.id,
            nickname: nickname,
            avatarUrl: avatarUrl,
            preferredLanguage: preferredLanguage,
            subscriptionStatus: subscriptionStatus
        )
        
        do {
            // 更新云端
            try await updateUserProfileInCloud(profile: updatedProfile)
            
            // 更新本地
            await updateLocalUserSettings(from: updatedProfile)
            
            // 更新状态
            userProfile = updatedProfile
            
        } catch {
            errorMessage = "更新用户配置失败: \(error.localizedDescription)"
            print("更新用户配置失败: \(error)")
        }
        
        isLoading = false
    }
    
    func updateUsername(_ newUsername: String) {
        guard let currentProfile = userProfile else { return }
        
        Task {
            await updateUserProfile(
                nickname: newUsername.isEmpty ? nil : newUsername,
                avatarUrl: currentProfile.avatarUrl,
                preferredLanguage: currentProfile.preferredLanguage,
                subscriptionStatus: currentProfile.subscriptionStatus
            )
        }
    }
    
    private func clearUserProfile() {
        userProfile = nil
        errorMessage = nil
    }
    
    // MARK: - Cloud Operations
    
    private func fetchUserProfileFromCloud(userId: String) async throws -> UserProfile? {
        let response: [UserProfileResponse] = try await supabase.supabase
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .execute()
            .value
        
        guard let userResponse = response.first else {
            return nil
        }
        
        return UserProfile(
            id: userResponse.id,
            nickname: userResponse.nickname,
            avatarUrl: userResponse.avatarUrl,
            preferredLanguage: userResponse.preferredLanguage,
            subscriptionStatus: userResponse.subscriptionStatus
        )
    }
    
    private func createUserProfileInCloud(profile: UserProfile) async throws {
        let userRequest = UserProfileRequest(
            id: profile.id,
            nickname: profile.nickname,
            avatarUrl: profile.avatarUrl,
            preferredLanguage: profile.preferredLanguage,
            subscriptionStatus: profile.subscriptionStatus
        )
        
        try await supabase.supabase
            .from("users")
            .upsert(userRequest, onConflict: "id")
            .execute()
    }
    
    private func updateUserProfileInCloud(profile: UserProfile) async throws {
        let userRequest = UserProfileRequest(
            id: profile.id,
            nickname: profile.nickname,
            avatarUrl: profile.avatarUrl,
            preferredLanguage: profile.preferredLanguage,
            subscriptionStatus: profile.subscriptionStatus
        )
        
        try await supabase.supabase
            .from("users")
            .update(userRequest)
            .eq("id", value: profile.id)
            .execute()
    }
    
    // MARK: - Local Operations
    
    @MainActor
    private func updateLocalUserSettings(from profile: UserProfile) async {
        let settings = dataManager.fetchOrCreateUserSettings()
        settings.preferredLanguage = profile.preferredLanguage
        settings.subscriptionStatus = profile.subscriptionStatus
        settings.updatedAt = Date()
        dataManager.save()
    }
}


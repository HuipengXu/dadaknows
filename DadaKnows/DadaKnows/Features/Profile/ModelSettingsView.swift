//
//  ModelSettingsView.swift
//  DadaKnows
//
//  专门的模型设置页面
//

import SwiftUI

struct ModelSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var localAIManager = LocalAIManager.shared
    @StateObject private var modelDownloader = ModelDownloader.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showingUpgradeAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingStorageInfo = false
    
    var body: some View {
        NavigationStack {
            List {
                // Model Selection Section
                modelSelectionSection
                
                // Local Model Management Section
                if !aiManager.useGeminiModel {
                    localModelManagementSection
                }
                
                // Storage Information Section
                storageInformationSection
                
                // Advanced Settings Section
                advancedSettingsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("model_settings", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert(NSLocalizedString("upgrade_required", comment: ""), isPresented: $showingUpgradeAlert) {
            Button(NSLocalizedString("upgrade_to_pro", comment: "")) {
                // TODO: Open subscription view
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("cloud_model_requires_pro", comment: ""))
        }
        .alert(NSLocalizedString("delete_model", comment: ""), isPresented: $showingDeleteAlert) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                deleteLocalModel()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("delete_model_confirmation", comment: ""))
        }
    }
    
    // MARK: - Model Selection Section
    
    private var modelSelectionSection: some View {
        Section {
            // Cloud Model Option
            cloudModelOption
            
            // Local Model Option  
            localModelOption
        } header: {
            Text(NSLocalizedString("ai_model_selection", comment: ""))
        } footer: {
            Text(NSLocalizedString("model_selection_description", comment: ""))
        }
    }
    
    private var cloudModelOption: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(aiManager.useGeminiModel ? Color.appPrimary.opacity(0.15) : Color.fillSecondary)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "cloud.fill")
                    .foregroundColor(aiManager.useGeminiModel ? .appPrimary : .textSecondary)
                    .font(.system(size: 20, weight: .medium))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("cloud_model", comment: ""))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    if !subscriptionManager.isProMember {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                }
                
                Text(NSLocalizedString("cloud_model_description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.leading)
                
                // Status indicators
                HStack(spacing: 12) {
                    Label(NSLocalizedString("always_updated", comment: ""), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.statusSuccess)
                    
                    Label(NSLocalizedString("requires_internet", comment: ""), systemImage: "wifi")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(aiManager.useGeminiModel ? Color.appPrimary : Color.separator, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if aiManager.useGeminiModel {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectCloudModel()
        }
    }
    
    private var localModelOption: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(!aiManager.useGeminiModel ? Color.appSecondary.opacity(0.15) : Color.fillSecondary)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "brain.head.profile")
                    .foregroundColor(!aiManager.useGeminiModel ? .appSecondary : .textSecondary)
                    .font(.system(size: 20, weight: .medium))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("local_model", comment: ""))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text(NSLocalizedString("local_model_description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.leading)
                
                // Status indicators
                HStack(spacing: 12) {
                    Label(NSLocalizedString("works_offline", comment: ""), systemImage: "airplane")
                        .font(.caption)
                        .foregroundColor(.statusSuccess)
                    
                    Label(NSLocalizedString("privacy_focused", comment: ""), systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.statusSuccess)
                }
            }
            
            Spacer()
            
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(!aiManager.useGeminiModel ? Color.appSecondary : Color.separator, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if !aiManager.useGeminiModel {
                    Circle()
                        .fill(Color.appSecondary)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectLocalModel()
        }
    }
    
    // MARK: - Local Model Management Section
    
    private var localModelManagementSection: some View {
        Section {
            // Model Status
            modelStatusRow
            
            // Download/Management Actions
            switch localAIManager.modelStatus {
            case .notDownloaded:
                downloadModelRow
                
            case .downloading:
                downloadProgressRow
                
            case .ready:
                modelReadyActions
                
            case .error:
                modelErrorActions
                
            default:
                EmptyView()
            }
        } header: {
            Text(NSLocalizedString("local_model_management", comment: ""))
        } footer: {
            Text(NSLocalizedString("local_model_management_description", comment: ""))
        }
    }
    
    private var modelStatusRow: some View {
        HStack(spacing: 12) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("model_status", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text(localAIManager.modelStatus.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)
            
            Image(systemName: statusSymbol)
                .foregroundColor(statusColor)
                .font(.system(size: 14, weight: .medium))
        }
    }
    
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var downloadModelRow: some View {
        Button(action: startDownload) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.appPrimary)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("download_model", comment: ""))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                    
                    Text(NSLocalizedString("download_model_description", comment: ""))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.appPrimary.opacity(0.6))
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
    
    private var downloadProgressRow: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.appPrimary)
                    
                    Text(NSLocalizedString("downloading", comment: ""))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                Text("\(Int(modelDownloader.downloadProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)
            }
            
            VStack(spacing: 8) {
                ProgressView(value: modelDownloader.downloadProgress)
                    .tint(.appPrimary)
                    .background(Color.fillSecondary)
                    .cornerRadius(2)
                
                HStack {
                    Text(formatBytes(modelDownloader.downloadedBytes))
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text(formatBytes(modelDownloader.totalBytes))
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }
            
            // Download control buttons
            HStack(spacing: 12) {
                if modelDownloader.downloadState == .downloading {
                    Button(NSLocalizedString("pause", comment: "")) {
                        pauseDownload()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                } else if modelDownloader.canResumeDownload {
                    Button(NSLocalizedString("resume", comment: "")) {
                        resumeDownload()
                    }
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                }
                
                Spacer()
                
                Button(NSLocalizedString("cancel", comment: "")) {
                    cancelDownload()
                }
                .font(.caption)
                .foregroundColor(.statusError)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var modelReadyActions: some View {
        VStack(spacing: 8) {
            // Ready status
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.statusSuccess)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("model_ready", comment: ""))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.statusSuccess)
                    
                    Text(NSLocalizedString("model_ready_description", comment: ""))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            
            // Management actions
            VStack(spacing: 8) {
                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.statusError)
                        
                        Text(NSLocalizedString("delete_model", comment: ""))
                            .foregroundColor(.statusError)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { showingStorageInfo = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.appPrimary)
                        
                        Text(NSLocalizedString("storage_info", comment: ""))
                            .foregroundColor(.appPrimary)
                        
                        Spacer()
                        
                        Text(formatBytes(ModelManager.shared.getModelStorageSize()))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var modelErrorActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.statusError)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("download_failed", comment: ""))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.statusError)
                    
                    if case .error(let message) = localAIManager.modelStatus {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
            }
            
            Button(NSLocalizedString("try_again", comment: "")) {
                retryDownload()
            }
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.appPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.appPrimary.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Storage Information Section
    
    private var storageInformationSection: some View {
        Section {
            // Available storage
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.appSecondary)
                    .frame(width: 24)
                
                Text(NSLocalizedString("available_storage", comment: ""))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text(formatBytes(ModelManager.shared.checkAvailableStorage()))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            // Required storage
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                Text(NSLocalizedString("required_storage", comment: ""))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text(formatBytes(Int64(ModelManager.modelInfo.expectedZipSize)))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            // Model storage (if downloaded)
            if ModelManager.shared.getModelStorageSize() > 0 {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.appSecondary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("model_storage_used", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Text(formatBytes(ModelManager.shared.getModelStorageSize()))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        } header: {
            Text(NSLocalizedString("storage_information", comment: ""))
        } footer: {
            Text(NSLocalizedString("storage_information_description", comment: ""))
        }
    }
    
    // MARK: - Advanced Settings Section
    
    private var advancedSettingsSection: some View {
        Section {
            // Background downloads
            HStack {
                Image(systemName: "moon.stars")
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("background_downloads", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Text(NSLocalizedString("background_downloads_description", comment: ""))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .tint(.appPrimary)
                    .disabled(true) // Always enabled for now
            }
            
            // Model information
            Button(action: { showingStorageInfo = true }) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.appSecondary)
                        .frame(width: 24)
                    
                    Text(NSLocalizedString("model_information", comment: ""))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text(NSLocalizedString("advanced_settings", comment: ""))
        }
    }
    
    // MARK: - Helper Properties
    
    private var statusColor: Color {
        switch localAIManager.modelStatus {
        case .ready:
            return .statusSuccess
        case .downloading:
            return .appPrimary
        case .error:
            return .statusError
        case .notDownloaded:
            return .textSecondary
        default:
            return .textSecondary
        }
    }
    
    private var statusSymbol: String {
        switch localAIManager.modelStatus {
        case .ready:
            return "checkmark"
        case .downloading:
            return "arrow.down"
        case .error:
            return "exclamationmark"
        case .notDownloaded:
            return "square.and.arrow.down"
        default:
            return "questionmark"
        }
    }
    
    private var statusText: String {
        switch localAIManager.modelStatus {
        case .ready:
            return NSLocalizedString("ready", comment: "")
        case .downloading:
            return NSLocalizedString("downloading", comment: "")
        case .error:
            return NSLocalizedString("error", comment: "")
        case .notDownloaded:
            return NSLocalizedString("not_downloaded", comment: "")
        default:
            return NSLocalizedString("unknown", comment: "")
        }
    }
    
    // MARK: - Actions
    
    private func selectCloudModel() {
        let success = aiManager.switchToGemini(true)
        if !success {
            showingUpgradeAlert = true
        }
    }
    
    private func selectLocalModel() {
        let localStatus = aiManager.getLocalModelStatus()
        if localStatus.isSupported {
            _ = aiManager.switchToGemini(false)
        }
    }
    
    private func startDownload() {
        Task {
            do {
                try await modelDownloader.startDownload(background: false)
            } catch {
                print("Download failed: \(error)")
            }
        }
    }
    
    private func pauseDownload() {
        Task {
            await modelDownloader.pauseDownload()
        }
    }
    
    private func resumeDownload() {
        Task {
            do {
                try await modelDownloader.startDownload(background: false)
            } catch {
                print("Resume failed: \(error)")
            }
        }
    }
    
    private func cancelDownload() {
        Task {
            await modelDownloader.cancelDownload()
        }
    }
    
    private func retryDownload() {
        Task {
            do {
                try await modelDownloader.startDownload(background: false)
            } catch {
                print("Retry failed: \(error)")
            }
        }
    }
    
    private func deleteLocalModel() {
        do {
            try ModelManager.shared.deleteModel()
            // Model status will be automatically updated by observing LocalAIManager
        } catch {
            print("Delete failed: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    ModelSettingsView()
}

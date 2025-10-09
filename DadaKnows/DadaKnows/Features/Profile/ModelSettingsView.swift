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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var downloadManager = ModelDownloadManager.shared
    
    @State private var showingUpgradeAlert = false
    @State private var selectedModel: LMModel?
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingModel = false
    @State private var deleteError: Error?
    @State private var showingDeleteError = false
    @State private var downloadError: Error?
    @State private var showingDownloadError = false
    @State private var refreshCount = 0
    @State private var showingBackgroundDownloadInfo = false
    
    // Timer to refresh status during download
    private let statusRefreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            List {
                // Model Selection Section
                modelSelectionSection
                
                // Model Information Section  
                if !aiManager.useGeminiModel {
                    modelInformationSection
                }
                
                // Storage Management Section
                if !aiManager.useGeminiModel {
                    storageManagementSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("model_settings", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        handleDismiss()
                    }
                    .foregroundColor(.appPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedModel = localAIManager.getTargetModelInfo()
            
            // 在调试模式下输出当前状态
            if Config.isDebug {
                print("""
                    📱 ModelSettings: 初始状态
                       模型状态: \(localAIManager.modelStatus.localizedDescription)
                       下载进度: \(Int(localAIManager.downloadProgress * 100))%
                       下载消息: \(localAIManager.downloadStatusMessage)
                    """)
            }
        }
        .onReceive(statusRefreshTimer) { _ in
            // 在下载或解压过程中强制刷新视图
            if localAIManager.modelStatus.isProcessing {
                if Config.isDebug {
                    // 每秒输出一次进度（定时器是0.5秒，所以每2次输出一次）
                    refreshCount += 1
                    if refreshCount % 2 == 0 {
                        let clampedProgress = min(1.0, max(0.0, localAIManager.downloadProgress))
                        print("🔄 ModelSettings: 状态刷新 - \(localAIManager.modelStatus.localizedDescription) \(Int(clampedProgress * 100))%")
                    }
                }
            } else {
                // 重置计数器
                refreshCount = 0
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
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                Task {
                    await performDeleteModel()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除本地模型吗？这将释放一定的存储空间，但下次使用时需要重新下载。")
        }
        .alert("删除失败", isPresented: $showingDeleteError) {
            Button("确定") { }
        } message: {
            if let error = deleteError {
                Text("删除模型时发生错误：\(error.localizedDescription)")
            }
        }
        .alert("下载失败", isPresented: $showingDownloadError) {
            Button("确定") { }
        } message: {
            if let error = downloadError {
                Text("下载模型时发生错误：\(error.localizedDescription)")
            }
        }
        .alert("后台下载", isPresented: $showingBackgroundDownloadInfo) {
            Button("好的") { 
                dismiss()
            }
            Button("留在此页") { }
        } message: {
            if localAIManager.modelStatus == .downloading {
                Text("模型正在后台下载中。您可以关闭此页面，下载将继续进行。下载完成后模型将自动可用。")
            } else {
                Text("模型正在后台解压中。此过程会继续在后台进行，完成后模型将自动可用。")
            }
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
                    if subscriptionManager.isProMember {
                        Label(NSLocalizedString("always_updated", comment: ""), systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.statusSuccess)
                    } else {
                        Label("每天2次免费", systemImage: "number.circle")
                            .font(.caption)
                            .foregroundColor(.appAccent)
                    }
                    
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
                    
                    Text("使用先进AI技术提供离线智能服务")
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
    
    // MARK: - Storage Management Section
    
    private var storageManagementSection: some View {
        Section {
            // Download model button
            if localAIManager.modelStatus == .notDownloaded {
                Button(action: {
                    Task {
                        await performDownloadModel()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.appPrimary)
                            .frame(width: 24)
                        
                        Text(NSLocalizedString("download_model", comment: ""))
                            .foregroundColor(.appPrimary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Download/Extract progress display
            if localAIManager.modelStatus.isProcessing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Icon based on status
                        if localAIManager.modelStatus == .extracting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 24)
                        } else {
                            Image(systemName: localAIManager.modelStatus.icon)
                                .foregroundColor(.appPrimary)
                                .frame(width: 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            // 状态标题（只显示一行）
                            if localAIManager.modelStatus == .downloading {
                                Text("正在下载... \(Int(min(1.0, max(0.0, localAIManager.downloadProgress)) * 100))%")
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)
                            } else if localAIManager.modelStatus == .paused {
                                Text("下载已暂停 \(Int(min(1.0, max(0.0, localAIManager.downloadProgress)) * 100))%")
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                            } else if localAIManager.modelStatus == .extracting {
                                Text("正在解压...")
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)
                            } else {
                                Text("准备中...")
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Progress bar
                    if localAIManager.downloadProgress > 0 && (localAIManager.modelStatus == .downloading || localAIManager.modelStatus == .paused) {
                        ProgressView(value: min(1.0, max(0.0, localAIManager.downloadProgress)))
                            .progressViewStyle(LinearProgressViewStyle(tint: localAIManager.modelStatus == .paused ? .orange : .appPrimary))
                    } else if localAIManager.modelStatus == .extracting {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: .appPrimary))
                    } else {
                        ProgressView(value: 0.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .appPrimary))
                    }
                    
                    // Control buttons
                    if localAIManager.modelStatus == .downloading || localAIManager.modelStatus == .paused {
                        HStack(spacing: 12) {
                            // Pause/Resume button
                            Button(action: {
                                Task {
                                    await performPauseResumeDownload()
                                }
                            }) {
                                if downloadManager.isPaused {
                                    Label("继续", systemImage: "play.circle")
                                        .font(.caption)
                                } else {
                                    Label("暂停", systemImage: "pause.circle")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            // Cancel button
                            Button(action: {
                                Task {
                                    await performCancelDownload()
                                }
                            }) {
                                Label("取消", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
            }
            
            // Delete model button
            if localAIManager.modelStatus.isReady {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        if isDeletingModel {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 24)
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                        }
                        
                        Text(isDeletingModel ? "删除中..." : "删除本地模型")
                            .foregroundColor(isDeletingModel ? .textSecondary : .red)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeletingModel)
            }
        } header: {
            Text("存储管理")
        } footer: {
            if localAIManager.modelStatus == .notDownloaded {
                Text("模型文件存储在设备本地。首次使用需要下载模型文件，建议在WiFi环境下进行。")
            } else {
                Text("模型文件已存储在设备本地。删除模型可释放存储空间。")
            }
        }
    }
    
    // MARK: - Model Information Section
    
    private var modelInformationSection: some View {
        Section {
            // Target model info  
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.appSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地AI模型")
                        .foregroundColor(.textPrimary)
                    
                    Text("高性能智能模型")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            
            // Model status
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(localAIManager.modelStatus.isReady ? .statusSuccess : .textSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("模型状态")
                        .foregroundColor(.textPrimary)
                    
                    Text(localAIManager.modelStatus.localizedDescription)
                        .font(.caption)
                        .foregroundColor(localAIManager.modelStatus.isReady ? .statusSuccess : .textSecondary)
                }
                
                Spacer()
            }
            
            // Device compatibility
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("设备兼容性")
                        .foregroundColor(.textPrimary)
                    
                    let status = localAIManager.getAvailabilityStatus()
                    Text(status.localizedDescription)
                        .font(.caption)
                        .foregroundColor(status.isSupported ? .statusSuccess : .statusError)
                }
                
                Spacer()
            }
        } header: {
            Text("模型信息")
            } footer: {
                Text("使用专为儿童优化的AI模型。采用先进技术针对Apple设备深度优化，提供高性能本地智能服务。")
            }
    }
    
    // MARK: - Actions
    
    private func selectCloudModel() {
        // 允许所有用户选择云端模型
        // 非Pro用户会受到每日使用次数限制（在 SubscriptionManager.canAskQuestion 中控制）
        _ = aiManager.switchToGemini(true)
    }
    
    private func selectLocalModel() {
        let localStatus = aiManager.getLocalModelStatus()
        if localStatus.isSupported {
            _ = aiManager.switchToGemini(false)
        }
    }
    
    /// 执行异步下载模型操作
    private func performDownloadModel() async {
        do {
            if Config.isDebug {
                print("📱 ModelSettings: 开始启动下载")
            }
            
            // 启动下载任务（不等待完成）
            // 下载进度由 localAIManager 的 @Published 属性自动更新 UI
            try await localAIManager.downloadModel()
            
            if Config.isDebug {
                print("✅ ModelSettings: 下载任务已启动")
            }
            
        } catch {
            await MainActor.run {
                downloadError = error
                showingDownloadError = true
                if Config.isDebug {
                    print("❌ ModelSettings: 启动下载失败 - \(error)")
                }
            }
        }
    }
    
    /// 执行异步删除模型操作
    private func performDeleteModel() async {
        await MainActor.run {
            isDeletingModel = true
            deleteError = nil
        }
        
        do {
            // 在后台线程执行删除操作，避免阻塞UI
            try await Task.detached(priority: .userInitiated) {
                try await localAIManager.deleteModel()
            }.value
            
            await MainActor.run {
                isDeletingModel = false
                if Config.isDebug {
                    print("🗑️ ModelSettings: 模型已删除")
                }
            }
            
        } catch {
            await MainActor.run {
                isDeletingModel = false
                deleteError = error
                showingDeleteError = true
                if Config.isDebug {
                    print("❌ ModelSettings: 删除模型失败 - \(error)")
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// 暂停/恢复下载
    private func performPauseResumeDownload() async {
        if downloadManager.isPaused {
            // 当前是暂停状态，执行恢复操作
            do {
                try await localAIManager.resumeDownload()
            } catch {
                downloadError = error
                showingDownloadError = true
                if Config.isDebug {
                    print("❌ ModelSettings: 恢复下载失败 - \(error)")
                }
            }
        } else {
            // 当前是下载状态，执行暂停操作
            await localAIManager.pauseDownload()
        }
    }
    
    /// 取消下载
    private func performCancelDownload() async {
        await localAIManager.cancelDownload()
    }
    
    /// 处理页面关闭
    private func handleDismiss() {
        // 如果正在下载或解压，显示后台提示
        if localAIManager.modelStatus.isProcessing {
            showingBackgroundDownloadInfo = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    ModelSettingsView()
}
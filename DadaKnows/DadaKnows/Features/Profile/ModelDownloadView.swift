//
//  ModelDownloadView.swift
//  DadaKnows
//
//  模型下载管理界面
//

import SwiftUI

struct ModelDownloadView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var localAIManager = LocalAIManager.shared
    @StateObject private var modelDownloader = ModelDownloader.shared
    @State private var showDeleteConfirmation = false
    @State private var downloadMode: DownloadMode = .foreground
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Model Information
                modelInfoView
                
                // Current Status
                currentStatusView
                
                // Actions
                actionButtonsView
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.backgroundPrimary)
            .navigationTitle(NSLocalizedString("本地AI模型", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("完成", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .alert(NSLocalizedString("删除模型", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) {
                deleteModel()
            }
        } message: {
            Text(NSLocalizedString("确定要删除本地模型吗？这将释放约640MB存储空间，但需要重新下载才能使用本地AI功能。", comment: ""))
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // AI Robot Icon
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "brain")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.appPrimary)
            }
            
            VStack(spacing: 4) {
                Text(NSLocalizedString("🤖 激活你的专属AI伙伴答答", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("下载本地模型后，答答即可完全离线为你服务，保护隐私，无任何提问限制。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Model Info View
    private var modelInfoView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.appSecondary)
                Text(NSLocalizedString("模型信息", comment: ""))
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                InfoRow(
                    icon: "cube.box",
                    title: NSLocalizedString("模型大小", comment: ""),
                    value: "约 640 MB"
                )
                
                InfoRow(
                    icon: "clock",
                    title: NSLocalizedString("下载时间", comment: ""),
                    value: NSLocalizedString("WiFi下约 5-10 分钟", comment: "")
                )
                
                InfoRow(
                    icon: "shield",
                    title: NSLocalizedString("隐私保护", comment: ""),
                    value: NSLocalizedString("完全离线，数据不上传", comment: "")
                )
                
                InfoRow(
                    icon: "infinity",
                    title: NSLocalizedString("使用限制", comment: ""),
                    value: NSLocalizedString("无限制提问", comment: "")
                )
            }
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Current Status View
    private var currentStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.appSecondary)
                Text(NSLocalizedString("当前状态", comment: ""))
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
            statusDetailView
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var statusDetailView: some View {
        switch localAIManager.modelStatus {
        case .notDownloaded:
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.textSecondary)
                Text(NSLocalizedString("模型未下载", comment: ""))
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.appPrimary)
                    Text(NSLocalizedString("正在下载...", comment: ""))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                ProgressView(value: progress)
                    .tint(.appPrimary)
                
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: modelDownloader.downloadedBytes, countStyle: .file))
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    
                    Text("/")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    
                    Text(ByteCountFormatter.string(fromByteCount: modelDownloader.totalBytes, countStyle: .file))
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    if modelDownloader.isBackgroundMode {
                        Text(NSLocalizedString("后台下载", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.appSecondary)
                    }
                }
            }
            
        case .downloaded:
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.statusSuccess)
                Text(NSLocalizedString("已下载，准备中...", comment: ""))
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
        case .extracting:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text(NSLocalizedString("正在准备模型...", comment: ""))
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.statusSuccess)
                    Text(NSLocalizedString("AI伙伴已准备就绪", comment: ""))
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                
                let storageInfo = localAIManager.getModelStorageInfo()
                Text(NSLocalizedString("存储占用：", comment: "") + ByteCountFormatter.string(fromByteCount: storageInfo.used, countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
            
        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.statusError)
                    Text(NSLocalizedString("下载失败", comment: ""))
                        .foregroundColor(.statusError)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 常见问题提示
                if message.contains("moved") || message.contains("不存在") || message.contains("目录") {
                    Text(NSLocalizedString("建议：请检查设备存储空间，并尝试重新下载", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.appSecondary)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            switch localAIManager.modelStatus {
            case .notDownloaded:
                downloadOptionsView
                
            case .downloading:
                downloadControlsView
                
            case .ready:
                managementButtonsView
                
            case .error:
                retryButtonView
                
            default:
                EmptyView()
            }
        }
    }
    
    private var downloadOptionsView: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("你想如何下载？", comment: ""))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 8) {
                Button(action: { startDownload(background: false) }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.white)
                        Text(NSLocalizedString("立即下载", comment: ""))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary)
                    .cornerRadius(10)
                }
                
                Button(action: { startDownload(background: true) }) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.appPrimary)
                        Text(NSLocalizedString("后台下载", comment: ""))
                            .fontWeight(.medium)
                            .foregroundColor(.appPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            Text(NSLocalizedString("应用需保持在前台，速度最快\n可以关闭应用，下载完成后通知你", comment: ""))
                .font(.caption2)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var downloadControlsView: some View {
        HStack(spacing: 12) {
            Button(action: { pauseDownload() }) {
                HStack {
                    Image(systemName: "pause.fill")
                    Text(NSLocalizedString("暂停", comment: ""))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.textSecondary)
                .background(Color.fillSecondary)
                .cornerRadius(8)
            }
            
            Button(action: { cancelDownload() }) {
                HStack {
                    Image(systemName: "xmark")
                    Text(NSLocalizedString("取消", comment: ""))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.statusError)
                .background(Color.statusError.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var managementButtonsView: some View {
        VStack(spacing: 8) {
            Button(action: { showDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text(NSLocalizedString("删除模型", comment: ""))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.statusError)
                .background(Color.statusError.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var retryButtonView: some View {
        Button(action: { startDownload(background: false) }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text(NSLocalizedString("重试下载", comment: ""))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(Color.appPrimary)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func startDownload(background: Bool) {
        Task {
            do {
                try await localAIManager.startModelDownload(background: background)
                if background {
                    dismiss()
                }
            } catch {
                // 错误会通过localAIManager的error属性传播
                if Config.isDebug {
                    print("❌ ModelDownloadView: 下载启动失败 - \(error)")
                }
            }
        }
    }
    
    private func pauseDownload() {
        Task {
            await localAIManager.pauseModelDownload()
        }
    }
    
    private func cancelDownload() {
        Task {
            await localAIManager.cancelModelDownload()
        }
    }
    
    private func deleteModel() {
        do {
            try localAIManager.deleteModel()
        } catch {
            if Config.isDebug {
                print("❌ ModelDownloadView: 删除模型失败 - \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.appSecondary)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}

enum DownloadMode {
    case foreground
    case background
}

#Preview {
    ModelDownloadView()
}

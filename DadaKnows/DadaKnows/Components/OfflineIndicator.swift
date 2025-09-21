//
//  OfflineIndicator.swift
//  DadaKnows
//
//  离线状态指示器
//

import SwiftUI

struct OfflineIndicator: View {
    @ObservedObject private var offlineManager = OfflineManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        if offlineManager.shouldShowOfflineIndicator {
            HStack(spacing: 8) {
                if !offlineManager.isOnline {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(NSLocalizedString("离线模式", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                } else if offlineManager.hasPendingSync {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .rotationEffect(.degrees(dataManager.isSyncing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: dataManager.isSyncing)
                    
                    Text(dataManager.isSyncing ? "同步中..." : "等待同步")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(offlineManager.isOnline ? Color.blue : Color.orange)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .onTapGesture {
                if offlineManager.canSync && offlineManager.hasPendingSync {
                    Task {
                        await offlineManager.forceSyncAll()
                    }
                }
            }
        }
    }
}

struct NetworkStatusBanner: View {
    @ObservedObject private var offlineManager = OfflineManager.shared
    @State private var showBanner = false
    @State private var hideTask: Task<Void, Never>?
    
    var body: some View {
        VStack {
            if showBanner && !offlineManager.isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("网络连接已断开", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text(NSLocalizedString("您可以浏览离线内容，问题将在联网后处理", comment: ""))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button("知道了") {
                        hideBanner()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.orange)
                .transition(.move(edge: .top))
            }
            
            Spacer()
        }
        .onChange(of: offlineManager.isOnline) { oldValue, newValue in
            handleNetworkStatusChange(isOnline: newValue)
        }
        .onDisappear {
            hideTask?.cancel()
        }
    }
    
    private func handleNetworkStatusChange(isOnline: Bool) {
        hideTask?.cancel()
        
        if !isOnline {
            withAnimation(.easeInOut(duration: 0.3)) {
                showBanner = true
            }
            
            // 5秒后自动隐藏
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        hideBanner()
                    }
                }
            }
        } else {
            hideBanner()
        }
    }
    
    private func hideBanner() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            showBanner = false
        }
    }
}

struct SyncStatusView: View {
    @ObservedObject private var offlineManager = OfflineManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: offlineManager.isOnline ? "wifi" : "wifi.slash")
                    .foregroundColor(offlineManager.isOnline ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("网络状态", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(offlineManager.networkStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("同步状态", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(offlineManager.syncStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if offlineManager.canSync && offlineManager.hasPendingSync {
                    Button(NSLocalizedString("立即同步", comment: "")) {
                        Task {
                            await offlineManager.forceSyncAll()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            
            if offlineManager.hasPendingSync {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("缓存大小", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(offlineManager.getCacheSize())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        OfflineIndicator()
        
        SyncStatusView()
        
        NetworkStatusBanner()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

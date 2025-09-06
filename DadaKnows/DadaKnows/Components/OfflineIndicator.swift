//
//  OfflineIndicator.swift
//  DadaKnows
//
//  离线状态指示器
//

import SwiftUI

struct OfflineIndicator: View {
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        if !offlineManager.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .medium))
                
                Text("离线模式")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if offlineManager.offlineQueueCount > 0 {
                    Text("(\(offlineManager.offlineQueueCount))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

struct NetworkStatusBanner: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var showBanner = false
    
    var body: some View {
        VStack {
            if showBanner && !offlineManager.isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("网络连接已断开")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("您可以浏览离线内容，问题将在联网后处理")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button("知道了") {
                        withAnimation {
                            showBanner = false
                        }
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
        .onChange(of: offlineManager.isOnline) {
            if !offlineManager.isOnline {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBanner = true
                }
                
                // 5秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBanner = false
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBanner = false
                }
            }
        }
    }
}

struct OfflineContentView: View {
    let targetAge: Int
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(offlineManager.getOfflineContent(for: targetAge)) { content in
                    OfflineContentCard(content: content)
                }
            }
            .padding()
        }
        .navigationTitle("离线内容")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OfflineContentCard: View {
    let content: OfflineContent
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.category)
                        .font(.caption)
                        .foregroundColor(.vibrantOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.vibrantOrange.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(content.question)
                        .font(.headline)
                        .foregroundColor(.darkGray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.lightGray)
                }
            }
            
            // Answer (expandable)
            if isExpanded {
                Text(content.answer)
                    .font(.body)
                    .foregroundColor(.darkGray)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    VStack {
        OfflineIndicator()
        
        OfflineContentCard(content: OfflineContent(
            question: "什么是颜色？",
            answer: "颜色就像彩虹一样美丽！红色像苹果，蓝色像天空，绿色像小草。",
            category: "基础认知"
        ))
    }
    .padding()
    .background(Color.creamYellow)
}

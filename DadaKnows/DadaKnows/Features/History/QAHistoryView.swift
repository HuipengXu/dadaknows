//
//  QAHistoryView.swift
//  DadaKnows
//
//  问答历史记录页面 - 替代好奇心日志
//

import SwiftUI
import CoreData

struct QAHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.createdAt, ascending: false)],
        animation: .default)
    private var allChats: FetchedResults<Chat>

    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedSession: ChatSession?
    
    private let spacing: CGFloat = 16
    private let cardPadding: CGFloat = 16
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索和筛选栏
                searchAndFilterSection
                
                // 历史记录列表
                historyListSection
            }
            .background(Color.backgroundSecondary)
            .navigationTitle("对话历史")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索问题或答案")
            .sheet(item: $selectedSession) { session in
                let firstAge = Int(session.chats.first?.targetAge ?? 5)
                ChatView(
                    question: "",
                    targetAge: firstAge,
                    onDismiss: {
                        selectedSession = nil
                    },
                    historicalSession: session
                )
            }
        }
    }
    
    // MARK: - 搜索和筛选区域
    private var searchAndFilterSection: some View {
        VStack(spacing: 0) {
            // 筛选选项
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.title,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color.backgroundPrimary)
        }
    }
    
    // MARK: - 历史记录列表
    private var historyListSection: some View {
        List {
            if filteredChats.isEmpty {
                EmptyHistoryView(searchText: searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(groupedSessions, id: \.date) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            Button(action: {
                                selectedSession = session
                            }) {
                                QASessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(formatSectionDate(group.date))
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.backgroundSecondary)
    }
    
    // MARK: - 数据处理
    private var filteredChats: [Chat] {
        var filtered = Array(allChats)
        
        // 应用搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { chat in
                (chat.question ?? "").localizedCaseInsensitiveContains(searchText) ||
                (chat.answer ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 应用类型筛选
        switch selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter { Calendar.current.isDateInToday($0.createdAt ?? Date.distantPast) }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filtered = filtered.filter { ($0.createdAt ?? Date.distantPast) >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            filtered = filtered.filter { ($0.createdAt ?? Date.distantPast) >= monthAgo }
        case .favorites:
            // TODO: 实现收藏功能
            break
        }
        
        return filtered.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    // 将同一日期内时间相近的问答合并为一个“会话”（例如10分钟内）
    private var groupedSessions: [SessionDateGroup] {
        let calendar = Calendar.current
        let sessionsByDay = Dictionary(grouping: filteredChats) { chat in
            calendar.startOfDay(for: chat.createdAt ?? Date())
        }
        
        let sessionGap: TimeInterval = 10 * 60 // 10分钟
        
        let mapped: [SessionDateGroup] = sessionsByDay.map { date, chats in
            let sortedChats = chats.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
            var sessions: [ChatSession] = []
            var current: [Chat] = []
            var lastTime: Date?
            for chat in sortedChats {
                let ts = chat.createdAt ?? .distantPast
                if let last = lastTime, ts.timeIntervalSince(last) > sessionGap {
                    if !current.isEmpty { sessions.append(ChatSession(chats: current)) }
                    current = [chat]
                } else {
                    current.append(chat)
                }
                lastTime = ts
            }
            if !current.isEmpty { sessions.append(ChatSession(chats: current)) }
            let ordered = sessions.sorted { ($0.chats.last?.createdAt ?? .distantPast) > ($1.chats.last?.createdAt ?? .distantPast) }
            return SessionDateGroup(date: date, sessions: ordered)
        }
        
        return mapped.sorted { $0.date > $1.date }
    }
    
    // MARK: - Helper Functions
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 支持组件

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .appPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.appPrimary : Color.fillSecondary)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - iOS Native List Row
struct QASessionRow: View {
    let session: ChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主要问题（第一个问题）
            if let firstChat = session.chats.first {
                Text(firstChat.question ?? "无问题内容")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
            }
            
            // 会话信息
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Text("\(session.chats.count)个问答")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if let lastChat = session.chats.last {
                    Text(lastChat.createdAt ?? Date(), style: .time)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct QAHistoryCard: View {
    let chat: Chat
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 问题内容
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "questionmark.bubble.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appPrimary)
                    
                    Text("问题")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimary)
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: chat.createdAt ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }
                
                Text(chat.question ?? "No question")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(isExpanded ? nil : 3)
            }
            
            // 答案预览（如果有对应的答案）
            if let answer = chat.answer, !answer.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text("答案")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text(answer)
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                .padding(.top, 8)
                .overlay(
                    Rectangle()
                        .frame(width: 2, height: nil)
                        .foregroundColor(.blue.opacity(0.3)),
                    alignment: .leading
                )
                .padding(.leading, 8)
            }
            
            // 操作按钮
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(isExpanded ? "收起" : "展开")
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct EmptyHistoryView: View {
    let searchText: String
    
    var body: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? "还没有对话记录" : "没有找到相关记录", 
                  systemImage: searchText.isEmpty ? "clock" : "magnifyingglass")
        } description: {
            Text(searchText.isEmpty ? "开始提问来创建你的第一条记录吧！" : "试试其他关键词或调整筛选条件")
        }
        .padding(.vertical, 60)
    }
}

// MARK: - 数据模型

struct ChatSession: Identifiable {
    let id = UUID()
    let chats: [Chat]
}

struct SessionDateGroup {
    let date: Date
    let sessions: [ChatSession]
}

// 会话卡片：展示同一次会话中的多个问答
struct QASessionCard: View, Identifiable {
    let id = UUID()
    let session: ChatSession
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.appPrimary)
                Text("本次会话 · \(sessionTimeRange)")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text(isExpanded ? "收起" : "展开")
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
            }
            
            VStack(spacing: 8) {
                ForEach(displayedChats) { chat in
                    QAHistoryCard(chat: chat)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
    
    private var displayedChats: [Chat] {
        if isExpanded { return session.chats.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) } }
        // 默认显示最新的两条，避免列表过长
        let sorted = session.chats.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        return Array(sorted.prefix(2))
    }
    
    private var sessionTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let first = session.chats.first?.createdAt, let last = session.chats.last?.createdAt else { return "" }
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
}

enum HistoryFilter: CaseIterable {
    case all, today, thisWeek, thisMonth, favorites
    
    var title: String {
        switch self {
        case .all: return "全部"
        case .today: return "今天"
        case .thisWeek: return "本周"
        case .thisMonth: return "本月"
        case .favorites: return "收藏"
        }
    }
}


#Preview {
    QAHistoryView()
}

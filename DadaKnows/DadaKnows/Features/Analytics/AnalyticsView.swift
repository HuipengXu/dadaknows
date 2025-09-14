//
//  AnalyticsView.swift
//  DadaKnows
//
//  学习分析界面
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showProUpgrade = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.creamYellow
                    .ignoresSafeArea()
                
                analyticsContent
            }
            .navigationTitle("学习分析")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showProUpgrade) {
                ProSubscriptionView()
            }
        }
    }
    
    private var analyticsContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // 总览卡片
                overviewSection
                
                // 学习进度图表
                progressChartSection
                
                // 成就展示
                achievementsSection
                
                // 分类统计
                categoryStatsSection
                
                // 学习习惯
                learningHabitsSection
                
                Spacer().frame(height: 50)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var proUpgradePrompt: some View {
        VStack(spacing: 30) {
            // 锁定图标
            ZStack {
                Circle()
                    .fill(Color.lightGray.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.lightGray)
            }
            
            VStack(spacing: 16) {
                Text("解锁学习分析")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Text("升级到Pro会员，查看详细的学习统计和进度分析")
                    .font(.body)
                    .foregroundColor(.lightGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                showProUpgrade = true
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("升级到Pro")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 16)
                .background(Color.vibrantOrange)
                .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            Text("学习概览")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.darkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "总问题数",
                    value: "\(analyticsManager.learningStats.totalQuestions)",
                    icon: "questionmark.circle.fill",
                    color: .vibrantOrange
                )
                
                StatCard(
                    title: "学习天数",
                    value: "\(analyticsManager.learningStats.currentStreak)",
                    icon: "flame.fill",
                    color: .red
                )
                
                StatCard(
                    title: "学习时长",
                    value: formatLearningTime(analyticsManager.learningStats.totalLearningTime),
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "今日问题",
                    value: "\(analyticsManager.learningStats.questionsToday)",
                    icon: "calendar",
                    color: .green
                )
            }
        }
    }
    
    private var progressChartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("学习进度")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Spacer()
                
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            VStack(spacing: 12) {
                // 简化的进度图表
                WeeklyProgressChart(data: analyticsManager.weeklyProgress)
                
                Text("过去7天的学习活动")
                    .font(.caption)
                    .foregroundColor(.lightGray)
            }
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private var achievementsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("成就徽章")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Spacer()
                
                Text("\(analyticsManager.achievements.count)/\(Achievement.allCases.count)")
                    .font(.subheadline)
                    .foregroundColor(.lightGray)
            }
            
            if analyticsManager.achievements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.lightGray)
                    
                    Text("继续学习来解锁成就吧！")
                        .font(.subheadline)
                        .foregroundColor(.lightGray)
                }
                .frame(height: 100)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(analyticsManager.achievements, id: \.rawValue) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
        }
    }
    
    private var categoryStatsSection: some View {
        VStack(spacing: 16) {
            Text("学习分类")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.darkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if analyticsManager.topCategories.isEmpty {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.lightGray)
                    .frame(height: 60)
            } else {
                VStack(spacing: 8) {
                    ForEach(analyticsManager.topCategories.prefix(5)) { category in
                        CategoryRow(category: category)
                    }
                }
            }
        }
    }
    
    private var learningHabitsSection: some View {
        VStack(spacing: 16) {
            Text("学习习惯")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.darkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HabitRow(
                    title: "平均响应时间",
                    value: String(format: "%.1f秒", analyticsManager.learningStats.averageResponseTime),
                    icon: "timer"
                )
                
                HabitRow(
                    title: "语音输入使用",
                    value: "\(analyticsManager.learningStats.voiceInputCount)次",
                    icon: "mic.fill"
                )
                
                HabitRow(
                    title: "离线模式使用",
                    value: "\(analyticsManager.learningStats.offlineModeUsageCount)次",
                    icon: "wifi.slash"
                )
                
                HabitRow(
                    title: "最长连续学习",
                    value: "\(analyticsManager.learningStats.longestStreak)天",
                    icon: "flame.fill"
                )
            }
        }
    }
    
    private func formatLearningTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.darkGray)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.lightGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct WeeklyProgressChart: View {
    let data: [DailyProgress]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { progress in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress.questionCount > 0 ? Color.vibrantOrange : Color.lightGray.opacity(0.3))
                        .frame(width: 30, height: max(4, CGFloat(progress.questionCount) * 10))
                        .animation(.easeInOut(duration: 0.5), value: progress.questionCount)
                    
                    Text(dayAbbreviation(for: progress.date))
                        .font(.caption2)
                        .foregroundColor(.lightGray)
                }
            }
        }
        .frame(height: 80)
    }
    
    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.vibrantOrange.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.vibrantOrange)
            }
            
            Text(achievement.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.darkGray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

struct CategoryRow: View {
    let category: CategoryStats
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.darkGray)
                
                Text("\(category.questionCount) 个问题")
                    .font(.caption)
                    .foregroundColor(.lightGray)
            }
            
            Spacer()
            
            // 简化的进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.lightGray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.vibrantOrange)
                        .frame(width: geometry.size.width * progressPercentage, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.vertical, 4)
    }
    
    private var progressPercentage: CGFloat {
        // 简化计算，基于问题数量
        return min(1.0, CGFloat(category.questionCount) / 50.0)
    }
}

struct HabitRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.vibrantOrange)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.darkGray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.vibrantOrange)
        }
        .padding(.vertical, 4)
    }
}

enum TimeRange: CaseIterable {
    case week
    case month
    case year
    
    var title: String {
        switch self {
        case .week:
            return "周"
        case .month:
            return "月"
        case .year:
            return "年"
        }
    }
}

#Preview {
    AnalyticsView()
}

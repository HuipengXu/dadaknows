//
//  LimitReachedSheet.swift
//  DadaKnows
//
//  免费用户达到每日限制时的提示页面
//  遵循Apple原生设计规范的Sheet呈现方式
//

import SwiftUI

struct LimitReachedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var aiManager = AIManager.shared
    @State private var showSubscriptionView = false
    @State private var showLocalModelView = false

    // 计算下次重置时间（24小时后）
    private var nextResetTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if let resetTime = subscriptionManager.getNextResetTime() {
            // 检查是否是今天
            let calendar = Calendar.current
            if calendar.isDateInToday(resetTime) {
                return NSLocalizedString("今天", comment: "") + " " + formatter.string(from: resetTime)
            } else {
                return NSLocalizedString("明天", comment: "") + " " + formatter.string(from: resetTime)
            }
        }

        // 默认返回明天午夜
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        return NSLocalizedString("明天", comment: "") + " " + formatter.string(from: tomorrow)
    }

    // 计算剩余时间（24小时计时）
    private var timeUntilReset: String {
        let calendar = Calendar.current
        let now = Date()

        guard let resetTime = subscriptionManager.getNextResetTime() else {
            return NSLocalizedString("明天", comment: "")
        }

        let components = calendar.dateComponents([.hour, .minute], from: now, to: resetTime)

        if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return String(format: NSLocalizedString("%d小时%d分钟后", comment: ""), hours, minutes)
            } else if minutes > 0 {
                return String(format: NSLocalizedString("%d分钟后", comment: ""), minutes)
            } else {
                return NSLocalizedString("即将重置", comment: "")
            }
        }

        return NSLocalizedString("明天", comment: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon and title section
                    headerSection

                    // Message section
                    messageSection

                    // Countdown section
                    countdownSection

                    // Options section
                    optionsSection

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(NSLocalizedString("今日提问已用完", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("稍后再说", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .presentationDetents([.fraction(0.9), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSubscriptionView) {
            ProSubscriptionView()
        }
        .sheet(isPresented: $showLocalModelView) {
            ModelSettingsView()
        }
        .onChange(of: subscriptionManager.isProMember) { newValue in
            if newValue {
                dismiss()
            }
        }
        .onChange(of: aiManager.useGeminiModel) { newValue in
            if !newValue {
                dismiss()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // 使用SF Symbols图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text(NSLocalizedString("今日免费提问已用完", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("免费用户每天可提问2次", comment: ""))
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("想要继续使用答答？选择以下方式：", comment: ""))
                .font(.body)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Countdown Section

    private var countdownSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.clock")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))

                Text(NSLocalizedString("下次重置时间", comment: ""))
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()
            }

            VStack(spacing: 4) {
                Text(nextResetTime)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Text(String(format: NSLocalizedString("还有%@", comment: ""), timeUntilReset))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(spacing: 16) {
            // Pro订阅选项
            optionButton(
                title: NSLocalizedString("升级到Pro会员", comment: ""),
                subtitle: NSLocalizedString("每月3000次提问 • 优先响应", comment: ""),
                iconName: "crown.fill",
                iconColor: .yellow,
                backgroundColor: Color.yellow.opacity(0.1),
                action: {
                    showSubscriptionView = true
                }
            )

            // 本地模型选项
            optionButton(
                title: NSLocalizedString("使用本地大模型", comment: ""),
                subtitle: NSLocalizedString("无限使用 • 离线可用 • 保护隐私", comment: ""),
                iconName: "brain.head.profile",
                iconColor: .green,
                backgroundColor: Color.green.opacity(0.1),
                action: {
                    showLocalModelView = true
                }
            )
        }
    }

    // MARK: - Option Button Component

    private func optionButton(
        title: String,
        subtitle: String,
        iconName: String,
        iconColor: Color,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .stroke(Color.separator.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LimitReachedSheet()
}
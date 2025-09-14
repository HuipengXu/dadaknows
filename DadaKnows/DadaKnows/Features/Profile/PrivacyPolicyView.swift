//
//  PrivacyPolicyView.swift
//  DadaKnows
//
//  隐私政策页面
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("隐私政策")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("最后更新：2024年1月")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Divider()
                    
                    // Content sections
                    privacySection(
                        title: "信息收集",
                        content: """
                        我们仅收集必要的信息以提供服务：
                        
                        • 您提出的问题（用于生成回答）
                        • 使用统计（用于改进应用体验）
                        • 账户信息（用于Pro功能管理）
                        
                        我们不会收集：
                        • 13岁以下儿童的个人信息
                        • 位置数据
                        • 联系人信息
                        • 健康信息
                        """
                    )
                    
                    privacySection(
                        title: "数据使用",
                        content: """
                        您的数据仅用于：
                        
                        • 为您的孩子提供个性化的教育回答
                        • 改进AI回答的质量和准确性
                        • 提供技术支持和客户服务
                        • 遵守法律法规要求
                        
                        我们承诺不会将您的数据用于广告或营销目的。
                        """
                    )
                    
                    privacySection(
                        title: "数据保护",
                        content: """
                        我们采用行业标准的安全措施：
                        
                        • 所有数据传输使用TLS 1.3加密
                        • 数据库采用静态加密存储
                        • 定期进行安全审计
                        • 严格的访问控制和权限管理
                        
                        您的数据存储在符合GDPR和COPPA标准的安全服务器上。
                        """
                    )
                    
                    privacySection(
                        title: "儿童隐私",
                        content: """
                        我们特别重视儿童隐私保护：
                        
                        • 不收集13岁以下儿童的个人信息
                        • 所有内容经过安全过滤
                        • 家长可随时查看和删除数据
                        • 遵守COPPA儿童在线隐私保护法
                        
                        如果您发现我们无意中收集了儿童信息，请立即联系我们。
                        """
                    )
                    
                    privacySection(
                        title: "您的权利",
                        content: """
                        您有权：
                        
                        • 查看我们收集的您的数据
                        • 要求更正不准确的信息
                        • 要求删除您的账户和数据
                        • 导出您的数据
                        • 撤回同意（在适用的情况下）
                        
                        如需行使这些权利，请通过应用内反馈功能联系我们。
                        """
                    )
                    
                    privacySection(
                        title: "联系我们",
                        content: """
                        如果您对本隐私政策有任何疑问，请联系我们：
                        
                        邮箱：privacy@dadaknows.com
                        
                        我们会在收到您的询问后48小时内回复。
                        """
                    )
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }
    
    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

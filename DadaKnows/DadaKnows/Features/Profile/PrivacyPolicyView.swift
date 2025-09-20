//
//  PrivacyPolicyView.swift
//  DadaKnows
//
//  隐私政策页面
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    private var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Privacy Policy", comment: ""))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text(NSLocalizedString("最后更新：2024年1月", comment: ""))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Divider()
                    
                    // Content sections
                    privacySection(
                        title: isEnglish ? "Information Collection" : "信息收集",
                        content: isEnglish ? """
                        We only collect necessary information to provide our services:
                        
                        • Questions you ask (to generate answers)
                        • Usage statistics (to improve app experience)
                        • Account information (for Pro feature management)
                        
                        We do not collect:
                        • Personal information from children under 13
                        • Location data
                        • Contact information
                        • Health information
                        """ : """
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
                        title: isEnglish ? "Data Usage" : "数据使用",
                        content: isEnglish ? """
                        Your data is only used for:
                        
                        • Providing personalized educational answers for your child
                        • Improving AI answer quality and accuracy
                        • Providing technical support and customer service
                        • Complying with legal requirements
                        
                        We promise not to use your data for advertising or marketing purposes.
                        """ : """
                        您的数据仅用于：
                        
                        • 为您的孩子提供个性化的教育回答
                        • 改进AI回答的质量和准确性
                        • 提供技术支持和客户服务
                        • 遵守法律法规要求
                        
                        我们承诺不会将您的数据用于广告或营销目的。
                        """
                    )
                    
                    privacySection(
                        title: isEnglish ? "Data Protection" : "数据保护",
                        content: isEnglish ? """
                        We employ industry-standard security measures:
                        
                        • All data transmission uses TLS 1.3 encryption
                        • Database uses static encryption storage
                        • Regular security audits
                        • Strict access control and permission management
                        
                        Your data is stored on secure servers compliant with GDPR and COPPA standards.
                        """ : """
                        我们采用行业标准的安全措施：
                        
                        • 所有数据传输使用TLS 1.3加密
                        • 数据库采用静态加密存储
                        • 定期进行安全审计
                        • 严格的访问控制和权限管理
                        
                        您的数据存储在符合GDPR和COPPA标准的安全服务器上。
                        """
                    )
                    
                    privacySection(
                        title: isEnglish ? "Children's Privacy" : "儿童隐私",
                        content: isEnglish ? """
                        We place special emphasis on children's privacy protection:
                        
                        • No collection of personal information from children under 13
                        • All content is safety filtered
                        • Parents can view and delete data at any time
                        • Compliance with COPPA Children's Online Privacy Protection Act
                        
                        If you discover we have inadvertently collected children's information, please contact us immediately.
                        """ : """
                        我们特别重视儿童隐私保护：
                        
                        • 不收集13岁以下儿童的个人信息
                        • 所有内容经过安全过滤
                        • 家长可随时查看和删除数据
                        • 遵守COPPA儿童在线隐私保护法
                        
                        如果您发现我们无意中收集了儿童信息，请立即联系我们。
                        """
                    )
                    
                    privacySection(
                        title: isEnglish ? "Your Rights" : "您的权利",
                        content: isEnglish ? """
                        You have the right to:
                        
                        • View the data we collect about you
                        • Request correction of inaccurate information
                        • Request deletion of your account and data
                        • Export your data
                        • Withdraw consent (where applicable)
                        
                        To exercise these rights, please contact us through the in-app feedback feature.
                        """ : """
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
                        title: isEnglish ? "Contact Us" : "联系我们",
                        content: isEnglish ? """
                        If you have any questions about this privacy policy, please contact us:
                        
                        Email: privacy@dadaknows.com
                        
                        We will respond to your inquiry within 48 hours.
                        """ : """
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
                    Button(NSLocalizedString("完成", comment: "")) {
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

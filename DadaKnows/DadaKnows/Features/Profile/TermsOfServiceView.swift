//
//  TermsOfServiceView.swift
//  DadaKnows
//
//  服务条款页面
//

import SwiftUI

struct TermsOfServiceView: View {
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
                        Text(NSLocalizedString("Terms of Service", comment: ""))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text(NSLocalizedString("最后更新：2024年1月", comment: ""))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Divider()
                    
                    // Content sections
                    termsSection(
                        title: isEnglish ? "Service Description" : "服务说明",
                        content: isEnglish ? """
                        DadaKnows is an AI educational app designed specifically for children, aimed at providing safe, accurate, and age-appropriate knowledge Q&A services for children aged 2-12.
                        
                        By using this app, you agree to comply with all provisions of these Terms of Service.
                        """ : """
                        DadaKnows（"答答"）是一款专为儿童设计的AI教育应用，旨在为2-12岁的儿童提供安全、准确、年龄适宜的知识问答服务。
                        
                        通过使用本应用，您同意遵守本服务条款的所有规定。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Usage Rules" : "使用规则",
                        content: isEnglish ? """
                        When using this app, you agree to:
                        
                        • Use the app only for educational purposes
                        • Not submit inappropriate, harmful, or illegal content
                        • Not attempt to bypass security measures or content filtering
                        • Not abuse or overuse the service
                        • Comply with local laws and regulations
                        
                        We reserve the right to suspend or terminate service upon discovering violations.
                        """ : """
                        使用本应用时，您同意：
                        
                        • 仅将应用用于教育目的
                        • 不提交不当、有害或违法内容
                        • 不尝试绕过安全措施或内容过滤
                        • 不滥用或过度使用服务
                        • 遵守当地法律法规
                        
                        我们保留在发现违规使用时暂停或终止服务的权利。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Content Accuracy" : "内容准确性",
                        content: isEnglish ? """
                        We strive to provide accurate and useful information, but please note:
                        
                        • AI-generated answers are for reference only
                        • Should not replace professional medical, legal, or other professional advice
                        • Parents should supervise and guide children's use
                        • We do not assume responsibility for complete content accuracy
                        
                        If you find inappropriate content, please report it promptly through the feedback feature.
                        """ : """
                        我们努力提供准确、有用的信息，但请注意：
                        
                        • AI生成的回答仅供参考
                        • 不应替代专业医疗、法律或其他专业建议
                        • 家长应监督和指导儿童使用
                        • 我们不对内容的完全准确性承担责任
                        
                        如发现不当内容，请及时通过反馈功能报告。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Pro Subscription Service" : "Pro订阅服务",
                        content: isEnglish ? """
                        Pro subscription includes the following features:
                        
                        • Unlimited questions
                        • Priority customer support
                        • Advanced feature access
                        • Ad-free experience
                        
                        Subscription fees:
                        • Monthly subscription: $1.99/month
                        • Annual subscription: $19.99/year
                        
                        Subscriptions will auto-renew, you can cancel anytime in App Store settings.
                        """ : """
                        Pro订阅包含以下特性：
                        
                        • 无限制提问次数
                        • 优先客户支持
                        • 高级功能访问
                        • 无广告体验
                        
                        订阅费用：
                        • 月度订阅：¥12/月
                        • 年度订阅：¥98/年
                        
                        订阅将自动续费，您可随时在App Store设置中取消。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Refund Policy" : "退款政策",
                        content: isEnglish ? """
                        Refund policy follows App Store standards:
                        
                        • Refunds can be requested within 24 hours of subscription start
                        • Service interruptions due to technical issues may qualify for refunds
                        • Refund requests must be processed through App Store
                        • We reserve the right to review refund requests
                        
                        For refunds, please contact Apple customer service or apply through App Store.
                        """ : """
                        退款政策遵循App Store标准：
                        
                        • 订阅开始后24小时内可申请退款
                        • 技术问题导致的服务中断可申请退款
                        • 退款申请需通过App Store处理
                        • 我们保留审核退款申请的权利
                        
                        如需退款，请联系Apple客服或通过App Store申请。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Intellectual Property" : "知识产权",
                        content: isEnglish ? """
                        This app and its content are protected by intellectual property law:
                        
                        • App design and code belong to us
                        • User-generated questions belong to users
                        • AI-generated answers are available for user use
                        • Unauthorized copying or distribution of app content is prohibited
                        
                        We respect others' intellectual property and expect users to do the same.
                        """ : """
                        本应用及其内容受知识产权法保护：
                        
                        • 应用设计、代码归我们所有
                        • 用户生成的问题归用户所有
                        • AI生成的回答可供用户使用
                        • 不得未经授权复制或分发应用内容
                        
                        我们尊重他人的知识产权，也期望用户同样如此。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Disclaimer" : "免责声明",
                        content: isEnglish ? """
                        To the maximum extent permitted by law:
                        
                        • Service is provided "as is" without any express or implied warranties
                        • We are not responsible for service interruptions, data loss, or other damages
                        • Users assume the risk of using the service
                        • Our liability is limited to the subscription fees you have paid
                        
                        Some jurisdictions do not allow the exclusion of certain warranties, so the above limitations may not apply to you.
                        """ : """
                        在法律允许的最大范围内：
                        
                        • 服务按"现状"提供，不提供任何明示或暗示的保证
                        • 我们不对服务中断、数据丢失或其他损失承担责任
                        • 用户使用服务的风险由用户自行承担
                        • 我们的责任限于您支付的订阅费用
                        
                        某些司法管辖区不允许排除某些保证，因此上述限制可能不适用于您。
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Terms Changes" : "条款变更",
                        content: isEnglish ? """
                        We may update these terms from time to time:
                        
                        • Major changes will be notified through in-app notifications
                        • Continued use of the service indicates acceptance of new terms
                        • If you disagree with new terms, please stop using the service
                        • Historical versions can be obtained by contacting us
                        """ : """
                        我们可能会不时更新这些条款：
                        
                        • 重大变更会通过应用内通知告知
                        • 继续使用服务即表示接受新条款
                        • 如不同意新条款，请停止使用服务
                        • 历史版本可通过联系我们获取
                        """
                    )
                    
                    termsSection(
                        title: isEnglish ? "Contact Us" : "联系我们",
                        content: isEnglish ? """
                        If you have any questions about these Terms of Service, please contact us:
                        
                        Email: support@dadaknows.com
                        
                        We will respond to your inquiry within 48 hours.
                        """ : """
                        如果您对服务条款有任何疑问，请联系我们：
                        
                        邮箱：support@dadaknows.com
                        
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
    
    private func termsSection(title: String, content: String) -> some View {
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
    TermsOfServiceView()
}

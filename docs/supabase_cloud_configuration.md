# Supabase云端配置指南

## 问题解决

您遇到的邮箱验证URL问题需要在Supabase云端控制台中解决。

### 当前问题

1. 验证邮件中的链接指向无效地址（带有@符号的URL）
2. 邮件验证后应该重定向到应用而不是浏览器

## 配置步骤

### 1. 配置Authentication URL设置

登录 [Supabase Dashboard](https://supabase.com/dashboard)，进入您的项目：

**位置：** Authentication → URL Configuration

```
Site URL: dadaknows://auth

Redirect URLs:
dadaknows://auth
dadaknows://auth/callback
```

### 2. 启用邮件确认

**位置：** Authentication → Settings

在 **Email** 部分：
- ✅ Enable email confirmations
- ✅ Enable signup confirmations

### 3. 配置SMTP设置（推荐）

**位置：** Authentication → Settings → SMTP Settings

推荐使用第三方SMTP服务：

#### Gmail SMTP
```
SMTP Host: smtp.gmail.com
SMTP Port: 587
SMTP User: your-email@gmail.com
SMTP Pass: your-app-password
Enable SSL: Yes
```

#### SendGrid SMTP
```
SMTP Host: smtp.sendgrid.net
SMTP Port: 587
SMTP User: apikey
SMTP Pass: your-sendgrid-api-key
Enable SSL: Yes
```

### 4. 自定义邮件模板（可选）

**位置：** Authentication → Email Templates → Confirm signup

#### 建议的邮件模板：

**Subject:** 验证您的DadaKnows账户

**Body:**
```html
<div style="font-family: 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="text-align: center; margin-bottom: 30px;">
        <div style="font-size: 24px; margin-bottom: 10px;">🧠</div>
        <h1 style="color: #FF6B35; margin: 0;">DadaKnows</h1>
        <p style="color: #666; margin: 10px 0 0 0;">您的AI智慧伙伴</p>
    </div>
    
    <div style="background: #f8f9fa; padding: 30px; border-radius: 12px; margin-bottom: 20px;">
        <h2 style="color: #333; margin: 0 0 15px 0;">欢迎加入DadaKnows！</h2>
        <p style="color: #666; line-height: 1.6; margin: 0 0 20px 0;">
            感谢您注册DadaKnows！请点击下面的按钮验证您的邮箱地址，开始您的智慧探索之旅。
        </p>
        
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" 
               style="background: #FF6B35; color: white; padding: 12px 30px; text-decoration: none; border-radius: 25px; font-weight: 600; display: inline-block;">
                验证邮箱地址
            </a>
        </div>
    </div>
    
    <div style="color: #999; font-size: 14px; text-align: center;">
        <p>此链接将在24小时后失效</p>
        <p>如果您没有创建DadaKnows账户，请忽略此邮件</p>
    </div>
</div>
```

## 验证配置

配置完成后，进行以下测试：

1. **测试注册流程**
   - 使用新邮箱注册
   - 检查是否收到验证邮件
   - 点击验证链接确认是否正确跳转到应用

2. **检查URL格式**
   - 验证邮件中的链接应该类似：
   ```
   https://fwvyrcekbngcpiudljpj.supabase.co/auth/v1/verify?token=...&type=signup&redirect_to=dadaknows://auth
   ```

3. **确认应用响应**
   - 点击验证链接后应该自动打开DadaKnows应用
   - 应用应该显示验证成功并完成登录

## 常见问题

### Q: 邮件中的链接包含@符号怎么办？
A: 这通常是URL编码问题，在Supabase控制台重新配置Redirect URLs可以解决。

### Q: 点击链接没有打开应用？
A: 确保在Redirect URLs中正确配置了`dadaknows://auth`。

### Q: 验证后没有自动登录？
A: 检查应用的URL处理逻辑，确保`handleSupabaseAuth`函数正常工作。

## 代码验证

您的应用代码已经正确配置：

✅ URL Scheme: `dadaknows` (Info.plist)  
✅ 深度链接处理: `handleSupabaseAuth` (DadaKnowsApp.swift)  
✅ 成功消息显示: AuthManager.successMessage  

只需要在Supabase云端控制台完成上述配置即可。

# DadaKnows Supabase 云端邮件模板

基于Supabase官方文档优化：[Email Templates Guide](https://supabase.com/docs/guides/auth/auth-email-templates)

## Mailgun SMTP 配置

在 Supabase Dashboard > Authentication > Emails > SMTP Settings 中配置：

```
Enable Custom SMTP: ✅
Host: smtp.mailgun.org
Port: 587
Username: postmaster@your-domain.mailgun.org
Password: [your-mailgun-password]
Sender email: support@dadaknows.com
Sender name: DadaKnows
```

## Supabase 邮件模板变量说明

根据[官方文档](https://supabase.com/docs/guides/auth/auth-email-templates)，可用变量包括：

- `{{ .ConfirmationURL }}` - 确认链接
- `{{ .Token }}` - 6位数OTP验证码
- `{{ .TokenHash }}` - 哈希版本的Token
- `{{ .SiteURL }}` - 应用站点URL
- `{{ .RedirectTo }}` - 重定向URL
- `{{ .Data }}` - 用户元数据
- `{{ .Email }}` - 用户邮箱地址
- `{{ .NewEmail }}` - 新邮箱地址（仅变更邮箱模板）

## 邮件模板

### 1. Confirm signup（确认注册）

**Subject:** 🧠 欢迎加入DadaKnows - 请验证您的邮箱

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>欢迎加入DadaKnows</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #2563eb, #3b82f6);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .otp-box {
            background: #f0f9ff;
            border: 2px solid #0ea5e9;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }
        .otp-code {
            font-size: 32px;
            font-weight: bold;
            color: #0ea5e9;
            letter-spacing: 4px;
            margin: 10px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
        .highlight {
            background: linear-gradient(120deg, #fef3c7 0%, #fef3c7 100%);
            padding: 2px 6px;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">欢迎加入DadaKnows！</h1>
        </div>
        
        <div class="message">
            <p>亲爱的用户{{ if .Email }} (<strong>{{ .Email }}</strong>){{ end }}，</p>
            <p>感谢您注册DadaKnows！我们很高兴您选择加入我们的<span class="highlight">AI智能问答</span>社区。</p>
            <p>请选择以下任一方式来验证您的邮箱地址：</p>
        </div>
        
        <!-- 方式1：点击确认链接 -->
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                ✅ 点击验证邮箱地址
            </a>
        </div>
        
        <div style="text-align: center; margin: 20px 0; color: #6b7280;">
            <em>或者</em>
        </div>
        
        <!-- 方式2：输入OTP验证码 -->
        <div class="otp-box">
            <h3 style="margin: 0 0 10px 0; color: #0ea5e9;">📱 验证码</h3>
            <p style="margin: 5px 0; color: #6b7280;">在应用中输入以下6位验证码：</p>
            <div class="otp-code">{{ .Token }}</div>
            <p style="margin: 5px 0; color: #6b7280; font-size: 14px;">验证码5分钟内有效</p>
        </div>
        
        <div class="message">
            <p><strong>关于DadaKnows：</strong></p>
            <ul style="color: #4b5563;">
                <li>🤖 智能AI助手，回答各种问题</li>
                <li>👶 适合不同年龄段的专业回答</li>
                <li>🌍 支持多语言交流</li>
                <li>📱 随时随地获取知识</li>
            </ul>
            <p>如果您没有注册DadaKnows账户，请忽略此邮件。</p>
        </div>
        
        <div class="footer">
            <p>此邮件由DadaKnows自动发送，请勿回复。</p>
            <p>如有疑问，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 让每个问题都有智慧的答案。</p>
            <p style="margin-top: 10px; font-size: 12px;">访问：<a href="{{ .SiteURL }}" style="color: #2563eb;">{{ .SiteURL }}</a></p>
        </div>
    </div>
</body>
</html>
```

---

### 2. Invite user（邀请用户）

**Subject:** 🎉 您被邀请加入DadaKnows！

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DadaKnows邀请</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #059669, #10b981);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">您被邀请加入DadaKnows！</h1>
        </div>
        
        <div class="message">
            <p>Hello！</p>
            <p>您的朋友邀请您加入DadaKnows - 一个智能AI问答平台！</p>
            <p>在这里，您可以：</p>
            <ul>
                <li>🤔 提出任何问题，获得智能回答</li>
                <li>👨‍👩‍👧‍👦 为不同年龄的家庭成员定制答案</li>
                <li>🌐 享受多语言支持</li>
                <li>📚 探索无限知识世界</li>
            </ul>
        </div>
        
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                🎉 接受邀请并注册
            </a>
        </div>
        
        <div class="footer">
            <p>此邀请链接将在24小时后失效。</p>
            <p>如有疑问，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 让每个问题都有智慧的答案。</p>
        </div>
    </div>
</body>
</html>
```

---

### 3. Magic Link（魔术链接登录）

**Subject:** 🚀 您的DadaKnows登录链接

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DadaKnows登录链接</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #7c3aed, #8b5cf6);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .otp-box {
            background: #f0f9ff;
            border: 2px solid #0ea5e9;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }
        .otp-code {
            font-size: 32px;
            font-weight: bold;
            color: #0ea5e9;
            letter-spacing: 4px;
            margin: 10px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
        .security-notice {
            background: #e0f2fe;
            border: 1px solid #0284c7;
            border-radius: 8px;
            padding: 16px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">快速登录DadaKnows</h1>
        </div>
        
        <div class="message">
            <p>您好{{ if .Email }} <strong>{{ .Email }}</strong>{{ end }}！</p>
            <p>我们收到了您的登录请求。选择以下任一方式安全登录您的DadaKnows账户：</p>
        </div>
        
        <!-- 方式1：魔术链接 -->
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                🚀 点击立即登录
            </a>
        </div>
        
        <div style="text-align: center; margin: 20px 0; color: #6b7280;">
            <em>或者</em>
        </div>
        
        <!-- 方式2：OTP验证码 -->
        <div class="otp-box">
            <h3 style="margin: 0 0 10px 0; color: #0ea5e9;">🔐 登录验证码</h3>
            <p style="margin: 5px 0; color: #6b7280;">在应用中输入以下6位验证码：</p>
            <div class="otp-code">{{ .Token }}</div>
            <p style="margin: 5px 0; color: #6b7280; font-size: 14px;">验证码15分钟内有效</p>
        </div>
        
        <!-- 防预取自定义链接 -->
        <div class="security-notice">
            <p><strong>🔐 安全提醒：</strong></p>
            <p>为防止邮件预取导致链接失效，您也可以<a href="{{ .SiteURL }}/auth/magic-link?token_hash={{ .TokenHash }}&type=magiclink{{ if .RedirectTo }}&redirect_to={{ .RedirectTo }}{{ end }}" style="color: #0284c7;">点击此安全链接</a>，然后在页面上确认登录。</p>
            <p style="margin-top: 10px; font-size: 13px;">此登录链接将在15分钟后失效，且只能使用一次。如果您没有请求登录，请忽略此邮件。</p>
        </div>
        
        <div class="footer">
            <p>此邮件由DadaKnows安全系统自动发送，请勿回复。</p>
            <p>如有疑问，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 安全便捷的AI问答体验。</p>
            <p style="margin-top: 10px; font-size: 12px;">访问：<a href="{{ .SiteURL }}" style="color: #2563eb;">{{ .SiteURL }}</a></p>
        </div>
    </div>
</body>
</html>
```

---

### 4. Change Email Address（更改邮箱地址）

**Subject:** ✉️ 确认您的DadaKnows邮箱地址更改

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>确认邮箱地址更改</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #ea580c, #f97316);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .otp-box {
            background: #f0f9ff;
            border: 2px solid #0ea5e9;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }
        .otp-code {
            font-size: 32px;
            font-weight: bold;
            color: #0ea5e9;
            letter-spacing: 4px;
            margin: 10px 0;
        }
        .email-change-box {
            background: #f3f4f6;
            border: 1px solid #d1d5db;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
        .info-box {
            background: #fef3c7;
            border: 1px solid #f59e0b;
            border-radius: 8px;
            padding: 16px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">确认邮箱地址更改</h1>
        </div>
        
        <div class="message">
            <p>您好！</p>
            <p>我们收到了更改您DadaKnows账户邮箱地址的请求。</p>
        </div>
        
        <!-- 邮箱更改详情 -->
        <div class="email-change-box">
            <h3 style="margin: 0 0 15px 0; color: #374151;">📧 邮箱更改详情</h3>
            {{ if .Email }}<p style="margin: 5px 0;"><strong>当前邮箱:</strong> {{ .Email }}</p>{{ end }}
            {{ if .NewEmail }}<p style="margin: 5px 0;"><strong>新邮箱:</strong> <span style="color: #ea580c; font-weight: bold;">{{ .NewEmail }}</span></p>{{ end }}
            <p style="margin: 5px 0; font-size: 14px; color: #6b7280;">请确认这是您要更改的邮箱地址</p>
        </div>
        
        <div class="message">
            <p>为了确保账户安全，请选择以下任一方式确认这次更改：</p>
        </div>
        
        <!-- 方式1：点击确认链接 -->
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                ✉️ 确认邮箱更改
            </a>
        </div>
        
        <div style="text-align: center; margin: 20px 0; color: #6b7280;">
            <em>或者</em>
        </div>
        
        <!-- 方式2：输入OTP验证码 -->
        <div class="otp-box">
            <h3 style="margin: 0 0 10px 0; color: #0ea5e9;">🔐 验证码</h3>
            <p style="margin: 5px 0; color: #6b7280;">在应用中输入以下6位验证码：</p>
            <div class="otp-code">{{ .Token }}</div>
            <p style="margin: 5px 0; color: #6b7280; font-size: 14px;">验证码24小时内有效</p>
        </div>
        
        <div class="info-box">
            <p><strong>⚠️ 重要提醒：</strong></p>
            <p>确认后，您将需要使用新邮箱地址 {{ if .NewEmail }}<strong>{{ .NewEmail }}</strong>{{ end }} 登录DadaKnows。请确保您可以正常访问新邮箱。</p>
        </div>
        
        <div class="message">
            <p>如果您没有请求更改邮箱地址，请立即联系我们的客服团队。</p>
        </div>
        
        <div class="footer">
            <p>此确认链接将在24小时后失效。</p>
            <p>如有疑问，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 保护您的账户安全。</p>
            <p style="margin-top: 10px; font-size: 12px;">访问：<a href="{{ .SiteURL }}" style="color: #2563eb;">{{ .SiteURL }}</a></p>
        </div>
    </div>
</body>
</html>
```

---

### 5. Reset Password（重置密码）

**Subject:** 🔐 重置您的DadaKnows密码

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>重置DadaKnows密码</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #dc2626, #ef4444);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
        .security-notice {
            background: #fef3c7;
            border: 1px solid #f59e0b;
            border-radius: 8px;
            padding: 16px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">重置您的密码</h1>
        </div>
        
        <div class="message">
            <p>您好，</p>
            <p>我们收到了重置您DadaKnows账户密码的请求。如果这是您本人的操作，请点击下面的按钮来设置新密码：</p>
        </div>
        
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                🔐 重置密码
            </a>
        </div>
        
        <div class="security-notice">
            <h3 style="color: #92400e; margin: 0 0 8px 0; font-size: 16px;">🛡️ 安全提醒</h3>
            <p style="color: #92400e; margin: 0; font-size: 14px;">此链接将在1小时后失效。如果您没有请求重置密码，请忽略此邮件并确保您的账户安全。</p>
        </div>
        
        <div class="message">
            <p><strong>密码安全建议：</strong></p>
            <ul style="color: #4b5563;">
                <li>🔒 使用至少8位字符的强密码</li>
                <li>🔄 包含大小写字母、数字和特殊符号</li>
                <li>❌ 不要使用与其他网站相同的密码</li>
                <li>📱 考虑使用密码管理器</li>
            </ul>
        </div>
        
        <div class="footer">
            <p>此邮件由DadaKnows安全系统自动发送，请勿回复。</p>
            <p>如有疑问或需要帮助，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 保护您的账户安全是我们的责任。</p>
        </div>
    </div>
</body>
</html>
```

---

### 6. Reauthentication（重新认证）

**Subject:** 🔒 DadaKnows账户安全验证

**Message body (HTML):**
```html
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>账户安全验证</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 32px;
            font-weight: bold;
            color: #2563eb;
            margin-bottom: 10px;
        }
        .title {
            color: #1f2937;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .message {
            color: #4b5563;
            font-size: 16px;
            margin-bottom: 30px;
        }
        .button {
            display: inline-block;
            padding: 16px 32px;
            background: linear-gradient(135deg, #7c2d12, #ea580c);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e5e7eb;
            color: #6b7280;
            font-size: 14px;
            text-align: center;
        }
        .warning-box {
            background: #fef2f2;
            border: 1px solid #f87171;
            border-radius: 8px;
            padding: 16px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🧠 DadaKnows</div>
            <h1 class="title">账户安全验证</h1>
        </div>
        
        <div class="message">
            <p>您好！</p>
            <p>为了保护您的DadaKnows账户安全，我们需要您重新验证身份。</p>
            <p>这通常发生在以下情况：</p>
            <ul>
                <li>🔄 修改重要账户信息</li>
                <li>🏠 从新设备或地点登录</li>
                <li>⏰ 长时间未使用账户</li>
                <li>🛡️ 检测到异常活动</li>
            </ul>
        </div>
        
        <div style="text-align: center;">
            <a href="{{ .ConfirmationURL }}" class="button">
                🔒 立即验证身份
            </a>
        </div>
        
        <div class="warning-box">
            <p><strong>🚨 安全提醒：</strong></p>
            <p style="color: #dc2626; margin: 0;">如果您没有进行任何敏感操作，请立即联系我们的客服团队，您的账户可能面临安全风险。</p>
        </div>
        
        <div class="footer">
            <p>此验证链接将在30分钟后失效。</p>
            <p>如有疑问，请联系我们：<a href="mailto:support@dadaknows.com" style="color: #2563eb;">support@dadaknows.com</a></p>
            <p style="margin-top: 20px;">© 2025 DadaKnows. 您的安全是我们的首要任务。</p>
        </div>
    </div>
</body>
</html>
```

## 云端配置步骤

1. **SMTP配置**：在 Authentication > Emails > SMTP Settings 中配置Mailgun

2. **URL配置**：在 Authentication > URL Configuration 中设置：
   - Site URL: `dadaknows://auth`
   - Redirect URLs: 添加 `dadaknows://auth`

3. **模板配置**：在 Authentication > Emails > Templates 中，分别选择对应的模板类型，复制上面的HTML代码到Message body字段中

4. **启用邮件确认**：在 Authentication > Settings 中启用 "Enable email confirmations"

## 重要特性和最佳实践

### 🔧 充分利用Supabase变量

根据[官方文档](https://supabase.com/docs/guides/auth/auth-email-templates)，我们的模板充分利用了：

- **双重验证方式**：每个模板都提供点击链接和OTP验证码两种方式
- **条件渲染**：使用Go模板语法 `{{ if .Email }}...{{ end }}` 动态显示内容
- **防预取保护**：Magic Link模板包含自定义防预取链接
- **邮箱信息显示**：Change Email模板显示当前和新邮箱地址对比

### 🛡️ 安全特性

1. **邮件预取保护**
   - Magic Link模板提供备用安全链接
   - 使用 `{{ .TokenHash }}` 构建自定义链接

2. **多重验证**
   - 所有模板提供OTP验证码作为备选方案
   - 防止某些邮件客户端的链接预取问题

3. **时效性提醒**
   - 明确标注各类验证码和链接的有效期
   - 提供安全建议和注意事项

### 📱 移动端优化

- 响应式设计，适配各种屏幕尺寸
- OTP验证码便于移动端输入
- 深度链接支持 `dadaknows://auth`

### 🎨 设计特色

- **一致的品牌形象**：统一的DadaKnows品牌元素
- **现代化UI**：渐变按钮、圆角设计、阴影效果
- **清晰的信息层级**：重要信息高亮显示
- **多语言友好**：中文本地化设计

### ⚠️ 注意事项

1. **邮件追踪**
   - 如果使用外部邮件服务商的"邮件追踪"功能，需要禁用以防链接被重写

2. **服务端重定向**
   - 如需服务端验证，可使用 `{{ .TokenHash }}` 构建自定义端点

3. **测试建议**
   - 在不同邮件客户端测试模板显示效果
   - 测试OTP和链接验证两种方式
   - 验证深度链接在iOS应用中的表现

### 📊 监控和优化

- 监控邮件送达率和打开率
- 跟踪用户使用OTP vs 链接的偏好
- 定期更新模板内容和设计

通过这些优化的模板，DadaKnows用户将获得专业、安全、用户友好的邮件验证体验！

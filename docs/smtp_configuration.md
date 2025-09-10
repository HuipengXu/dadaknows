# DadaKnows SMTP 邮件配置指南

## 问题解决

您遇到的邮箱验证问题已经修复：
1. ✅ 重定向URL已从localhost改为`dadaknows://auth`
2. ✅ 配置了自定义邮件模板，品牌化为DadaKnows
3. ✅ 添加了自定义URL Scheme处理
4. ✅ 配置了SMTP邮件服务器

## 环境变量配置

在Supabase项目设置中配置以下环境变量：

### 方案1: Gmail SMTP (推荐)
```bash
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

**设置步骤：**
1. 登录Gmail账户
2. 开启两步验证
3. 生成应用专用密码
4. 使用该密码作为SMTP_PASS

### 方案2: SendGrid
```bash
SMTP_USER=apikey
SMTP_PASS=your-sendgrid-api-key
```

### 方案3: 阿里云邮件推送
```bash
SMTP_USER=your-aliyun-user
SMTP_PASS=your-aliyun-password
```

## 部署步骤

1. **配置环境变量**
   ```bash
   # 在Supabase Dashboard中设置环境变量
   # 或在本地.env文件中配置（不要提交到git）
   ```

2. **部署Supabase配置**
   ```bash
   cd /Users/xuhuipeng/Code/dada-knows
   supabase db push
   ```

3. **重启Supabase服务**
   ```bash
   supabase stop
   supabase start
   ```

## 配置文件说明

### 修改的文件：
- `supabase/config.toml` - Supabase配置
- `supabase/templates/confirmation.html` - 确认邮件模板
- `supabase/templates/recovery.html` - 密码重置邮件模板
- `DadaKnows/Info.plist` - iOS URL Scheme配置
- `DadaKnowsApp.swift` - 深度链接处理

### 新的重定向URL：
- 应用内：`dadaknows://auth`
- 网页回调：`https://fwvyrcekbngcpiudljpj.supabase.co/auth/v1/callback`

## 邮件模板特色

### 确认邮件
- 🧠 DadaKnows品牌标识
- 现代化设计风格
- 中文本地化
- 响应式布局

### 密码重置邮件  
- 🔐 安全主题设计
- 安全提醒信息
- 密码安全建议

## 测试流程

1. 启动应用
2. 尝试邮箱注册
3. 检查邮箱是否收到品牌化确认邮件
4. 点击邮件中的确认链接
5. 应用应该自动打开并完成验证

## 故障排除

### 如果仍收到localhost链接：
1. 确认环境变量已正确设置
2. 重启Supabase服务
3. 清除浏览器缓存

### 如果邮件未发送：
1. 检查SMTP配置
2. 验证邮箱服务商设置
3. 查看Supabase日志

## 后续优化建议

1. **域名配置**：购买域名并配置自定义邮件域名
2. **邮件服务**：升级到专业邮件服务提供商
3. **监控**：添加邮件发送监控和统计
4. **多语言**：根据用户语言偏好发送不同语言邮件

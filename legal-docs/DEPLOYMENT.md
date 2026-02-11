# DadaKnows 法律文档部署指南

## 📁 文件清单

您的 `legal-docs` 目录现在包含以下文件：

```
legal-docs/
├── index.html          # 首页（导航页）
├── styles.css          # 共享样式表
├── privacy-en.html     # 英文版隐私政策
├── privacy-zh.html     # 中文版隐私政策
├── terms-en.html       # 英文版服务条款
└── terms-zh.html       # 中文版服务条款
```

## 🌐 部署到 dadaknows.localllama.cn

### 方法 1: 使用 Vercel（推荐 ⭐）

#### 步骤 1: 准备 Git 仓库

```bash
cd /Users/xuhuipeng/Code/dada-knows/legal-docs
git init
git add .
git commit -m "Initial commit: Legal documents for App Store compliance"
```

#### 步骤 2: 推送到 GitHub

```bash
# 在 GitHub 上创建新仓库（例如：dadaknows-legal）
git remote add origin https://github.com/YOUR_USERNAME/dadaknows-legal.git
git branch -M main
git push -u origin main
```

#### 步骤 3: 部署到 Vercel

1. 访问 [Vercel](https://vercel.com/) 并登录（可使用 GitHub 账号）
2. 点击 **"Add New Project"**
3. 选择您刚创建的 `dadaknows-legal` 仓库
4. 点击 **"Import"**
5. 配置项目：
   - **Framework Preset**: 选择 "Other"
   - **Root Directory**: `.` （默认即可）
   - 点击 **"Deploy"**
6. 等待部署完成（通常只需几秒钟）

#### 步骤 4: 配置自定义域名

1. 部署成功后，进入项目的 **Settings** → **Domains**
2. 在 "Add Domain" 输入框中填写：`dadaknows.localllama.cn`
3. 点击 **"Add"**
4. Vercel 会提示您添加 DNS 记录

#### 步骤 5: 配置 DNS（在域名服务商处）

在您的 `localllama.cn` 域名的 DNS 管理界面添加：

**CNAME 记录：**
```
类型: CNAME
主机记录: dadaknows
记录值: cname.vercel-dns.com
TTL: 600（或默认值）
```

#### 步骤 6: 等待生效

- DNS 配置后，通常需要几分钟到几小时生效
- Vercel 会自动为您配置 HTTPS/SSL 证书
- 完成后，访问 `https://dadaknows.localllama.cn` 即可看到您的文档

### 方法 2: 使用 GitHub Pages

1. **创建 GitHub 仓库并推送代码**（同上方法1的步骤1-2）

2. **启用 GitHub Pages**
   - 进入仓库 Settings → Pages
   - Source 选择 "main" 分支
   - 保存

3. **配置自定义域名**
   - 在 GitHub Pages 设置中，Custom domain 输入 `dadaknows.localllama.cn`
   - 在您的域名服务商处添加 CNAME 记录指向 `YOUR_USERNAME.github.io`

### 方法 3: 直接上传到服务器

如果您已有服务器：

```bash
# 使用 SCP 上传文件
scp -r legal-docs/* user@your-server:/var/www/dadaknows.localllama.cn/

# 配置 Nginx/Apache 虚拟主机指向该目录
```

## 🔗 需要在 App Store Connect 填写的 URL

部署完成后，您需要在 App Store Connect 填写以下链接：

### 1. 隐私政策 URL (Privacy Policy)
```
https://dadaknows.localllama.cn/privacy-en.html
```

### 2. 服务条款 URL (Terms of Service)
在应用描述末尾添加：
```
Terms of Service: https://dadaknows.localllama.cn/terms-en.html
```

**完整示例（App Description 末尾）：**
```
---
Privacy Policy: https://dadaknows.localllama.cn/privacy-en.html
Terms of Service: https://dadaknows.localllama.cn/terms-en.html
```

## ✅ App Store Connect 填写步骤

### 步骤 1: 添加隐私政策链接
1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 选择您的应用 → **App 信息**
3. 找到 **隐私政策 URL** (Privacy Policy URL) 字段
4. 填写：`https://dadaknows.localllama.cn/privacy-en.html`
5. 点击保存

### 步骤 2: 在应用描述中添加服务条款链接
1. 在 App Store Connect 中，进入您的应用版本
2. 找到 **应用描述** (App Description) 字段
3. 在描述的**末尾**添加：

```
---
Privacy Policy: https://dadaknows.localllama.cn/privacy-en.html
Terms of Service: https://dadaknows.localllama.cn/terms-en.html
```

### 步骤 3: 重新提交审核
1. 保存所有更改
2. 重新提交应用进行审核

## 📱 应用内链接（已实现）

您的应用内部已经有了服务条款和隐私政策的可点击按钮（在 `ProSubscriptionView.swift` 中），这些已经满足苹果的要求。网页版本主要是为了满足 App Store Connect 元数据的要求。

## 🎨 本地预览

在部署前，您可以在本地预览这些页面：

```bash
cd /Users/xuhuipeng/Code/dada-knows/legal-docs
python3 -m http.server 8000
```

然后在浏览器中访问：`http://localhost:8000/`

## ⚠️ 重要提示

1. **确保 URL 可访问**：在提交 App Store Connect 之前，确保您填写的 URL 是公开可访问的
2. **使用 HTTPS**：如果可能，请使用 HTTPS 协议
3. **保持内容一致**：网页版和应用内版本的内容应保持一致
4. **定期更新**：如果修改了条款，记得同时更新网页版和应用内版本

## 🆘 需要帮助？

如果您在部署过程中遇到问题，请告诉我您选择的部署方式，我可以提供更详细的指导！

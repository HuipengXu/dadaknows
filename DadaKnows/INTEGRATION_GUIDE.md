# DadaKnows iOS 应用 - 集成指南

## 项目概述

DadaKnows（问问答答）是一款专为 2-12岁儿童父母设计的AI知识伙伴应用，使用 SwiftUI 开发，采用 MVVM 架构模式。

## 技术栈

- **前端**: SwiftUI + Combine
- **架构**: MVVM (Model-View-ViewModel)
- **本地存储**: CoreData
- **后端**: Supabase (认证 + 数据库 + Edge Functions)
- **AI 服务**: Google Gemini API (通过 Supabase Edge Functions)

## 已完成功能

### ✅ 核心架构
- [x] 项目目录结构和基础架构
- [x] 颜色系统和设计规范
- [x] 多语言支持 (中英双语)
- [x] CoreData 数据模型

### ✅ 用户界面
- [x] 启动页 (SplashView)
- [x] 登录注册页面 (AuthView)
- [x] 首页提问界面 (HomeView) 
- [x] 流式聊天界面 (ChatView)
- [x] 个人中心 (ProfileView)
- [x] 底部Tab导航

### ✅ 核心功能
- [x] 问题输入和年龄选择
- [x] AI流式回答显示（模拟实现）
- [x] "换个说法" 功能
- [x] 用户反馈处理
- [x] 成长统计展示

## 待集成功能

### ✅ 已完成的配置

#### 1. API密钥配置 ✅
- ✅ **Supabase URL**: 已在 `Config.swift` 中配置
- ✅ **Supabase Keys**: 所有必要密钥已设置
- ✅ **Gemini API Key**: AI服务密钥已配置
- ✅ **配置验证**: 启动时自动验证所有配置

#### 2. 代码架构准备 ✅
- ✅ **SupabaseClient**: 已更新使用真实配置
- ✅ **AIManager**: 已集成Supabase调用
- ✅ **增强模拟响应**: 更真实的AI回答模拟
- ✅ **错误处理**: 完善的异常处理机制

### 🔄 需要完成的集成

#### 1. Supabase Swift SDK依赖
**步骤** (详见 `SUPABASE_INTEGRATION_GUIDE.md`):
1. 在 Xcode 中添加 Supabase Swift SDK
   - File → Add Package Dependencies
   - URL: `https://github.com/supabase/supabase-swift`
   
2. 取消注释 `SupabaseClient.swift` 中的代码
   - import Supabase
   - 实际的 Supabase 调用代码
   
3. 部署 Edge Functions
   - ask-dada 函数 (AI服务)
   - 认证集成

#### 2. AI 服务集成
**步骤**:
1. 部署 Supabase Edge Functions (参考架构文档)
2. 实现 `AIManager.swift` 中的真实 API 调用
3. 替换模拟的流式响应逻辑

#### 3. 数据库同步
**步骤**:
1. 实现聊天记录同步到 Supabase
2. 本地 CoreData 与云端数据同步
3. 离线功能支持

## 文件结构说明

```
DadaKnows/
├── Core/
│   ├── Network/           # 网络层和API客户端
│   ├── Storage/           # 本地存储管理
│   └── AI/               # AI服务管理
├── Features/             # 功能模块 (MVVM)
│   ├── Splash/
│   ├── Authentication/
│   ├── Home/
│   ├── Chat/
│   ├── Profile/
│   └── Main/
├── Components/           # 可复用UI组件
├── Models/              # CoreData模型
└── Resources/           # 资源文件
```

## 配置说明

### 环境变量
在实际部署时需要配置以下环境变量：
- `SUPABASE_URL`: Supabase 项目 URL
- `SUPABASE_ANON_KEY`: Supabase 匿名密钥
- `GEMINI_API_KEY`: Google Gemini API 密钥

### Info.plist 配置
需要添加以下权限：
```xml
<key>NSNetworkVolumesUsageDescription</key>
<string>应用需要网络权限来获取AI回答</string>
```

## 运行说明

### 当前状态
- 应用可以正常编译和运行
- 所有UI界面已完成
- 使用模拟数据展示功能流程

### 下一步
1. 添加 Supabase 依赖
2. 配置真实的后端服务
3. 实现真实的AI调用
4. 完成支付功能集成

## 设计规范

### 颜色系统
- 主背景色: 奶油黄 `#FFF8E1`
- 主交互色: 活力橙 `#FFB347`
- 文本色: 深灰色 `#333333`
- 辅助色: 天空蓝 `#B3E5FC`, 珊瑚粉 `#FFAB91`

### 字体规范
- 标题: `.title2` + `.fontWeight(.bold)`
- 正文: `.body` 
- 按钮: `.headline` + `.fontWeight(.semibold)`

## 注意事项

1. **安全性**: 所有API密钥应通过环境变量或安全的配置方式管理
2. **本地化**: 应用支持中英双语，新增文本需要在 `Localizable.xcstrings` 中添加
3. **测试**: 建议为核心功能编写单元测试
4. **性能**: 流式响应需要优化内存使用，避免长时间累积

## 支持

如有问题请参考：
- `docs/dada-knows-prd.md` - 产品需求文档
- `docs/dada_low_cost_architecture.md` - 技术架构文档
- `docs/data-knows-database.md` - 数据库设计文档

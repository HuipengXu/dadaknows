### **Dada Knows 低成本架构方案**

#### **1. 核心设计哲学**

本方案旨在为 "Dada Knows" 项目提供一个从零启动到规模化运营的完整技术蓝图。它遵循三大核心原则：

*   **精益启动 (Lean Startup)**：以最低的成本和最快的速度构建最小可行产品 (MVP)，核心目标是验证产品的核心价值——“用富有童趣的AI回答守护孩子的好奇心”。
*   **成本可控 (Cost-Conscious)**：严格利用成熟云服务的免费额度启动项目，将初期固定成本降至几乎为零。每一分钱的投入都应在产品得到市场初步验证之后。
*   **未来兼容 (Future-Proof)**：架构设计具备前瞻性，不能因追求初期简单而牺牲长期扩展性。为端侧AI、复杂功能和私有化部署预留清晰、低耦合的接口。

#### **2. 项目文件结构**

项目的整体结构设计旨在实现关注点分离、高内聚和低耦合，将源代码、文档、共享资源和工具清晰地分离开来，便于团队协作和长期维护。

```
dada-knows/
├── README.md
├── .gitignore
├── docker-compose.yml
│
├── backend/                      # FastAPI后端 (阶段二启用)
│   ├── app/
│   │   ├── main.py               # FastAPI应用入口
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── chat.py       # 对话API
│   │   │       ├── user.py       # 用户管理API
│   │   │       └── subscription.py # 订阅API
│   │   ├── core/
│   │   │   ├── config.py         # 配置管理
│   │   │   └── database.py       # 数据库配置
│   │   ├── models/
│   │   │   ├── user.py
│   │   │   └── chat.py
│   │   ├── services/
│   │   │   ├── ai_service.py     # AI模型调用
│   │   │   └── prompt_service.py # Prompt工程
│   │   ├── schemas/
│   │   │   ├── chat.py           # Pydantic模型
│   │   │   └── user.py
│   │   └── utils/
│   │       └── logger.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── alembic/                  # 数据库迁移
│       └── versions/
│
├── DadaKnows/                          # iOS客户端
│   ├── DadaKnows/
│   │   ├── DadaKnowsApp.swift
│   │   ├── Core/
│   │   │   ├── Network/          # API服务和模型
│   │   │   ├── Storage/          # 本地存储 (CoreData)
│   │   │   └── AI/
│   │   │       └── AIManager.swift # AI智能调度中心
│   │   ├── Features/             # 各功能模块 (MVVM)
│   │   │   ├── Home/
│   │   │   ├── Chat/
│   │   │   ├── Profile/
│   │   │   └── Subscription/
│   │   ├── Components/           # 可复用UI组件
│   │   └── Resources/
│   ├── DadaKnows.xcodeproj
│   └── Package.swift              # Swift Package Manager
│
├── supabase/                     # Supabase 后端 (MVP主力)
│   └── functions/
│       ├── ask-dada/
│       │   └── index.ts          # 核心问答云函数
│       └── _shared/
│           ├── gemini.ts         # Gemini API 客户端
│           └── prompts.ts        # Prompt 模板与管理
│
├── shared/                       # 前后端共享资源
│   ├── api-specs/
│   │   └── openapi.yaml          # API文档
│   └── assets/
│       ├── dada-character/       # 答答IP形象生产资源
│       ├── animations/           # Lottie动画文件
│       └── icons/
│
├── docs/                         # 项目文档
│   ├── assets/                   # 文档配图与设计稿
│   │   ├── answer-page.jpeg
│   │   ├── dada-ip.jpeg
│   │   └── data-home.jpeg
│   ├── dada_low_cost_architecture.md # 本技术方案
│   ├── dada-knows-prd.md         # 产品需求文档
│   ├── dada-knows-pages.md       # 界面设计说明
│   └── dada-knows-pages-en.md    # 界面设计说明(英文)
│
├── tools/                        # 开发工具
│   ├── scripts/
│   │   ├── setup.sh
│   │   └── deploy.sh
│   └── api-client-generator/     # 自动生成iOS API客户端
│
└── tests/                        # 集成与端到端测试
    ├── backend/
    └── e2e/
```

#### **3. 分阶段演进路线图**

我们采用清晰的三阶段演进路径，确保成本与产品发展阶段相匹配。

##### **阶段一: MVP - 验证核心价值 (0-3个月)**
*   **架构**: `iOS App` -> `Supabase (Auth, DB)` -> `Supabase Edge Function (Streaming)` -> `Google Gemini API (Streaming)`
*   **核心**: 快速上线，验证用户是否愿意为“答答”的回答付费或持续使用。
*   **技术实现**: 后端逻辑完全在 `supabase/functions/` 目录中用 TypeScript 实现。`backend/` 目录在此阶段不部署。
*   **成本**: **云服务基础设施成本 ~$0/月**

##### **阶段二: 功能扩展与商业化 (3-9个月)**
*   **架构**: 引入 `FastAPI on Render` 处理复杂任务 (如图片生成)，核心问答仍由 Edge Functions 处理。
*   **核心**: 推出 Pro 订阅，实现商业闭环。
*   **技术实现**: 部署 `backend/` 目录中的 FastAPI 应用。iOS 客户端的 `AIManager` 开始根据任务类型向 Supabase 或 FastAPI 路由请求。
*   **成本**: **~ $50/月**

##### **阶段三: 体验优化与生态构建 (9个月以后)**
*   **架构**: 在 iOS 客户端集成端侧AI小模型 (如 Phi-3 Mini)，处理离线和简单请求。
*   **核心**: 降低云端AI成本，提供离线等极致体验，构建社区。
*   **技术实现**: 在 `DadaKnows/` 项目中实现 `AIManager` 的本地模型调用逻辑，可能需要集成 CoreML 等框架。
*   **成本**: **按需扩展**

#### **4. 核心技术栈与实现细节**

##### **4.1. iOS 客户端**
*   **语言/框架**: Swift / SwiftUI
*   **架构模式**: MVVM (Model-View-ViewModel)
*   **核心组件**:
    *   `AIManager`: AI请求的智能调度中心，为三阶段演进提供统一入口。它将处理流式响应，为UI提供逐字更新的数据流，以实现“打字机”效果。
    *   `Supabase-Swift`: 用于认证和数据库交互。
    *   `CoreData`: 用于本地缓存历史记录，实现“好奇心日志”的快速加载和离线查看。

```swift
// DadaKnows/DadaKnows/Core/AI/AIManager.swift
// 伪代码示例
class AIManager {
    func getAnswerStream(for question: String, age: Int) -> AsyncThrowingStream<String, Error> {
        // 阶段一 (核心): 调用Supabase云函数，返回一个可供SwiftUI视图消费的异步字符流。
        // UI层将通过这个Stream的更新，实现逐字的打字机动画效果。
        return SupabaseClient.shared.askDadaStream(...)
    }

    // 阶段二: 对于特定复杂任务，路由到FastAPI
    func generateImage(for prompt: String) async throws -> UIImage {
        return await FastAPIClient.shared.generateImage(...)
    }
    
    // 阶段三: 逻辑将更加复杂，会优先尝试本地模型
}```

##### **4.2. 后端 (MVP - Supabase Edge Functions)**
*   **语言/环境**: Deno / TypeScript
*   **核心职责**:
    1.  **处理核心问答**：接收客户端请求，与 Gemini API 通信。
    2.  **支持流式响应**：直接将 Gemini API 返回的数据流 (Stream) 转发给客户端，以实现**流式的实时打字机效果**，这是提升用户体验的关键。
*   **“换个说法”实现**：当用户请求“换个说法”时，客户端需将**上一次的答案**一并传回。云函数将调用一个特殊的Prompt，明确指示AI“请提供一个与旧答案完全不同的比喻”。
*   **优势**: 无服务器、毫秒级冷启动、与数据库和认证无缝集成、零成本启动。

```typescript
// supabase/functions/ask-dada/index.ts
// 伪代码示例: 展示如何处理流式响应
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { GeminiProvider } from '../_shared/gemini.ts'
import { createDadaPrompt } from '../_shared/prompts.ts'

serve(async (req) => {
  const { question, age, language, previousAnswer } = await req.json()
  
  // 根据是否有previousAnswer，选择不同的Prompt模板
  const prompt = createDadaPrompt(question, age, language, previousAnswer)
  
  // 调用Gemini的流式生成接口
  const stream = await GeminiProvider.generateStream(prompt)

  // 将Gemini的流直接转发给客户端，使用Server-Sent Events (SSE) 格式
  const body = new ReadableStream({
    async start(controller) {
      for await (const chunk of stream) {
        const textChunk = chunk.text();
        controller.enqueue(`data: ${JSON.stringify({ piece: textChunk })}\n\n`);
      }
      controller.close();
    },
  });

  return new Response(body, {
    headers: { 
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
    },
  })
})
```

##### **4.3. 后端 (扩展 - FastAPI)**
*   **语言/框架**: Python / FastAPI
*   **职责**: 处理复杂、长时间运行的业务逻辑，如AI图片生成、用户社区、数据分析等。
*   **数据库**: 通过 SQLAlchemy 与 Supabase PostgreSQL 连接。
*   **AI服务**: `services/ai_service.py` 封装对多个AI提供商（Gemini, Claude, Stable Diffusion等）的调用。
*   **Prompt工程**: `services/prompt_service.py` 负责从数据库中动态加载和填充Prompt模板。**建议将Prompt模板存储在Supabase数据库的一个专门表中**，而非硬编码在代码中。这使得运营人员可以随时优化和A/B测试Prompt，无需重新部署后端服务。

##### **4.4. 数据库与数据同步**
*   **主数据库**: Supabase PostgreSQL。
*   **本地缓存**: iOS CoreData。
*   **同步策略**: 采用“在线优先，后台同步”策略。新问答直接写入 Supabase，成功后异步更新到本地 CoreData 缓存。离线时，问答记录可先存入本地，待网络恢复后由同步服务上传。

#### **5. 部署策略**

##### **5.1. MVP 部署**
*   **目标**: `Supabase Edge Functions`
*   **方式**: 通过 Supabase CLI `supabase functions deploy ask-dada` 命令进行部署。
*   **CI/CD**: 可在 GitHub Actions 中配置，当 `supabase/functions` 目录有变更时自动触发部署。

##### **5.2. 扩展阶段部署**
*   **目标**: `FastAPI Application`
*   **平台选型**:
    *   **Render (首选)**: 提供每月750小时的免费实例时长，适合单体服务持续运行。需注意免费版有冷启动延迟。
    *   **Fly.io**: 提供灵活的免费资源包，冷启动较快，但配置稍复杂。
*   **方式**: 通过 `Dockerfile` 将 FastAPI 应用容器化，推送到 Render 或 Fly.io 进行部署。

##### **5.3. 静态资源与CDN**
*   **服务**: Cloudflare
*   **用途**: 提供 DNS 解析、免费 SSL 证书、CDN 加速应用内可能用到的静态图片或资源。

#### **6. 成本分析与控制**

*   **阶段一 (MVP)**:
    *   **云服务基础设施**: **~$0/月**。这部分成本完全被Supabase和Gemini API的免费套餐覆盖。
    *   **固定运营开销**: **~$9.25/月**。这部分费用主要来自苹果开发者账号（$99/年）和可选域名（$12/年）的月度摊销。
    *   **总计**: **约 $9.25/月**

*   **阶段二 (扩展)**:
    *   Supabase Pro: $25/月 (数据库和服务升级)
    *   Render Starter: $7/月 (为FastAPI提供无休眠服务)
    *   AI API 调用: 按量付费，预估 $10-$50/月起
    *   **总计: ~$50 - $100/月**

*   **成本控制策略**:
    *   **用量监控**: 在Supabase和Google Cloud平台设置**严格的计费警报**，当用量接近免费额度上限时，能及时收到邮件通知，防止意外的高额账单。

#### **7. 性能、监控与优化**

*   **性能优化**:
    *   **数据库**: 在 Supabase 中为 `chats` 表的 `user_id` 和 `created_at` 字段创建复合索引。
    *   **缓存**: 在 FastAPI 后端，对不经常变化的通用查询结果使用 `functools.lru_cache` 进行内存缓存。
*   **监控与分析**:
    *   **日志**: FastAPI 应用通过 `utils/logger.py` 将结构化日志输出到控制台。Render 等平台会自动收集这些日志。
    *   **服务状态**: 使用 Supabase 的内置仪表盘监控数据库和API健康状况。
    *   **用户行为**: 初期通过在数据库中记录关键事件（如提问、订阅）进行简单分析。

#### **8. 开发环境**

*   **本地环境**: 使用 `docker-compose.yml` 一键启动本地开发所需的所有服务，包括 PostgreSQL 数据库 (可使用 Supabase 官方 Docker 镜像) 和 FastAPI 后端。
*   **代码规范**: 使用 Black (Python) 和 SwiftLint (iOS) 强制执行代码风格。
*   **API 协作**: `shared/api-specs/openapi.yaml` 作为前后端协作的“单一事实来源”，iOS 客户端可通过 `tools/api-client-generator/` 中的脚本基于此文件自动生成网络层代码。

#### **9. 风险管理**

*   **风险1：AI 内容安全与合规性**
    *   **应对**: 在Prompt设计中加入极其严格的安全护栏；在 FastAPI 中增加关键词过滤中间件；优先选择有强大安全机制的 API。
*   **风险2：云服务平台政策变更**
    *   **应对**: 采用解耦架构，FastAPI 和 Supabase Functions 的核心逻辑易于迁移。例如，FastAPI 可从 Render 迁移到 Fly.io 或其他 PaaS 平台。
*   **风险3：后端服务冷启动 (针对阶段二)**
    *   **应对**: 将受冷启动影响的 FastAPI 功能设计为非即时性任务（如图片生成）。核心的实时问答由无冷启动问题的 Supabase Edge Functions 处理，将风险隔离在次要功能上。
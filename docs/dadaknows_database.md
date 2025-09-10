### **Dada Knows - 数据库设计文档**

#### **1. 设计总览**

本数据库方案基于 **PostgreSQL**，专为在 **Supabase** 平台上部署而设计。其核心设计原则是**数据安全**、**性能**与**可扩展性**。方案深度整合了 Supabase 的认证（Auth）和行级安全（Row Level Security, RLS）机制，以确保用户数据的绝对隔离与隐私。

#### **2. 实体关系概览 (Schema Relationships)**

数据库围绕以下核心实体构建，它们之间的关系如下：

*   **用户 (`users`)** 是所有数据的中心。
*   一个 **用户** 可以拥有多条 **对话记录 (`chats`)**。
*   一个 **用户** 只能有一条有效的 **订阅信息 (`subscriptions`)**。
*   一个 **用户** 可以解锁多种 **个性化装扮 (`cosmetics`)**，通过 **`user_unlocked_cosmetics`** 表进行关联。
*   一条 **对话** 可以生成多个 **媒体资产 (`assets`)**（如图片）。
*   一条 **对话** 可以被制作成一张 **知识卡片 (`knowledge_cards`)**。
*   每一次与AI的交互都会被记录为一条 **AI请求日志 (`ai_requests`)**。
*   **提示词 (`prompts`)** 表作为独立的配置库，被后端服务动态调用。

---

### **3. 核心表结构详解**

#### **3.1. 用户与认证**

##### **表名: `users`**

*   **用途**: 存储用户的应用内配置文件，是对 Supabase `auth.users` 表的扩展，记录了用户的个性化设置和核心状态。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY`, `REFERENCES auth.users(id)` | 用户唯一ID，与认证系统严格关联，确保数据一致性。 |
| `nickname` | `TEXT` | | 用户在App内显示的昵称。 |
| `avatar_url` | `TEXT` | | 指向用户头像图片的URL。 |
| `preferred_language` | `VARCHAR(5)` | `NOT NULL`, `DEFAULT 'en-US'` | 用户偏好的界面语言，如 'zh-CN' 或 'en-US'。 |
| `subscription_status`| `ENUM` | `NOT NULL`, `DEFAULT 'free'` | 用户当前的订阅状态，是一个冗余字段，由`subscriptions`表触发器更新，用于快速权限检查。 |
| `stripe_customer_id`| `TEXT` | `UNIQUE` | 关联到Stripe支付网关的客户ID，用于处理付款。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | 记录创建时间。 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL` | 记录最后更新时间。 |

*   **核心逻辑与安全策略**:
    *   **RLS策略**: 必须启用行级安全。策略规定，用户只能查看和修改自己的个人资料 (`auth.uid() = id`)。

---
#### **3.2. 核心内容与交互**

##### **表名: `chats`**

*   **用途**: 应用的核心数据表，记录用户与“答答”的每一次问答历史，构成“好奇心日志”。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY`, `GENERATED ALWAYS AS IDENTITY` | 内部自增ID。 |
| `uuid` | `UUID` | `NOT NULL`, `UNIQUE` | 对外暴露的唯一标识符，避免暴露自增ID。 |
| `user_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)` | 标识该对话属于哪个用户。 |
| `parent_chat_id`| `BIGINT` | `REFERENCES chats(id)` | 指向上一轮对话，为未来的“追问”功能预留。 |
| `question_text` | `TEXT` | `NOT NULL` | 用户提出的完整问题。 |
| `answer_text` | `TEXT` | | AI生成的完整回答。 |
| `target_age` | `SMALLINT` | `NOT NULL` | 用户提问时设定的目标年龄。 |
| `language` | `VARCHAR(5)` | `NOT NULL` | 本次问答使用的语言。 |
| `user_feedback` | `ENUM` | `NOT NULL`, `DEFAULT 'none'` | 记录用户反馈，如 'liked' (懂啦!) 或 'regenerated' (换个说法)。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | 对话创建时间。 |

*   **核心逻辑与安全策略**:
    *   **性能**: 必须为 `(user_id, created_at DESC)` 创建复合索引，以极大地优化“好奇心日志”的查询性能。
    *   **RLS策略**: 启用行级安全。策略规定，用户只能对自己创建的对话记录进行增删改查操作 (`auth.uid() = user_id`)。

##### **表名: `assets`**

*   **用途**: 统一管理与对话内容关联的媒体资产，如“AI魔法画笔”生成的图片。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | 资产的唯一ID。 |
| `chat_id` | `BIGINT` | `NOT NULL`, `REFERENCES chats(id)` | 关联到生成此资产的具体对话。 |
| `user_id` | `UUID` | `NOT NULL`, `REFERENCES users(id)` | 资产所有者的ID。 |
| `asset_type` | `ENUM` | `NOT NULL` | 资产类型，如 'image' 或 'audio'。 |
| `storage_url` | `TEXT` | `NOT NULL` | 指向在云存储（如Supabase Storage）中的文件URL。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | 创建时间。 |

*   **核心逻辑与安全策略**:
    *   **RLS策略**: 启用行级安全。策略规定，用户只能查看和管理属于自己的媒体资产 (`auth.uid() = user_id`)。

##### **表名: `knowledge_cards`**

*   **用途**: 存储用户选择生成的“知识卡片”，支持分享和未来的社区功能。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | 卡片的唯一ID。 |
| `source_chat_id` | `BIGINT` | `NOT NULL`, `UNIQUE`, `REFERENCES chats(id)`| 关联到生成此卡片的源对话，一个对话只能生成一张卡片。 |
| `creator_user_id`| `UUID` | `NOT NULL`, `REFERENCES users(id)`| 卡片创建者的ID。 |
| `card_image_url` | `TEXT` | `NOT NULL` | 指向最终生成的精美卡片图片的URL。 |
| `visibility` | `ENUM` | `NOT NULL`, `DEFAULT 'private'` | 可见性，如 'private' (私有) 或 'public' (公开)。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | 创建时间。 |

*   **核心逻辑与安全策略**:
    *   **RLS策略**: 启用行级安全。用户可以管理自己创建的卡片 (`auth.uid() = creator_user_id`)。对于公开卡片，可以设置一个单独的读取策略，允许任何人读取 `visibility = 'public'` 的记录。

---
#### **3.3. 商业化与增值服务**

##### **表名: `subscriptions`**

*   **用途**: 作为用户订阅信息的唯一真实来源，精确管理Pro会员资格。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | 订阅记录的唯一ID。 |
| `user_id` | `UUID` | `NOT NULL`, `UNIQUE`, `REFERENCES users(id)` | 关联的用户ID，一个用户只有一条订阅记录。 |
| `status` | `ENUM` | `NOT NULL` | 订阅的权威状态，如 'pro_active', 'pro_canceled'。 |
| `plan_id` | `TEXT` | `NOT NULL` | 对应支付服务中的订阅计划ID。 |
| `current_period_start`| `TIMESTAMPTZ` | `NOT NULL` | 当前计费周期开始时间。 |
| `current_period_end`| `TIMESTAMPTZ` | `NOT NULL` | 当前计费周期结束时间，用于判断会员是否到期。 |
| `canceled_at` | `TIMESTAMPTZ` | | 如果订阅被取消，记录取消时间。 |

*   **核心逻辑与安全策略**:
    *   **数据同步**: 此表的数据状态应由支付网关的Webhook事件驱动更新。
    *   **触发器**: 应设置数据库触发器，当此表的 `status` 发生变化时，自动同步更新 `users` 表的 `subscription_status` 字段。
    *   **RLS策略**: 启用行级安全。用户只能查看自己的订阅信息 (`auth.uid() = user_id`)。

##### **表名: `cosmetics` (个性化装扮目录)**

*   **用途**: 作为所有可用装扮（如蛋壳帽皮肤）的目录，是一个静态配置表。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PRIMARY KEY` | 装扮的唯一ID。 |
| `name` | `TEXT` | `NOT NULL` | 装扮的名称，如“草莓蛋壳”。 |
| `asset_url` | `TEXT` | `NOT NULL` | 指向该装扮的图片或动画文件URL。 |
| `unlock_condition`| `TEXT` | `NOT NULL` | 解锁条件，如 'pro_exclusive' 或 'event_reward'。 |

*   **核心逻辑与安全策略**:
    *   此表为公共数据，通常允许所有已认证用户读取。

##### **表名: `user_unlocked_cosmetics` (用户装扮解锁记录)**

*   **用途**: 记录哪个用户在何时解锁了哪个装扮，是 `users` 和 `cosmetics` 之间的多对多连接表。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `user_id` | `UUID` | `PRIMARY KEY`, `REFERENCES users(id)` | 关联的用户ID。 |
| `cosmetic_id` | `INT` | `PRIMARY KEY`, `REFERENCES cosmetics(id)`| 关联的装扮ID。 |
| `unlocked_at` | `TIMESTAMPTZ` | `NOT NULL` | 解锁该装扮的时间。 |

*   **核心逻辑与安全策略**:
    *   **RLS策略**: 启用行级安全。用户只能查看自己已解锁的装扮列表 (`auth.uid() = user_id`)。

---
#### **3.4. 运营与监控**

##### **表名: `prompts`**

*   **用途**: 将AI提示词与代码分离，实现动态、免部署的Prompt优化和版本管理。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PRIMARY KEY`, `GENERATED ALWAYS AS IDENTITY` | 内部ID。 |
| `name` | `VARCHAR(100)`| `NOT NULL` | Prompt的用途标识，如 'ask_dada', 'regenerate_answer'。 |
| `template_text` | `TEXT` | `NOT NULL` | 完整的Prompt模板，包含占位符。 |
| `version` | `INT` | `NOT NULL` | 版本号，用于追踪迭代。 |
| `is_active` | `BOOLEAN` | `NOT NULL`, `DEFAULT false` | 标记此版本是否为当前线上使用的版本。 |
| `notes` | `TEXT` | | 备注此版本的修改内容或特点。 |

*   **核心逻辑与安全策略**:
    *   **唯一性**: 应为 `(name, is_active)` 创建唯一约束，确保同名Prompt只有一个活跃版本。
    *   **访问控制**: 此表通常只允许后端服务（Service Role）进行读取，普通用户无权访问。

##### **表名: `ai_requests`**

*   **用途**: 详细记录每一次对大模型API的调用，为成本分析、性能监控和用量审计提供原始数据。
*   **字段描述**:
| 字段名 (Field Name) | 数据类型 (Data Type) | 约束 (Constraints) | 详细描述 |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY` | 请求的唯一ID。 |
| `user_id` | `UUID` | `REFERENCES users(id)` | 发起请求的用户ID。 |
| `chat_id` | `BIGINT` | `REFERENCES chats(id)` | 关联到具体的对话。 |
| `provider` | `TEXT` | `NOT NULL` | AI模型提供商，如 'Google Gemini'。 |
| `model_name` | `TEXT` | `NOT NULL` | 具体的模型名称。 |
| `input_tokens` | `INT` | | 输入的Token数量。 |
| `output_tokens` | `INT` | | 输出的Token数量。 |
| `latency_ms` | `INT` | | 请求耗时（毫秒）。 |
| `cost` | `NUMERIC` | | 本次请求的预估成本（美元）。 |
| `status_code` | `INT` | | API返回的状态码。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | 请求发起时间。 |

*   **核心逻辑与安全策略**:
    *   **写入**: 这张表由后端服务在每次调用AI后异步写入，以避免影响主流程性能。
    *   **访问控制**: 严格限制访问，只有后端服务和数据分析角色可以访问，普通用户绝对无法访问此表。
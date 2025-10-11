# In-App Purchase & Payment Setup Guide

> 面向首次上架美国区、首次收款的 iOS 开发者

---

## 1. 加入 Apple Developer Program

| 步骤 | 说明 |
|------|------|
| 1. 注册 | 使用 Apple ID 登录 <https://developer.apple.com> 并加入 „Apple Developer Program“。 |
| 2. 费用 | 个人/公司账户均需支付 USD 99/年。 |
| 3. D-U-N-S® | 公司开发者需准备 D-U-N-S 编号；个人开发者无需。 |

> 完成后即可访问 **App Store Connect** 与 **TestFlight**。

---

## 2. App Store Connect 基础配置

1. 登录 <https://appstoreconnect.apple.com>
2. „Agreements, Tax, and Banking“：
   - **Paid Applications Agreement**
   - **Banking**：添加收款银行账户（美国境内或可收美元的国际账户，如 Wise/Payoneer）。
   - **税务**：填写 W-8BEN（非美籍个人/公司）或 W-9（美国实体）。
3. 所有状态为 „Active“ 后，App 可开始售卖付费项目/订阅并收款。

> 若仅做免费 App 而且没有 IAP，也可跳过 Paid Applications Agreement。但 Pro 订阅需要勾选。

---

## 3. 创建 In-App Purchase 产品

> DadaKnows 的 `SubscriptionManager` 使用以下 ProductID：
>
> - `com.dadaknows.DadaKnows.monthly`  (自动续订订阅 - 月付)
> - `com.dadaknows.DadaKnows.biannual` (自动续订订阅 - 半年付)
> - `com.dadaknows.DadaKnows.annual`   (自动续订订阅 - 年付)

1. 打开 „My Apps → DadaKnows → In-App Purchases"。
2. 点击 „+" 选择 **Auto-Renewable Subscription** → 创建订阅组 "DadaKnows Pro"。
3. 创建三个订阅产品：
   - **月付订阅** (Monthly Plan)
     - Product ID: `com.dadaknows.DadaKnows.monthly`
     - 订阅周期：1 个月
   - **半年付订阅** (6-Month Plan)
     - Product ID: `com.dadaknows.DadaKnows.biannual`
     - 订阅周期：6 个月
   - **年付订阅** (Annual Plan) - 推荐
     - Product ID: `com.dadaknows.DadaKnows.annual`
     - 订阅周期：12 个月
4. 配置每个产品：
   - Reference Name / Product ID **必须与代码一致**。
   - 价格等级（USD）、地区（默认为全球可选）。
   - 计划：可选 3 天/7 天免费试用或 3 天宽限期。 
   - 屏幕截图（JPG/PNG 640 × 920 以上）、描述（英文及所选语言）。
5. „Add for Review" → 等待状态变为 **Ready for Sale** / **Approved**。

> **定价建议**：设置年付价格时，建议相比月付价格 × 12 有一定优惠（如 15-20%），以鼓励用户选择长期订阅。

---

## 4. 沙盒 & TestFlight 测试购买

1. **Sandbox Tester**：App Store Connect → Users & Access → Sandbox → Testers。创建使用 gmail/icloud 的测试 Apple ID（*不可为真实购买账户*）。
2. Xcode ➜ Product → Destination 选择真实设备。
3. 配置 `StoreKit Configuration` 文件（可选）：
   - Xcode File → New File → StoreKit Configuration，添加相同产品 ID 便于本地调试。
4. 运行或 TestFlight 安装后：
   - iOS 17+: 设置 → App Store → Sandbox Account 登录测试者。
   - 在 App 内触发购买，观察成功、Pending、取消等路径。
5. 通过 **StoreKit 2** 日志 (`Transaction` / `Product.purchase()`) 验证：
   - `SubscriptionManager` 的 `isProMember`、`subscriptionStatus` 等字段是否正确更新。

---

## 5. 收款与结算

| 事项 | 说明 |
|------|------|
| 付款周期 | 每月收款；达到最低付款额（美国 USD 150）后次月 45 天内打款。 |
| 付款方式 | ACH（美国境内），或 SWIFT（国际）。支持 Wise、Payoneer。 |
| 货币转换 | 可选择以当地货币或 USD 收款；银行可能收取汇率/手续费。 |
| 报表 | App Store Connect 中 Financial Reports、Payments and Sales。可导出 CSV/PDF。 |

> 建议使用可收美元的国际账户（Wise 商业 USD 账号）以减少汇损。

---

## 6. 上架美国区注意事项

1. **年龄分级**：DadaKnows 面向儿童，需设置 „Made for Kids“ 或适配 COPPA。 
2. **隐私合规**：在 App Privacy 中声明数据收集、追踪、加密。 
3. **税务**：非美国开发者向美国用户销售需缴纳 Withholding Tax；正确填写 W-8BEN 可降低税率（默认 30%，多数与中国等国家签署条约后降至 10%）。 
4. **审查材料**：在 „App Review Notes“ 中提供测试账户、求助文档，说明 AI 合规性与儿童保护措施。 

---

## 7. 当前实现说明

DadaKnows 采用 **StoreKit 2** 进行订阅管理，完全在客户端处理订阅逻辑。

### 7.1 订阅管理架构

#### 技术栈
- **StoreKit 2**：使用现代 StoreKit 2 API 和 async/await
- **客户端验证**：使用 StoreKit 2 的内置 `VerificationResult` 验证交易
- **本地持久化**：订阅状态保存在 `UserDefaults`，支持离线访问
- **自动交易监听**：通过 `Transaction.updates` 实时监听购买和退款
- **模拟器兼容**：自动检测模拟器环境，避免 `ASDErrorDomain 509` 错误

#### 核心类
```swift
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // 发布的状态
    @Published var isProMember: Bool
    @Published var subscriptionStatus: SubscriptionStatus
    @Published var availableProducts: [Product]
    @Published var purchasedProducts: [Product]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
}
```

### 7.2 核心功能

#### 产品加载
```swift
func loadProducts() async
```
- 从 App Store Connect 加载可用产品
- 自动按优先级排序：年付 → 半年付 → 月付
- 检查当前订阅状态
- 仅在真机环境启动交易监听

#### 购买流程
```swift
func purchase(_ product: Product) async
```
- 调用 `product.purchase()` 发起购买
- 验证交易 `VerificationResult`
- 更新订阅状态
- 完成交易 `transaction.finish()`

#### 恢复购买
```swift
func restorePurchases() async
```
- 调用 `AppStore.sync()` 同步购买记录
- 重新检查订阅状态
- 更新 UI 显示

#### 权限检查
```swift
func canAskQuestion() -> Bool
```
- **Pro 会员**：返回 `true`（无限制）
- **使用端侧模型**：返回 `true`（无需订阅）
- **免费用户**：检查每日提问次数限制

```swift
func getRemainingQuestions() -> Int?
```
- Pro 会员返回 `nil`（无限制）
- 免费用户返回剩余次数

### 7.3 订阅计划配置

| 计划类型 | Product ID | 订阅周期 | 定价示例 | 节省比例 |
|---------|-----------|---------|---------|---------|
| 月付 | `com.dadaknows.DadaKnows.monthly` | 1 个月 | $0.99/月 | - |
| 半年付 | `com.dadaknows.DadaKnows.biannual` | 6 个月 | $4.99/半年 | ~16% |
| 年付 | `com.dadaknows.DadaKnows.annual` | 12 个月 | $7.99/年 | ~33% |

> **注意**：节省比例由 App 根据实际定价自动计算，公式为：
> ```
> 节省比例 = (月付×周期 - 长期订阅价格) / (月付×周期)
> ```

### 7.4 订阅状态管理

#### 状态定义
```swift
enum SubscriptionStatus: String {
    case unknown        // 未知状态
    case active         // 订阅活跃
    case inactive       // 未订阅
    case expired        // 已过期
    case inGracePeriod  // 宽限期
}
```

#### 持久化存储
```swift
// 保存到 UserDefaults
UserDefaults.standard.set(isProMember, forKey: "isProMember")
UserDefaults.standard.set(subscriptionStatus.rawValue, forKey: "subscriptionStatus")
```

#### 交易监听
```swift
private func listenForTransactions() -> Task<Void, Error> {
    return Task.detached {
        for await result in Transaction.updates {
            let transaction = try await self.checkVerified(result)
            await self.updateSubscriptionStatus(for: transaction)
            await transaction.finish()
        }
    }
}
```

### 7.5 界面集成

#### ProSubscriptionView
订阅页面 (`ProSubscriptionView.swift`) 提供完整的订阅购买流程：

**功能特点**：
- 三种订阅计划展示（卡片式设计）
- 动态计算节省比例
- 推荐年付计划（`Recommended` 标签）
- 购买确认弹窗
- 恢复购买功能
- 服务条款和隐私政策链接

**关键实现细节**：
```swift
// ⚠️ 重要：判断产品类型时必须先检查 biannual
// 因为 "biannual" 包含 "annual" 子串
if product.id.contains("biannual") {
    // 半年付逻辑
} else if product.id.contains("annual") {
    // 年付逻辑
}
```

**节省比例计算**：
```swift
// 半年付
let monthlySixMonthCost = monthlyProduct.price * Decimal(6)
let savings = (monthlySixMonthCost - biannualCost) / monthlySixMonthCost

// 年付
let monthlyYearCost = monthlyProduct.price * Decimal(12)
let savings = (monthlyYearCost - annualCost) / monthlyYearCost
```

### 7.6 使用限制策略

#### 免费用户
- 每天限制提问次数（默认配置）
- 可以使用基础功能
- 可以查看历史记录
- 提示升级到 Pro

#### Pro 会员
- 无限制提问
- 无广告体验
- 优先访问新功能
- 支持应用开发

#### 端侧模型用户
- 下载本地模型后可离线使用
- 无需订阅即可无限制提问
- 注重隐私保护
- 需要约 640MB 存储空间

### 7.7 未来增强（可选）

#### 服务器端验证
如需更高安全性，可在 Supabase Edge Function 进行服务器端验单：

```typescript
// /supabase/functions/verify-receipt.ts (预留)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { signedTransaction } = await req.json()
  
  // 使用 App Store Server API 验证
  const response = await fetch(
    'https://api.storekit.itunes.apple.com/inApps/v1/transactions/' + signedTransaction,
    {
      headers: {
        'Authorization': `Bearer ${Deno.env.get('APPSTORE_JWT')}`,
      }
    }
  )
  
  const result = await response.json()
  
  // 存储到 Supabase 数据库
  // await supabase.from('subscriptions').upsert({...})
  
  return new Response(JSON.stringify(result))
})
```

#### 跨设备同步
可以通过 Supabase 实现跨设备订阅状态同步：

```swift
// 购买成功后同步到云端
func syncSubscriptionToCloud(transaction: Transaction) async {
    // 上传交易信息到 Supabase
}

// App 启动时从云端恢复
func restoreSubscriptionFromCloud() async {
    // 从 Supabase 读取订阅状态
}
```

---

## 8. 常见问题与解决方案

### 8.1 产品加载问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 无法看到产品列表 | IAP 未配置或未通过审核 | 1. 确认 IAP 状态为 „Ready for Sale"<br>2. 检查 Product ID 是否与代码一致（`com.dadaknows.DadaKnows.*`）<br>3. 使用正确的 App Store Connect 账号安装 TestFlight 构建<br>4. 检查网络连接 |
| 产品价格显示错误 | 货币区域设置问题 | 1. 检查设备的 Apple ID 区域设置<br>2. 确认 App Store Connect 中针对该区域的定价<br>3. 使用 `product.displayPrice` 显示本地化价格 |

### 8.2 购买流程问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 购买按钮点击后无反应 | 未登录沙盒账户 | 1. iOS 17+: 设置 → App Store → Sandbox Account<br>2. 确保真机可访问苹果服务器<br>3. 使用 StoreKit Configuration 进行本地测试<br>4. 检查 `isLoading` 状态是否正确 |
| 购买后未生效 | 交易未完成 | 1. 检查 `transaction.finish()` 是否被调用<br>2. 查看 Console 日志确认交易状态<br>3. 调用 `restorePurchases()` 恢复购买 |
| 重复购买提示 | 订阅已存在 | 这是正常行为，StoreKit 会提示用户已订阅 |

### 8.3 节省百分比计算问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 半年付显示错误的百分比 | `"biannual"` 包含 `"annual"` 子串 | ⚠️ **必须先判断 `biannual`**：<br>```swift<br>if product.id.contains("biannual") {<br>    // 半年付<br>} else if product.id.contains("annual") {<br>    // 年付<br>}<br>``` |
| 节省百分比不准确 | 定价设置不合理 | 1. 检查 App Store Connect 中的实际定价<br>2. 手动计算：`(月付×周期 - 长期价格) / (月付×周期)`<br>3. App 会自动动态计算，无需硬编码 |
| 年付和半年付显示相同百分比 | 判断顺序错误 | 参考上面的代码示例，确保先判断 `biannual` |

### 8.4 技术问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 模拟器出现 ASDErrorDomain 509 | 模拟器无 App Store 账户 | ✅ 已处理：代码自动检测模拟器环境，跳过交易枚举。<br>使用 StoreKit Configuration 文件测试。 |
| 订阅状态不同步 | UserDefaults 未持久化 | 1. 检查 `saveSubscriptionStatus()` 是否被调用<br>2. 重启 App 后调用 `loadStoredSubscriptionStatus()`<br>3. 考虑使用 Supabase 进行云端同步 |
| 交易监听未启动 | 模拟器环境 | 交易监听仅在真机环境启动（`#if !targetEnvironment(simulator)`） |

### 8.5 结算问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 结算延迟 | Apple 结算周期 | 1. 在 Financial Reports 检查销售报表<br>2. 确认达到最低付款额（USD 150）<br>3. 正常延迟为次月 45 天内 |
| 金额不对 | 多种原因 | 1. 检查税务扣除（W-8BEN 填写正确可降至 10%）<br>2. 检查汇率转换<br>3. 联系 Apple Support 提交 „Payment Inquiry" |

### 8.6 开发调试

#### 启用调试日志
代码中已包含详细的调试日志：

```swift
// 产品加载日志
📦 Product: com.dadaknows.DadaKnows.annual
   Price: 7.99 (US$7.99)
   Display Name: Annual Plan

// 节省比例计算日志
💰 Annual savings: monthly=0.99, total=11.88, annual=7.99, savings=33%
💰 Biannual savings: monthly=0.99, total=5.94, biannual=4.99, savings=16%
```

#### StoreKit Configuration 测试
1. Xcode → File → New File → StoreKit Configuration
2. 添加测试产品：
   ```
   Product ID: com.dadaknows.DadaKnows.monthly
   Price: $0.99
   Duration: 1 month
   ```
3. Scheme → Options → StoreKit Configuration → 选择配置文件
4. 运行 App 即可使用测试产品

#### 常用测试场景
- **首次购买**：清空 App 数据，进行首次订阅
- **恢复购买**：卸载重装，点击"恢复购买"
- **订阅续期**：在 StoreKit Configuration 中加速时间
- **订阅取消**：在沙盒环境取消订阅，测试降级逻辑
- **退款测试**：在 Transaction Manager 中模拟退款

### 8.7 代码检查清单

在实现订阅功能时，请确保：

- [ ] Product ID 与 App Store Connect 完全一致
- [ ] 判断 `biannual` 时使用正确顺序（先 biannual，后 annual）
- [ ] 节省比例使用动态计算，不硬编码
- [ ] 交易完成后调用 `transaction.finish()`
- [ ] 模拟器环境跳过交易枚举
- [ ] 订阅状态持久化到 UserDefaults
- [ ] 提供恢复购买功能
- [ ] 添加购买确认弹窗
- [ ] 显示服务条款和隐私政策链接
- [ ] 处理所有错误情况（网络、取消、失败等）
- [ ] 测试所有订阅周期（月付、半年付、年付）
- [ ] 测试恢复购买流程
- [ ] 真机测试沙盒购买
- [ ] TestFlight 测试生产环境购买

---

> 如需进一步帮助，可查阅苹果官方文档：
> • In-App Purchase Overview: <https://developer.apple.com/in-app-purchase/>  
> • App Store Connect Help (Payments): <https://help.apple.com/app-store-connect/#/dev7a3f427b8>

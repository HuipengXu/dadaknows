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
> - `com.dadaknows.pro.monthly`  (自动续订订阅)
> - `com.dadaknows.pro.yearly`   (自动续订订阅)
> - `com.dadaknows.pro.lifetime` (非消耗型)

1. 打开 „My Apps → DadaKnows → In-App Purchases“。
2. 点击 „+“ 选择对应类型：
   - **Auto-Renewable Subscription** → 创建订阅组，例如 “DadaKnows Pro”。
   - **Non-Consumable** → 终身订阅。
3. 配置：
   - Reference Name / Product ID **必须与代码一致**。
   - 价格等级（USD）、地区（默认为全球可选）。
   - 计划（订阅）：可选 3 天/7 天免费试用或 3 天宽限期。 
   - 屏幕截图（JPG/PNG 640 × 920 以上）、描述（英文及所选语言）。
4. „Add for Review“ → 等待状态变为 **Ready for Sale** / **Approved**。

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

## 7. 服务器验单（可选增强）

虽然 StoreKit 2 可在设备端直接验证，生产环境建议在 Supabase Edge Function 进行二次验单：

```ts
// /supabase/functions/verify-receipt.ts (示例)
export async function verifyAppStoreReceipt(signedTransaction: string) {
  const res = await fetch('https://api.storekit.itunes.apple.com/inApps/v1/verifyReceipt', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.APPSTORE_JWT}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ signedTransaction }),
  });
  return res.json();
}
```

在客户端 `SubscriptionManager` 成功购买后，上传 `transaction.signedTransactionInfo` 给服务器验证并存储用户订阅状态。

---

## 8. 常见问题

| 问题 | 解决方案 |
|------|----------|
| 无法看到产品列表 | 确认 IAP 状态为 „Ready for Sale“、使用正确的 App Store Connect 账号安装 TestFlight 构建。 |
| 购买按钮点击后毫无反应 | 检查 `App Sandbox` 登录；确保真机可访问苹果服务器，或使用 StoreKit Configuration 进行本地测试。 |
| 结算延迟或金额不对 | 在 Financial Reports 区域检查销售与付款报表；联系 Apple Support 提交 „Payment Inquiry"。 |

---

> 如需进一步帮助，可查阅苹果官方文档：
> • In-App Purchase Overview: <https://developer.apple.com/in-app-purchase/>  
> • App Store Connect Help (Payments): <https://help.apple.com/app-store-connect/#/dev7a3f427b8>

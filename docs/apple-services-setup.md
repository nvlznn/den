# Apple 服務設定

先完成「一個內購商品」，再完成「CloudKit」。不需要建立六個商品。

## 1. New Egg 內購

### 先在手機測試（不扣款）

1. Xcode 選 **Den StoreKit** scheme、你的 iPhone，按 **⌘R** 更新；不要刪 App。
2. Edit Scheme → Run → Options → StoreKit Configuration 確認是 `Den.storekit`。
3. Characters → Add New Egg → 選白／黑。前兩顆免費，用完後顯示 Apple 回傳的價格。
4. 購買一次白蛋、一次黑蛋，確認同一商品可重複購買，每次只加一顆、蛋色正確。
5. 取消一次購買，確認沒有新增蛋。關閉重開，確認角色、蛋和專注時數都保留。

### 開通付款合約

1. 登入 [App Store Connect](https://appstoreconnect.apple.com/) → **Business** → **Agreements**。
2. Account Holder 在 Paid Apps 那一列選 **View and Agree to Terms**，閱讀並接受條款。
3. 完成 Banking 和 Tax Forms，確認 Paid Apps Agreement 為 **Active**，才測正式 Sandbox 商品。

### 只建立這一個商品

Apps → Den → Monetization → In-App Purchases → ＋，填入：

| 欄位 | 填入 |
| --- | --- |
| Type | **Consumable** |
| Reference Name | New Egg |
| Product ID | **dev.noky.den.egg** |

Product ID 要完全一致。顏色是在 App 內選，不需要兩個顏色商品；新增更多角色也不用新增商品。

進入商品頁後：

1. **App Store Localization** → ＋ → English (U.S.)。
2. Display Name：`New Egg`。
3. Description：`Hatch a new friend through focus!`。
4. **Price Schedule** → Add Pricing → Base Country or Region：Taiwan → Price：**NT$90**。美國售價設為 **US$2.99**；檢查日期及其他地區價格，確認儲存。
5. **Availability**：至少勾選 Taiwan；若要全球販售，選你要提供的其他地區。
6. **Review Information**：上傳 New Egg 購買視窗截圖。
7. Review Notes 可貼：

   `The first two eggs are free. Each later purchase grants one permanent egg. Users choose white or black before buying the same consumable product. Each egg reserves a unique character of that color and reveals it at level 1 after 5 hours of actual focus. Unhatched eggs count toward collection capacity. Purchases are disabled once the chosen color or the entire collection is full. Test with an account that has used both free eggs.`

8. 若顯示 Missing Metadata，完成商品頁剩餘必填欄位。商品資料變更最多可能需要一小時才反映在 Sandbox。
9. Xcode 改回一般 **Den** scheme（StoreKit Configuration 為 None），使用 Sandbox 測試帳號或 TestFlight 測商品載入、價格、連買、取消。
10. 第一次送審：App 新版本頁 → **In-App Purchases and Subscriptions** → 加入 New Egg，和新版 App 一起送審。

如果尚未建立正式商品，一般 Den scheme 顯示 Unavailable 是正常的；Den StoreKit 使用本機測試商品，不代表商品已上架。

### 保存與恢復

- 免費兩顆及角色進度仍存於私人 iCloud CharacterLibrary。
- 每次付款前保存 EggPurchase 意圖：顏色、保留角色、UUID。Apple 交易回傳相同 UUID。
- 驗證成功後保存交易編號和蛋，再呼叫 finish；同一交易重送不會多加蛋。
- 中斷後從 Transaction.unfinished 重試。未載入對應私人資料時，交易保持未完成。
- 已完成的消耗型購買以私人 iCloud 收據及角色資料恢復，不提供會誤導使用者的 Restore Purchases 按鈕。
- 沒有 iCloud 時只保存在裝置；刪除 App 前需讓私人 iCloud 完成同步，才能在重裝後恢复資料。
- 舊版測試中的六個非消耗型購買保留相容讀取；新版只販售 New Egg，原本取得的蛋與進度不清除。

來源：[付款合約](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements)、[建立內購](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/)、[設定內購價格](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/)、[完成交易](https://developer.apple.com/documentation/storekit/transaction/finish())。

## 2. CloudKit：角色、購買紀錄與全體時數

### 產生私人資料結構

1. 手機登入 iCloud，以一般 Den scheme 安裝新版並完成一段專注。
2. 登入 [CloudKit Console](https://icloud.developer.apple.com/) → 選團隊 → CloudKit Database → **iCloud.dev.noky.den** → **Development**。
3. Schema → Record Types：確認原有 CD_FocusSession、CD_FocusTag，以及新增 CD_CharacterLibrary、CD_FocusContribution、**CD_EggPurchase** 等私人 SwiftData 類型存在。購買紀錄是私人資料，不要開放 World Read。

### 建立公開時數類型

Schema → Record Types → ＋：

| 欄位 | 填入 |
| --- | --- |
| Record Type Name | **FocusContribution**（沒有 CD_ 前綴） |
| 新增 Field Name | **seconds** |
| Field Type | **Double** |

儲存後：

1. Schema → **Indexes** → ＋。
2. Record Type：FocusContribution。
3. Index Name：`FocusContribution_recordName_query`。
4. Type：**QUERYABLE**。
5. Field：**recordName** → Add。recordName 是系統 metadata，不要自行建立同名欄位。
6. Schema → **Security Roles**，設定 FocusContribution：

| Role | Read | Create | Write |
| --- | --- | --- | --- |
| World | ✓ | — | — |
| Authenticated | — | ✓ | — |
| Creator | — | — | ✓ |

World Read 也包含登入者；只有 Creator 可修改自己建立的紀錄。不要給所有 Authenticated 使用者 Write。

### 驗證與部署

1. 手機完成一段實際專注，離開 Settings 等同步，再回到 Settings；Global Focus 應有數字。手動補登不增加全體時數。
2. Console → Data → Records → Database 選 **Public** → Zone：Default → Record Type：FocusContribution → Query Records。應看到含 seconds 的貢獻。
3. 用另一個 iCloud 帳號也完成專注，確認兩台總數一致。
4. **Deploy Schema Changes to Production**，檢查私人 CD_EggPurchase 等新模型與公開 FocusContribution 的欄位、索引、權限，再部署。保留原有類型。
5. 切到 Production，確認 schema 已存在。這只搬資料結構，不會複製 Development 的測試資料。
6. 上傳 TestFlight，驗證購買資料保留與全體總数；TestFlight 使用 Production。

計算僅含實際專注，排除手動補登；離線先保存在私人 outbox，回到 App 後重試。公開資料只有原始時長及不透明識別碼，沒有標籤、角色或私人紀錄內容。CloudKit 仍有系統 metadata。

`community-schema.ckdb` 是公開類型參考片段。不要拿片段覆蓋容器完整 schema。

來源：[CloudKit 索引](https://developer.apple.com/documentation/cloudkit/inspecting-and-editing-an-icloud-container-s-schema)、[CloudKit 權限及部署](https://developer.apple.com/icloud/cloudkit/designing/)。

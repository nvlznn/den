# App Store 截圖

- `overview.png`：七張宣傳圖的總覽，僅供檢查。
- `screenshots/`：正式尺寸 PNG，依檔名前綴 01–07 上傳至 App Store Connect 的 **App Screenshots** 欄位。
- 每張 **1206 × 2622 px、RGB、不含 alpha**，符合指定的 iPhone 6.1" / 6.3" 截圖尺寸。第 1–4 張的手機皆為相同尺寸、正向直立並加上動態島；第 5 張是角色收藏圖卡，第 6 張聚焦兩種統計圖，第 7 張展示 widgets。這組是靜態截圖，不是影片 App Preview。
- 順序：選蛋 → 孵化 → 陪伴 → No pressure → 收集 → 統計 → Widgets。
- Widgets 頁為依現有功能製作的宣傳排版示意；其餘手機畫面使用既有深色模式 App 截圖。角色均取自當前 `Den/Pet/PetSprites.swift`，包含白色 Drop。

## 修改與重新產生

`source/render.swift` 是排版原稿；`source/sprites.json` 為目前角色的像素資料快照，其他 PNG 為本組使用的原始 App 截圖。

在專案根目錄執行：

```sh
swift previews/app-store/source/render.swift
```

僅上傳 `screenshots/` 中七張 PNG；不要上傳總覽或原稿。

## 第六張示範資料

第六張的圖表以 App 內 2026 年 9 月的示範資料排版：114 筆、95 小時 20 分，六個標籤為 Study、Reading、Deep Work、Writing、Languages、Creative。每筆 20–90 分鐘，每日筆數不同。截圖用的獨立模擬器使用記憶體資料庫並關閉 CloudKit。

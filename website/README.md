# Den website

純靜態網站，沒有任何外部依賴，不需要建置步驟。整個 `website/` 資料夾直接上傳就能用。

## 上架前要改的地方

只有一個檔案：`assets/config.js`

- `appStoreUrl`：App 上架後貼上 App Store 網址，兩個「Download on the App Store」按鈕就會啟用。留空時顯示「Coming soon to the App Store」，按了沒反應。
- `supportEmail`：首頁與 Privacy & Support 頁上的聯絡信箱，已設為 `support@noky.dev`。留空時改顯示「請透過 App Store 頁面的支援連結聯絡」。修改信箱時也請同步更新兩個 HTML 檔案中的預設 `mailto:` 連結，讓停用 JavaScript 的使用者仍可聯絡。

建議：上架後把按鈕換成 Apple 官方的 App Store 徽章（到 Apple 的 Marketing Resources 網站下載），App Store 審核和品牌規範都偏好官方徽章。

## App Store Connect 要填的網址

假設網站部署在 `https://den.example.com`：

- 隱私權政策網址（Privacy Policy URL）：`https://den.example.com/privacy`
- 支援網址（Support URL）：`https://den.example.com/privacy#support`
- 行銷網址（Marketing URL，選填）：`https://den.example.com/`

## 本機預覽

連結不帶 `.html`（例如 `privacy`），直接雙擊 `index.html` 用 `file://` 開的話，點連結會找不到頁面。本機預覽請在 `website/` 裡跑 `npx vercel dev`，或 `npx serve`。

## 部署方式（擇一）

- **GitHub Pages**：repo 的 Settings → Pages，來源選這個分支，資料夾選 `/website`（如果選不到，可以用 GitHub Actions 部署這個資料夾）。
- **Vercel / Netlify**：新增專案，Root Directory 設成 `website`，Build Command 留空。
- **任何靜態主機**：把 `website/` 裡的檔案原樣上傳。

## 檔案

- `index.html`：首頁
- `privacy.html`：隱私權政策 + 支援（網址是 `/privacy`，`vercel.json` 的 `cleanUrls` 會拿掉 `.html`）
- `vercel.json`：開啟 `cleanUrls`；舊的 `/privacy.html` 會自動轉址到 `/privacy`
- `assets/config.js`：App Store 網址、支援信箱
- `assets/sprites.js`：六隻角色的像素圖，由 `Den/Pet/PetSprites.swift` 產生；改了角色之後要重新產生
- `assets/site.js`：LCD 繪製、寵物動畫、套用設定
- `assets/style.css`：樣式，跟著系統的淺色／深色模式切換
- `assets/screens/`：App 截圖（603×1311，從 6.3 吋截圖縮小一半）

# SV_名片自動化製作 SOP

> StreetVoice 名片自動化製作標準作業流程
> 建立日期：2026-05-22
> 適用範圍：StreetVoice TW 街聲版名片（一般名片）
> 依賴：Adobe Illustrator + Claude Code + spencerhhubert/illustrator-mcp-server

---

## 🎯 觸發指令

要在 Claude Code 中啟動這個流程，跟 Claude 說：

> 「**我要製作名片**」/「**幫我做 SV 名片**」+ 直接拖入或貼上簽呈 PDF 路徑

**Claude 收到後必須做的第一件事**：
- 第一句話**逐字**回覆：「**好準備執行，illustator請確保為關閉狀態**」
- 然後**不等使用者確認**，立即依下面流程全自動執行直到 Step 11

Claude 自動依序：
1. 讀取此 SOP
2. 讀 PDF 萃取個人資料
3. **在 `$SV_OUTPUT_BASE/` 下建立新資料夾**（預設 `~/Documents/SV-名片/`，可由 `~/.config/sv-card/env` 覆寫），命名格式：`{中文姓名}_{英文名}`（不含 alias）
   - 例如：簽呈姓名 `王小明` + 英文名 `阿明 Ming Wang` → 資料夾 `王小明_Ming Wang`
4. **複製模板**並重新命名成 `{YYYYMMDD}-{中文姓名}_{英文名}.ai`
5. **自動 `open` 開啟 Illustrator + 載入該檔案**
6. 替換 7 欄位 → 自動存檔 → 產 vCard + QR → 置入 QR → 自動存檔
7. **停下來問使用者：「請確認資訊無誤」** ← 唯一一個 gate
8. 使用者 OK 後，輸出 JPG + OL CS6 檔到資料夾

> 也接受明確版觸發：「**執行 SV_名片自動化製作**，PDF: `[路徑]`」

---

## 📋 完整流程

```
[你]  ① 給 Claude 簽呈 PDF（一句話：「我要製作名片」）
        ↓
[我]  ② 第一句話：「好準備執行，illustator請確保為關閉狀態」並直接執行
        ↓
[我]  ③ 讀 PDF → 萃取 6 欄資料
        ↓
[我]  ④ 在 $SV_OUTPUT_BASE/ 建立資料夾 + 複製模板 .ai
        ↓
[我]  ⑤ 自動 `open -a "Adobe Illustrator" <new.ai>` + 輪詢直到 activeDocument 就緒
        ↓
[我]  ⑥ 替換 7 個文字物件 → 自動 `app.activeDocument.save()`
        ↓
[我]  ⑦ 呼叫 `make_card_artifacts.py` → 一次產 vCard + QR SVG + 預處理
        ↓
[我]  ⑧ 呼叫 place_qr.jsx → 自動 `app.activeDocument.save()`（原檔 .ai 已更新到資料夾）
        ↓
[我]  ⑨ 🛑 GATE：問使用者「請確認資訊無誤」
        ↓
[你]  ⑩ 切到 Illustrator 目視檢查 → 回覆 OK
        ↓
[我]  ⑪ 清殘留 → 重存原檔（saveAs /tmp → mv）→ 匯出 JPG → 外框化 → 存 OL CS6
```

> 💡 在 Step 9 GATE 時：使用者切去 Illustrator 看到的就是「替換 + QR 置入後的最新狀態」（Step 8 已 save 進資料夾）。確認 OK 後再產出最終交付檔。

---

## 📐 規範與慣例

### 模板物件命名（首次設定，已完成）

模板位置：`~/.claude/skills/sv-card/templates/20260522-王小明.ai`（install.sh 會 symlink 進去）

7 個可編輯欄位都已用 `PH_` 前綴命名：

| TextFrame.name | 內容範例 | 字級 |
|---|---|---|
| `PH_NAME_CN_SURNAME` | 王 | 12pt |
| `PH_NAME_CN_GIVEN` | 小明 | 12pt |
| `PH_NAME_EN` | Ming Wang | 7pt |
| `PH_TITLE` | 美術設計 | 6.2pt |
| `PH_PHONE_OFFICE` | +886-2-2741-7065#XXX | 6.2pt |
| `PH_PHONE_MOBILE` | +886-900-000-000 | 6.2pt |
| `PH_EMAIL` | mingwang@streetvoice.com | 6.2pt |
| `PH_QRCODE` | (GroupItem 40×40 placeholder) | - |

QR Code 命名（置入後）：`PH_QRCODE`（模板已內建命名，直接用名字找）

### 輸出檔名規則

| 檔案類型 | 命名 | 範例 |
|---|---|---|
| 原檔 | `{YYYYMMDD}-{中文名}_{英文名}.ai` | `20260522-王小明_Ming Wang.ai` |
| OL 檔 | `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | `OL-20260522-王小明_Ming Wang.ai` |
| JPG 預覽 | `{YYYYMMDD}-{中文名}_{英文名}.jpg` | `20260522-王小明_Ming Wang.jpg` |
| vCard | `{無空格英文名}.vcf` | `MingWang.vcf` |

> `YYYYMMDD` 使用「製作日」（不是申請日）

### 資料轉換規則

| 欄位 | 簽呈原始 | 名片顯示 |
|---|---|---|
| 中文姓名（去員編）| `王小明(XXX)` | 拆 → 姓=`黃` 名=`靖瑜` |
| 英文名（含 alias）| `阿明 Ming Wang` | 整段 |
| 公司電話 + 分機 | `#XXX` | `+886-2-2741-7065#XXX` |
| 手機 | `0900-000-000` | `+886-900-000-000`（去 0、加國碼）|
| QR Code 顏色 | - | CMYK(0,0,0,88) — 即 K=88% 純黑灰，K-only 印刷乾淨 |
| QR Code 尺寸 | - | 1.4cm × 1.4cm |

### vCard 特殊欄位

vCard 與名片**不完全相同**，注意：
- 公司電話：vCard 用 `02-27417065`（**不含分機**），名片用 `+886-2-2741-7065#XXX`
- FAX（vCard 才有）：`02-27488490`
- 手機：vCard 用簽呈原格式（如 `0900-000-000` 或 `+886 905 773 375`）
- 地址 (ADR)：松山區光復北路 11 巷 35 號 11 樓
- **不要嵌入 PHOTO 欄位**：讓 macOS 通訊錄自動依姓氏產生字母頭貼。
  早期舊範例 (MingWang.vcf) 的 PHOTO 其實是 macOS 自動產的「黃」字頭貼，**不是公司 logo**，誤搬到別人的 vCard 會顯示錯人的姓氏

---

## 📜 詳細步驟

### Step 1：使用者觸發

說：「**幫我做 SV 名片**」+ 給 Claude 簽呈 PDF 路徑（拖入 / 貼上 / 直接讀附件）

### Step 2：Claude 讀 PDF 萃取資料（自動）

Claude 用 Read tool 讀 PDF，萃取：
- 中文姓名（去員編，例如 `王小明(XXX)` → `王小明`）
- 英文名（含 alias，例如 `阿明 Ming Wang`）
- 職稱（例如 `美術設計`）
- 分機（例如 `#XXX`）
- 手機（例如 `0900-000-000`，會被規格化為 `+886-900-000-000`）
- Email

### Step 3 + 4 + 5 + 8 預備：合併呼叫 `card_helper.sh init`（吃所有原始欄位）

單一 Bash 指令完成 建資料夾 + 複製模板 + 開檔 + 輪詢 + **寫 sidecar JSON**：
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh init \
    --chinese "王小明" --english "Ming Wang" \
    --surname "王" --given "小明" \
    --title "美術設計" \
    --email "mingwang@streetvoice.com" \
    --mobile "+886 900 000 000" \
    --office-ext "395"
```

**英文名取「去 alias」版本：** 若英文名是 `阿明 Ming Wang`，`--english` 取 `Ming Wang`（規則：移除最前面的中文 alias 部分）

腳本內部行為：
1. `mkdir -p $SV_OUTPUT_BASE/{chinese}_{english}`（路徑來自 `~/.config/sv-card/env` 或環境變數，預設 `~/Documents/SV-名片/`）
2. `cp -L $SV_TEMPLATE` 到該資料夾並重新命名為 `{YYYYMMDD}-{chinese}_{english}.ai`（模板預設 `~/.claude/skills/sv-card/templates/20260522-王小明.ai`）
3. **寫 sidecar `/tmp/sv_card_fields.json`**，內含 `fields` 區塊（7 個 PH_*）+ `artifacts` 區塊（vCard/QR 所需欄位）。內部推導：
   - `mobile_display = mobile.replace(" ", "-")` → 名片用
   - `vcf_name = en.replace(" ", "") + ".vcf"`
   - `PH_PHONE_OFFICE = "+886-2-2741-7065#" + office_ext`
4. `open -a "Adobe Illustrator" "$NEW_FILE"`
5. 輪詢 osascript（最多 60 秒）直到 activeDocument 就緒
6. 印出 `BASENAME=...` 和 `DEST_DIR=...` 供後續 Step 12 使用

> ⚠️ 若 Illustrator 已運行且停在歡迎頁，`open` 有可能被攔截。腳本會偵測並警告。**建議冷啟動**（觸發後第一句話「請確保 illustator 為關閉狀態」就是要使用者先關掉）。
>
> 冷啟動實測：Illustrator 啟動 + 載檔 + textFrames 就緒約 1 秒內完成。

### Step 6 + 7：Claude 替換 7 欄位 + 自動存檔（呼叫 `replace_fields.jsx`）

Claude 透過 MCP 執行（**無需傳資料，自動讀 sidecar**）：

```javascript
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/replace_fields.jsx");
```

replace_fields.jsx 內部行為：
1. **若 `$.global.FIELDS` 未設，自動讀 `/tmp/sv_card_fields.json` 的 `fields` 區塊**
2. 建立 `name → TextFrame` 索引（避免每欄位都全表掃）
3. 對每個 `PH_*` key 找對應 TextFrame，找不到就累積到 missing 列表
4. 全部處理完才一次回報 missing（不中斷，便於 Claude 一次收集問題）
5. 完成後自動 `d.save()`

> 為什麼抽成 jsx + sidecar：避免 SKILL.md 內 inline JSON literal 重複（init 已收過一次資料），mcp call 內容變固定字串，模板欄位增減也不用改 SKILL.md。

### Step 8 + 9 + 10a：呼叫 `card_helper.sh artifacts`（無參數，從 sidecar 讀）

單一 Bash 指令完成 vCard、QR SVG、預處理：
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh artifacts
```

此命令無 args 時自動帶 `--from /tmp/sv_card_fields.json`，從 sidecar 的 `artifacts` 區塊讀：surname / given / en / title / email / mobile / folder / vcf_name。

腳本內部做 3 件事：
1. 產生 vCard `{folder}/{vcf-name}` — 用 make_vcard.make_vcard
2. 產生 QR SVG `{folder}/QR Code.svg`，內容是 URL `http://drive.streetvoice.com/vcard/{vcf-name}`
3. 預處理 SVG → `/tmp/qr_processed.svg`（剝 `id="bg"` 背景白底，供 place_qr.jsx 匯入）

> 為什麼從 sidecar 讀：消除與 Step 6 替換 7 欄位的重複輸入；Claude 全流程只在 Step 3（init）填一次資料。
>
> 向後相容：`card_helper.sh artifacts --surname ... --given ...` 命名參數模式仍可用。

> ⚠️ vCard URL 編碼進 QR 後，**.vcf 仍需使用者事後上傳到 drive.streetvoice.com/vcard/**，否則掃描會 404。腳本印出的 URL 是給使用者事後上傳對齊用。

### Step 10：呼叫 `place_qr.jsx`

封裝了 匯入 + group + 縮放 + 對齊 + 命名 + 染色 CMYK + BringToFront：
```javascript
$.global.QR_OPTS = {
    svgPath: "/tmp/qr_processed.svg",
    sizeCm: 1.4,
    cmykBlack: 88
};
// Folder("~") 展開為家目錄，跨機器通用（ExtendScript 不支援 ~ 在字串字面值內展開）
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/place_qr.jsx");
```

> 為什麼用 .jsx：避開 AppleScript 字串層轉義風險、便於版本管理、未來新名片款（中子/CN/EN）可直接重用。
>
> .jsx 內部行為見檔頭註解；前置條件是文件中存在 `PH_QRCODE` placeholder。

> ⚠️ **必須用 `CMYKColor` 直接賦值**。本模板是 CMYK 文件，賦值 `RGBColor` 會被 Illustrator 自動轉換成 rich black (75,71,68,34)，螢幕呈現偏藍紫。
>
> ⚠️ make_qr.py 的 finder pattern 是「中空 ring 路徑 + 實心 ball rect」結構，**沒有白色填補**，靠 BringToFront 露出底層卡片白色。因此 paint 不需區分黑/白，可直接全部染深。

### Step 11：Claude 自動存檔 + 🛑 GATE

```javascript
app.activeDocument.save();
```

存檔後，Claude **必須停下來**詢問使用者：

> 「**請確認資訊無誤**」

（可附上資料夾連結或提示使用者切到 Illustrator 目視檢查）

待使用者回覆 OK / 確認後，才執行 Step 12 輸出最終交付檔。

> 💡 這是整個流程**唯一**的 gate。Step 5–11 都自動串接無詢問。設計理由：QR 置入完成後是視覺最終狀態，這時候請使用者一次性確認最划算。

### Step 12：Claude 輸出 5 個檔案到新資料夾（合併呼叫 `finalize.jsx` + `card_helper.sh finalize`）

輸出資料夾：`$SV_OUTPUT_BASE/{NAME_FOLDER}/`（預設 `~/Documents/SV-名片/`）

**12a. 一次跑完 Illustrator 端**（清殘留 + 存 original + 外框化 + 存 OL）：

```javascript
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/finalize.jsx");
```

finalize.jsx 內部行為：
1. 清除位置或尺寸 > 1000 的殘留物（SVG 匯入副作用，見已知問題 4）
2. saveAs `/tmp/output_original.ai`（中文路徑會 8700，先存 /tmp）
3. createOutline 全部 textFrames
4. saveAs `/tmp/output_ol.ai`（CS6 相容）

**12b. 一次搬完檔 + JPG + 列產出**：

```bash
~/.claude/skills/sv-card/scripts/card_helper.sh finalize "$DEST_DIR" "$BASENAME"
```
> `$DEST_DIR` 和 `$BASENAME` 是 Step 3 init 印出的；BASENAME 例：`20260527-王小明_Ming Wang`
>
> finalize 子命令內部：
> 1. mv `/tmp/output_original.ai` → `$DEST_DIR/$BASENAME.ai`
> 2. sips 從原檔產 2000×780 JPG → `$DEST_DIR/$BASENAME.jpg`
> 3. mv `/tmp/output_ol.ai` → `$DEST_DIR/OL-$BASENAME.ai`
> 4. `ls -la` 列出 5 個交付檔

> 為什麼合併：原本 GATE 後是 4 個 tool call 交替（mcp→bash→mcp→bash），合併後變 2 個（mcp→bash），且 Claude 不用記中間步驟順序。

---

## ⚠️ 已知問題與解法

### 1. 中文路徑 `saveAs` 8700 取消錯誤
**症狀：** `Error 8700: the operation was cancelled`
**原因：** ExtendScript `File` 寫含中文字元的路徑會 silently cancel
**解法：** **先存到 `/tmp/英文檔名.ai`，再用 Bash `mv` 搬到中文目標路徑**

### 2. `-1712 AppleEvent 逾時` 假警報
**症狀：** osascript 報 -1712，但檔案實際被建立
**原因：** AppleScript 預設 60 秒 timeout，大檔存檔超過
**解法：** MCP server 已加 `with timeout of 600 seconds`。即使看到 -1712，先 `ls` 檢查 /tmp 檔，通常有產出
**位置：** illustrator-mcp-server repo 內 `src/illustrator/server.py`（fork 自 spencerhhubert/illustrator-mcp-server）

### 3. `ExportOptionsJPEG` 不寫檔
**症狀：** `exportFile()` 回傳成功但 JPG 不出現
**原因：** Illustrator 2026 對部分 export API 行為改變
**解法：** 改用 `sips` 把 .ai 當 PDF 處理（見 Step 12c）

### 4. SVG `placedItems.add()` 失敗的副作用
**症狀：** 用 `placedItems.add()` + SVG 會 9080 錯誤，但留下 3 個殘留物（1 個 0×0 PlacedItem + 2 個 16383 大小的 PathItem）
**解法：**
- **不要用 placedItems 載 SVG**，改用 `app.open(svgFile)` + 跨文件 `duplicate()`
- **流程末尾務必執行 Step 12a 清理**

### 5. 同一 TextFrame 內混合字級會閃退
**症狀：** 設定 `characters[i].characterAttributes.size` 跑 10+ 次後 Illustrator 閃退
**解法：** 模板已拆成 3 個獨立 TextFrame（姓 / 名 / 英文名），各自單一字級

### 6. AppleScript `\r` / `\n` 轉義問題
**症狀：** ExtendScript 內含 `/\r/g` 或 `/\n/g` regex 會語法錯
**原因：** AppleScript 字串會把 `\r` 解譯成 CR 字元
**解法：**
- 用 `String.fromCharCode(10)` 代替 `"\n"`
- 用 `charCodeAt(i) === 13` 代替 `/\r/g`
- 或寫 .jsx 檔，用 `$.evalFile()` 執行（繞過 AppleScript 字串層）

### 7. JPEG 文字顏色 (`style="fill:..."`) 被 Illustrator 忽略
**症狀：** SVG 內 `style="fill: rgb(0,0,0)"` 匯入後變成黑色（無視 SVG 的設定值）
**解法：** 不靠 SVG 預處理改色，**匯入後用 ExtendScript 強制重染色**（見 Step 10g）

### 8. CMYK 文件下 `RGBColor` 賦值被自動轉成 rich black
**症狀：** Step 10g 用 `var c = new RGBColor(); c.red=68; c.green=64; c.blue=63` 賦值後，色彩面板顯示 CMYK(75,71,68,34)，螢幕呈現偏藍紫
**原因：** Illustrator 在 CMYK 文件中收到 RGBColor 時，會用 ICC 配方轉成 rich black（多版套印的混合黑），而非 K-only 純灰
**解法：** **直接賦值 CMYKColor**：`var c = new CMYKColor(); c.black=88;`（K-only 純印 88% 灰）

### 9. 通用 white-rect regex 會誤殺 finder pattern 內白
**症狀：** Step 10a 預處理若用 `re.sub(r'<rect[^/>]*fill="rgb\(255,\s*255,\s*255\)"[^/>]*/>', "", svg)` 會把 SVG 中**所有** 白 rect 全剝光，包含 finder pattern 中間的 5×5 白方塊
**結果：** finder 變成 7×7 黑 + 3×3 黑（兩者完全堆疊）→ 視覺呈現為 SOLID 黑方塊，看不出 ring + ball 的結構
**解法：**
- make_qr.py 給背景 rect 加 `id="bg"`
- 預處理改成 `re.sub(r'<rect id="bg"[^/>]*/>', "", svg)`，只剝那一個
- 或者：make_qr.py 直接把 finder 設計為「中空 ring 路徑 + ball rect」結構，根本不放白 rect（當前作法）

---

## 🧰 涉及的腳本與檔案

| 用途 | 路徑 |
|---|---|
| 模板 .ai（已含 `PH_QRCODE` 命名）| `~/.claude/skills/sv-card/templates/20260522-王小明.ai` |
| vCard 產生器 | `~/.claude/skills/sv-card/scripts/make_vcard.py` |
| **QR Code 產生器**（取代 qrcode-monkey）| `~/.claude/skills/sv-card/scripts/make_qr.py` |
| **Artifacts 合併腳本**（Step 8+9+10a，CLI 介面）| `~/.claude/skills/sv-card/scripts/make_card_artifacts.py` |
| **Bash 操作合集**（init / save / finalize）| `~/.claude/skills/sv-card/scripts/card_helper.sh` |
| **欄位替換 jsx**（Step 6+7 合併）| `~/.claude/skills/sv-card/scripts/replace_fields.jsx` |
| **QR 置入 + 染色 jsx**（Step 10 主邏輯）| `~/.claude/skills/sv-card/scripts/place_qr.jsx` |
| **GATE 後合併收尾 jsx**（Step 12a）| `~/.claude/skills/sv-card/scripts/finalize.jsx` |
| 名片替換 jsx（舊版，已被 PH_ 命名替代）| `~/.claude/skills/sv-card/scripts/make_card.jsx` |
| Illustrator MCP server | 由使用者另行安裝（fork: spencerhhubert/illustrator-mcp-server，需去掉 Claude activate、加長 timeout）|
| 使用者偏好設定 | `~/.config/sv-card/env`（install.sh 寫入；可覆寫 SV_OUTPUT_BASE、SV_TEMPLATE）|

---

## 🚀 未來優化方向（按優先序）

- [ ] **整合所有步驟成單一 Python 腳本** `make_business_card.py`，接受 JSON 設定
- [ ] **支援 PDF 自動萃取**：用 Python PyPDF/pdfplumber 從簽呈 PDF 抽欄位
- [ ] **transmit.app API 整合**（如有公開 API），自動上傳 vCard 取得 URL
- [ ] **QR Code 生成自動化**（qrcode-monkey 或自寫 SVG 樣式生成）
- [ ] **支援其他名片版型**：Legacy（含色號）、CN 版、EN 版、無手機號碼版
- [ ] **設定檔化**：把固定欄位（公司名、地址、FAX）抽到設定檔，方便日後維護

---

## 📞 模板速查

### 固定欄位（永不變更）
- 街聲股份有限公司　統編 24560657
- 台北市 105 松山區光復北路 11 巷 35 號 11 樓
- 北京中子街聲文化發展有限公司 / 北京市朝陽區八里莊北里保利東郡 8 號樓 A 座 10 層
- 上海奇我文化發展有限公司 / 上海市長寧區古北路 666 號嘉麒大廈 4 樓 401-10 室
- www.streetvoice.com
- 統一公司電話：+886-2-2741-7065
- 統一 FAX：02-27488490

### Logo 元素（圖層上已有，無需更動）
- StreetVoice 主 logo（正面大字）
- 子品牌 logos：Simple Life / Packer / Blow 吹音樂（正面下方）
- SV logo 圓形橘底（反面右上）
- 樂譜 icon ♪（職稱前）
- 手機 icon 📱（電話前）
- 信封 icon ✉（Email 前）

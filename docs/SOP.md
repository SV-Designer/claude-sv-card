# SV_名片自動化製作 SOP

> StreetVoice 名片自動化製作標準作業流程
> 建立日期：2026-05-22
> 適用範圍：StreetVoice TW 街聲版名片（一般名片）
> 依賴：Adobe Illustrator + Claude Code + spencerhhubert/illustrator-mcp-server

---

## 🎯 觸發指令

要在 Claude Code 中啟動這個流程，跟 Claude 說以下任一句 + 直接拖入或貼上簽呈 PDF 路徑。**觸發語同時帶出「期望版型」**：

| 觸發語 | 期望版型 |
|---|---|
| 「**做名片**」（核心觸發詞）| 無指定 → 依簽呈「名片版型」欄位判斷 |
| 「**做 SV 名片**」 | TW 街聲版 |
| 「**做中子名片**」 | 中子 BVI 版 |
| 「**做台灣中子名片**」 | 台灣中子版 |

> **版型交叉檢核**：不論用哪句觸發，一律仍讀簽呈「名片版型」欄位。觸發語有指定版型但與簽呈不符（例：說「做中子名片」但簽呈寫「TW 街聲」）→ 🛑 停下問使用者以哪個為準；觸發語無指定 → 直接採簽呈版型。詳見 [`SKILL.md`](../skill/SKILL.md) 「觸發 + 版型路由」段。

**Claude 收到後必須做的第一件事**：
- 第一句話**逐字**回覆：「**好的，準備開始！請完全關閉 illustrator (⌘Q)**」
- 然後**不等使用者確認**，立即依下面流程全自動執行直到 Step 11

Claude 自動依序：
1. 讀取此 SOP
2. 讀 PDF 萃取個人資料
3. **在 `$SV_OUTPUT_BASE/SV/` 下建立新資料夾**（v0.14.0+：`SV_OUTPUT_BASE` 為名片根目錄、TW 接 `/SV`；預設 `~/Documents/名片/SV/`，可由 `~/.config/sv-card/env` 覆寫），命名格式：`{中文姓名}_{英文名}`（不含 alias）
   - 例如：簽呈姓名 `王小明` + 英文名 `阿明 Ming Wang` → 資料夾 `王小明_Ming Wang`
4. **複製模板**並重新命名成 `{YYYYMMDD}-{中文姓名}_{英文名}.ai`
5. **自動 `open` 開啟 Illustrator + 載入該檔案**
6. 替換 7 欄位 → 自動存檔 → 產 vCard + QR → 置入 QR → 自動存檔
7. **停下來問使用者：「請確認資訊無誤」** ← 唯一一個 gate
8. 使用者 OK 後，輸出 JPG + OL CS6 檔到資料夾

> 也接受附 PDF 路徑：「**做名片**，PDF: `[路徑]`」

---

## 📋 完整流程

```
[你]  ① 給 Claude 簽呈 PDF（一句話：「做名片」）
        ↓
[我]  ② 第一句話：「好的，準備開始！請完全關閉 illustrator (⌘Q)」並直接執行
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
        ↓
[我]  ⑫ 上傳 vCard 到 drive.streetvoice.com/vcard/（FTP 自動覆蓋同名檔）
```

> 💡 在 Step 9 GATE 時：使用者切去 Illustrator 看到的就是「替換 + QR 置入後的最新狀態」（Step 8 已 save 進資料夾）。確認 OK 後再產出最終交付檔。

### 中子 BVI 版分支（v0.10.0+；v0.10.1+ 加輸出路徑分流 + email/職稱 GATE）

`template_type == "中子BVI"` 時改走以下流程（簡化版）：

```
[你]  ① 給 Claude 簽呈 PDF（版型欄位填「中子BVI」）
        ↓
[我]  ② 第一句話：「好的，準備開始！請完全關閉 illustrator (⌘Q)」
        ↓
[我]  ③ 讀 PDF → 萃取資料 + 依「公司」欄位推導 --company
       「中子創新（BVI）」→ bvi；「中子文化股份有限公司」→ wenhua
        ↓
[我]  ④ 建資料夾 + 複製中子模板（`SV_TEMPLATE_ZHONGZI`），輸出 base 依 --company 分流：
       bvi → $SV_OUTPUT_BASE_ZHONGZI（v0.10.3+ 預設 ~/Documents/名片/中子）
       wenhua → $SV_OUTPUT_BASE_ZHONGZI_WENHUA（v0.10.3+ 預設 ~/Documents/名片/中子文化）
        ↓
[我]  ⑤ 開檔
        ↓
[我]  ⑥ 替換 8 欄位（v0.10.2+ 含 PH_COMPANY 動態公司名）→ 自動 save
        ↓
[我]  ⑦ ❌ 跳過 artifacts（無 vCard / QR；card_helper.sh artifacts 偵測 template_type 自動 skip）
        ↓
[我]  ⑧ ❌ 跳過 place_qr.jsx（範本本身無 QR 區塊）
        ↓
[我]  ⑨ 🛑 GATE：問使用者「請確認資訊無誤」
        ↓
[你]  ⑩ 目視檢查 → 回覆 OK
        ↓
[我]  ⑪ 清殘留 → 重存原檔 → JPG → 外框化 → 存 OL CS6
        ↓
[我]  ⑫ ❌ 跳過 upload-vcard（沒產 vCard 不用上傳）
```

> ✅ **中子 BVI 版已於 v0.14.0 畢業納入自動化白名單**：流程同 TW 全自動，僅 Step 6 GATE 需確認，不再每步停下。上方 8 步流程圖保留供理解分支差異。逐步確認規則（見本檔「🆕 新版型測試 → 畢業規則」節）改為**僅未來新增版型**適用。

### 台灣中子版分支（v0.12.0+）

`template_type == "台灣中子"`（簽呈版型欄）時走 `--template-type zhongzi-taiwan`，流程同上中子 BVI 簡化版，差異如下：

- **不需 `--company`**：台灣中子是中子創新旗下台灣子公司，**單一公司**，公司名「台灣中子創新股份有限公司」**靜態寫死於模板**（模板無 `PH_COMPANY` 框，⑥ 只替換 7 欄位）。
- **專屬模板**：`SV_TEMPLATE_ZHONGZI_TAIWAN`（`templates/20260612-名片模版_台灣中子.ai`），設計含 FAX 行（靜態）、僅台北一址。
- **輸出路徑**：`$SV_OUTPUT_BASE_ZHONGZI_TAIWAN`（預設 `~/Documents/名片/台灣中子`）。
- email 同為 `@neuin.com`；office 電話/地址與街聲同（模板靜態）；分機照簽呈帶入。
- 同中子 BVI：跳過 artifacts / QR / upload（card_helper.sh 與 finalize.jsx 一律以「`template_type != tw`」判斷 skip，v0.12.0+ 泛化）。
- ✅ **已通過 2 次測試納入自動化白名單（v0.14.0）**：流程同 TW 全自動，僅 Step 6 GATE 需確認，不再每步停下。

> 📌 模板製作補記（v0.12.0）：原始範例檔 FAX 行的文字框誤命名為 `PH_PHONE_MOBILE`（與手機框重名），會導致替換時手機號碼被寫進 FAX 行。repo 模板已修正（FAX 框改回靜態無名）。

### 經典復刻款 BVI 版分支（v0.17.x，**輕度畢業**）

**簽呈版型欄「經典復刻款 BVI」** → 走此分支。**雙面卡、米褐色系設計**，與其他款差異大，**此款 SOP 有專屬微調**。目前**手動逐步製作**（尚未納入 card_helper 自動化），需跑通 2 次才畢業。模板：`templates/20260622-名片模版_經典復刻款.ai`（雙面並排：正面 `left<500`、背面 `left>=500`；v0.19.0 加寬 `PH_COMPANY` 框以容下台灣中子 12 字全名）。

**框集合（框名已英文化；雙面同名框加 `_F`/`_B` 區分，v0.16.x）**：
- 單面：`PH_NAME_CN`、`PH_NAME_EN`、`PH_TITLE`（中文職稱）、`PH_TITLE_EN`（英文職稱）、`PH_COMPANY`、`PH_EMAIL`、`PH_PHONE_EXT`
- 雙面：`PH_COMPANY_EN_F`/`_B`、`PH_PHONE_MOBILE_F`（純號碼如 `0933-329-996`）/`_B`（`Mobile: +886-…`）
- 靜態不替換：公司電話/傳真/地址（固定）、網址、底色、文字底色、備註＆參考線
- **分機格式**：`PH_PHONE_EXT` 顯示 `ext.253`（不是其他款的 `#402`）

**專屬 SOP 微調（僅此款）**：
1. **省略 vCard & QR**（同中子系列）。
2. **存 PNG-24 不存 JPG**：尺寸 **2000×668**（`sips -s format png --resampleHeightWidth 668 2000`，雙面 3:1 比例）；sips 出圖含 alpha → 用 PIL 合成底色轉 **24-bit RGB**（`Image.convert('RGBA')` + 底色 `paste(mask=alpha)` + 存，去掉 alpha 才是嚴格 PNG-24）。**合成底色依簽呈是否改色**：
   - **有顏色備註**（已改底色）→ **白底** `(255,255,255)`
   - **無顏色備註**（底色維持預設白卡）→ **灰底 K70**（CMYK 0,0,0,70 ≈ RGB `(76,76,76)`，襯托白卡才看得出邊界）
3. **`PH_COMPANY` 預設「中子創新有限公司」**；簽呈為中子文化 → 「中子文化股份有限公司」、台灣中子 → 「台灣中子創新股份有限公司」。
4. **`PH_COMPANY_EN_F`/`_B` 預設「Neutron Innovation (BVI) Ltd.」**；簽呈中子文化 → 「Neutron Culture Co., Ltd.」。
5. **其他需求欄備註名片顏色** → 改底色（見下配色 SOP）。**色碼不明確 → 問使用者**。
6. **存 PNG + OL 前** GATE 提示「**請確認資訊及配色無誤**」（比其他款多「配色」）。

**配色 SOP（簽呈有顏色備註時，CMYK 例 `C0 M7 Y23 K30`）—— 核心就 3 句**：

1. **名稱含「底色」的物件 → 備註色**。⚠️ 雙面底色**兩種結構**：正面「底色」是 **PathItem**、背面「底色」是 **GroupItem**（要進群組染內部 PathItem）。
2. **其餘所有元素（文字 + 文字底色黑條）→ 白**。
   - 文字描邊：**只改原本就有 stroke 的、保留原粗細**（`strokeColor.typename !== "NoColor"` 才改 strokeColor，**不動 `strokeWeight`**）；原本無描邊的不加邊框。
   - 排除「備註＆參考線」群組。
3. **唯一例外：`PH_COMPANY_EN_F`（正面直排公司英文）→ 回備註色**（fill + stroke）。因第 2 句把它腳下的黑條翻成白條，白字躺白條會消失，故翻回備註色才有對比。

> 💡 心法：**底翻備註色、其餘全翻白；只有正面直排公司英文回備註色**。`PH_COMPANY_EN_B`（背面）不是例外——它躺在備註色底上，跟其餘字一樣翻白即可，自動歸第 2 句。

> 🎨 **無顏色備註時**：不改色（底色維持黑白範本），出 PNG 時 PIL 合**灰底 K70**（見上方第 2 點）。

**實作已知坑（手動製作）**：
- **遺失字體 → 文字框鎖死無法編輯（v0.19.0）**：經典款用 `FakePearl-SemiBold` / `rounded-mgenplus-1cp-regular` / `Questrial-Regular`（＋ Noto Sans CJK TC）。**機器沒裝這些字體時，Illustrator 不只跳「遺失字體」，更會鎖住「使用該字體的文字框」無法被 `tf.contents=` 改值** → 自動填值對英文框（Questrial）等直接失效，且看起來像「replaced 成功但畫面沒變」。**解法**：跑 `install.sh`（v0.19.0+ 會自動把 `fonts/` 內字體裝進 `~/Library/Fonts/`），或手動安裝字體包，**裝完務必完全關閉並重開 Illustrator（⌘Q）字體才生效**。字體清單與來源見 repo `fonts/README.txt`。
- **`MRAP` 錯誤（Error 1200 'MRAP'）**：剛 `tf.contents=...` 填值後立刻設 `characterAttributes` 顏色會報此錯（文字 cache 失效）→ **填值與設色之間 close + 重開文件刷新**（`app.open` 重載）再設色。
- **易斷線**：文字 `characterAttributes`/`strokeColor` 大量操作會讓 Illustrator 卡 → MCP `Connection closed`。**分小批（每批 ~8 框）+ 每批 saveAs 保進度 + Illustrator 保持前景**（重連用 `/mcp`）。
- 中文路徑 saveAs 8700 → 先存 `/tmp` 再 bash `mv`。

**最終產出（4 檔）**：原檔 `.ai`、`OL-*.ai`、`*.png`（PNG-24）、簽呈備份 PDF。

> 🧪 測試紀錄（**已跑通 2 次、輕度畢業**）：(1) v0.16.x 表單 646 / 李大同 — 中子創新 BVI + **改色**（米褐 C0M7Y23K30 + PNG 白底）；(2) v0.17.x 同表單另一版 — 中子文化 + **無改色**（黑白範本 + PNG 灰底 K70）。兩次涵蓋改色/無改色、公司名（中子創新↔中子文化）切換分支，`_F`/`_B` 框名自動對應 11/11。
>
> 🎓 **輕度畢業**：流程已穩定，但**維持手動逐步製作 + 本節 SOP 指引**，**暫不做 card_helper 自動化**（配色需人眼確認、易踩 MRAP/斷線，全自動 ROI 低）。每步仍逐步確認（尤其配色 + GATE）。

---

## 🆕 新版型測試 → 畢業規則

做 **TW 街聲以外的新名片版型**（CN / EN / Legacy / 無手機等尚未支援者）時，依下列規則處理：

1. **逐步確認**：每個「會改磁碟 / 文件狀態」的關鍵步驟（建資料夾、複製模板、執行 Illustrator script、染色、輸出檔案）**先停下等使用者「OK」再執行**，不可直接套 TW 全自動 SOP。
   - 原因：新款模板結構、欄位數、QR 規格、染色需求可能不同，直接沿用會踩看不見的雷（例如缺 `PH_QRCODE` 命名、欄位命名規則不同、座標範圍不同）。
2. **≥ 2 次成功才畢業**：該版型**成功跑通 ≥ 2 次**後，才可詢問是否納入「全自動白名單」。畢業後流程同 TW 全自動、僅 Step 6 GATE 需確認。
3. 畢業時更新下方「各版型狀態」表與對應措辭。

### 各版型畢業狀態（截至 v0.14.0）

| 版型 | 狀態 |
|---|---|
| TW 街聲 | ✅ 早已全自動（僅 Step 6 GATE）|
| 中子 BVI | ✅ v0.14.0 畢業（v0.10.3 表單 647 BVI + v0.14.0 同簽呈乾淨跑通）|
| 台灣中子 | ✅ v0.14.0 畢業（v0.12.0 表單 647/劉琪琪 第 1 次 + v0.14.0 第 2 次）|
| 經典復刻款 BVI | 🎓 **輕度畢業**（v0.17.x 跑通 2 次：改色版 + 無改色版）；維持手動逐步 + SOP 指引，**未做 card_helper 自動化**（配色需人眼確認）|
| CN / EN / Legacy / 無手機 | ⏳ 尚未支援，走上方逐步確認規則 |

→ 目前所有支援版型皆全自動；逐步確認規則自此**只對未來新增版型**適用。

---

## 📐 規範與慣例

### 模板物件命名（首次設定，已完成）

模板位置：`~/.claude/skills/sv-card/templates/20260612-名片模版_TW 街聲.ai`（install.sh 會 symlink 進去）

可編輯欄位都已用 `PH_` 前綴命名：

| TextFrame.name | 內容範例 | 字級 |
|---|---|---|
| `PH_NAME_CN_SURNAME` | 王 | 12pt |
| `PH_NAME_CN_GIVEN` | 小明 | 12pt |
| `PH_NAME_EN` | Ming Wang | 7pt |
| `PH_TITLE` | 美術設計 | 6.2pt |
| `PH_PHONE_EXT` | #375（**v0.15.x 新框**：只放分機，留白則空）| 6.2pt |
| `PH_PHONE_MOBILE` | +886-900-000-000 | 6.2pt |
| `PH_EMAIL` | mingwang@streetvoice.com | 6.2pt |
| `PH_QRCODE` | (GroupItem placeholder，**僅 TW 有手機版有**) | - |
| `PH_COMPANY` | 中子創新有限公司（v0.10.2+，**僅中子BVI 模板有**）| 6pt |

> **v0.15.x 電話框改版**：公司電話 `+886-2-2741-7065` 改為**靜態文字框**（名為「公司電話」，**無 `PH_` 前綴 → 腳本不替換**）；分機獨立成新框 `PH_PHONE_EXT`（值 = `#`+分機，對照 PDF 室內分機；簽呈留白則框留空）。所有現行 template（TW 有手機 / TW 無手機 / 中子BVI / 台灣中子）皆此設計。
>
> **v0.18.0**：無手機版已換新排版 `20260622-名片模版_TW 街聲（無手機）.ai`，同採 `PH_PHONE_EXT` 新框（`legacy_office=0`），與有手機版一致。舊合成框 `PH_PHONE_OFFICE` / `legacy_office=1` 分支已無模板使用（程式保留向後相容）。

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
| 中文姓名（去員編）| `王小明(XXX)` | 拆 → 姓=`王` 名=`小明` |
| 英文名（含 alias）| `阿明 Ming Wang` | 整段 |
| 公司電話 | - | `+886-2-2741-7065`（**靜態於模板，腳本不填**）|
| 分機（新版三 template）| `375` | `PH_PHONE_EXT` = `#375`（簽呈留白 → 框留空）|
| 手機 | `0900-000-000` | `+886-900-000-000`（去 0、加國碼）|
| **無手機** | （空白）| 名片不顯示手機行（**自動選無手機版模板**），vCard 跳過 TEL CELL |
| QR Code 顏色 | - | CMYK(0,0,0,88) — 即 K=88% 純黑灰，K-only 印刷乾淨 |
| QR Code 尺寸 | - | 1.4cm × 1.4cm |

### 分支處理（v0.8.0+）

由 `card_helper.sh init` 自動處理，使用者只需傳對應參數：

| 簽呈情況 | init 參數 | 結果 |
|---|---|---|
| 有手機 + 有分機 | `--mobile "..." --office-ext "..."` | 用預設新版模板 (`20260612-名片模版_TW 街聲.ai`)，`PH_PHONE_EXT` = `#`+分機，`PH_PHONE_MOBILE` 有值 |
| 有手機 + 無分機 | `--mobile "..." --office-ext ""` | 用預設新版模板，`PH_PHONE_EXT` 留空字串，`PH_PHONE_MOBILE` 有值 |
| 無手機 + 有分機 | `--mobile "" --office-ext "..."` | 用無手機版模板 (`20260622-名片模版_TW 街聲（無手機）.ai`，`legacy_office=0`)，新框 `PH_PHONE_EXT` = `#`+分機，sidecar 跳過 `PH_PHONE_MOBILE` |
| 無手機 + 無分機 | `--mobile "" --office-ext ""` | 用無手機版模板，新框 `PH_PHONE_EXT` 留空字串，sidecar 跳過 `PH_PHONE_MOBILE` |

> ✅ **無手機版已更新成新電話框設計（v0.18.0）**：四款現行模板（TW 有手機 / TW 無手機 / 中子BVI / 台灣中子）皆「公司電話靜態 + `PH_PHONE_EXT`」，無手機版改用 `20260622-名片模版_TW 街聲（無手機）.ai`、走 `legacy_office=0`。舊 `PH_PHONE_OFFICE` 合成框 / `legacy_office=1` 分支已無模板使用，程式保留作向後相容。

### vCard 特殊欄位

vCard 與名片**不完全相同**，注意：
- 公司電話：vCard 用 `02-27417065`（**不含分機**），名片用 `+886-2-2741-7065#XXX`
- FAX（vCard 才有）：`02-27488490`
- 手機：vCard 用簽呈原格式（如 `0900-000-000` 或 `+886 905 773 375`）。**簽呈無手機 → 整行 TEL CELL 略過**
- 地址 (ADR)：松山區光復北路 11 巷 35 號 11 樓
- **不要嵌入 PHOTO 欄位**：讓 macOS 通訊錄自動依姓氏產生字母頭貼。
  早期舊範例 (MingWang.vcf) 的 PHOTO 其實是 macOS 自動產的「黃」字頭貼，**不是公司 logo**，誤搬到別人的 vCard 會顯示錯人的姓氏

---

## 📜 詳細步驟

> **編號慣例**：本節 Step 0–9 與 [`SKILL.md`](../skill/SKILL.md) 完全對齊。子步驟編號（1.5、9a–d）也一致。歷史版本（v0.7 以前）SOP 內曾用 Step 1–13，已全面替換。

### 觸發（不編號，屬於使用者動作）

使用者說：「**做名片**」+ 給 Claude 簽呈 PDF 路徑（拖入 / 貼上 / 直接讀附件）

### PDF 萃取（不編號，屬於 init 前準備；雙重檢核，v0.8.6+）

**兩條並行的萃取管道，比對結果**：

1. **Claude Read PDF**：保留人類視覺判斷（typo、特殊備註、格式異常）
2. **`card_helper.sh extract-pdf <pdf>` 腳本**：純機械抽取 18 個欄位輸出 JSON

**比對規則**：
- 兩邊欄位值不一致 → 停下與使用者確認
- Claude 看視覺發現 typo（例：英文名 `Strong Wo` 像是 `Chang` 的拼錯）→ 停下與使用者確認
- 「其他需求」欄位通常為空白；若有「請協助送印」「TW」以外的特殊備註 → 停下與使用者確認
- 「表單註釋」欄位內容**可完全忽略** —— 不作為停下判斷（腳本 `form_remark` / `form_remark_is_placeholder` 仍抽出但不採用）
- 版型非「TW 街聲」→ 停下與使用者確認

**為何不純信腳本**（拿掉 Claude Read PDF）：
- 腳本對 typo 無辨識能力（沒字典）
- 腳本對「特殊請求」也只能字面提取，無法判斷此句是否「過去沒碰過」
- 失去視覺校驗 → 一旦 PDF 格式變動、欄位漏抓也察覺不到

**為何不純信 Claude Read PDF**（不跑腳本）：
- Claude 拆中文姓 / 名易出錯（複姓判斷需查表）
- Claude 拆英文 alias 需判斷字符類型
- 腳本萃取規範化（一定回傳 18 欄 JSON，省了 Claude 逐個欄位思考）

實作見 `scripts/extract_signoff_fields.py`：
- pdfplumber `extract_text()` 一次性抓全文
- regex 抓 `表單號`、`申請人`、`名片上的姓名`、`名片上的英文名` 等錨點
- 中文姓名拆分含 18 個常見複姓表（歐陽 / 上官 / 司徒 / 諸葛 / 慕容 / 皇甫 / 司馬 / 東方 / 夏侯 / 南宮 / 令狐 / 宇文 / 長孫 / 軒轅 / 鍾離 / 尉遲 / 鮮于 / 公孫）
- 英文 alias 偵測：首 token 含 CJK 字符 → 是 alias
- 「其他需求」欄位用 greedy `.*` 避開 PDF 內第一個「其他需求」字串（那是 Legacy 提示文字）

### Step 0：首次製作 — 確認名片存放路徑（僅首次跑）

對應 SKILL.md Step 0。呼叫 `card_helper.sh check-firstrun` 判斷是否需走首次流程；若需，問使用者「① 路徑（A 預設 `~/Documents/名片` 根目錄 / B 自訂）② 以後都用同路徑？」，回答後呼叫 `card_helper.sh confirm-firstrun "<路徑>"` 自動 mkdir + 開 Finder + 寫 `SV_OUTPUT_CONFIRMED=1` 到 `~/.config/sv-card/env`。完成後續跑 Step 1。v0.14.0+：確認的是**名片根目錄**（非 `SV` 子夾）；TW 版做的時候才在根目錄下自動建 `SV/`，中子各版建 `中子` / `中子文化` / `台灣中子`。

### Step 1：填欄位 + 建資料夾 + 開檔 + 寫 sidecar（`card_helper.sh init`）

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
1. `mkdir -p $SV_OUTPUT_BASE/SV/{chinese}_{english}`（TW 版；路徑來自 `~/.config/sv-card/env` 或環境變數，v0.14.0+ `SV_OUTPUT_BASE` 為根目錄、TW 接 `/SV`，預設 `~/Documents/名片/SV/`）
2. `cp -L $SV_TEMPLATE` 到該資料夾並重新命名為 `{YYYYMMDD}-{chinese}_{english}.ai`（模板預設 `~/.claude/skills/sv-card/templates/20260612-名片模版_TW 街聲.ai`）
3. **寫 sidecar `/tmp/sv_card_fields.json`**，內含 `fields` 區塊（7 個 PH_*）+ `artifacts` 區塊（vCard/QR 所需欄位）。內部推導：
   - `mobile_display = mobile.replace(" ", "-")` → 名片用
   - `vcf_name = en.replace(" ", "") + ".vcf"`
   - 新版三 template：`PH_PHONE_EXT = "#" + office_ext`（留白則 `""`）；公司電話靜態於模板
   - 舊無手機版（`legacy_office=1`）：`PH_PHONE_OFFICE = "+886-2-2741-7065#" + office_ext`
4. `open -a "Adobe Illustrator" "$NEW_FILE"`
5. 輪詢 osascript（最多 60 秒）直到 activeDocument 就緒
6. 印出 `BASENAME=...` 和 `DEST_DIR=...` 供後續 Step 7/8 使用

> ⚠️ 若 Illustrator 已運行且停在歡迎頁，`open` 有可能被攔截。腳本會偵測並警告。**建議冷啟動**（觸發後第一句話「請確保 illustator 為關閉狀態」就是要使用者先關掉）。
>
> 冷啟動實測：Illustrator 啟動 + 載檔 + textFrames 就緒約 1 秒內完成。

### Step 1.5：備份簽呈 PDF（v0.8.5+）

Claude 在 init 完成、拿到 `$DEST_DIR` 之後，立即備份簽呈 PDF 到該資料夾：

```bash
~/.claude/skills/sv-card/scripts/card_helper.sh backup-pdf "<簽呈 PDF 原始路徑>" "$DEST_DIR" [<form-no>]
```

**內部行為**（v0.10.3+ `backup_signoff_pdf.py`）：
1. 取表單號：CLI 第三參數 `<form-no>` > `pdfplumber` regex `表單號\s*[:：]\s*(\d+)` > 報錯
   - **中子 PDF 必傳 `<form-no>`**：中文 layer 圖片化（CID 編碼），pdfplumber 抓不到「表單號:」中文標籤
   - TW 簽呈可省略：腳本自動 regex 抓
2. `pypdf` 開原 PDF，改 `page.mediabox.lower_left` 與 `page.cropbox.lower_left` 的 y 值為 `page.height - 352`（**固定保留上方 352px**，v0.10.3 拍板）
3. 寫到 `<dest-dir>/簽呈編號-{表單號}.pdf`

**結果**：
- 保留：標題「名片申請」+ 申請人/表單號行 + 名片欄位表格（直到「所屬地區」），約頁面上方 352px
- 隱藏：「其他需求」box 下半 + 「表單註釋」section + 「簽核列表」表格

> **為何用固定 352px**（v0.10.3 取代動態邏輯）：
> 1. 中子 PDF 中文 layer 圖片化（CID 編碼），`extract_words()` 抓不到「表單註釋」word
> 2. 固定值對 TW + 中子 + 未來新版型一致；實測對 TW 簽呈也安全（過去動態切點約 ~265px，352 保留更多 = 更安全）
> 3. 設計簡化，移除 `pdfplumber` 在 `backup_signoff_pdf.py` 的依賴（但 `extract_signoff_fields.py` 仍依賴 pdfplumber）

> **為何用 CropBox 而非真正裁切**：CropBox 是 PDF 標準視窗概念，原內容仍在檔案內，只是 viewer 不顯示。優點是無損、實作極簡（只改一個 box 座標）；缺點是 PDF 編輯工具可還原 — 對名片簽呈這種已無隱私的文件夠用。

> **依賴**：`pip3 install --user pypdf pdfplumber`（v0.8.5+ 必要）。`install.sh` 已於 v0.8.8 同步檢查此兩套件（缺則互動安裝）。

### Step 2：替換 7 欄位 + 自動存檔（`replace_fields.jsx`）

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

> Step 9 `upload-vcard` 子命令會自動把產出的 vcf 上傳到 server（透過 curl + FTP），所以掃描 QR 不會 404。詳見 Step 13。

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

輸出資料夾：`$SV_OUTPUT_BASE/SV/{NAME_FOLDER}/`（TW 版，v0.14.0+ 根目錄下 `SV` 子夾；預設 `~/Documents/名片/SV/`）

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

### Step 13：上傳 vCard 到 server（拆三步 9a/9b/9c，呼叫 `card_helper.sh upload-vcard`）

**9a. 預查（必跑）**：
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard --check-only "$DEST_DIR/{無空格英文名}.vcf"
```
印 `exists` / `new`。`exists` 觸發 9b GATE，`new` 直接 9c。

**9b. 🛑 GATE**（僅 `exists` 觸發）：Claude 問使用者「`{vcf}` 偵測到相同檔案，請問是否覆蓋？」

**9c. 上傳**：
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard "$DEST_DIR/{無空格英文名}.vcf"
```

子命令內部（9c）：
1. 從 Transmit favorite「Streetvoice」（可由 `SV_TRANSMIT_FAVORITE` 環境變數覆寫）動態讀 host + user — 跨同事通用，不寫死
2. 從 macOS Keychain（label：`sv-card upload (Streetvoice)`）取密碼；找不到就跳 `osascript display dialog` 跟使用者要，存進 Keychain（之後永久靜默）
3. 用 `curl --list-only` 先查 server 是否已有同名檔，記 `existed_before`
4. **STOR + retry**：第一次 STOR 失敗 sleep 1 秒 retry（ProFTPD 偶有 transient 550）
5. 根據 `existed_before` 印兩種訊息擇一：
   - 新檔：`✅ vCard 已上傳 server`
   - 覆蓋：`✅ vCard 已上傳 server 並覆蓋舊檔`
6. 印出公開 URL（`http://drive.streetvoice.com/vcard/{vcf}`）
7. 兩次 STOR 都失敗 → 印「❌ 請手動用 Transmit 上傳並覆蓋舊檔」+ 本地路徑

> **不採 DELE-then-STOR**：實測使用者對「owner 非自己」的檔有 STOR 覆寫權限但沒 DELE 權限，DELE 路徑根本走不通。直接 STOR + retry 才是對的路徑。

**9d. 驗證**（9c 失敗 + 使用者手動 Transmit 上傳完後跑）：
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh verify-vcard "$DEST_DIR/{無空格英文名}.vcf"
```
抓 server 上同名 vcf 內容 cmp 對本地：
- `match` → 已驗證一致
- `mismatch` → server 端內容跟本地不同（可能被 owner 覆蓋回去）
- `missing` → server 上沒檔案

> **為什麼要 9d 驗證**：實測過 9c STOR 226 Transfer complete 後，server 端檔案被其他 process / 真實 owner 覆蓋回原版。`9c ✅` 訊息可能 false positive。verify-vcard 用 cmp 二進位比對才確認 server 端真的是 sv-card 上傳的內容。

> 為什麼不直接用 Transmit AppleScript：Transmit 5 字典中 `connect to favorite` 在 `tell document` scope 內反覆失敗（試了 6+ 個 syntax 變體），改用「Transmit favorite 動態查 host/user + macOS Keychain 存密碼 + curl FTP」更簡單可靠，且密碼完全不在 skill repo 內。

> ⚠️ 第一次跑會跳 macOS Keychain 對話框「需要使用 Keychain」— 按「Always Allow」之後永久靜默。

> ⚠️ 若改過密碼導致上傳 401：執行 `security delete-internet-password -s drive.streetvoice.com -a "$USER" -l "sv-card upload (Streetvoice)"`（其中 `-a "$USER"` 帶你的 Mac username；upload-vcard 預設用 `whoami` 取得），下次跑 upload-vcard 會再 prompt 新密碼。

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
| 模板 .ai（已含 `PH_QRCODE` 命名）| `~/.claude/skills/sv-card/templates/20260612-名片模版_TW 街聲.ai` |
| vCard 產生器 | `~/.claude/skills/sv-card/scripts/make_vcard.py` |
| **QR Code 產生器**（取代 qrcode-monkey）| `~/.claude/skills/sv-card/scripts/make_qr.py` |
| **Artifacts 合併腳本**（Step 8+9+10a，CLI 介面）| `~/.claude/skills/sv-card/scripts/make_card_artifacts.py` |
| **Bash 操作合集**（init / save / finalize / upload-vcard）| `~/.claude/skills/sv-card/scripts/card_helper.sh` |
| **欄位替換 jsx**（Step 6+7 合併）| `~/.claude/skills/sv-card/scripts/replace_fields.jsx` |
| **QR 置入 + 染色 jsx**（Step 10 主邏輯）| `~/.claude/skills/sv-card/scripts/place_qr.jsx` |
| **GATE 後合併收尾 jsx**（Step 12a）| `~/.claude/skills/sv-card/scripts/finalize.jsx` |
| 名片替換 jsx（舊版，已被 PH_ 命名替代）| `~/.claude/skills/sv-card/scripts/make_card.jsx` |
| Illustrator MCP server | 由使用者另行安裝（fork: spencerhhubert/illustrator-mcp-server，需去掉 Claude activate、加長 timeout）|
| 使用者偏好設定 | `~/.config/sv-card/env`（install.sh 寫入；可覆寫 SV_OUTPUT_BASE、SV_TEMPLATE）|

---

## 🚀 未來優化方向（按優先序）

> 設計原則（優化優先降出錯、非省 token）：提改動先分類 —— **降出錯／降維護 → 優先做；省 token／批量 → 降優先或擱置**。名片製作頻率不高、token 收益低，故**只挑「降低出錯機率」的項目**；整合腳本、API 封裝這類重構性改動 ROI 低，不入此清單。

### P1 — 文件債

- [x] ~~固定欄位設定檔化~~（v0.9.0 完成）— 抽至 `~/.config/sv-card/company.json` + `scripts/company_config.py` 載入器

### P2 — 需求驅動（等實際 PDF 進來再做）

- [x] ~~中子 BVI 版~~（v0.10.0 完成 + v0.10.1 補強；**v0.14.0 納入自動化白名單**）— 模板 `templates/20260612-名片模版_中子BVI.ai`，`--template-type zhongzi-bvi --company {bvi|wenhua}` 走簡化分支（跳過 vCard / QR / 上傳，輸出 4 個檔案，路徑依公司分流）。**已畢業 → 全自動同 TW，僅 Step 6 GATE 需確認。**
- [x] ~~台灣中子版~~（v0.12.0 完成；**v0.14.0 通過 2 次測試納入自動化白名單**）— 模板 `templates/20260612-名片模版_台灣中子.ai`，`--template-type zhongzi-taiwan`（單一公司，不需 `--company`）走中子簡化分支，輸出至 `~/Documents/名片/台灣中子`。skip 判斷由 `== zhongzi-bvi` 泛化為 `!= tw`（card_helper.sh + finalize.jsx）。**已畢業 → 全自動同 TW，僅 Step 6 GATE 需確認。**
- ~~**中子版 — 無手機版**~~（2026-06-12 使用者拍板**暫不做**，未來真有無手機中子簽呈會再主動提出）
- ~~CN / EN / Legacy 版~~（2026-06-12 使用者拍板**不做、完全忽略**，自此不列入待辦）

### ❌ 已評估不做（ROI 低）

- ~~整合所有步驟成單一 Python 腳本~~：分步流程便於 debug 與 gate 切換，整合的 net win 是降出錯但目前流程已穩，反而增加維護負擔。
- ~~Transmit API 整合自動上傳取得公開 URL~~：現行 `curl FTP STOR + retry + 9d verify` 已穩定且涵蓋 false positive 情境，再封裝收益小。

### ✅ 已完成（歷史紀錄，供回溯）

- ✅ PDF 自動萃取（v0.8.6，`extract_signoff_fields.py` + 雙重檢核流程）
- ✅ QR Code 生成自動化（`make_qr.py` 取代 qrcode-monkey）
- ✅ 無手機號碼版（v0.8.0；v0.18.0 換新排版 `20260622-名片模版_TW 街聲（無手機）.ai`，改新分機框 `PH_PHONE_EXT`）
- ✅ `install.sh` 同步檢查 `pypdf` / `pdfplumber`（v0.8.8）
- ✅ `extract_signoff_fields.py` 全面 regex 收緊（v0.8.9，8 條 `\s` → `[ \t]`，#554 回歸測試 diff 為空）
- ✅ 公司固定資訊抽離至 `~/.config/sv-card/company.json`（v0.9.0，`company_config.py` 載入器 + fallback DEFAULTS，3 處 hardcoded 改 1 處設定）
- ✅ 中子 BVI 版分支（v0.10.0，新增 `--template-type zhongzi-bvi`、`SV_TEMPLATE_ZHONGZI` 環境變數、sidecar `template_type` 標記、artifacts/QR/upload 自動 skip）
- ✅ 中子分流輸出路徑 + 規則補強（v0.10.1，新增 `--company bvi/wenhua`、`SV_OUTPUT_BASE_ZHONGZI` / `SV_OUTPUT_BASE_ZHONGZI_WENHUA` 環境變數、email 白名單加 @neuin.com、職稱中英混填 GATE 規則）
- ✅ 中子版動態公司名 `PH_COMPANY`（v0.10.2，模板 textFrames[4] 命名為 PH_COMPANY；card_helper.sh sidecar 依 --company 推導：bvi → 中子創新有限公司、wenhua → 中子文化股份有限公司；replace_fields.jsx 自動處理新欄位無需改動）
- ✅ v0.10.3 五大修復：
  - (1) `backup_signoff_pdf.py` 改用固定 `KEEP_TOP_PX=352`，移除「找『表單註釋』word」邏輯；加 `--form-no` 參數（中子 PDF 必傳）
  - (2) `card_helper.sh backup-pdf` 加可選 `<form-no>` 第三參數 forward 給 py
  - (3) 中子版預設輸出路徑改 `~/Documents/名片/SV/{中子,中子文化}`（跟 TW 版同根 `名片/SV/`）
  - (4) `card_helper.sh init` 寫 `dest_path` 進 sidecar；`replace_fields.jsx` 用此顯式 `saveAs` 繞 corrupt `fullName`（Illustrator 啟動中 `open` 會把 `fullName` 設為 `/Applications/Adobe Illustrator 2026`）
  - (5) `finalize.jsx` 讀 sidecar `template_type`，**中子版跳過清殘留**（中子模板有 16383×16383 clip group 內含 7 個 PH_*，清殘留會連帶刪掉）
  - (6) `to_card_mobile` 加尾段 `(\d{3})(\d{3})$` regex 拆段：`+886-909-050269` → `+886-909-050-269`

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

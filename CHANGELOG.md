# Changelog

本檔案記錄 sv-card 的變更歷史。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。

版本號採 [Semantic Versioning](https://semver.org/lang/zh-TW/)：MAJOR.MINOR.PATCH。

## [Unreleased]

## [0.14.0] — 2026-06-11

### Changed
- **台灣中子版 + 中子 BVI 版雙雙納入自動化白名單**（各跑通 2 次後畢業）：
  - 台灣中子：v0.12.0 表單號 647／劉琪琪第 1 次 + 本版同簽呈第 2 次。
  - 中子 BVI：v0.10.3 表單號 647 BVI 簽呈（修完 4 bug 後跑通）+ 本版同簽呈乾淨跑通。
  - 兩版流程皆改為**全自動同 TW，僅 Step 6 GATE 需確認**，不再每步停下。
  - **至此所有支援版型（TW 街聲 / 中子 BVI / 台灣中子）皆全自動**；逐步確認規則（memory `feedback_new_card_type_testing`）改為**僅未來新增版型**（CN / EN / Legacy 等）適用。
  - 影響文件：`skill/SKILL.md`（frontmatter description + PDF 萃取規則中子BVI/台灣中子兩段）、`docs/SOP.md`（中子分支流程註記 + P2 待辦兩項）。
- **`SV_OUTPUT_BASE` 語意改為「名片根目錄」**（`~/Documents/名片`），各版型在其下接子資料夾：
  - TW 街聲版 → `$SV_OUTPUT_BASE/SV/`（`SV` 子夾只在真的做 TW 版時才建，不再於首次製作預先建立）
  - 中子 BVI → `$SV_OUTPUT_BASE/中子`；中子文化 → `$SV_OUTPUT_BASE/中子文化`；台灣中子 → `$SV_OUTPUT_BASE/台灣中子`（三者由根目錄衍生，改根目錄會一起跟著走）
  - **首次製作確認的是根目錄**（Step 0 訊息 A 由 `~/Documents/名片/SV` 改 `~/Documents/名片`）
  - 影響檔案：`scripts/card_helper.sh`（`SV_OUTPUT_BASE` 預設 + 3 個中子 base 改衍生 + TW 版 `output_base` 接 `/SV`）、`install.sh`（`default_output`）、`skill/SKILL.md` / `docs/SOP.md` / `README.md` 路徑公式與 Step 0 文案同步。

### Fixed
- 補建 skill / SOP 長期引用卻不存在的 memory `feedback_new_card_type_testing`（規則本體仍指向決策原則 memory，新檔追蹤各版型測試→畢業狀態）。

### 設計動機
- 跑台灣中子第 2 次時，首次製作流程在做「台灣中子」名片卻去建 `~/Documents/名片/SV` 空夾並把它當輸出根 — 不合理。使用者拍板：**首次確認的應是名片根目錄 `~/Documents/名片`，`SV` 子夾屬 TW 街聲版專有，做 TW 時才建。**

### 遷移注意
- 既有安裝若 `~/.config/sv-card/env` 仍寫 `SV_OUTPUT_BASE=".../名片/SV"`，需改為根目錄 `.../名片`（否則 TW 會變 `.../名片/SV/SV`）。owner 本機 env 已於本版同步修正（備份 `env.bak-20260611`）。

### 不破壞
- TW 最終產出實體路徑不變（仍 `~/Documents/名片/SV/{name}`）；中子各版實體路徑不變。

## [0.13.0] — 2026-06-11

### Changed
- **預設輸出路徑根目錄改 `~/Documents/SV-名片/` → `~/Documents/名片/`**，並讓 SV 街聲版也收進自己的子資料夾（與中子系列一致）：
  - SV 街聲：`~/Documents/SV-名片/`（原直接放根）→ `~/Documents/名片/SV`
  - 中子 BVI：`~/Documents/SV-名片/中子` → `~/Documents/名片/中子`
  - 中子文化：`~/Documents/SV-名片/中子文化` → `~/Documents/名片/中子文化`
  - 台灣中子：`~/Documents/SV-名片/台灣中子` → `~/Documents/名片/台灣中子`
- 影響檔案：`scripts/card_helper.sh`（4 個 `SV_OUTPUT_BASE*` 預設）、`install.sh`（`default_output`）、`README.md` / `skill/SKILL.md` / `docs/SOP.md` 文件同步。
- 使用者仍可在 `~/.config/sv-card/env` 自訂覆寫；既有安裝若已設 env 不受影響。

## [0.12.0] — 2026-06-11

### Added
- **台灣中子版**（中子創新旗下台灣子公司，GAIA／台灣中子創新股份有限公司）
  - 新版型 `--template-type zhongzi-taiwan`，專屬模板 `templates/20260611-王小明_台灣中子.ai`
  - **單一公司、不需 `--company`**：公司名「台灣中子創新股份有限公司」靜態寫死於模板（無 `PH_COMPANY`），設計含 FAX 行（靜態）、僅台北一址
  - 走中子簡化分支：跳過 vCard / QR / 上傳；輸出至 `$SV_OUTPUT_BASE_ZHONGZI_TAIWAN`（預設 `~/Documents/SV-名片/台灣中子`）
  - 員工 email 同為 `@neuin.com`（已在白名單內）；office 電話 / 地址與街聲同（模板靜態）
  - 新環境變數：`SV_TEMPLATE_ZHONGZI_TAIWAN`、`SV_OUTPUT_BASE_ZHONGZI_TAIWAN`
- **觸發語**「**做台灣中子名片**」→ 期望台灣中子版（仍與簽呈版型交叉檢核）

### Changed
- **跳過 artifacts / 清殘留判斷泛化**：`card_helper.sh` artifacts 子命令與 `finalize.jsx` 清殘留，由原本硬判 `template_type == "zhongzi-bvi"` 改為 `template_type != "tw"`，自動涵蓋 zhongzi-bvi / zhongzi-taiwan 及未來新版型
- `skill/SKILL.md`、`docs/SOP.md`、`README.md`：版型路由表、PDF 萃取對照、init 參數說明、模板路徑表、已知限制等同步補台灣中子

### Fixed
- **台灣中子模板 FAX 框誤命名修正**：原始範例檔 FAX 行文字框誤名為 `PH_PHONE_MOBILE`（與手機框重名），替換時會把手機號碼寫進 FAX 行。repo 模板已將 FAX 框改回靜態無名（FAX 為公司固定號碼）

### Notes
- 台灣中子版屬**新款測試階段**（依 memory `feedback_new_card_type_testing`）：初期每步先停下確認，成功跑 ≥ 2 次後才討論加入自動化白名單。本版已用簽呈（表單號 647 / 劉琪琪）測試 1 次通過（原檔 / JPG / OL-CS6 / 簽呈備份皆正確）
- 中子系列 PDF（含台灣中子）中文 layer 圖片化，`extract-pdf` 機械萃取可能全 null，欄位以 Claude 視覺讀 PDF 為準

## [0.11.0] — 2026-06-10

### Added
- **觸發語版型路由**：觸發句本身帶出「期望版型」
  - 「做 SV 名片」/「幫我做 SV 名片」→ 期望 TW 街聲版
  - 「做中子名片」→ 期望中子 BVI 版
  - 「做名片」/「作名片」/「我要製作名片」/「執行 SV_名片自動化製作」→ 無指定，沿用簽呈「名片版型」欄位判斷（同現行）
- **觸發語期望版型 vs 簽呈版型交叉檢核**：兩者不符（例：說「做中子名片」但簽呈寫「TW 街聲」）→ 停下問使用者以哪個為準，不自行猜

### Changed
- `skill/SKILL.md`：「🎯 觸發」段改為「🎯 觸發 + 版型路由」，加觸發語→期望版型對照表與雙重來源決策規則；frontmatter description 同步補新觸發詞與路由說明
- `docs/SOP.md`：「🎯 觸發指令」段加觸發語→期望版型對照表與交叉檢核說明
- `README.md`：懶人包「怎麼用」補「做 SV 名片 / 做中子名片」指定版型用法

### 設計動機
- 過去版型只由簽呈「名片版型」欄位決定；新增觸發語路由後使用者可口頭指定，且與簽呈交叉檢核可擋住「口誤」或「簽呈版型填錯」造成做錯版（依 `feedback_sv_card_decisions` 降出錯原則）

### 不破壞
- 純文件 / skill 指令層改動，無腳本邏輯變更；「做名片」等無指定觸發語行為與現行完全一致

## [0.10.4] — 2026-06-10

### Changed
- **文件去 owner 化**（純文件 / 註解修正，零行為改動）：
  - `skill/SKILL.md` 中子版觸發判斷段落：輸出路徑分流預設值由 `~/Documents/02_街聲/6 名片/{中子,中子文化}` 改為 v0.10.3 新值 `~/Documents/SV-名片/{中子,中子文化}`
  - `docs/SOP.md` 中子分支流程圖：兩處中子預設路徑同步更新
  - `docs/SOP.md` keychain 砍密碼指令範例：`-a owner` 改為 `-a "$USER"` 並補說明
  - `scripts/card_helper.sh` STOR 註解：「實測 owner 對 owner 非自己的檔有 STOR 覆寫權限」改為「實測：對 owner 非自己的檔有 STOR 覆寫權限」（去人名）

### 設計動機
- v0.10.3 修了預設路徑但**文件說明沒同步更新**，下載者讀 SKILL.md / SOP.md 會以為預設要跑到「02_街聲」資料夾，跟程式碼實際預設值對不上
- keychain 指令範例寫死 `-a owner` 對下載者（username 不是 owner）會無效
- 註解中的 owner 人名對外部閱讀者無意義，泛化為「實測」更通用
- 注意：CHANGELOG.md 中的 owner / 02_街聲 提及屬於**歷史紀錄與設計動機**（解釋「當時為什麼這麼設計、後來為什麼改」），刻意保留以維持文件可追溯性

### 不破壞
- 零程式邏輯改動；只動 4 行文件與 1 行註解

## [0.10.3] — 2026-06-10

### Added
- **`backup_signoff_pdf.py` 加 `--form-no <N>` 參數**：覆寫表單號（中子 PDF 必傳）
- **`card_helper.sh backup-pdf` 加可選 `<form-no>` 第三參數**：forward 給 py 端 `--form-no`
- **`card_helper.sh init` 在 sidecar 寫 `dest_path` 頂層欄位**：jsx 用此繞 Illustrator `fullName` corrupt bug

### Changed
- **簽呈 PDF 裁切改用固定 `KEEP_TOP_PX = 352`**（取代原本「pdfplumber 找『表單註釋』word top - 1pt」動態邏輯）
  - 中子 PDF 中文 layer 圖片化（CID 編碼），pdfplumber 抓不到「表單註釋」word，動態邏輯壞掉
  - 固定值對 TW + 中子 + 未來新版型一致；實測對 TW 安全（過去動態切點約 ~265px，352 保留更多 = 更安全）
  - 副作用：`backup_signoff_pdf.py` 不再需要 `extract_words()` 找 word，僅在 `--form-no` 未傳時用 pdfplumber 抓「表單號:」regex
- **中子版預設輸出路徑改 `~/Documents/SV-名片/中子` 與 `~/Documents/SV-名片/中子文化`**（原本 `~/Documents/02_街聲/6 名片/{中子,中子文化}` 是 owner 私人路徑，對下載 sv-card 的其他人不友善）
  - owner 本機已被 `~/.config/sv-card/env` 覆寫，**改預設值不影響 owner 自己**
- **`replace_fields.jsx` 改用 sidecar `dest_path` 做顯式 `saveAs`**（繞 Illustrator 啟動中時 `open` 會把 `fullName` 設為 `/Applications/Adobe Illustrator 2026` 的 corrupt 狀態）
- **`finalize.jsx` 讀 sidecar `template_type`**：`zhongzi-bvi` 跳過清殘留
  - 原因：中子模板有 16383×16383 clip group 內含 7 個 PH_* TextFrame（PH_NAME_CN_*/PH_NAME_EN/PH_TITLE/PH_PHONE_OFFICE/PH_PHONE_MOBILE/PH_EMAIL），舊版清殘留誤判此 group 為 SVG 殘留刪掉，連帶刪 7 個 PH_* 造成名片資訊全失
- **`to_card_mobile` 加尾段 `(\d{3})(\d{3})$` regex 拆段**：簽呈寫 `0909-050269` → 名片印 `+886-909-050-269`（之前印 `+886-909-050269` 後段六位連在一起不好讀）
- **SKILL.md / SOP.md** 對應更新 backup-pdf 用法、中子預設路徑、PDF 萃取規則

### 設計動機
- 跑劉琪琪中子 BVI 簽呈（表單號 647）時連續踩到 4 個 bug：
  1. `backup-pdf` 抓不到「表單號:」與「表單註釋」（中子 PDF 圖片化）
  2. `finalize.jsx` 清殘留把 7 個 PH_* TextFrame 連帶刪光（中子模板 clip group 結構不同）
  3. `replace_fields.jsx` 的 `d.save()` 因 Illustrator `fullName` corrupt 失敗（9031 錯誤）
  4. `to_card_mobile` 尾段 6 位連續數字沒拆 dash
- 使用者拍板：簽呈裁切固定 `352px`，所有版型一致，移除依賴「中文 word 抓取」的動態邏輯
- 中子版預設路徑改用 `~/Documents/SV-名片/{中子,中子文化}`：與 TW 版同根，對下載 sv-card 的其他人友善

### 回歸測試（6 綠）
- `to_card_mobile` 尾段 dash：`0909-050269` → `+886-909-050-269` ✓
- sidecar `dest_path` 已寫入頂層欄位 ✓
- 中子 BVI 走新預設 `SV_OUTPUT_BASE_ZHONGZI` ✓
- 中子文化走新預設 `SV_OUTPUT_BASE_ZHONGZI_WENHUA` ✓
- `backup_signoff_pdf.py --form-no 647` 對中子 PDF 跑通（772 KB 裁切版）✓
- `card_helper.sh backup-pdf <pdf> <dest> 647` 第三參數 forward 給 py 跑通 ✓

### 不破壞
- TW 流程零改動（`backup-pdf` 不傳 `<form-no>` 時 fallback regex 自動抓；`replace_fields.jsx` 用 saveAs 顯式路徑對 TW 也是 saveAs 同樣文件路徑，無視覺差異）

## [0.10.2] — 2026-06-10

### Added
- **中子版動態公司名 `PH_COMPANY`**：模板 textFrames[4]（原寫死「中子創新有限公司」）已重命名為 `PH_COMPANY`，依 `--company` 自動替換
  - `--company bvi` → 名片印「中子創新有限公司」（母公司）
  - `--company wenhua` → 名片印「中子文化股份有限公司」（旗下公司）
  - 模板：`templates/20260609-王小明_中子BVI.ai`（SRC + REPO 同步完成，留 `.before-rename.bak` 備份）
  - `card_helper.sh` sidecar 在 `template_type == "zhongzi-bvi" and company in {bvi, wenhua}` 時自動寫入 `fields.PH_COMPANY`
  - `replace_fields.jsx` 沿用「依名稱找 PH_* 替換」邏輯，**零改動**就支援新欄位

### Changed
- **SKILL.md** Step 1 `--company` 說明補上 `PH_COMPANY` 自動替換對照
- **docs/SOP.md** 模板物件命名表加 `PH_COMPANY`、中子分支流程「替換 7 欄位」改為「替換 8 欄位（含 PH_COMPANY 動態公司名）」、已完成歷史新增 v0.10.2

### 設計動機
- v0.10.1 確認中子版有 BVI / 文化 兩家子公司，但名片上**寫死印「中子創新有限公司」**會讓中子文化員工拿到錯印名片
- 不分模板（一張範本搞定）原則：用 `PH_COMPANY` placeholder 動態替換，比建兩張 .ai 模板更易維護
- `replace_fields.jsx` 已用「依名稱找 PH_*」邏輯，新增欄位零 code 改動就支援

### 回歸測試（3 綠）
- TW 版 sidecar **不應有** `PH_COMPANY`（避免污染 TW 模板）✓
- 中子 BVI + `--company bvi` → `fields.PH_COMPANY == "中子創新有限公司"` ✓
- 中子 BVI + `--company wenhua` → `fields.PH_COMPANY == "中子文化股份有限公司"` ✓

## [0.10.1] — 2026-06-09

### Added
- **中子版輸出路徑分流**：`card_helper.sh init` 新增 `--company` 參數（值：`bvi` / `wenhua`，**僅 `--template-type zhongzi-bvi` 時必填**）
  - `bvi` → 中子創新 BVI（母公司）員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI`（預設 `~/Documents/02_街聲/6 名片/中子`）
  - `wenhua` → 中子文化股份有限公司（旗下公司）員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI_WENHUA`（預設 `~/Documents/02_街聲/6 名片/中子文化`）
- 兩個新環境變數 `SV_OUTPUT_BASE_ZHONGZI` / `SV_OUTPUT_BASE_ZHONGZI_WENHUA`
- Sidecar JSON 在 `template_type == "zhongzi-bvi"` 時於頂層新增 `company` 欄位（debug / 未來分析用）

### Changed
- **SKILL.md「非常規簽呈」規則 + PDF 萃取必看項** 更新：
  - **Email 白名單** 新增 `@neuin.com`（中子員工正常信箱），與 `@streetvoice.com` 並列；其他網域才觸發 GATE
  - **職稱中英文混填 GATE**（例：簽呈寫「事業發展總監（英文: Business Development Director）」）→ 停下問使用者用中文還是英文
- **SKILL.md Step 1 範例** 補上 `--company` 參數說明
- **docs/SOP.md** 中子分支流程圖補上 `--company` 推導邏輯與輸出路徑分流

### 設計動機
- 使用者澄清公司關係：中子創新 = 母公司、中子文化 = 旗下公司。兩種子公司的員工名片需分別歸檔到不同資料夾管理
- 中子員工 email 域名固定 `@neuin.com`，原本「非 @streetvoice.com 都停下問」規則會誤觸發；改為白名單模式
- 職稱中英文混填無法自動 disambiguate，但範本 `PH_TITLE` 只能放一個字串，必須 GATE
- 維持向後相容：TW 流程不變（`--company` 在 TW 版禁用、報錯阻擋）

### 回歸測試（6 綠）
- TW 版 sidecar：`template_type=tw`、無 `company` key、有 `artifacts` 區塊、`PH_PHONE_OFFICE` 正確 ✓
- 中子 BVI + `--company bvi`：sidecar `company=bvi`、無 `artifacts`、輸出在 `$SV_OUTPUT_BASE_ZHONGZI` ✓
- 中子 BVI + `--company wenhua`：sidecar `company=wenhua`、輸出在 `$SV_OUTPUT_BASE_ZHONGZI_WENHUA` ✓
- 中子 BVI 漏傳 `--company` → 報錯阻擋（含解釋 bvi/wenhua 對應）✓
- 無效 `--company invalid` → 報錯阻擋 ✓
- TW 版多傳 `--company` → 報錯阻擋（`--company` 僅 zhongzi-bvi 可用）✓

### 已知問題（v0.10.2 候選）
- `extract_signoff_fields.py` 對中子版簽呈 PDF 全 null：中子簽呈 PDF 的中文表格欄位是「圖片化呈現」（不是真實 text layer），pdfplumber 抓不到。目前用 Claude 視覺萃取代替

## [0.10.0] — 2026-06-09

### Added
- **中子 BVI 版分支**：sv-card skill 新增第二種名片版型，依簽呈「名片版型」欄位「中子BVI」觸發
  - 模板：`templates/20260609-王小明_中子BVI.ai`（PH_* 命名 7 個欄位與 TW 版完全相同，但含 5 行寫死的中國分公司資訊）
  - `card_helper.sh init` 新增 `--template-type` 參數（值：`tw` / `zhongzi-bvi`，預設 `tw`）
  - 新環境變數 `SV_TEMPLATE_ZHONGZI`（預設 `$SV_CARD_SKILL_DIR/templates/20260609-王小明_中子BVI.ai`）
  - Sidecar JSON 新增頂層欄位 `template_type`，artifacts 子命令據此自動 skip
  - 中子分支自動跳過：Step 3 產 vCard / QR、Step 4 置入 QR、Step 9 上傳 vCard
  - 輸出檔案數：TW 版 6 個 → 中子版 4 個（少 `.vcf` 與 `QR Code.svg`）

### Changed
- **SKILL.md frontmatter description** 更新涵蓋中子 BVI 版觸發判斷與初期測試規則
- **SKILL.md Step 1**：`init` 範例補上 `--template-type` 參數說明
- **SKILL.md Step 3 / 4 / 9**：標註中子版自動跳過
- **SKILL.md 最終產出表**：拆成 TW 版（6 檔）/ 中子版（4 檔）兩張對照表
- **docs/SOP.md**：完整流程章節新增「中子 BVI 版分支」簡化流程圖；P2 章節標完成

### 設計動機
- 依使用者明確指示：中子版**不產 vCard、不放 QR Code**（決定簡化方案），電話 prefix 同 `+886-2-2741-7065`（公司資訊不用分版設定檔）
- 模板沒有 PH_QRCODE 命名（範本本身沒 QR 區塊），所以中子分支邏輯比想像中乾淨——不用偵測 / 移除 QR placeholder
- 維持向後相容：`--template-type` 預設 `tw`，現有 SV 流程零改動
- 依 `feedback_new_card_type_testing`：中子版屬新款測試階段，**初期每步驟須先停下確認**（雖然 code 完成，但跑第一次中子簽呈時不可全自動），跑 ≥ 2 次成功後才討論加入白名單

### 回歸測試
- **TW 版 sidecar**：含 `template_type: "tw"` + `artifacts` 區塊（vCard 流程資料）→ 與 v0.9.0 行為一致 ✓
- **中子版 sidecar**：只有 `template_type: "zhongzi-bvi"` + `fields`，**無** `artifacts` 區塊 ✓
- **中子版 `artifacts` 子命令**：偵測 sidecar template_type 後印「📋 中子版跳過 artifacts」並 exit 0 ✓
- **`--template-type` 驗證**：傳無效值（如 `invalid`）報錯阻擋 ✓

### 待手動處理（不在 v0.10.0 範圍，未來實際跑第一張中子簽呈時須注意）
- 中子版**首次跑必須每步停下 GATE 確認**（不像 SV 版可一路衝）
- 中子版**「無手機版」模板**尚未建（依需求驅動原則，等實際無手機簽呈進來再加）
- 中子版**模板內 5 行固定文字**（北京/上海公司名與地址）目前仍 rasterized 在 .ai 檔，搬家時要手動編 Illustrator

## [0.9.0] — 2026-06-08

### Added
- **公司固定資訊抽離至設定檔（P1）**：新增 `scripts/company_config.py` 載入器與 `~/.config/sv-card/company.json` 預設檔
  - 涵蓋欄位：公司中文/英文名、統編、公司電話（office + vCard 兩種格式）、FAX、地址（街/區/市/郵遞/國）、vCard URL prefix、PRODID、website
  - 設計：fallback DEFAULTS + 深層字典合併。缺檔 / 缺欄位 / JSON 解析失敗都不中斷，自動補預設值（向後相容，現行使用者無感）
  - 環境變數覆寫路徑：`SV_COMPANY_CONFIG`（預設 `~/.config/sv-card/company.json`）
  - CLI debug：`python3 scripts/company_config.py` 印出生效設定值

### Changed
- **`make_vcard.py`、`make_card_artifacts.py`、`card_helper.sh`** 三處硬編碼公司值改為從 `company_config` 讀取
  - `make_vcard.py`：ORG / PRODID / TEL VOICE / TEL FAX / ADR / URL 6 個欄位 + `VCARD_URL_BASE` 常數
  - `make_card_artifacts.py`：QR Code 編碼的 vCard URL prefix
  - `card_helper.sh`：sidecar 寫入時的 `PH_PHONE_OFFICE` prefix（傳 `SV_CARD_SCRIPT_DIR` 讓 Python heredoc 找到 module）

### 設計動機
- 依 `feedback_sv_card_decisions` 原則 2（優化優先降出錯）：公司搬家 / 統編變更 / 電話 FAX 變更時，現行需散改 3 個檔案，容易漏改一處導致 vCard / 名片電話不一致。抽離至單一 JSON 後，改一處即可
- 為什麼選 JSON 而非 YAML：Python 3.9 無 `tomllib`、`pyyaml` 需新依賴（install.sh 要新增檢查）；現有 scripts 全用 stdlib `json`，零新依賴
- 為什麼保留 DEFAULTS fallback：現有使用者首次跑 v0.9.0 時 `~/.config/sv-card/company.json` 不存在，要保持零摩擦；DEFAULTS 即現行 hardcoded 值
- 為什麼不一併動模板 .ai：模板內的固定欄位是 rasterized text + 視覺排版，動態注入會破壞美術設計師的版面控制。模板維持手動編輯，但 README 已標註「同時改」

### 回歸測試
- vCard 輸出 byte-level diff = 空（baseline 用 `git show HEAD:scripts/make_vcard.py` 抽取舊版跑）
- sidecar `PH_PHONE_OFFICE`：含分機版 `+886-2-2741-7065#393`、無分機版 `+886-2-2741-7065`，兩者皆正確
- vCard URL prefix：`http://drive.streetvoice.com/vcard/{vcf_name}` 正確
- Config 編輯即時生效：改 `~/.config/sv-card/company.json` 後新 process 立刻讀到新值

### 待手動處理（不在 P1 範圍，未來新版迭代時須同步）
- 模板 `templates/20260522-王小明.ai` / `20260529-王小明_無手機版.ai` 仍含硬編公司中文名 / 地址 / 統編等文字
- 文件 `docs/SOP.md` Step 12「固定欄位」清單仍列字面值（已加註腳指向 company.json）

## [0.8.9] — 2026-06-08

### Changed
- **`extract_signoff_fields.py` 全面 regex 收緊**：將 8 條欄位 regex 中的 `\s` 改為 `[ \t]`，禁止跨行 match
  - 高風險修正（同 v0.8.7 Bug B 結構）：
    - 英文名 `名片上的英文名\s+(.+?)\s+名片上的職稱\s+(.+)` → `[ \t]+`：若英文名空白且 PDF 換行排版，`(.+?)` lazy + `\s+` 可能誤抓相鄰欄位
    - 郵件地址 `名片上的郵件地址\s+(\S+@\S+)` → `[ \t]+`：若 email 空白且頁面有其他 `@` 字串（如 footer），`\s+` 跨行可能誤抓
  - 一致性修正：表單號 / 申請人 / 名片上的姓名 / 室內分機 / 名片版型 / 所屬地區（6 條 `\s` → `[ \t]`，防未來）
  - DOTALL 兩條（其他需求 / 表單註釋）故意跨行多行內容，不動
- **修正 stale memory 參照**：將 `skill/SKILL.md` 與 `docs/SOP.md` 中對 `feedback_new_card_type_testing` 與 `feedback_sv_card_optimization_roi` 的參照，更新為合併後的 `feedback_sv_card_decisions`（原則 1 / 原則 2）
  - 起因：2026-06-08 全域 memory 重組（plan A）將兩份 feedback 合併為單一 `feedback_sv_card_decisions.md`，repo 內參照變成 dangling reference
  - 改動只動文字參照，不動行為邏輯

### 設計動機
- v0.8.7 修了手機欄位的「`\s*` 跨行誤抓」Bug B 後，SOP.md 列入 P1 todo：同類風險可能潛伏其他複合 regex
- 一次性掃過所有欄位 regex，把「不應跨行」的 `\s` 收緊為 `[ \t]`，全檔語意一致
- 兩條 DOTALL（其他需求 / 表單註釋）的跨行是預期行為（多行內容），保留
- **回歸測試**：對 #554（黃阿福 / Fu Huang）簽呈 PDF 跑 `extract-pdf` 比對前後輸出，diff 為空 — 改動無 regression

## [0.8.8] — 2026-06-08

### Added
- **`install.sh` 補 `pypdf` / `pdfplumber` 套件檢查**：照既有 `qrcode` 同 pattern（互動/非互動兩種模式），新機器首裝可一次裝齊三個 PDF 相關依賴

### 設計動機
- v0.8.5 加 `backup-pdf`、v0.8.6 加 `extract-pdf` 時引入 `pypdf` + `pdfplumber` 兩個新依賴，但 `install.sh` 一直只檢查 `qrcode`，新機器 fresh install 跑 Step 1.5 / PDF 萃取就會炸 ImportError
- v0.8.5 CHANGELOG 已自註此為 TODO，SOP.md「未來優化方向」也列為 P0「環境一致性」項目
- **為何不直接在 `card_helper.sh` 動態裝**：install 階段一次裝齊比執行階段炸了才裝體驗好，且符合既有 idempotent 設計

## [0.8.7] — 2026-06-04

### Fixed
- **`extract_signoff_fields.py` Bug A：全形 CJK 相容字符未回正**
  - v0.8.6 `normalize_placeholder()` 手列 5 字（⽚⼈⼿⼯⽂），漏掉 ⾯ ⾏ ⽯ 等大量同類字符
  - 實測 #498（林小芳）`title="平⾯設計"`、#554（黃阿福）`applicant_dept="執⾏董事辦公室"` / `surname_cn="⽯"` 都抓出怪字
  - 改用 `unicodedata.normalize("NFKC", text)` 統一處理 — Unicode 標準算法，涵蓋全部 CJK Compatibility Ideographs / Radicals 範圍
- **`extract_signoff_fields.py` Bug B：手機空白時 regex 抓到下一行**
  - 原 regex `名片上的個人手機號碼\s*(\S*)` 的 `\s*` 包含 `\n`，手機欄位空白時會跨行 match 下一行的「名片版型」字串
  - 實測 #498 抓出 `mobile="名片版型"`（應為 null）
  - 改為 `[ \t]*`（只允許空白/tab，禁止跨行）

### 設計動機
- 兩個 bug 都是 v0.8.6 開發時只用 #661 一個 PDF 測試，沒覆蓋到「全形字符 / 手機空白」變體
- 使用者測試時拿 #498 + #554 兩張新 PDF 跑 extract-pdf，**雙重檢核流程本身有效**（Claude 在 JSON 看到 `title="平⾯設計"` 跟 PDF 視覺「平面設計」不一致就 catch）— 但腳本可靠性還能更好
- **Bug A 的選擇**：手列字符表（局部、可解釋）vs NFKC（全面、Unicode 標準）。選 NFKC 因為今天遇到的字符不會是最後一批，全面解掉一勞永逸
- **Bug B 的選擇**：拆兩個 regex 各自抓分機/手機 line vs 修飾現有複合 regex。選後者改動最小，但風險是同類 cross-line 問題未來可能在其他欄位重現 — 列入未來注意項

## [0.8.6] — 2026-06-03

### Added
- **`scripts/extract_signoff_fields.py`**：簽呈 PDF 機械萃取 18 個欄位（表單號、申請人、中文姓名拆分、英文名 alias 偵測、職稱、Email、分機、手機、版型、地區、其他需求、表單註釋等），印 JSON 到 stdout
- **`card_helper.sh extract-pdf <pdf-path>` 子命令**：包裝上述 Python 腳本
- **SKILL.md / SOP.md「PDF 萃取規則」章節重寫**：從「Claude 自己照表抽」改為「Claude Read PDF + 腳本萃取 JSON」雙重檢核，比對不一致 / Claude 看出 typo / 特殊備註 → 停下與使用者確認

### 設計動機
- **背景**：當天製作 #661 名片時實測抓到 PDF 上英文名是 typo「Strong Wo」（應為 `Wu`），Claude 視覺判斷後停下確認 — 證明人類視覺校驗有不可取代的價值
- **為何雙重檢核而非純腳本**：
  - 腳本對 typo 無辨識能力（沒字典 + 中文姓名沒有權威字典可比對）
  - 腳本對「過去未碰過的特殊請求」只能字面抽取，無法判斷語意
  - PDF 格式變動時，沒有 Claude 視覺校驗就察覺不到欄位漏抓
- **為何雙重檢核而非純 Claude**：
  - 拆中文姓 / 名（複姓判斷）、拆英文 alias（字符類型判斷）容易出錯
  - 腳本一定回傳 18 欄 JSON，省了 Claude 逐個欄位思考的 token
- **權衡**：相比純 Claude 多 ~300 tokens（JSON output），但 typo 偵測機率顯著上升（雙重檢核交叉確認）— 對「製作頻率不高」的使用者來說，**降低出錯機率比省 token 更重要**

### Technical Notes
- **複姓表**：列入 18 個常見複姓（歐陽 / 上官 / 司徒 / 諸葛 / 慕容 / 皇甫 / 司馬 / 東方 / 夏侯 / 南宮 / 令狐 / 宇文 / 長孫 / 軒轅 / 鍾離 / 尉遲 / 鮮于 / 公孫）。罕見複姓會被拆錯字 → Claude 視覺校驗會 catch
- **alias 偵測**：英文名首 token 含 CJK 字符 → 是 alias。對「阿明 Ming Wang」OK；若有人寫「Ming 阿明 Wang」會抓錯（罕見）
- **「其他需求」regex 陷阱**：PDF 內第一個「其他需求」字串其實是 Legacy 提示文字（「請將色號填寫於下方的其他需求欄中」），用 greedy `.*` 吃光前文避開
- **PDF 全形字回正**：pdfplumber 抽出的 `⽚` `⼈` `⼿` 等全形字符回正為 `片 / 人 / 手`，方便 regex 比對

## [0.8.5] — 2026-06-03

### Added
- **`card_helper.sh backup-pdf <pdf-path> <dest-dir>` 子命令**：把使用者上傳的簽呈 PDF 備份到製作檔資料夾，重命名為 `簽呈編號-{表單號}.pdf`
- **`scripts/backup_signoff_pdf.py`**：核心邏輯 — pdfplumber 抓表單號 + 找「表單註釋」word top，pypdf 改 mediabox/cropbox 的 lower-left y 隱藏下半（含表單註釋 section + 簽核列表）
- **SKILL.md Step 1.5「備份簽呈 PDF」**：Claude 在 init 完成、拿到 `$DEST_DIR` 後立即呼叫 backup-pdf
- 最終產出表新增 `簽呈編號-{表單號}.pdf` 一列（變成 6 個檔）
- SOP.md Step 5.5 詳細描述（座標系換算、CropBox 而非真裁的設計理由、margin=1pt 實測過程）

### 設計動機
- 使用者要求名片製作完後保留簽呈 PDF 作為佐證/檔案紀錄，但簽核列表那塊資訊雜訊太多
- **裁切策略**：用 PDF 標準的 CropBox 隱藏視窗下半，原內容仍在檔案內（無損、實作極簡），但 PDF viewer 只顯示上半。這對名片簽呈這種無隱私需求的文件夠用
- **切點選擇**：以「表單註釋」word 為錨點（不用「簽核列表」是因為 PDF 頁首也有「簽核列表」文字會抓錯第一個出現）。margin=1pt 經使用者實測 5→12→15→3→2→1 拍板
- **依賴**：`pypdf` + `pdfplumber`（pip3 install --user，已驗證可用）。install.sh 尚未同步加入此依賴檢查（TODO）

### Changed
- SKILL.md `init` 內部推導說明同步 v0.8.4：`PH_PHONE_MOBILE` 改寫成「空格→dash、開頭 0→+886-」（之前還寫舊版的「mobile-display 空格→dash」）

## [0.8.4] — 2026-06-03

### Fixed
- **`card_helper.sh` init 內 Python 沒實作「名片用 +886 國碼格式」轉換**：SKILL.md / SOP.md 規格明文「名片用 `+886-XXX-XXX-XXX` 國碼格式；vCard 沿用簽呈原格式」，但 v0.8.3 之前 Python 邏輯只做 `mobile_vcard.replace(" ", "-")`，導致 `PH_PHONE_MOBILE` 仍是簽呈原樣 `0909-050-269`，名片畫面開頭沒 +886
  - 新增 `to_card_mobile()` helper：空格→dash + 開頭 `0` → `+886-`
  - 只動 `fields["PH_PHONE_MOBILE"]`（名片用）；`artifacts["mobile"]`（vCard 用）仍沿用簽呈原格式不變
  - 實測：`0909-050-269` → `+886-909-050-269`、`0900 000 000` → `+886-900-000-000`、已是 `+886-...` 不再加前綴

### 設計動機
- 本次 Strong Wu 名片實測時使用者發現名片畫面手機開頭沒 +886，回看 sidecar 確認 `PH_PHONE_MOBILE` 寫的就是 `0909-050-269`（未轉），追到 line 213-214 Python 邏輯缺漏
- SKILL.md 的「規格描述」與 card_helper.sh 的「實作」長期不同步 — 之前的名片可能也都是 0 開頭沒人發現（vcf 對外格式 OK，名片視覺差異小但仍違規格）

## [0.8.3] — 2026-05-29

### Added
- **`card_helper.sh verify-vcard <vcf-path>` 子命令**：抓 server 上同名 vcf 內容 cmp 二進位對比本地檔。印 `match` / `mismatch` / `missing`
  - 抓檔用 `curl ... -o /tmp/sv_verify_${vcf_basename}`，比對完即 rm
  - 處理「server 上找不到該檔」（curl 失敗）→ `missing`
  - 處理「兩邊內容不同」（cmp 失敗）→ `mismatch`
  - 完整一致 → `match`
- **SKILL.md Step 9d「驗證手動上傳結果」**：9c STOR 兩次都失敗時，Claude 轉達「手動上傳 vcard 至 transmit 覆蓋舊檔」+ 等使用者完成後跑 9d 驗證
  - `match` → 「✅ vCard 已驗證 server 端與本地一致」
  - `mismatch` / `missing` → 「❌ 上傳失敗，請洽產品工程部協助確認」

### Changed
- **9c STOR 兩次都失敗訊息簡化**：移除原本「可能原因 + 建議解法 a/b」分兩種 case 印的邏輯，改為一條「請手動用 Transmit 上傳並覆蓋舊檔」+ 本地路徑。「可能原因」改由 Claude 評估當下情況補充
- SKILL.md / SOP.md Step 9 / 13 同步加入 9d 驗證流程描述

### 設計動機
- **預防性安全網**：FTP STOR 回 `226 Transfer complete` 只代表「傳輸完成」，**不代表「server 端最終內容 = 你上傳的內容」**。可能情境：他人同時用 Transmit 上傳同名檔覆蓋你、server 端有 sync process 把 vcf revert 回原版等
- `9c ✅ 已上傳` 訊息對這類情境會 false positive；唯有 9d cmp 二進位比對才能確認 server 端真的是 sv-card 上傳的內容
- **後記**：實測 #554 FuHuang.vcf 跑 verify 印 mismatch（server 30 KB Apple 通訊錄版 vs 本地 476 bytes sv-card 版）— 但事後確認那是使用者另外用 Transmit 手動覆蓋，**不是真實 race condition**。該 case 仍有效證明 verify-vcard 邏輯運作正確；多人協作的真實 race 仍是 9d 預防的目標情境

## [0.8.2] — 2026-05-29

### Added
- **`upload-vcard --check-only` flag**：只做「拿密碼 + preflight + 查 server」，不上傳。最後一行印 `exists` 或 `new` 並 exit 0，供 SKILL.md Step 9a 預檢
- **Step 9 拆三步**：9a 預查 → 9b GATE（僅 `exists` 觸發）→ 9c 上傳
  - 9b GATE 規則：Claude 用「**`<vcf 檔名>` 偵測到相同檔案，請問是否覆蓋？**」問使用者；OK 才進 9c
  - 使用者回否定 → 跳過 Step 9（vcf 仍在本地，未來可手動跑上傳）
  - 防止不知不覺覆寫掉 server 上 owner 是別人的舊 vcf（直接覆蓋可能是預期行為，但 v0.8.2 之後要明確同意）

### Changed
- SKILL.md Step 9 重寫為三步流程，「可能印出的結果訊息」同步 v0.8.1（移除誤判的「檔案未開放編輯權限」分類，改為「STOR 兩次都失敗」+ Transmit fallback）
- SOP.md Step 13 同步加 9a/9b/9c 三步描述
- `card_helper.sh` 頂部 usage 註解 + 底部 Usage echo 加 `[--check-only]` flag 說明

## [0.8.1] — 2026-05-29

### Fixed
- **`upload-vcard` 對 transient 550 的誤判**：v0.7.x「該檔案未開放編輯權限」訊息會在 ProFTPD 偶發 transient 550 時誤導使用者洽產品工程部開權限，但實測使用者帳號**有 STOR 覆寫權限**（Transmit GUI Replace 證實，curl 後續 retry 也直接成功）
  - 改為 **STOR + retry 一次** 策略：第一次 STOR 失敗 sleep 1 秒再試，幾乎都會 work（實測 #554 FuHuang.vcf 場景 — owner 對該檔 owner 是別人但仍能 STOR 覆寫）
  - 失敗 fallback 訊息加 Transmit 手動上傳指引（含 vcf 本地路徑），避免使用者卡死
  - **不採 DELE-then-STOR**：實測使用者對「owner 非自己」的檔有 STOR 權限但沒 DELE 權限，DELE 路徑根本走不通

## [0.8.0] — 2026-05-29

子品牌泛化第一步：SV 名片內部分支優化（無手機版、無分機、姓名以 PDF 欄位為主、未碰過備註停下問）。

### Added
- **無手機版分支**（核心）：簽呈沒填手機時自動走獨立流程
  - `templates/20260529-王小明_無手機版.ai`：新模板，無 PH_PHONE_MOBILE TextFrame（共 6 個 PH_ 欄位 + PH_QRCODE）
  - 模板原有 QR 圖形已命名為 `PH_QRCODE`（idx=7, pos=316,-398, size=40x40），讓 place_qr.jsx 能識別 placeholder
  - `SV_TEMPLATE_NO_MOBILE` 環境變數預設指向此模板，可由 `~/.config/sv-card/env` 覆寫
  - `card_helper.sh init --mobile ""` 自動選此模板
- **無分機支援**：`card_helper.sh init --office-ext ""` → PH_PHONE_OFFICE 顯示 `+886-2-2741-7065`（不含 `#`）
- `tests/fixtures/sidecar_valid_no_mobile.json`：無手機 + 無分機的 valid 樣本（4 個 fixture 全部通過 schema）
- `.gitignore` 加 `~ai-*.tmp`：避免 Illustrator 暫存檔誤入 commit
- `tests/smoke.sh`：本地或 CI 都可跑的煙霧測試。4 個 phase：bash -n（必跑）、shellcheck（可選）、python py_compile（必跑）、sidecar JSON schema 驗證（可選）。「可選」項本地未裝套件不會擋你跑，CI 上會自動裝
- `tests/sidecar_schema.json`：sidecar `/tmp/sv_card_fields.json` 結構規範（JSON Schema draft-07）
- `tests/validate_sidecar.py`：跑 schema validation 對 fixtures。負面樣本（檔名含 `_invalid_`）會被預期應該失敗
- `tests/fixtures/sidecar_valid.json`、`sidecar_invalid_missing_field.json`、`sidecar_invalid_bad_phone.json`
- `tests/README.md`：測試範圍、跑法、擴充指南
- `.github/workflows/ci.yml`：GitHub Actions 在 push 到 main / PR 時自動跑 smoke.sh（Ubuntu runner，自動裝 shellcheck + jsonschema）

### Changed
- `card_helper.sh init`：`--mobile` 和 `--office-ext` 從必填改為選填。Usage / header comment 同步更新
- `make_vcard.py`：`data.get("mobile") or ""` 取代 `data["mobile"]`；空字串時跳過整行 `TEL;type=CELL;type=VOICE:`
- `make_card_artifacts.py`：sidecar mode 用 `a.get("mobile", "")` 而非 `a["mobile"]`，避免 KeyError；命名參數模式把 `--mobile` 移出 required
- `tests/sidecar_schema.json`：`fields.PH_PHONE_MOBILE` 和 `artifacts.mobile` 從 required 改為 optional（兩者仍保留型別/pattern 規範）
- **SKILL.md PDF 萃取規則表大幅重寫**：
  - 加「以 PDF『名片上的姓名』欄位為主」規則（即使 ≠ 申請人，常見於外部夥伴情境）
  - 「室內分機」+「手機」改為「有 / 空白」兩態，明示對應 init 參數與下游行為
  - 加「其他需求 / 備註欄」處理規則（未碰過特殊請求 → 萃取階段停下問）
- SKILL.md「非常規簽呈 → 停下問」：移除「室內分機空白」（已自動處理），保留「特殊備註 / 外部 email / 非 TW 街聲版」
- SKILL.md Step 1 init 範例加說明：`--mobile ""` 和 `--office-ext ""` 的下游影響
- SKILL.md「涉及檔案」表加無手機版模板路徑
- SOP.md「資料轉換規則」加「無分機」+「無手機」兩列；新增「分支處理（v0.8.0+）」段詳列 4 種簽呈情境 + init 參數 + 結果
- `.github/workflows/ci.yml` 加 `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true`：預先 opt-in Node.js 24。GitHub 公告 2026-06-02 起會強制把 actions/checkout@v4、actions/setup-python@v5 升到 Node 24
- SKILL.md description 精簡 50%（393 → 193 字元）：移除執行細節，只保留 trigger 判斷需要的資訊
- SKILL.md Step 9 同步 v0.7.2 內部流程：列出 preflight 登入檢查流程、4 種可能結果訊息

## [0.7.2] — 2026-05-28

### Added
- **`upload-vcard` 加入 preflight 登入檢查**：在實際 STOR 之前先用 `curl --list-only` 對 `${remote_dir}/` 做 noop 連線測試，把「登入失敗」與「上傳失敗」徹底切開：
  - preflight 失敗 → 訊息：登入失敗 → 自動刪 Keychain 密碼 → 跳 dialog 重輸 → 再 preflight 一次
  - 第二次仍失敗 → 訊息：「可能密碼錯誤、帳號未開通寫權限、或網路問題，請洽產品工程部」
  - 通過 → 印 `✅ 登入 ${host} 成功` → 才進入正式上傳
- 首次使用者與已有 Keychain 密碼的使用者走同一條 preflight 路徑，UX 一致

### Changed
- `upload-vcard` 上傳階段的失敗訊息簡化：因為登入已 preflight 通過，STOR 失敗就**純粹**是檔案層級權限問題，不再需要「可能是密碼錯」的分支誤導
  - `existed_before=1`：「該檔案未開放編輯權限」
  - `existed_before=0`：「新檔上傳失敗，登入已驗證 OK 故非密碼問題，請洽產品工程部確認目錄寫權限」

### Fixed
- `upload-vcard` 的 FTP 550 失敗訊息**移除錯誤的 owner 假設**。v0.7.1 把「existed_before=1 + 上傳失敗」直接斷言成「owner 非當前帳號」，但實測證明這個假設錯了 — server 上的 vcard 可由非 owner 編輯（只要該檔有被開放編輯權限），決定權在「檔案是否被開放編輯」而非 owner

### Rationale
- 把 script 的「設計時假設」當「事實」寫進錯誤訊息會誤導使用者方向（白跑去問 owner 權限，但真因是檔案 ACL）。修正後框架對齊真實的 FTP 權限模型 — 是檔案層級的編輯權限，不是 owner 身份
- preflight 切開「登入」與「上傳」兩個失敗類別，新人交接情境最痛的「混在 STOR 失敗裡的密碼錯誤」終結 — 不會再卡在「刪密碼→重輸→再失敗→懷疑人生」迴圈

## [0.7.1] — 2026-05-28

### Changed
- `upload-vcard` 對「server 已有同名檔但 owner 非當前 user」的 FTP 550 失敗印明確訊息：
  ```
  ❌ 目前您的 Server 權限無法覆蓋原檔，請洽資訊部同仁。
     → 對應檔案：XxxYyy.vcf（server 上已存在但 owner 非當前帳號 {user}）
  ```
  原本的籠統 `curl exit 25` 訊息只在「`existed_before=0`（純密碼錯/網路問題）」時保留
- SKILL.md「執行流程」段開頭加 dock 跳動提示：Step 2 / 4 / 7 跑 `$.evalFile(.../jsx)` mcp call 後，Claude 須在訊息內提示使用者「請點一下 Illustrator 以便繼續」

### Rationale
- FTP 550 在「製作者非 vcf owner」這個 use case 很常見（專人替別人重做名片）— 明確訊息直接指向解決路徑（洽資訊部開權限），避免使用者誤以為是密碼錯
- BridgeTalk.bringToFront 不強制搶焦點是刻意設計（不打斷使用者手邊的事），但 macOS 對背景 GUI app 的 throttle 仍存在 — 需使用者點 dock 才解除。文字提示讓使用者知道為什麼卡住

## [0.7.0] — 2026-05-28

### Added
- **`card_helper.sh upload-vcard <vcf-path>` 子命令**：自動把 vCard 上傳到 `drive.streetvoice.com/vcard/`，完成「名片→vCard→QR→上傳」全鏈閉環。
  - host / user 從 Transmit favorite「Streetvoice」（可由 `SV_TRANSMIT_FAVORITE` env 覆寫）動態 query，跨同事通用不寫死
  - 密碼存 macOS Keychain（label：`sv-card upload (Streetvoice)`），首次跑透過 osascript dialog 跟使用者要密碼後存入，之後永久靜默重用
  - 用 `curl --list-only` 先查 server 是否已有同名檔，據此印兩種訊息擇一：
    - `✅ vCard 已上傳 server`（新檔）
    - `✅ vCard 已上傳 server 並覆蓋舊檔`（FTP STOR 自動 overwrite）
  - 上傳完印公開 URL `http://drive.streetvoice.com/vcard/{vcf}`
- **SKILL.md Step 9 + SOP.md Step 13**：把 upload-vcard 加進流程；流程圖第 ⑫ 步補上「上傳 vCard」

### Changed
- SKILL.md「最終產出」表格的 vcf 描述從「請使用者事後上傳」改為「Step 9 已自動上傳」
- SOP.md 收尾說明從「掃 QR 會 404，需事後上傳」改為「Step 13 自動上傳，QR 可直接掃」

### Rationale
- vCard 上傳是流程內最後一個「使用者手動環節」（在 Transmit 拖檔），自動化後整套名片製作從 PDF → 5 個交付檔 → server 全閉環
- 密碼處理方式（macOS Keychain + 首次 prompt）滿足「不寫進 repo + 跨同事通用」雙條件：repo 內零密碼，每個同事第一次跑時自己輸入存進各自的 Keychain
- 不走 Transmit AppleScript 路線：Transmit 5.9.1 字典中 `connect to favorite` 在 `tell document` scope 反覆失敗（試 6+ 個 syntax 變體），改用「Transmit favorite 動態查 + curl FTP」更直接可靠

### Testing
- 對 ~/Documents/SV-名片/MingWang.vcf 連跑兩次：
  1. 第一次：osascript 跳 dialog 拿密碼 → 存 Keychain → 上傳成功
  2. 第二次：Keychain 靜默取密碼 → 上傳並覆蓋舊檔，訊息分流正確
- 順便修 `$kc_label）` 全形括號吃 byte 顯示亂碼（同 v0.3.0 修過的 `${VAR}` 顯式語法 bug 復發）

## [0.6.0] — 2026-05-27

### Added
- **Sidecar JSON 機制** `/tmp/sv_card_fields.json`：`card_helper.sh init` 寫入，含 `fields`（7 個 PH_*）+ `artifacts`（vCard/QR 欄位）兩區塊，後續 Step 2/3 自動讀取
- `make_card_artifacts.py --from <json>` 模式：從 sidecar 的 `artifacts` 區塊讀，取代命名參數
- `replace_fields.jsx` 讀 sidecar：預設讀 `/tmp/sv_card_fields.json` 的 `fields` 區塊
- `SV_SIDECAR` 環境變數：可覆寫預設 sidecar 路徑
- **`BridgeTalk.bringToFront(BridgeTalk.appName)` 加入 3 個 jsx 開頭**（place_qr / finalize / replace_fields）：解決 macOS 對背景 GUI app 限速問題（app.open / executeMenuCommand / saveAs 大檔特別明顯）。效果：Illustrator dock icon 跳動提示使用者，禮貌 attention 不強制搶焦點

### Changed
- **`card_helper.sh init` 介面破壞性變更**：從位置參數 `init "中文" "英文"` 改為 named-args `init --chinese ... --english ... --surname ... --given ... --title ... --email ... --mobile ... --office-ext ...`。init 內部推導 mobile-display（空格→dash）、vcf-name（英文名去空格）、PH_PHONE_OFFICE（+886-2-2741-7065#分機）
- **SKILL.md Step 2 mcp call 變固定字串**：原本 inline `$.global.FIELDS = {...}` JSON literal 不再需要，Claude 直接 `$.evalFile(replace_fields.jsx)`
- **SKILL.md Step 3 bash 變固定字串**：原本 7 個 `--xxx` 命名參數不再需要，Claude 直接 `card_helper.sh artifacts`
- `make_card_artifacts.py` 命名參數全部改 optional（搭配 sidecar 模式），缺欄位時統一回報

### Fixed
- **`replace_fields.jsx` 來源優先級**：原本邏輯 `if (!$.global.FIELDS) read sidecar` 在 Illustrator session 內會踩雷 — `$.global` 跨 mcp call 持續存在，導致前次測試殘留的 FIELDS 永遠優先於 sidecar，連續做兩張不同名片時會用第一張的資料替換第二張。
  - 修為 **sidecar 優先**：sidecar 存在就用 sidecar（當前流程權威來源），`$.global.FIELDS` 降級為 emergency override
  - 執行完順手 `$.global.FIELDS = null` 清掉殘留，避免下次 sidecar 缺席時誤用

### Rationale
Step 2 與 Step 3 的資料 80% 重疊（5 個共用欄位 + 2 個格式差異）。原本 Claude 要在兩個 step 各自輸入一次，容易抄錯（特別是中文職稱、手機格式）。改成 init 階段一次填寫、後續從 sidecar 讀取後：

- Claude 全流程「需要填資料」的 step 數：3 個 → 1 個（僅 init）
- Step 2 mcp call 內容長度：~250 char → ~120 char
- Step 3 bash 命令長度：~250 char → ~60 char
- 杜絕「Step 2 填 A、Step 3 填 B」的資料漂移風險

### Testing
- 連跑兩張不同名片（同事 A → 同事 B）實測通過：
  1. 第一張完整流程跑通，5 個交付檔正確
  2. 第二張：sidecar 優先機制驗證有效（替換後內容是新名片而非殘留）
  3. BridgeTalk 在 finalize.jsx 觸發 dock 跳動，不強制搶焦點

## [0.5.0] — 2026-05-27

### Added
- `scripts/finalize.jsx`：GATE 後合併收尾（清殘留 + saveAs original + createOutline + saveAs OL CS6），一次跑完取代原本 2 個 mcp__illustrator__run 呼叫
- `scripts/replace_fields.jsx`：Step 2 欄位替換封裝，吃 `$.global.FIELDS` JSON 替換 7 個 PH_* 欄位 + 自動 save；找不到欄位累積到 missing 一次回報（不中斷）
- `card_helper.sh finalize <dest> <basename>` 子命令：等同 save-original 後接 save-ol，配合 finalize.jsx 把 GATE 後 4 個 tool call 縮為 2 個

### Changed
- **SKILL.md GATE 後流程從 4 步驟（Step 7-10）簡化為 2 步驟（Step 7-8）**：mcp 呼叫 finalize.jsx → bash 呼叫 finalize 子命令
- **SKILL.md Step 2 從 inline ExtendScript 改為 `$.global.FIELDS = {...}; $.evalFile(replace_fields.jsx)`**：避免 JS 字串轉義、模板欄位增減不用改 SKILL.md
- SOP.md 同步更新 Step 6+7 與 Step 12 的合併說明

### Rationale
延續 v0.4.x 設計哲學「減少 inline code、減少 tool call、走既有 allow 規則」：
- 收尾 mcp call 數：4 → 2
- Step 2 inline JS 字串長度：~400 char → ~250 char（JSON literal 比手寫 find() 函式短）
- Claude 寫名片時不再需要手寫 ExtendScript 字串（出錯機率降低）

## [0.4.5] — 2026-05-27

### Changed
- `card_helper.sh save-ol` 跑完自動 `ls -la` 列出 5 個交付檔（整合進子命令，避免 SKILL.md Step 10 出現 `&& ls -la` multi-statement command）
- SKILL.md Step 10 簡化為單一 `save-ol` 呼叫

### Documentation
- README「給 Claude」section 加強重啟提醒：`~/.claude/settings.json` allow 清單也是 session 啟動時讀一次，重啟才會生效（不重啟，安裝完當下做名片每個 Bash 還是會 prompt）

## [0.4.4] — 2026-05-27

### Added
- `card_helper.sh artifacts <args...>` 子命令：forward 所有 args 給 `make_card_artifacts.py`

### Changed
- SKILL.md Step 3 從直呼 `python3 ~/.claude/.../make_card_artifacts.py` 改為 `card_helper.sh artifacts ...`

### Fixed
- 同事在 Step 3 仍被 permission prompt：Claude Code 對 `python3` 這種 interpreter 命令的 allow rule 比對較侷限，`Bash(python3 <full-path>:*)` 規則不容易精確 match。改走 `card_helper.sh artifacts` 後，沿用既有 `Bash(~/.claude/skills/sv-card/scripts/card_helper.sh:*)` allow 規則，整套流程不再被任何 Bash prompt 中斷

## [0.4.3] — 2026-05-27

### Fixed
- install.sh 寫入的 allow 規則用絕對路徑（`/Users/X/.claude/...`），但 Claude Code 實際看到的 Bash 命令字串是 `~/.claude/...`，字面比對不 match，導致使用者裝完仍會被每個 sv-card Bash 命令 prompt
- 改用 `~` 形式（字面字串）寫入 allow 規則，與 SKILL.md 內的命令字串一致

## [0.4.2] — 2026-05-27

### Fixed
- `card_helper.sh confirm-firstrun`：`~` 展開錯誤，導致路徑被寫成 `/Users/X/~/Documents/...`（多了字面 `~`）
  - 原因：bash 對 `${var#pattern}` 的 pattern 內 `~` 會做 tilde expansion，故 `${out#~/}` 實際變成 `${out#$HOME/}`，當 `out=~/...` 時 pattern 不 match，原樣返回，再被 `$HOME` 前綴串接
  - 修法：改用 substring 取代 `${out:1}`（移除前綴 `~`），避開 pattern tilde expansion 陷阱

## [0.4.1] — 2026-05-27

### Added
- `card_helper.sh check-firstrun` 子命令：印 `run-step0` 或 `skip-step0`
- `card_helper.sh confirm-firstrun <path>` 子命令：mkdir + open Finder + 寫 env 為 `SV_OUTPUT_CONFIRMED=1`；支援 `~` 展開（不用 eval，避免注入）

### Changed
- SKILL.md Step 0 內裸 bash（`. env && echo`、`mkdir + open + cat > env`）全改為呼叫 card_helper.sh 子命令；裸 bash 無法精確 allow，封裝後可走既有 `Bash(card_helper.sh:*)` allow 規則，整套流程不再被 permission prompt 中斷

## [0.4.0] — 2026-05-27

### Added
- **Step 0「首次確認存放路徑」** 加入 SKILL.md：第一次製作名片時，Claude 主動詢問「名片存放路徑、以後是否都同路徑」，自動 mkdir + open Finder 引導，寫入 env
- **`SV_OUTPUT_CONFIRMED` marker** 在 `~/.config/sv-card/env`：`=0` 代表首次製作會引導確認、`=1` 代表已確認跳過
- **install.sh 寫入 `~/.claude/settings.json` allow 清單**：自動加 sv-card 相關 Bash + `mcp__illustrator__run` 規則，日常做名片時不會被 permission prompt 中斷（先 backup `.bak`，idempotent 去重）
- **setup-mcp.sh 加授權驗證點**：寫入 `~/.claude.json` 前明確印「🔐 授權驗證點」訊息列舉動作與備份策略；互動模式 prompt 確認，`--yes` 直接寫
- README「給 Claude」section 加 **🔐 授權驗證 ⏸ step**：跑 install.sh 前 Claude 必須先跟使用者徵詢授權，列出將修改的 4 個位置

### Changed
- `install.sh` `NON_INTERACTIVE` 模式下不再把 `SV_OUTPUT_CONFIRMED` 設為 `1`，改為 `0` 讓首次製作時走確認流程；互動模式才會設 `1`

## [0.3.0] — 2026-05-27

### Added
- `scripts/setup-mcp.sh`：自動安裝 `illustrator-mcp-server`（clone → 套 patch → 寫入 `~/.claude.json` 的 `mcpServers.illustrator`），全程 idempotent
- `scripts/mcp-patches/illustrator-mcp-server.patch`：對上游 `spencerhhubert/illustrator-mcp-server` 的修改（去掉 Claude activate、加 600s timeout）
- README 加「給協助安裝的 Claude」section，明確列 Claude 拿到連結後該執行的步驟、判斷邏輯、常見錯誤修法
- `CHANGELOG.md`（本檔）

### Changed
- `install.sh` 整合 setup-mcp.sh：偵測不到 MCP server 或 `~/.claude.json` 內無 `mcpServers.illustrator` 時，自動觸發安裝
- README 主要受眾從「工程師同事」改為「同事的 Claude」，搭配「給人類使用者」section 給不懂程式的同事看
- 系統需求新增 `uv`（Python 套件管理器，MCP server 啟動用）

### Fixed
- Bash 在 `$VAR` 後緊接 UTF-8 multibyte 字元（如全形括號 `）`）時，會把後續 byte 誤吞為變數名延伸，導致顯示亂碼。改用 `${VAR}` 顯式語法修正（install.sh / setup-mcp.sh 內 4 處）

## [0.2.0] — 2026-05-27

### Added
- `install.sh`：跨機器可移植化安裝腳本，建 symlink、檢查依賴、寫使用者偏好
- `~/.config/sv-card/env`：使用者偏好設定（card_helper.sh 啟動時 source）

### Changed
- 所有腳本/文件內 `/Users/owner/...` 硬編碼路徑改為 `~/.claude/skills/sv-card/` 前綴
- `card_helper.sh` 環境變數化：`SV_TEMPLATE` / `SV_OUTPUT_BASE` / `SV_CARD_SKILL_DIR`，皆有預設 fallback
- `make_vcard.py` 移除無效 placeholder 路徑，改用 `SV_VCARD_TEMPLATE` 環境變數
- ExtendScript 路徑改用 `Folder("~").fsName` 寫法（跨機器通用）
- README 重寫：加系統需求、快速安裝、設定覆寫段落
- `.gitignore` 加 `__pycache__/`、`*.pyc`、`.env*`

### Removed
- `scripts/make_qrcode.py`（與 `make_qr.py` 重複的舊版）

## [0.1.0] — 2026-05-27

### Added
- 初版發佈：SV 名片自動化製作 skill 整合
- 三件套腳本：`card_helper.sh`、`make_card_artifacts.py`、`place_qr.jsx`
- Illustrator 模板（假名範例 `20260522-王小明.ai`）
- SOP 完整文件 + skill 入口

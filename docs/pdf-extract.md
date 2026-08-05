# PDF 萃取細節：欄位對照表 + Claude 必看項

> 本檔內容自 SKILL.md「📋 PDF 萃取規則」搬出（逐字保留）。雙重檢核主流程見 SKILL.md；本檔是欄位層級的完整對照與停下判斷清單。

## 腳本 JSON 欄位（`scripts/extract_signoff_fields.py`）

| JSON key | 用途 / 對 init 參數的對應 |
|---|---|
| `form_no` | 表單號（→ Step 1.5 簽呈備份檔名）|
| `surname_cn` / `given_cn` | 中文姓名拆分（→ `--surname` / `--given`，含 18 個常見複姓判斷）|
| `card_name_cn` | 中文全名去員編（→ `--chinese`）：姓名欄後的「(數字)」一律去掉、絕不進 PH_NAME（全/半形括號＋數字都吃，例「王小明(454)」→「王小明」）|
| `english_name_no_alias` | 英文名去 alias（→ `--english`，alias 偵測：首 token 含中文字 = alias）。**注意**：`--english` 值原樣進名片 PH_NAME_EN（可中英混填），但 `.vcf` 檔名 + 上傳 URL + QR **只取 ASCII 英文**（見下方必看項）|
| `english_alias` | 中文 alias（如「阿明 Ming Wang」→ `阿明`）|
| `title` | 職稱（→ `--title`）|
| `email` | Email（→ `--email`）|
| `office_ext` | 分機（→ `--office-ext`，null = 簽呈空白，傳 `""`）|
| `mobile` | 簽呈原格式手機（→ `--mobile`，null = 簽呈空白，傳 `""`）|
| `template_type` | 版型（「TW 街聲」→ `--template-type tw`；「中子BVI」→ `--template-type zhongzi-bvi`；「台灣中子」→ `--template-type zhongzi-taiwan`；「經典復刻款BVI」→ 不進 card_helper.sh，停下改走 [`SOP.md`](SOP.md) 手動流程；其餘版型停下問）|
| `other_requests` | 「其他需求」欄位純文字（通常空白；有特殊備註才停下確認）|
| `form_remark` + `form_remark_is_placeholder` | 「表單註釋」欄位文字 — **內容可完全忽略**，不作為停下判斷（腳本仍抽出但不採用）|

## Claude 必看項（腳本抓不到的判斷）

> **v0.22.0+：非常規欄位已機械化偵測。** `extract-pdf` 會在 JSON output 加旗標並對 stderr 印 ⚠️，**看到 ⚠️ 一律照指示處理、別略過**。
> v0.22.0 三旗標：`english_name_has_cjk`（英文名中英混填 → 🛑 印英/中/兩者，停下問）、`card_name_had_employee_id`（姓名帶員編已**自動去除**＝自動修正型、僅 ℹ️ 告知**不停下**）、`mobile_nonstandard`（手機非標準 → init 自動 3-3-3、請核對）。
> v0.23.0 再加 5 旗標（皆「自動偵測」型 → 停下問，不自動決定）：`title_has_mixed_lang`（職稱括號含英文 → 🛑 印中/英）、`email_nonwhitelist`（非 @streetvoice.com/@neuin.com → 🛑 確認網域）、`template_unsupported`（版型非**四**支援版 → 🛑 不自行製作；v0.23.2 修正白名單漏「經典復刻款BVI」）、`card_name_differs_from_applicant`（名片姓名≠申請人 → 🛑 確認是否預期）、`other_requests_nonempty`（備註欄非空 → 讀內容判斷是否特殊請求）。

- **機械萃取全 null（關鍵欄位全抓不到）**→ 中子系列 PDF 中文 layer 圖片化（CID 編碼）常見，`extract-pdf` 會印 `⚠️` 警告。此時**以 Claude 視覺萃取（Read PDF）為準、逐欄與使用者人工確認**（失去機械雙重檢核），不可照單全收直接跑。
- **中英文 typo**：腳本照字面抓（如 `Ming Wan` 會原樣輸出），Claude 看 PDF 視覺判斷是否為 typo → 停下問
- **「其他需求」欄位通常為空白**；若有「請協助送印」「TW」以外的特殊備註 → 停下問
- **「表單註釋」欄位內容可完全忽略** —— 不論 placeholder 與否，皆不作為停下判斷
- **`template_type == "中子BVI"`**→ 走中子分支（傳 `--template-type zhongzi-bvi --company bvi|wenhua`），跳過 Step 3 artifacts、Step 4 place QR、Step 9 upload vCard；**已通過測試納入自動化白名單**：流程同 TW 全自動，僅 Step 6 GATE 需確認。**`--company` 依簽呈「公司」欄位推導：「中子創新（BVI）」→ `bvi`；「中子文化股份有限公司」→ `wenhua`**。輸出路徑分流（預設）：bvi → `~/Documents/名片/中子`；wenhua → `~/Documents/名片/中子文化`（可用 `SV_OUTPUT_BASE_ZHONGZI` / `SV_OUTPUT_BASE_ZHONGZI_WENHUA` 在 `~/.config/sv-card/env` 覆寫）
- **`template_type == "台灣中子"`**→ 走台灣中子分支（傳 `--template-type zhongzi-taiwan`，**不需 `--company`**），跳過 Step 3 artifacts、Step 4 place QR、Step 9 upload vCard；**已通過 2 次測試納入自動化白名單**：流程同 TW 全自動，**僅 Step 6 GATE 需確認**，不再每步停下。台灣中子是中子創新旗下台灣子公司，**單一公司、公司名「台灣中子創新股份有限公司」靜態寫死於模板**（無 PH_COMPANY，毋須推導）；員工 email 同為 `@neuin.com`。輸出路徑：`~/Documents/名片/台灣中子`（可用 `SV_OUTPUT_BASE_ZHONGZI_TAIWAN` 在 `~/.config/sv-card/env` 覆寫）
- **`template_type` 為「經典復刻款BVI」**→ 合法支援版型，但停下改走 [`SOP.md`](SOP.md)「經典復刻款 BVI 版分支」手動流程，不進 `card_helper.sh init`
- **`template_type` 非「TW 街聲」、「中子BVI」、「台灣中子」、「經典復刻款BVI」**（CN / EN）→ 停下問（未支援）
- **「名片上的姓名」與「申請人」不同**（外部夥伴情境）→ 雖然腳本仍能抽，但要跟使用者確認此為預期
- **職稱中英文混填**（如「事業發展總監（英文: Business Development Director）」）→ **停下問使用者用中文還是英文**，再決定 `--title` 傳哪個值
- **英文名中英混填**（如「Ming Wang 小明」）：名片顯示 PH_NAME_EN 用哪個仍要停下問（使用者可能要「只印英文」或「中英都印」）；但 `.vcf` 檔名 / 上傳 URL / QR **自動只取 ASCII 英文**（→ `MingWang.vcf`），中文絕不進檔名，毋須手動改名。若英文名完全無 ASCII（純中文）→ 屬非常規、停下問。
- **手機格式自動 3-3-3**：標準台灣手機（10 碼 09XXXXXXXX，不論簽呈填法有無空格/dash）名片一律輸出 `+886-9XX-XXX-XXX`（例 `0909050269` → `+886-909-050-269`）；非標準號碼沿用舊格式。此為 `to_card_mobile` 自動處理，無需人工。
- **Email 網域白名單**：`@streetvoice.com`（TW 員工）、`@neuin.com`（中子員工）皆視為正常；其他網域 → 停下問

> 中子分支的 init 參數與輸出細節另見 [`branch-neutron.md`](branch-neutron.md)。

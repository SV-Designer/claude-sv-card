# 中子分支細節（中子 BVI / 台灣中子）

> 本檔內容自 SKILL.md 搬出（逐字保留）：Step 1 init 的 `--template-type` / `--company` 詳解、中子版最終產出。簽呈判讀面的中子規則（company 推導、email 網域、機械萃取全 null 的處理）見 [`pdf-extract.md`](pdf-extract.md)。

## Step 1 init 參數詳解

> **`--template-type` 為選填**（預設 `tw`）：
> - `tw`（預設）→ SV 全流程，含 vCard / QR / 上傳
> - `zhongzi-bvi` → 中子 BVI 版（簽呈版型「中子BVI」），用 `SV_TEMPLATE_ZHONGZI` 模板；sidecar 不寫 artifacts 區塊，Step 3 / 4 / 9 自動跳過
> - `zhongzi-taiwan` → 台灣中子版（簽呈版型「台灣中子」），用 `SV_TEMPLATE_ZHONGZI_TAIWAN` 模板；**不傳 `--company`**；輸出至 `$SV_OUTPUT_BASE_ZHONGZI_TAIWAN`（預設 `~/Documents/名片/台灣中子`）；公司名「台灣中子創新股份有限公司」靜態於模板（無 PH_COMPANY）；同中子 BVI 跳過 Step 3 / 4 / 9
>
> **`--company` 僅 `--template-type zhongzi-bvi` 時必填**（`zhongzi-taiwan` 單一公司不需 company）：
> - `bvi` → 中子創新（BVI）員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI`（預設 `~/Documents/名片/中子`），名片印「中子創新有限公司」
> - `wenhua` → 中子文化股份有限公司員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI_WENHUA`（預設 `~/Documents/名片/中子文化`），名片印「中子文化股份有限公司」
> - 依簽呈「公司」欄位推導：「中子創新（BVI）」→ `bvi`；「中子文化股份有限公司」→ `wenhua`
> - **`PH_COMPANY` 文字框會被自動替換**：bvi → `中子創新有限公司`；wenhua → `中子文化股份有限公司`

## 流程差異總覽

- **中子系列**：腳本偵測 sidecar `template_type != "tw"`（即 zhongzi-bvi / zhongzi-taiwan）會印「📋 中子系列跳過 artifacts（無 vCard / QR）」並 exit 0。**Step 4（置入 QR）也整個跳過**（範本本身沒有 QR 區塊），直接進 Step 5 自動存檔。Step 9 上傳 vCard 整段跳過（沒產 vCard 就不用上傳），Step 8 收尾後流程結束。
- Step 1.5 備份簽呈：**中子 PDF 必傳 `<form-no>`**（Claude 視覺判斷後 echo 進命令）；TW 可省略，腳本自動 regex 抓。

## 最終產出

**中子 BVI 版（4 個檔案）：**

| 檔案 | 用途 |
|---|---|
| `{YYYYMMDD}-{中文名}_{英文名}.ai` | 原檔（可編輯）|
| `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | OL CS6（送印）|
| `{YYYYMMDD}-{中文名}_{英文名}.jpg` | 預覽 2000×780 |
| `簽呈編號-{表單號}.pdf` | 簽呈備份 |

> 中子版**不產 vCard / QR Code**（依使用者指示），Step 9 也整段跳過。

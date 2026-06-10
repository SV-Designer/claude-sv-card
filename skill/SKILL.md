---
name: sv-card
description: StreetVoice 街聲名片自動化製作（TW 街聲版 + 中子 BVI 版，v0.10.0+）。觸發詞：「做 SV 名片」/「我要製作名片」/「幫我做 SV 名片」/「執行 SV_名片自動化製作」，並附簽呈 PDF（拖入或路徑）。版型判斷依簽呈「名片版型」欄位：「TW 街聲」走 TW 全流程；「中子BVI」走中子分支（跳過 vCard / QR / 上傳）。CN / EN 版尚未支援。中子版屬新款測試階段，依 memory `feedback_new_card_type_testing` 規則，初期每步驟須先停下確認，不直接走自動流程；成功跑 ≥ 2 次後才討論加入自動化白名單。
---

# SV 名片自動化製作

> 本 skill 是 SOP 的「執行手冊」精簡版。完整原理、已知問題、設計理由見 [`SOP.md`](~/.claude/skills/sv-card/docs/SOP.md)
>
> **首次使用前必須跑 `install.sh`**（在 repo 根目錄）。腳本會建 symlink、檢查依賴、寫入使用者偏好設定。

## 🎯 觸發

使用者說以下任一句 + 提供簽呈 PDF：
- 「**我要製作名片**」
- 「**做 SV 名片**」/「**幫我做 SV 名片**」
- 「**執行 SV_名片自動化製作**」

## 📜 第一句話（逐字、不要改寫）

收到觸發後，第一句**必須逐字**回覆：

> **好的，準備開始！請完全關閉 illustrator (⌘Q)**

說完**不等使用者確認**，立即執行下方流程。

## 📋 PDF 萃取規則（雙重檢核，v0.8.6+）

**流程**：
1. Claude 用 Read tool 讀 PDF（**保留人類視覺判斷** — 抓 typo、特殊備註、簽呈格式異常）
2. 跑 `card_helper.sh extract-pdf <pdf-path>` 拿機械萃取 JSON
3. **比對 Claude 自己萃取結果 vs 腳本 JSON**：
   - 全部一致 → 用 JSON 欄位值 echo 進 init
   - 任一欄位不一致 / Claude 看出 typo / 特殊備註 → **停下與使用者確認**
4. 確認後執行 Step 1 init

**腳本 JSON 欄位**（`scripts/extract_signoff_fields.py`）：

| JSON key | 用途 / 對 init 參數的對應 |
|---|---|
| `form_no` | 表單號（→ Step 1.5 簽呈備份檔名）|
| `surname_cn` / `given_cn` | 中文姓名拆分（→ `--surname` / `--given`，含 18 個常見複姓判斷）|
| `card_name_cn` | 中文全名去員編（→ `--chinese`）|
| `english_name_no_alias` | 英文名去 alias（→ `--english`，alias 偵測：首 token 含中文字 = alias）|
| `english_alias` | 中文 alias（如「阿明 Ming Wang」→ `阿明`）|
| `title` | 職稱（→ `--title`）|
| `email` | Email（→ `--email`）|
| `office_ext` | 分機（→ `--office-ext`，null = 簽呈空白，傳 `""`）|
| `mobile` | 簽呈原格式手機（→ `--mobile`，null = 簽呈空白，傳 `""`）|
| `template_type` | 版型（v0.10.0+：「TW 街聲」→ `--template-type tw`；「中子BVI」→ `--template-type zhongzi-bvi`；其餘版型停下問）|
| `other_requests` | 「其他需求」欄位純文字 |
| `form_remark` + `form_remark_is_placeholder` | 「表單註釋」欄位文字，placeholder=true 代表是系統提示文字不是申請人填的 |

**Claude 必看項**（腳本抓不到的判斷）：
- **中英文 typo**：腳本照字面抓（如 `Strong Wo` 會原樣輸出），Claude 看 PDF 視覺判斷是否為 typo → 停下問
- **「其他需求」非空且非「請協助送印」「TW」這類常見備註** → 停下問
- **「表單註釋」`form_remark_is_placeholder=false` 表示申請人實際填了內容** → 停下問
- **`template_type == "中子BVI"`**（v0.10.0+）→ 走中子分支（傳 `--template-type zhongzi-bvi --company bvi|wenhua`），跳過 Step 3 artifacts、Step 4 place QR、Step 9 upload vCard；**初期每步驟先停下確認**（依 `feedback_new_card_type_testing` 規則，成功跑 ≥ 2 次才討論加入自動化）。**`--company` 依簽呈「公司」欄位推導：「中子創新（BVI）」→ `bvi`；「中子文化股份有限公司」→ `wenhua`**。輸出路徑分流（v0.10.3+ 預設）：bvi → `~/Documents/SV-名片/中子`；wenhua → `~/Documents/SV-名片/中子文化`（可用 `SV_OUTPUT_BASE_ZHONGZI` / `SV_OUTPUT_BASE_ZHONGZI_WENHUA` 在 `~/.config/sv-card/env` 覆寫）
- **`template_type != "TW 街聲"` 且 != "中子BVI"`**（CN / EN）→ 停下問（未支援）
- **「名片上的姓名」與「申請人」不同**（外部夥伴情境）→ 雖然腳本仍能抽，但要跟使用者確認此為預期
- **職稱中英文混填**（如「事業發展總監（英文: Business Development Director）」，v0.10.1+）→ **停下問使用者用中文還是英文**，再決定 `--title` 傳哪個值
- **Email 網域白名單**（v0.10.1+）：`@streetvoice.com`（TW 員工）、`@neuin.com`（中子員工）皆視為正常；其他網域 → 停下問

## 🚧 非常規簽呈 → 停下問

依 `feedback_sv_card_decisions` 原則 1（新款逐步確認）規則，遇以下狀況**不要照走自動流程**，先停下問使用者：
- 「其他需求」/ 備註欄出現**過去未碰過的特殊請求**（覆寫姓名、改地址、改 logo、特殊版型等）
- Email 非 `@streetvoice.com` 也非 `@neuin.com`（v0.10.1+：白名單已含中子員工域名）
- 版型非「TW 街聲」也非「中子BVI」（CN / EN 版尚未支援）
- 職稱中英混填（v0.10.1+，例：「事業發展總監（英文: ...）」）

> 已自動處理的分支（不再屬於非常規）：簽呈無分機 → `--office-ext ""`；簽呈無手機 → `--mobile ""`。

## 🔁 執行流程（全自動，僅 Step 0 首次 + Step 6 GATE 需詢問）

> 💡 **Illustrator dock 跳動提示**：執行 Step 2 / 4 / 7（含 `$.evalFile(.../jsx)` 的 mcp call）時，BridgeTalk 會讓 Illustrator dock 圖示跳動但不強制搶焦點 — macOS 對背景 GUI app 有 throttle，需使用者點一下 dock 才會繼續。
>
> **⚠️ 時機關鍵**：請在「送出 mcp call **之前**」（也就是 Claude Code UI 即將顯示 `Called illustrator` 之前）就先用文字提示使用者：**📌 點一下 Illustrator 以便繼續**。如果放在 mcp call 之後印，使用者在等 throttle 解除的這段時間看不到提示，會以為流程卡住。

### Step 0：首次製作 — 確認名片存放路徑（僅首次跑）

在 Step 1 前，先檢查是否需要走首次流程：

```bash
~/.claude/skills/sv-card/scripts/card_helper.sh check-firstrun
```

- 印 `skip-step0` → 直接跳到 Step 1
- 印 `run-step0` → 執行下列首次確認流程：

**a. 用以下精簡訊息問使用者**（不要加贅字）：

```
首次製作名片請先確認：
① 名片製作檔存放路徑：
　A. ~/Documents/SV-名片（預設）
　B. 自訂（請輸入完整路徑）
② 以後都存同路徑？
```

**b. 收到回答後，呼叫子命令**（自動 mkdir + open Finder + 寫 env 含 `SV_OUTPUT_CONFIRMED=1`）：

```bash
# 選 A 或回 "OK"
~/.claude/skills/sv-card/scripts/card_helper.sh confirm-firstrun "~/Documents/SV-名片"
# 選 B
~/.claude/skills/sv-card/scripts/card_helper.sh confirm-firstrun "<使用者輸入路徑>"
```

**c. 告訴使用者**：「資料夾已建立並開啟給您看。以後做名片都會存到這裡，可隨時編輯 `~/.config/sv-card/env` 改設定。」

然後繼續 Step 1。

### Step 1：填入所有欄位 + 建資料夾 + 開檔 + 寫 sidecar
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh init \
    --chinese "<中文全名>" --english "<英文名去alias>" \
    --surname "<中文姓>" --given "<中文名>" \
    --title "<職稱>" \
    --email "<email>" \
    --mobile "<簽呈原格式手機，例如 +886 900 000 000>" \
    --office-ext "<分機，例如 395>" \
    --template-type "<tw 或 zhongzi-bvi，預設 tw>" \
    --company "<bvi 或 wenhua，僅 zhongzi-bvi 必填>"
```
> **`--mobile` / `--office-ext` 為選填**：簽呈空白時傳空字串 `""`（或不傳）。
> - `--mobile ""` → 自動選無手機版模板（SV_TEMPLATE_NO_MOBILE）、vCard 跳過 TEL CELL
> - `--office-ext ""` → PH_PHONE_OFFICE 顯示 `+886-2-2741-7065`（不含 `#`）
>
> **`--template-type` 為選填**（v0.10.0+，預設 `tw`）：
> - `tw`（預設）→ SV 全流程，含 vCard / QR / 上傳
> - `zhongzi-bvi` → 中子 BVI 版（簽呈版型「中子BVI」），用 `SV_TEMPLATE_ZHONGZI` 模板；sidecar 不寫 artifacts 區塊，Step 3 / 4 / 9 自動跳過
>
> **`--company` 僅 `--template-type zhongzi-bvi` 時必填**（v0.10.1+）：
> - `bvi` → 中子創新（BVI）員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI`（v0.10.3+ 預設 `~/Documents/SV-名片/中子`），名片印「中子創新有限公司」
> - `wenhua` → 中子文化股份有限公司員工，輸出至 `$SV_OUTPUT_BASE_ZHONGZI_WENHUA`（v0.10.3+ 預設 `~/Documents/SV-名片/中子文化`），名片印「中子文化股份有限公司」
> - 依簽呈「公司」欄位推導：「中子創新（BVI）」→ `bvi`；「中子文化股份有限公司」→ `wenhua`
> - **`PH_COMPANY` 文字框會被自動替換**（v0.10.2+）：bvi → `中子創新有限公司`；wenhua → `中子文化股份有限公司`
>
> init 內部推導：名片用 `PH_PHONE_MOBILE`（空格→dash、開頭 `0` → `+886-`，v0.8.4+）、vCard `mobile`（沿用簽呈原格式）、`vcf-name`（英文名去空格+.vcf）、PH_PHONE_OFFICE。
> 資料寫入 `/tmp/sv_card_fields.json` sidecar，Step 2/3 自動讀取。腳本印出 `BASENAME=...` 和 `DEST_DIR=...` 給 Step 8 收尾用。

### Step 1.5：備份簽呈 PDF（v0.8.5+）
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh backup-pdf "<簽呈 PDF 原始路徑>" "$DEST_DIR" [<form-no>]
```
> 把使用者上傳的簽呈 PDF 備份到製作檔資料夾，命名為 `簽呈編號-{表單號}.pdf`。
> v0.10.3+：固定**保留上方 352px**（取代原本「找『表單註釋』word top - 1pt」動態邏輯）。原因：中子版 PDF 中文 layer 圖片化（CID 編碼），pdfplumber 抓不到「表單註釋」word，改用固定值對 TW + 中子 + 未來新版型一致。
> 表單號取得：CLI 第三參數 `<form-no>` > pdfplumber 抓「表單號:」regex > 報錯。**中子 PDF 必傳 `<form-no>`**（Claude 視覺判斷後 echo 進命令）；TW 可省略，腳本自動 regex 抓。

### Step 2：替換 7 欄位 + 自動存檔（mcp__illustrator__run）
```javascript
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/replace_fields.jsx");
```
> 從 sidecar 自動讀 7 個 PH_* 欄位 + save。找不到欄位回 `ERROR: missing PH_X` 不中斷。

### Step 3：產 vCard + QR + 預處理 SVG
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh artifacts
```
> 自動讀 sidecar 的 artifacts 區塊（無參數）。
>
> **中子版（v0.10.0+）**：腳本偵測 sidecar `template_type == "zhongzi-bvi"` 會印「📋 中子版跳過 artifacts（無 vCard / QR）」並 exit 0。**Step 4（置入 QR）也整個跳過**，直接進 Step 5 自動存檔。

### Step 4：置入 QR Code（mcp__illustrator__run）
```javascript
$.global.QR_OPTS = { svgPath: "/tmp/qr_processed.svg", sizeCm: 1.4, cmykBlack: 88 };
// Folder("~") 展開為家目錄，跨機器通用
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/place_qr.jsx");
```
> **中子版（v0.10.0+）**：整個跳過（範本本身沒有 QR 區塊）。直接進 Step 5。

### Step 5：自動存檔（mcp__illustrator__run）
```javascript
app.activeDocument.save();
```

### Step 6：🛑 GATE — 問使用者「請確認資訊無誤」

這是整個流程**唯一**的詢問點。Claude 用此句提示使用者：**👀 請檢查名片內容是否無誤，回 OK 跑收尾**。使用者切到 Illustrator 檢查，回覆 OK 後才繼續 Step 7。

### Step 7：清殘留 + 存原檔 + 外框化 + 存 OL（mcp__illustrator__run）
```javascript
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/finalize.jsx");
```
> finalize.jsx 一次完成：清殘留 → saveAs `/tmp/output_original.ai` → createOutline 全部 textFrames → saveAs `/tmp/output_ol.ai` CS6。中文路徑問題仍由 Step 8 用 mv 處理。

### Step 8：搬原檔 + JPG + 搬 OL + 列最終產出
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh finalize "$DEST_DIR" "$BASENAME"
```
（finalize 內部：mv original + sips JPG + mv OL + `ls -la` 列 5 個交付檔）

### Step 9：上傳 vCard 到 drive.streetvoice.com/vcard/

> **中子版（v0.10.0+）**：整段跳過（沒產 vCard 就不用上傳）。Step 8 收尾後流程結束。

**9a. 預查 server 是否已有同名檔（必跑）**
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard --check-only "$DEST_DIR/<無空格英文名>.vcf"
```
腳本走「拿密碼 + preflight + curl --list-only」流程，不上傳。最後一行印：
- `exists` → 進 **9b GATE**
- `new` → 跳到 **9c 直接上傳**
- 異常（找不到 favorite / 密碼錯）→ 同 9c 處理，由 upload 內邏輯接管

**9b. 🛑 GATE — 偵測到重複時詢問**（僅 `exists` 觸發）

Claude 用此句問使用者（**逐字**，把實際檔名代入）：

> **`<無空格英文名>.vcf` 偵測到相同檔案，請問是否覆蓋？**

- 使用者回 OK / 是 / 覆蓋 → 進 9c
- 使用者回否定 → 跳過 Step 9（vcf 仍在本地 `$DEST_DIR/`，未來可手動跑上傳）

**9c. 上傳（含 v0.8.1+ retry 邏輯）**
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard "$DEST_DIR/<無空格英文名>.vcf"
```

> **內部流程（v0.8.1+）**：
> 1. 取得密碼：Keychain 有就用；沒有 → 跳 dialog 要密碼 → 存 Keychain
> 2. **preflight 登入檢查**（curl --list-only noop）
>    - 失敗 → 自動刪 Keychain 密碼 + 跳 dialog 重輸 → 再 preflight 一次
>    - 仍失敗 → 印「請洽產品工程部」+ exit 1
> 3. **STOR + retry 一次**：第一次 STOR 失敗 sleep 1 秒再試（ProFTPD 偶有 transient 550，retry 幾乎都會 work）

**9c 結果分支**：

| 印出 | Claude 轉達 |
|---|---|
| `✅ vCard 已上傳 server [並覆蓋舊檔]` + URL | 「✅ vCard 已上傳並驗證成功」+ URL（建議續跑 9d 驗證確認 server 端沒被別人覆蓋回去）|
| `❌ 登入仍失敗` | 「❌ 登入失敗，請洽產品工程部協助確認帳號權限」|
| `❌ STOR 兩次都失敗` | **「❌ 上傳失敗（[Claude 評估當下可能原因]），手動上傳 vcard 至 transmit 覆蓋舊檔。完成後告知我，我會驗證 server」** → 等使用者完成後進 9d |

> **不採 DELE-then-STOR**：實測使用者對「owner 非自己」的檔有 STOR 覆寫權限但沒 DELE 權限，DELE 路徑根本走不通。

**9d. 驗證手動上傳結果**（9c 失敗後使用者手動 Transmit 上傳完，告知 Claude 後跑）
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh verify-vcard "$DEST_DIR/<無空格英文名>.vcf"
```
腳本抓 server 上同名 vcf 內容 cmp 對本地，印：
- `match` → Claude 轉達「✅ vCard 已驗證 server 端與本地一致」+ URL
- `mismatch` → Claude 轉達「❌ 上傳失敗（server 端內容與本地不同，可能被其他人覆蓋），請洽產品工程部協助確認」
- `missing` → Claude 轉達「❌ 上傳失敗（server 上找不到該檔案），請洽產品工程部協助確認」

> 為什麼要驗證：`9c ✅ 上傳成功` 訊息可能 false positive — 實測過 STOR 226 Transfer complete 後，server 端檔案被其他 process / 真實 owner 覆蓋回原版。verify-vcard 用 cmp 二進位比對才能確認 server 端真的是您上傳的內容。

## 📂 最終產出

`$SV_OUTPUT_BASE/{中文姓名}_{英文名去alias}/`（預設 `~/Documents/SV-名片/`）內：

**TW 版（6 個檔案）：**

| 檔案 | 用途 |
|---|---|
| `{YYYYMMDD}-{中文名}_{英文名}.ai` | 原檔（可編輯）|
| `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | OL CS6（送印）|
| `{YYYYMMDD}-{中文名}_{英文名}.jpg` | 預覽 2000×780 |
| `{無空格英文名}.vcf` | vCard — Step 9 已自動上傳到 `drive.streetvoice.com/vcard/`（覆蓋同名舊檔）|
| `QR Code.svg` | QR 原檔 |
| `簽呈編號-{表單號}.pdf` | 簽呈備份（Step 1.5 裁掉表單註釋以下；v0.8.5+）|

**中子 BVI 版（4 個檔案，v0.10.0+）：**

| 檔案 | 用途 |
|---|---|
| `{YYYYMMDD}-{中文名}_{英文名}.ai` | 原檔（可編輯）|
| `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | OL CS6（送印）|
| `{YYYYMMDD}-{中文名}_{英文名}.jpg` | 預覽 2000×780 |
| `簽呈編號-{表單號}.pdf` | 簽呈備份 |

> 中子版**不產 vCard / QR Code**（依使用者指示），Step 9 也整段跳過。

> Step 9 upload-vcard 已自動印出「vCard 已上傳 server [並覆蓋舊檔]」+ 公開 URL，收尾時把這兩行轉達給使用者即可。

## ⚠️ 關鍵注意事項

1. **Illustrator 必須冷啟動** — 已運行時 `open` 可能被歡迎頁攔截，這就是為什麼第一句要說「請確保為關閉狀態」
2. **中文路徑會 8700 cancel** — 一律先存 /tmp 再 mv（card_helper.sh save-* 已封裝）
3. **CMYK 文件下 QR 必須用 CMYKColor 直接賦值** — RGBColor 會被自動轉成 rich black (75,71,68,34) 偏藍紫（place_qr.jsx 已處理）
4. **PH_QRCODE placeholder 必須存在** — 模板已預先命名好；若使用者改過模板要先確認還在

## 🧰 涉及檔案

| 用途 | 路徑 |
|---|---|
| 模板 .ai（TW 有手機版，預設）| `~/.claude/skills/sv-card/templates/20260522-王小明.ai` |
| 模板 .ai（TW 無手機版）| `~/.claude/skills/sv-card/templates/20260529-王小明_無手機版.ai`（簽呈無手機時自動選用）|
| 模板 .ai（中子 BVI 版，v0.10.0+）| `~/.claude/skills/sv-card/templates/20260609-王小明_中子BVI.ai`（簽呈版型「中子BVI」時用 `--template-type zhongzi-bvi`）|
| Bash 操作合集 | `~/.claude/skills/sv-card/scripts/card_helper.sh` |
| vCard + QR + 預處理 | `~/.claude/skills/sv-card/scripts/make_card_artifacts.py` |
| 欄位替換 + 存檔 | `~/.claude/skills/sv-card/scripts/replace_fields.jsx` |
| QR 置入 + CMYK 染色 | `~/.claude/skills/sv-card/scripts/place_qr.jsx` |
| GATE 後合併收尾（清殘留+存 original+OL）| `~/.claude/skills/sv-card/scripts/finalize.jsx` |
| 簽呈 PDF 備份 + 裁切（v0.8.5+）| `~/.claude/skills/sv-card/scripts/backup_signoff_pdf.py` |
| 詳細 SOP（含已知問題深度說明）| `~/.claude/skills/sv-card/docs/SOP.md` |
| Illustrator MCP server | 依使用者安裝位置（install.sh 會偵測；常見路徑 `~/mcp-servers/illustrator-mcp-server/`）|
| 使用者偏好設定 | `~/.config/sv-card/env`（install.sh 寫入；可覆寫 SV_OUTPUT_BASE、SV_TEMPLATE）|

---
name: sv-card
description: StreetVoice 街聲名片自動化製作（TW 街聲版＋中子 BVI 版＋台灣中子版）。觸發詞：「做名片」（附簽呈 PDF，拖入或路徑）。版型依簽呈「名片版型」欄位自動判斷：「TW 街聲」→ TW 全流程；「中子BVI」/「台灣中子」→ 中子分支（跳過 vCard / QR / 上傳）；非上述三種或未支援的新版型 → 停下與使用者確認。
---

# SV 名片自動化製作

> 本 skill 是 SOP 的「執行手冊」精簡版。完整原理、已知問題、設計理由見 [`SOP.md`](~/.claude/skills/sv-card/docs/SOP.md)。**首次使用前必須跑 `install.sh`**（在 repo 根目錄）：建 symlink、檢查依賴、寫入使用者偏好設定。

## 🎯 觸發 + 版型路由

使用者說「**做名片**」+ 提供簽呈 PDF 即觸發。**版型一律依簽呈欄位判斷，不靠觸發語指定。** 版型決策（單一來源：簽呈欄位）：
1. 照下方「PDF 萃取規則」讀簽呈「名片版型」欄位（`template_type`）拿到版型
2. 依版型分流：
   - 「TW 街聲」→ TW 全流程
   - 「中子BVI」/「台灣中子」→ 中子分支（跳過 vCard / QR / 上傳）→ 細節見 [`docs/branch-neutron.md`](~/.claude/skills/sv-card/docs/branch-neutron.md)
   - 非上述三種（CN / EN）→ 🛑 **停下問使用者**（未支援）

目前三種支援版型皆已納入自動化白名單：全自動、僅 Step 6 GATE 需確認。**未來新增版型**依 SOP「🆕 新版型測試 → 畢業規則」節：初期每步驟先停下確認，成功跑 ≥ 2 次後才討論加入白名單。

## 📜 第一句話（逐字、不要改寫）

收到觸發後，第一句**必須逐字**回覆（說完**不等使用者確認**，立即執行下方流程）：

> **好的，準備開始！請完全關閉 illustrator (⌘Q)**

## 📋 PDF 萃取規則（雙重檢核）

1. Claude 用 Read tool 讀 PDF（**保留人類視覺判斷** — 抓 typo、特殊備註、簽呈格式異常）
2. 跑 `card_helper.sh extract-pdf <pdf-path>` 拿機械萃取 JSON
3. **比對 Claude 自己萃取結果 vs 腳本 JSON**：
   - 全部一致 → 用 JSON 欄位值 echo 進 init
   - 任一欄位不一致 / Claude 看出 typo / 特殊備註 → **停下與使用者確認**
4. 確認後執行 Step 1 init

腳本 JSON 欄位對照表＋「Claude 必看項」（機械萃取全 null、typo、alias、company 推導、Email 白名單等停下判斷）→ 詳見 [`docs/pdf-extract.md`](~/.claude/skills/sv-card/docs/pdf-extract.md)

## 🚧 非常規簽呈 → 停下問

依 SOP「🆕 新版型測試 → 畢業規則」（新款逐步確認），遇以下狀況**不要照走自動流程**，先停下問使用者：
- 「其他需求」/ 備註欄出現**過去未碰過的特殊請求**（覆寫姓名、改地址、改 logo、特殊版型等）
- Email 非 `@streetvoice.com` 也非 `@neuin.com`（白名單已含中子員工域名）
- 版型非「TW 街聲」、「中子BVI」、「台灣中子」（CN / EN 版尚未支援）
- 職稱中英混填（例：「事業發展總監（英文: ...）」）

> 已自動處理的分支（不再屬於非常規）：簽呈無分機 → `--office-ext ""`；簽呈無手機 → `--mobile ""`。

## 🔁 執行流程（全自動，僅 Step 0 首次 + Step 6 GATE 需詢問）

> 💡 **Illustrator dock 跳動提示**：執行 Step 2 / 4 / 7（含 `$.evalFile(.../jsx)` 的 mcp call）時，BridgeTalk 會讓 Illustrator dock 圖示跳動但不強制搶焦點 — macOS 對背景 GUI app 有 throttle，需使用者點一下 dock 才會繼續。
> **⚠️ 時機關鍵**：請在「送出 mcp call **之前**」（也就是 Claude Code UI 即將顯示 `Called illustrator` 之前）就先用文字提示使用者（**逐字**）：**📌 點進 Illustrator 並切回這裡，以便繼續！**。如果放在 mcp call 之後印，使用者在等 throttle 解除的這段時間看不到提示，會以為流程卡住。

### Step 0：首次製作 — 確認名片存放路徑（僅首次跑）

先跑 `~/.claude/skills/sv-card/scripts/card_helper.sh check-firstrun`：印 `skip-step0` → 直接跳 Step 1；印 `run-step0` → 🛑 停下用精簡訊息問使用者名片根目錄（a 問句模板、b `confirm-firstrun` 用法、c 回覆句 → **逐字照** [`docs/first-run.md`](~/.claude/skills/sv-card/docs/first-run.md) 執行），完成後繼續 Step 1。

### Step 1：填入所有欄位 + 建資料夾 + 開檔 + 寫 sidecar
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh init \
    --chinese "<中文全名>" --english "<英文名去alias>" \
    --surname "<中文姓>" --given "<中文名>" \
    --title "<職稱>" --email "<email>" \
    --mobile "<簽呈原格式手機，例如 +886 909 050 269>" \
    --office-ext "<分機，例如 395>" \
    --template-type "<tw / zhongzi-bvi / zhongzi-taiwan，預設 tw>" \
    --company "<bvi 或 wenhua，僅 zhongzi-bvi 必填；zhongzi-taiwan 不傳>"
```
> **`--mobile` / `--office-ext` 為選填**：簽呈空白時傳空字串 `""`（或不傳）。`--mobile ""` → 自動選無手機版模板（SV_TEMPLATE_NO_MOBILE）、vCard 跳過 TEL CELL；`--office-ext ""` → 新版分機框 `PH_PHONE_EXT` 留空（公司電話 `+886-2-2741-7065` 靜態於模板）；無手機版仍走舊 `PH_PHONE_OFFICE`。
> **`--template-type` / `--company` 詳解（中子分支）**→ 見 [`docs/branch-neutron.md`](~/.claude/skills/sv-card/docs/branch-neutron.md)
> init 內部推導：名片用 `PH_PHONE_MOBILE`（空格→dash、開頭 `0` → `+886-`）、vCard `mobile`（沿用簽呈原格式）、`vcf-name`（英文名去空格+.vcf）、`PH_PHONE_EXT`（`#`+分機；無手機版改 `PH_PHONE_OFFICE` 合成框）。資料寫入 `/tmp/sv_card_fields.json` sidecar，Step 2/3 自動讀取。腳本印出 `BASENAME=...` 和 `DEST_DIR=...` 給 Step 8 收尾用。

> 🛑 **若 init 輸出含 `NEEDS_MCP_OPEN=1`**：表示 Illustrator 已運行、`open` 被既有文件攔截，**current document 不是目標檔**（直接替換會改錯文件）。此時在 Step 2 之前先用 MCP 強制開啟目標檔（只有 MCP `app.open` 會 bringToFront 可靠生效）：`app.open(new File("<DEST_DIR>/<BASENAME>.ai"));` 並確認 `app.activeDocument.name` 回 `<BASENAME>.ai`。**未確認前絕不執行 Step 2 replace**。

### Step 1.5：備份簽呈 PDF
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh backup-pdf "<簽呈 PDF 原始路徑>" "$DEST_DIR" [<form-no>]
```
> 把簽呈 PDF 備份到製作檔資料夾，命名 `簽呈編號-{表單號}.pdf`，固定**保留上方 352px**（中子版 PDF 中文 layer 圖片化、pdfplumber 抓不到「表單註釋」word，固定值對所有版型一致）。
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
> 自動讀 sidecar 的 artifacts 區塊（無參數）。**中子系列**：腳本偵測 `template_type != "tw"` 印「📋 中子系列跳過 artifacts」並 exit 0，**Step 4 也整個跳過**，直接進 Step 5。

### Step 4：置入 QR Code（mcp__illustrator__run）
```javascript
$.global.QR_OPTS = { svgPath: "/tmp/qr_processed.svg", sizeCm: 1.4, cmykBlack: 88 };
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/place_qr.jsx");
```
> **中子系列**：整個跳過（範本本身沒有 QR 區塊），直接進 Step 5。

### Step 5：自動存檔（mcp__illustrator__run）：`app.activeDocument.save();`

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

### Step 9：上傳 vCard 到 drive.streetvoice.com/vcard/（**中子版整段跳過**）

9a 預查同名檔（`upload-vcard --check-only`，必跑）→ `exists` 時 **9b 🛑 GATE 逐字問是否覆蓋** → 9c 上傳（含 preflight + retry）→ 失敗時 9d `verify-vcard` 驗證手動上傳。完整命令、GATE 逐字問句、9c 結果分支表、9d 驗證轉達句 → 詳見 [`docs/upload-vcard.md`](~/.claude/skills/sv-card/docs/upload-vcard.md)

## 📂 最終產出

`$SV_OUTPUT_BASE/SV/{中文姓名}_{英文名去alias}/`（`SV_OUTPUT_BASE` 為名片根目錄、TW 接 `/SV`；預設 `~/Documents/名片/SV/`）內，**TW 版 6 個檔案**：
- `{YYYYMMDD}-{中文名}_{英文名}.ai`（原檔，可編輯）、`OL-{YYYYMMDD}-{中文名}_{英文名}.ai`（OL CS6，送印）、`{YYYYMMDD}-{中文名}_{英文名}.jpg`（預覽 2000×780）
- `{無空格英文名}.vcf`（vCard — Step 9 已自動上傳到 `drive.streetvoice.com/vcard/`，覆蓋同名舊檔）
- `QR Code.svg`（QR 原檔）、`簽呈編號-{表單號}.pdf`（簽呈備份，Step 1.5 裁掉表單註釋以下）

中子 BVI 版 4 個檔案（無 vCard / QR）→ 見 [`docs/branch-neutron.md`](~/.claude/skills/sv-card/docs/branch-neutron.md)。收尾時把 upload-vcard 印出的「vCard 已上傳 server」+ 公開 URL 轉達給使用者。

## ⚠️ 關鍵注意事項

1. **Illustrator 必須冷啟動** — 已運行時 `open` 可能被歡迎頁攔截，這就是為什麼第一句要說「請確保為關閉狀態」
2. **中文路徑會 8700 cancel** — 一律先存 /tmp 再 mv（card_helper.sh save-* 已封裝）
3. **CMYK 文件下 QR 必須用 CMYKColor 直接賦值** — RGBColor 會被自動轉成 rich black (75,71,68,34) 偏藍紫（place_qr.jsx 已處理）
4. **PH_QRCODE placeholder 必須存在** — 模板已預先命名好；若使用者改過模板要先確認還在

## 🧰 涉及檔案

| 用途 | 路徑 |
|---|---|
| 模板 .ai ×4：TW 有手機（預設，`20260612-名片模版_TW 街聲.ai`）／TW 無手機（簽呈無手機時自動選用，`20260622-名片模版_TW 街聲（無手機）.ai`）／中子BVI（`20260612-名片模版_中子BVI.ai`）／台灣中子（`20260612-名片模版_台灣中子.ai`）| `~/.claude/skills/sv-card/templates/` |
| Bash 操作合集 | `~/.claude/skills/sv-card/scripts/card_helper.sh` |
| vCard + QR + 預處理／簽呈 PDF 備份裁切 | `scripts/make_card_artifacts.py`／`backup_signoff_pdf.py` |
| 欄位替換／QR 置入／GATE 後收尾 | `scripts/replace_fields.jsx`／`place_qr.jsx`／`finalize.jsx` |
| PDF 欄位對照＋必看項／中子分支／Step 9 分支／首次流程 | `docs/pdf-extract.md`／`branch-neutron.md`／`upload-vcard.md`／`first-run.md` |
| 詳細 SOP（含已知問題深度說明）| `~/.claude/skills/sv-card/docs/SOP.md` |
| Illustrator MCP server | 依使用者安裝位置（install.sh 會偵測；常見 `~/mcp-servers/illustrator-mcp-server/`）|
| 使用者偏好設定 | `~/.config/sv-card/env`（install.sh 寫入；可覆寫 SV_OUTPUT_BASE、SV_TEMPLATE）|

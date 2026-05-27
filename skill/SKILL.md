---
name: sv-card
description: StreetVoice 街聲名片自動化製作。觸發條件 = 使用者說「我要製作名片」或「做 SV 名片」或「幫我做 SV 名片」並提供簽呈 PDF。產出 5 個交付檔案（原檔 .ai / OL CS6 / JPG 預覽 2000×780 / vCard / QR SVG）到 $SV_OUTPUT_BASE/{中文姓名}_{英文名去 alias}/（預設 ~/Documents/SV-名片，可由 ~/.config/sv-card/env 覆寫）。整套流程封裝為 3 個腳本（card_helper.sh / make_card_artifacts.py / place_qr.jsx），全程零 Bash prompt，唯一停下來的點是 Step 6 的 GATE「請確認資訊無誤」。詳細 SOP 與已知問題見 ~/.claude/skills/sv-card/docs/SOP.md。
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

> **好準備執行，illustator請確保為關閉狀態**

說完**不等使用者確認**，立即執行下方流程。

## 📋 PDF 萃取規則

| 簽呈欄位 | 處理方式 |
|---|---|
| 中文姓名（去員編） | `王小明(XXX)` → 拆姓 `王` + 名 `小明` |
| 英文名（含 alias） | 整段保留，例如 `阿明 Ming Wang`；資料夾命名時去 alias 取 `Ming Wang` |
| 職稱 | 原樣 |
| 室內分機 `#XXX` | 名片用 `+886-2-2741-7065#XXX`；vCard 不含分機 |
| 手機 | 名片用 `+886-XXX-XXX-XXX` 國碼格式；vCard 沿用簽呈原格式 |
| Email | 原樣 |

## 🚧 非常規簽呈 → 停下問

依 `feedback_new_card_type_testing` 規則，若 PDF 出現以下任一狀況，**不要照走自動流程**，先停下問使用者：
- 「其他需求」欄要求改中文名（外部夥伴情境）
- 室內分機空白（電話欄該如何處理？）
- Email 非 @streetvoice.com（外部信箱）
- 版型非「TW 街聲」

## 🔁 執行流程（全自動，僅 Step 0 首次 + Step 6 GATE 需詢問）

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

### Step 1：建資料夾 + 開檔 + 等就緒
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh init "<中文全名>" "<英文名去alias>"
```
腳本印出 `BASENAME=...` 和 `DEST_DIR=...` 給後面用。

### Step 2：替換 7 欄位 + 自動存檔（mcp__illustrator__run）
```javascript
$.global.FIELDS = {
    PH_NAME_CN_SURNAME: "姓",
    PH_NAME_CN_GIVEN:   "名",
    PH_NAME_EN:         "英文名",
    PH_TITLE:           "職稱",
    PH_PHONE_OFFICE:    "+886-2-2741-7065#分機",
    PH_PHONE_MOBILE:    "+886-XXX-XXX-XXX",
    PH_EMAIL:           "email@streetvoice.com"
};
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/replace_fields.jsx");
```
> replace_fields.jsx 內部會 save，且找不到欄位時回 `ERROR: missing PH_X` 不會中斷。

### Step 3：產 vCard + QR + 預處理 SVG
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh artifacts \
    --surname "X" --given "XX" --en "Foo Bar" \
    --title "..." \
    --email "...@streetvoice.com" \
    --mobile "+886 XXX XXX XXX" \
    --folder "$DEST_DIR" \
    --vcf-name "FooBar.vcf"
```

### Step 4：置入 QR Code（mcp__illustrator__run）
```javascript
$.global.QR_OPTS = { svgPath: "/tmp/qr_processed.svg", sizeCm: 1.4, cmykBlack: 88 };
// Folder("~") 展開為家目錄，跨機器通用
$.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/place_qr.jsx");
```

### Step 5：自動存檔（mcp__illustrator__run）
```javascript
app.activeDocument.save();
```

### Step 6：🛑 GATE — 問使用者「請確認資訊無誤」

這是整個流程**唯一**的詢問點。使用者切到 Illustrator 目視檢查，回覆 OK 後才繼續 Step 7。

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

## 📂 最終產出

`$SV_OUTPUT_BASE/{中文姓名}_{英文名去alias}/`（預設 `~/Documents/SV-名片/`）內 5 個檔案：

| 檔案 | 用途 |
|---|---|
| `{YYYYMMDD}-{中文名}_{英文名}.ai` | 原檔（可編輯）|
| `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | OL CS6（送印）|
| `{YYYYMMDD}-{中文名}_{英文名}.jpg` | 預覽 2000×780 |
| `{無空格英文名}.vcf` | vCard — **請使用者事後上傳到 `drive.streetvoice.com/vcard/`** |
| `QR Code.svg` | QR 原檔 |

> 收尾時記得告訴使用者：`📋 vCard URL: http://drive.streetvoice.com/vcard/{vcf 檔名}`

## ⚠️ 關鍵注意事項

1. **Illustrator 必須冷啟動** — 已運行時 `open` 可能被歡迎頁攔截，這就是為什麼第一句要說「請確保為關閉狀態」
2. **中文路徑會 8700 cancel** — 一律先存 /tmp 再 mv（card_helper.sh save-* 已封裝）
3. **CMYK 文件下 QR 必須用 CMYKColor 直接賦值** — RGBColor 會被自動轉成 rich black (75,71,68,34) 偏藍紫（place_qr.jsx 已處理）
4. **PH_QRCODE placeholder 必須存在** — 模板已預先命名好；若使用者改過模板要先確認還在

## 🧰 涉及檔案

| 用途 | 路徑 |
|---|---|
| 模板 .ai | `~/.claude/skills/sv-card/templates/20260522-王小明.ai` |
| Bash 操作合集 | `~/.claude/skills/sv-card/scripts/card_helper.sh` |
| vCard + QR + 預處理 | `~/.claude/skills/sv-card/scripts/make_card_artifacts.py` |
| 欄位替換 + 存檔 | `~/.claude/skills/sv-card/scripts/replace_fields.jsx` |
| QR 置入 + CMYK 染色 | `~/.claude/skills/sv-card/scripts/place_qr.jsx` |
| GATE 後合併收尾（清殘留+存 original+OL）| `~/.claude/skills/sv-card/scripts/finalize.jsx` |
| 詳細 SOP（含已知問題深度說明）| `~/.claude/skills/sv-card/docs/SOP.md` |
| Illustrator MCP server | 依使用者安裝位置（install.sh 會偵測；常見路徑 `~/mcp-servers/illustrator-mcp-server/`）|
| 使用者偏好設定 | `~/.config/sv-card/env`（install.sh 寫入；可覆寫 SV_OUTPUT_BASE、SV_TEMPLATE）|

# Changelog

本檔案記錄 sv-card 的變更歷史。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。

版本號採 [Semantic Versioning](https://semver.org/lang/zh-TW/)：MAJOR.MINOR.PATCH。

## [Unreleased]

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

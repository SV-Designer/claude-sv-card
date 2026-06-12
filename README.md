# sv-card

StreetVoice 街聲名片自動化製作。

觸發「做名片」+ 提供簽呈 PDF > 自動產出 5 個交付檔（.ai 原檔 / OL CS6 / JPG 預覽 2000×780 / vCard / QR SVG），並把 vCard 自動上傳 server。

---

# 🐷 懶人包

> 安裝skill前，請先部屬好您的Claude code。


## 1. 首次安裝步驟

**將此頁 URL 貼給 Claude Code 說「幫我安裝這個 skill」。**

Claude 會自動照進階區的步驟跑完整套，過程中只會跟你確認 1-2 次（重啟 Claude Code 那一步）。

> 🔗 URL：https://github.com/chensoo8911/sv-card

完整系統需求清單見下方「進階 → 系統需求」，最低是 **macOS + Adobe Illustrator + Claude Code**，其他套件 
Claude 會自動處理。


## 2. 怎麼用？

**在 Claude Code 說「做名片」，並將簽呈 PDF 拖進對話框。**

> 想指定版型可直接講：「**做 SV 名片**」做 TW 街聲版、「**做中子名片**」做中子 BVI 版、「**做台灣中子名片**」做台灣中子版。只說「做名片」則由簽呈「名片版型」欄位自動判斷。指定版型若和簽呈不符，Claude 會停下來問你。

Claude 會自動：
1. 從簽呈 PDF 萃取你的個人資料
2. 開 Illustrator 套模板、替換姓名/職稱/電話/Email
3. 生成 QR Code 並貼到名片上
4. 停下來問你「**請確認資訊無誤**」← ‼️唯一需要手動的地方‼️
5. 你確認 OK 後，自動產出 5 個檔案 + 上傳 vCard 到 server

完成後 5 個交付檔會放在 `~/Documents/名片/SV/{你的中文名}_{英文名}/`（路徑可改，見下方「設定覆寫」）。



## 3. 問題排解

| 狀況 | 怎麼處理 |
|---|---|
| 安裝過程卡住 | 直接告訴 Claude 卡在哪一步，它會自己處理 |
| 做名片時 Illustrator 沒開起來 | 第一次跑時 Claude 會說「請確保 illustator 為關閉狀態」，先把 Illustrator 關掉再重觸發 |
| 簽呈 PDF 資料萃取錯了 | 直接告訴 Claude「職稱應該是 XXX」，它會重做 |
| 想換名片存放路徑 | 編輯 `~/.config/sv-card/env`，改 `SV_OUTPUT_BASE="你的新路徑"` |
| 想找以前做過的名片 | 都在 `~/Documents/名片/SV/`（或你自己設的路徑）內，依中文姓名分資料夾 |

如 Claude 無法正常運作，請截圖 slack 洽產品工程部。

---

# 🔧 進階 / 內部細節

> 以下是給「協助安裝的 Claude」「想了解內部」「需要 debug」的人看的。日常使用者不用看這段。

## 給協助安裝的 Claude

如果使用者把這個連結傳給你並要求協助安裝，請依下列步驟操作。**全程主動進行，僅在標註 ⏸ 的地方停下來與使用者確認。**

### 前置確認 ⏸
跟使用者確認他符合以下系統需求（任一不符就先停下來告知使用者）：
- macOS
- Adobe Illustrator CC 2024 以上已安裝
- Claude Code v2.0+（既然他正在跟你對話，已具備）
- 已安裝 `uv`（Python 套件管理器）— `command -v uv` 確認；沒裝可建議 `brew install uv`

### 安裝步驟（idempotent，可重複跑）

1. **clone repo**（預設位置 `~/Projects/sv-card`，可依使用者偏好調整）
   ```bash
   git clone https://github.com/chensoo8911/sv-card.git ~/Projects/sv-card
   ```

2. **🔐 授權驗證 ⏸**：跑 install.sh 前，跟使用者明確徵詢授權：
   > 「我即將安裝 sv-card skill，這會：
   > 1. clone illustrator-mcp-server 到 `~/mcp-servers/`
   > 2. 修改你的 `~/.claude.json`（加 MCP server 設定，會先備份）
   > 3. 修改你的 `~/.claude/settings.json`（加 sv-card 相關 allow 規則，會先備份）
   > 4. 在 `~/.claude/skills/sv-card/` 建 symlink、寫 `~/.config/sv-card/env`
   >
   > 是否授權？」

   收到授權後才繼續 step 3。**這是整個安裝流程唯一需要使用者明確點頭的關卡。**

3. **跑 install.sh**（會自動串接 setup-mcp.sh）
   ```bash
   bash ~/Projects/sv-card/install.sh --yes
   ```
   `--yes` 模式會使用預設值（輸出 `~/Documents/名片/SV`、模板用 repo 內附範例、`SV_OUTPUT_CONFIRMED=0` 留待首次製作時引導確認）。

4. **install.sh 內部會做的事**（你不需手動拆解，但需要時可知道）：
   - 檢查 Adobe Illustrator / python3 / `qrcode` 套件（缺 qrcode 會自動 pip install）
   - 自動跑 `scripts/setup-mcp.sh`：clone `spencerhhubert/illustrator-mcp-server` 到 `~/mcp-servers/`、套 sv-card patch（去掉 Claude activate + 加 600s timeout）、寫入 `~/.claude.json` 的 `mcpServers.illustrator`（會先備份 `.bak`）
   - 在 `~/.claude/skills/sv-card/` 建 symlink（SKILL.md / scripts / templates / docs）→ 指回 repo
   - 寫使用者偏好到 `~/.config/sv-card/env`（含 `SV_OUTPUT_CONFIRMED` marker）
   - 寫入 `~/.claude/settings.json` 的 `permissions.allow`：加 sv-card 相關 Bash + `mcp__illustrator__run` 規則，日常做名片不會再被 prompt 中斷

5. **驗證 ⏸**：跟使用者說「**請重啟 Claude Code，然後跟我說一聲**」
   - **MCP server** 必須重啟 Claude Code 才會載入
   - **`~/.claude/settings.json` 的 allow 清單**也是 session 啟動時讀一次，重啟才會生效（否則安裝完當下不會 reload，做名片每個 Bash 還是會 prompt）

6. **重啟後再驗證**：請使用者跟你說「`mcp__illustrator__run` 工具存在嗎？」你可用 ToolSearch 確認。沒有的話，可能是 `~/.claude.json` 寫入位置不對（user-level vs project-level），改寫入 project-level 看看

7. **完成**：告訴使用者「現在可以對 Claude Code 說『幫我做 SV 名片』+ 附簽呈 PDF 就會觸發了。首次製作時會引導確認名片存放位置。」

### 常見錯誤 & 修法

| 症狀 | 原因 | 修法 |
|---|---|---|
| `setup-mcp.sh` 報 `uv: command not found` | 缺 uv | `brew install uv`，再重跑 |
| `git apply --check` 失敗 | server.py 已被別人改過 | 看 `scripts/mcp-patches/illustrator-mcp-server.patch` 手動 merge |
| 重啟後 Claude 仍看不到工具 | settings 寫到 project-level 而非 user-level | 直接 grep `~/.claude.json` 看 `mcpServers.illustrator` 是否在頂層 |
| 模板 `.ai` 缺失 | repo 內 templates/ 沒抓到 | 確認 `~/.claude/skills/sv-card/templates/20260612-王小明.ai` symlink 沒斷 |
| 首次 upload-vcard 跳 Keychain 對話框 | 正常 — macOS 第一次 access keychain 會問 | 按 "Always Allow" |

## 結構

```
sv-card/
├── install.sh           主安裝腳本
├── scripts/
│   ├── setup-mcp.sh     副安裝腳本（裝 illustrator-mcp-server）
│   ├── mcp-patches/     對 mcp-server 的修改 patch
│   ├── card_helper.sh   Bash 操作合集（init / artifacts / finalize / upload-vcard）
│   ├── make_card_artifacts.py    vCard + QR + 預處理
│   ├── replace_fields.jsx        ExtendScript：替換 7 個 PH_* 欄位
│   ├── place_qr.jsx              ExtendScript：QR 置入 + CMYK 染色
│   └── finalize.jsx              ExtendScript：GATE 後合併收尾
├── templates/           Illustrator 模板（假名範例 20260612-王小明.ai）
├── skill/SKILL.md       Claude Code skill 入口
└── docs/SOP.md          完整 SOP 與已知問題
```

## 系統需求

- macOS（流程使用 `osascript`、`sips`、`open -a`）
- Adobe Illustrator CC 2024 以上（建議 2026）
- Python 3.9+
- [`uv`](https://docs.astral.sh/uv/) — `brew install uv`
- Claude Code v2.0+
- Transmit 5+（用於 vCard 上傳；favorite 名為 `Streetvoice`，可由 `SV_TRANSMIT_FAVORITE` env 覆寫）

`qrcode` Python 套件與 `illustrator-mcp-server` 會由 install.sh 自動處理。

## 設定覆寫

`~/.config/sv-card/env` 範例：

```bash
SV_OUTPUT_BASE="$HOME/Documents/名片"   # v0.14.0+：名片根目錄；TW 版自動接 /SV，中子各版接 /中子 等子夾
SV_TEMPLATE="$HOME/.claude/skills/sv-card/templates/20260612-王小明.ai"
SV_TRANSMIT_FAVORITE="Streetvoice"
SV_TRANSMIT_REMOTE_DIR="/vcard"
```

`card_helper.sh` 啟動時會 source 此檔；環境變數覆寫優先。

## 產出位置

`$SV_OUTPUT_BASE/SV/{中文姓名}_{英文名去 alias}/`（TW 街聲版，v0.14.0+ 根目錄下 `SV` 子夾）下 5 個檔案（不在本 repo）：

| 檔案 | 用途 |
|---|---|
| `{YYYYMMDD}-{中文名}_{英文名}.ai` | 原檔（可編輯） |
| `OL-{YYYYMMDD}-{中文名}_{英文名}.ai` | OL CS6（送印） |
| `{YYYYMMDD}-{中文名}_{英文名}.jpg` | 預覽 2000×780 |
| `{無空格英文名}.vcf` | vCard（已自動上傳到 `drive.streetvoice.com/vcard/`） |
| `QR Code.svg` | QR 原檔 |

## 文件

- 執行手冊（精簡）：[`skill/SKILL.md`](skill/SKILL.md)
- 完整 SOP（含已知問題深度說明）：[`docs/SOP.md`](docs/SOP.md)
- 變更紀錄：[`CHANGELOG.md`](CHANGELOG.md)
- 測試說明：[`tests/README.md`](tests/README.md)

## 測試

煙霧測試（不需 Illustrator、不需 FTP）：

```bash
bash tests/smoke.sh
```

每次 push 到 `main` 或 PR 時，GitHub Actions 也會自動跑（見 [`.github/workflows/ci.yml`](.github/workflows/ci.yml)）。詳見 [`tests/README.md`](tests/README.md)。

## 已知限制

- 已支援 TW 街聲版、中子 BVI 版、台灣中子版（一般名片）。CN / EN 版尚未泛化
- 中文路徑 saveAs 會 8700 cancel —— 流程用 /tmp 中轉繞過
- Illustrator 必須冷啟動（已運行時 `open` 可能被歡迎頁攔截）
- vCard 上傳走 FTP（密碼存 macOS Keychain，首次跑會 prompt 一次）

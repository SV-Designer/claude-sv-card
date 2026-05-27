# sv-card

StreetVoice 街聲名片自動化製作。觸發「我要製作名片 / 幫我做 SV 名片」+ 提供簽呈 PDF，自動產出 5 個交付檔（.ai 原檔 / OL CS6 / JPG 預覽 2000×780 / vCard / QR SVG）。

---

## 🤖 給協助安裝的 Claude（同事 A 把連結貼給你了？看這段）

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
   `--yes` 模式會使用預設值（輸出 `~/Documents/SV-名片`、模板用 repo 內附範例、`SV_OUTPUT_CONFIRMED=0` 留待首次製作時引導確認）。

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
| 模板 `.ai` 缺失 | repo 內 templates/ 沒抓到 | 確認 `~/.claude/skills/sv-card/templates/20260522-王小明.ai` symlink 沒斷 |

---

## 💁 給人類使用者（不懂程式也 OK）

**最簡單方式**：把這個 README 連結貼給 Claude Code，說「**幫我安裝這個 skill**」即可。Claude 會照上面的步驟跑完整套流程，過程中只會問你 1-2 次確認（重啟 Claude Code 那邊）。

安裝完成後，直接在 Claude Code 內說：

> 「**幫我做 SV 名片**」+ 拖入或貼上簽呈 PDF 路徑

---

## 結構

```
sv-card/
├── install.sh           主安裝腳本
├── scripts/
│   ├── setup-mcp.sh     副安裝腳本（裝 illustrator-mcp-server）
│   ├── mcp-patches/     對 mcp-server 的修改 patch
│   ├── card_helper.sh / make_card_artifacts.py / place_qr.jsx (SOP 三件套)
│   └── ...
├── templates/           Illustrator 模板（假名範例 20260522-王小明.ai）
├── skill/SKILL.md       Claude Code skill 入口
└── docs/SOP.md          完整 SOP 與已知問題
```

## 系統需求

- macOS（流程使用 `osascript`、`sips`、`open -a`）
- Adobe Illustrator CC 2024 以上（建議 2026）
- Python 3.9+
- [`uv`](https://docs.astral.sh/uv/) — `brew install uv`
- Claude Code v2.0+

`qrcode` Python 套件與 `illustrator-mcp-server` 會由 install.sh 自動處理。

## 設定覆寫

`~/.config/sv-card/env` 範例：

```bash
SV_OUTPUT_BASE="$HOME/Documents/SV-名片"
SV_TEMPLATE="$HOME/.claude/skills/sv-card/templates/20260522-王小明.ai"
```

card_helper.sh 啟動時會 source 此檔；環境變數覆寫優先。

## 產出位置

`$SV_OUTPUT_BASE/{中文姓名}_{英文名去 alias}/` 下 5 個檔案（不在本 repo）。

## 文件

- 執行手冊（精簡）：[`skill/SKILL.md`](skill/SKILL.md)
- 完整 SOP（含已知問題深度說明）：[`docs/SOP.md`](docs/SOP.md)
- 變更紀錄：[`CHANGELOG.md`](CHANGELOG.md)

## 已知限制

- 僅支援 StreetVoice TW 街聲版（一般名片）。子品牌（中子、CN、EN 版）尚未泛化
- 中文路徑 saveAs 會 8700 cancel —— 流程用 /tmp 中轉繞過
- Illustrator 必須冷啟動（已運行時 `open` 可能被歡迎頁攔截）

# Changelog

本檔案記錄 sv-card 的變更歷史。格式參考 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)。

版本號採 [Semantic Versioning](https://semver.org/lang/zh-TW/)：MAJOR.MINOR.PATCH。

## [Unreleased]

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

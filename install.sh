#!/bin/bash
#
# sv-card 安裝腳本
#
# 行為（全部 idempotent，可重複執行）：
#   1. 檢查必要依賴（Adobe Illustrator, Python3, qrcode / pypdf / pdfplumber 套件）
#   2. 提示使用者 illustrator-mcp-server 安裝狀態（不自動裝，因需 Claude Code MCP 設定）
#   3. 建立 ~/.claude/skills/sv-card/ 內的 symlink (SKILL.md/scripts/templates/docs)
#   4. 互動式問使用者偏好（SV_OUTPUT_BASE 等），寫入 ~/.config/sv-card/env
#
# 用法：
#   bash install.sh           # 互動模式
#   bash install.sh --yes     # 全部用預設值，不問
#
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/sv-card"
CONFIG_DIR="$HOME/.config/sv-card"
CONFIG_FILE="$CONFIG_DIR/env"

NON_INTERACTIVE=0
[ "$1" = "--yes" ] && NON_INTERACTIVE=1

echo "🚀 sv-card 安裝開始（repo: ${REPO_DIR}）"
echo

# ─── 1. 依賴檢查 ────────────────────────────────────────────────
echo "📋 檢查依賴..."

# Adobe Illustrator
if [ ! -d "/Applications/Adobe Illustrator 2026" ] \
    && [ ! -d "/Applications/Adobe Illustrator 2025" ] \
    && [ ! -d "/Applications/Adobe Illustrator 2024" ] \
    && ! ls -d /Applications/Adobe\ Illustrator* >/dev/null 2>&1; then
    echo "  ⚠️  未偵測到 Adobe Illustrator。請先安裝（macOS CC 2024 以上）"
else
    echo "  ✅ Adobe Illustrator 已安裝"
fi

# Python3
if ! command -v python3 >/dev/null 2>&1; then
    echo "  ❌ python3 未安裝。請先安裝 Python 3.9+" >&2
    exit 1
fi
echo "  ✅ python3: $(python3 --version)"

# qrcode 套件
if ! python3 -c "import qrcode" 2>/dev/null; then
    echo "  ⚠️  Python qrcode 套件未安裝"
    if [ "$NON_INTERACTIVE" = "1" ]; then
        echo "    → 自動執行 pip3 install qrcode"
        python3 -m pip install --user qrcode
    else
        read -p "    → 現在用 pip3 install --user qrcode 安裝？[Y/n] " yn
        case "$yn" in
            [Nn]*) echo "    略過。請手動執行：python3 -m pip install --user qrcode" ;;
            *) python3 -m pip install --user qrcode ;;
        esac
    fi
else
    echo "  ✅ Python qrcode 套件已安裝"
fi

# pypdf 套件（v0.8.5+ backup-pdf 必要）
if ! python3 -c "import pypdf" 2>/dev/null; then
    echo "  ⚠️  Python pypdf 套件未安裝（backup-pdf 必要）"
    if [ "$NON_INTERACTIVE" = "1" ]; then
        echo "    → 自動執行 pip3 install pypdf"
        python3 -m pip install --user pypdf
    else
        read -p "    → 現在用 pip3 install --user pypdf 安裝？[Y/n] " yn
        case "$yn" in
            [Nn]*) echo "    略過。請手動執行：python3 -m pip install --user pypdf" ;;
            *) python3 -m pip install --user pypdf ;;
        esac
    fi
else
    echo "  ✅ Python pypdf 套件已安裝"
fi

# pdfplumber 套件（v0.8.5+ backup-pdf / extract-pdf 必要）
if ! python3 -c "import pdfplumber" 2>/dev/null; then
    echo "  ⚠️  Python pdfplumber 套件未安裝（backup-pdf / extract-pdf 必要）"
    if [ "$NON_INTERACTIVE" = "1" ]; then
        echo "    → 自動執行 pip3 install pdfplumber"
        python3 -m pip install --user pdfplumber
    else
        read -p "    → 現在用 pip3 install --user pdfplumber 安裝？[Y/n] " yn
        case "$yn" in
            [Nn]*) echo "    略過。請手動執行：python3 -m pip install --user pdfplumber" ;;
            *) python3 -m pip install --user pdfplumber ;;
        esac
    fi
else
    echo "  ✅ Python pdfplumber 套件已安裝"
fi

# illustrator-mcp-server 偵測
MCP_HINT=""
for candidate in \
    "$HOME/mcp-servers/illustrator-mcp-server" \
    "$HOME/Projects/illustrator-mcp-server" \
    "$HOME/.local/share/illustrator-mcp-server"; do
    if [ -d "$candidate" ]; then
        MCP_HINT="$candidate"
        break
    fi
done

# 確認 ~/.claude.json 已有 illustrator MCP 設定
HAS_MCP_CONFIG=0
if [ -f "$HOME/.claude.json" ]; then
    if python3 -c "
import json, sys
try:
    with open('$HOME/.claude.json') as f:
        d = json.load(f)
    sys.exit(0 if 'illustrator' in d.get('mcpServers', {}) else 1)
except Exception:
    sys.exit(1)
"; then
        HAS_MCP_CONFIG=1
    fi
fi

if [ -n "$MCP_HINT" ] && [ "$HAS_MCP_CONFIG" = "1" ]; then
    echo "  ✅ illustrator-mcp-server 已安裝且設定於 $MCP_HINT"
else
    if [ -z "$MCP_HINT" ]; then
        echo "  ⚠️  未偵測到 illustrator-mcp-server"
    fi
    if [ "$HAS_MCP_CONFIG" = "0" ]; then
        echo "  ⚠️  ~/.claude.json 內未設定 mcpServers.illustrator"
    fi
    echo
    if [ "$NON_INTERACTIVE" = "1" ]; then
        echo "  → 自動執行 setup-mcp.sh 安裝 + 設定..."
        bash "$REPO_DIR/scripts/setup-mcp.sh" --yes
    else
        read -p "  → 現在自動安裝 + 設定 MCP server？[Y/n] " yn
        case "$yn" in
            [Nn]*) echo "  → 跳過。請事後手動執行：bash $REPO_DIR/scripts/setup-mcp.sh" ;;
            *) bash "$REPO_DIR/scripts/setup-mcp.sh" ;;
        esac
    fi
fi
echo

# ─── 2. 建立 ~/.claude/skills/sv-card/ symlink ─────────────────
echo "🔗 設定 skill 資料夾 $SKILL_DIR ..."
mkdir -p "$SKILL_DIR"

link_into_skill() {
    local target="$1"
    local linkname="$2"
    local linkpath="$SKILL_DIR/$linkname"
    if [ -L "$linkpath" ]; then
        local current
        current="$(readlink "$linkpath")"
        if [ "$current" = "$target" ]; then
            echo "  ✅ $linkname (已正確 symlink)"
            return
        fi
        echo "  ♻️  $linkname 舊 symlink 指向 $current，更新為 $target"
        rm "$linkpath"
    elif [ -e "$linkpath" ]; then
        echo "  ⚠️  $linkpath 已存在且非 symlink，跳過（請手動處理）" >&2
        return
    fi
    ln -s "$target" "$linkpath"
    echo "  ✅ $linkname → $target"
}

link_into_skill "$REPO_DIR/skill/SKILL.md"   "SKILL.md"
link_into_skill "$REPO_DIR/scripts"          "scripts"
link_into_skill "$REPO_DIR/templates"        "templates"
link_into_skill "$REPO_DIR/docs"             "docs"
echo

# ─── 3. 寫入使用者偏好 ─────────────────────────────────────────
echo "⚙️  寫入使用者偏好 $CONFIG_FILE ..."
mkdir -p "$CONFIG_DIR"

default_output="$HOME/Documents/名片/SV"
default_template="$SKILL_DIR/templates/20260522-王小明.ai"

# 若已有舊設定，沿用為新預設
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_FILE"
    [ -n "$SV_OUTPUT_BASE" ] && default_output="$SV_OUTPUT_BASE"
    [ -n "$SV_TEMPLATE" ]    && default_template="$SV_TEMPLATE"
fi

if [ "$NON_INTERACTIVE" = "1" ]; then
    out_base="$default_output"
    tpl="$default_template"
    confirmed=0   # 沒互動，留待首次製作名片時引導確認
else
    read -p "  名片輸出資料夾 [$default_output]: " out_base
    out_base="${out_base:-$default_output}"
    read -p "  模板 .ai 路徑 [$default_template]: " tpl
    tpl="${tpl:-$default_template}"
    confirmed=1
fi

cat > "$CONFIG_FILE" <<EOF
# sv-card 使用者偏好（由 install.sh 產生，可手動編輯）
# card_helper.sh 啟動時會 source 此檔
SV_OUTPUT_BASE="$out_base"
SV_TEMPLATE="$tpl"
SV_OUTPUT_CONFIRMED=$confirmed
EOF
echo "  ✅ 寫入 ${CONFIG_FILE}（SV_OUTPUT_CONFIRMED=$confirmed）"
echo

# ─── 4. 寫入 Claude Code allow 清單 ─────────────────────────
SETTINGS_FILE="$HOME/.claude/settings.json"
echo "🛡️  設定 Claude Code 權限白名單 ${SETTINGS_FILE}"
echo "    （將加入 sv-card 相關 Bash 腳本 + mcp__illustrator__run，"
echo "     日常做名片時不會被 permission prompt 中斷）"

if [ "$NON_INTERACTIVE" = "1" ]; then
    write_allow=1
else
    read -p "  → 寫入 allow 清單？[Y/n] " yn
    case "$yn" in [Nn]*) write_allow=0 ;; *) write_allow=1 ;; esac
fi

if [ "$write_allow" = "1" ]; then
    SETTINGS_FILE_EXPORT="$SETTINGS_FILE" python3 <<'PYEOF'
import json, os, shutil
from pathlib import Path

path = Path(os.environ["SETTINGS_FILE_EXPORT"])
path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    backup = Path(str(path) + ".bak")
    shutil.copy(path, backup)
    print(f"  ✅ 備份原檔: {backup}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        print("  ❌ settings.json 不是合法 JSON，跳過寫入")
        raise SystemExit(0)
else:
    data = {}

data.setdefault("permissions", {}).setdefault("allow", [])
allow = data["permissions"]["allow"]
# 用 ~ 形式（字面字串）— Claude Code 對 allow rule 是字面比對，
# Bash 命令字串通常以 ~/... 出現，故 ~ 形式才會 match。
to_add = [
    "Bash(~/.claude/skills/sv-card/scripts/card_helper.sh:*)",
    "Bash(python3 ~/.claude/skills/sv-card/scripts/make_card_artifacts.py:*)",
    "Bash(~/.claude/skills/sv-card/install.sh:*)",
    "Bash(~/.claude/skills/sv-card/scripts/setup-mcp.sh:*)",
    "mcp__illustrator__run",
]
added = []
for rule in to_add:
    if rule not in allow:
        allow.append(rule)
        added.append(rule)

tmp = Path(str(path) + ".tmp")
tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False))
tmp.replace(path)
print(f"  ✅ 加入 {len(added)} 條規則")
for r in added:
    print(f"    + {r}")
PYEOF
else
    echo "  → 跳過。日常每次做名片時會被 permission prompt 中斷"
fi
echo

# ─── 5. 完成 ──────────────────────────────────────────────────
mkdir -p "$out_base"
echo "🎉 安裝完成！"
echo
echo "下一步："
echo "  1. 確認 ~/.claude/skills/sv-card/SKILL.md 已可被 Claude Code 載入（重啟 Claude Code）"
echo "  2. 在 Claude Code 中說「幫我做 SV 名片」+ 附簽呈 PDF 即可觸發"
echo "     （首次製作時會引導您確認存放位置）"
echo "  3. 若要改設定，編輯 ${CONFIG_FILE}"
echo
echo "目前生效值："
echo "  SV_OUTPUT_BASE      = $out_base"
echo "  SV_TEMPLATE         = $tpl"
echo "  SV_OUTPUT_CONFIRMED = $confirmed (0=首次製作會引導確認，1=已確認)"

#!/bin/bash
#
# 安裝並設定 illustrator-mcp-server，讓 Claude Code 可以執行 Illustrator ExtendScript
#
# 行為：
#   1. clone spencerhhubert/illustrator-mcp-server 到 $SV_MCP_DIR（預設 ~/mcp-servers/illustrator-mcp-server）
#   2. 套用 sv-card patch（去掉 Claude activate、加長 timeout 到 600s）
#   3. 確認 uv 已安裝
#   4. 寫入 ~/.claude.json 的 mcpServers.illustrator（會先備份原檔）
#
# 用法：
#   bash setup-mcp.sh            # 互動確認
#   bash setup-mcp.sh --yes      # 跳過確認
#
# 全程 idempotent；重複跑不會壞東西。
#
set -e

SV_MCP_DIR="${SV_MCP_DIR:-$HOME/mcp-servers/illustrator-mcp-server}"
REPO_URL="https://github.com/spencerhhubert/illustrator-mcp-server.git"

# 找 patch 檔（兩種情境：從 repo 跑 / 從 ~/.claude/skills/sv-card/ 跑）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/mcp-patches/illustrator-mcp-server.patch"
if [ ! -f "$PATCH_FILE" ]; then
    PATCH_FILE="$HOME/.claude/skills/sv-card/scripts/mcp-patches/illustrator-mcp-server.patch"
fi
if [ ! -f "$PATCH_FILE" ]; then
    echo "❌ 找不到 patch 檔 $PATCH_FILE" >&2
    exit 1
fi

NON_INTERACTIVE=0
[ "$1" = "--yes" ] && NON_INTERACTIVE=1

echo "🔧 setup-mcp.sh: 安裝 illustrator-mcp-server"
echo "  目標位置: $SV_MCP_DIR"
echo

# ─── 1. clone ────────────────────────────────────────────────
if [ -d "$SV_MCP_DIR/.git" ]; then
    echo "  ✅ 已存在於 ${SV_MCP_DIR}（跳過 clone）"
else
    if [ "$NON_INTERACTIVE" != "1" ]; then
        read -p "  → 即將 clone $REPO_URL 到 ${SV_MCP_DIR}，繼續？[Y/n] " yn
        case "$yn" in [Nn]*) echo "中止"; exit 1 ;; esac
    fi
    mkdir -p "$(dirname "$SV_MCP_DIR")"
    git clone "$REPO_URL" "$SV_MCP_DIR"
fi

# ─── 2. 套 patch ─────────────────────────────────────────────
SERVER_PY="$SV_MCP_DIR/src/illustrator/server.py"
if grep -q "with timeout of 600 seconds" "$SERVER_PY"; then
    echo "  ✅ patch 已套用（偵測到 600s timeout）"
else
    cd "$SV_MCP_DIR"
    if git apply --check "$PATCH_FILE" 2>/dev/null; then
        git apply "$PATCH_FILE"
        echo "  ✅ 套用 sv-card patch"
    else
        echo "  ⚠️  patch 套用失敗（server.py 可能已被修改過），請手動處理：" >&2
        echo "      diff -u 原檔 patch 內容: $PATCH_FILE" >&2
        exit 1
    fi
fi

# ─── 3. uv 檢查 ──────────────────────────────────────────────
if ! command -v uv >/dev/null 2>&1; then
    echo
    echo "  ❌ 需要 uv（Python 套件管理器）但未安裝" >&2
    echo "      → 安裝指令：brew install uv" >&2
    echo "      → 或：curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    exit 1
fi
echo "  ✅ uv: $(uv --version)"

# ─── 4. 寫入 ~/.claude.json ──────────────────────────────────
CLAUDE_JSON="$HOME/.claude.json"
echo
echo "  📝 寫入 $CLAUDE_JSON 的 mcpServers.illustrator..."

if [ -f "$CLAUDE_JSON" ]; then
    cp "$CLAUDE_JSON" "$CLAUDE_JSON.bak"
    echo "    （已備份至 ${CLAUDE_JSON}.bak）"
fi

SV_MCP_DIR_EXPORT="$SV_MCP_DIR" python3 <<'PYEOF'
import json, os, sys
path = os.path.expanduser("~/.claude.json")
mcp_dir = os.environ["SV_MCP_DIR_EXPORT"]

try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError as e:
    print(f"  ❌ ~/.claude.json 不是合法 JSON：{e}", file=sys.stderr)
    sys.exit(1)

data.setdefault("mcpServers", {})
existing = data["mcpServers"].get("illustrator")
new_config = {
    "type": "stdio",
    "command": "uv",
    "args": ["--directory", mcp_dir, "run", "illustrator"],
    "env": {}
}

if existing == new_config:
    print("  ✅ mcpServers.illustrator 設定已是最新（無變動）")
else:
    data["mcpServers"]["illustrator"] = new_config
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)
    print("  ✅ 寫入 mcpServers.illustrator")
PYEOF

echo
echo "🎉 illustrator-mcp-server 設定完成"
echo
echo "下一步："
echo "  → 重啟 Claude Code 讓新 MCP server 載入"
echo "  → 重啟後在 Claude Code 內應該能看到 mcp__illustrator__run 工具"

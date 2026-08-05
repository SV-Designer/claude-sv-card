#!/bin/bash
#
# sv-card 煙霧測試（smoke test）
#
# 跑哪些檢查：
#   1. Shell script syntax — bash -n（必跑，不需安裝任何東西）
#   2. shellcheck — 進階 lint，未安裝會跳過
#   3. Python syntax — python3 -m py_compile（必跑）
#   4. Sidecar JSON schema 驗證 — 需 jsonschema 套件，未安裝會跳過
#
# 不跑哪些：
#   - 需要 Adobe Illustrator 的測試（mcp__illustrator__run）
#   - 需要 FTP server 的測試（upload-vcard）
#   - 需要 macOS 系統 API（sips、osascript、open）
#
# 用法：
#   bash tests/smoke.sh
#
# 退出碼：
#   0 = 全部通過（含可跳過的項目）
#   1 = 至少一項必跑檢查失敗

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

fail=0
warn=0

# ─── Phase 1: shell syntax (bash -n) ──────────────────────────
echo "📋 Phase 1: shell script syntax (bash -n)"
for f in install.sh scripts/*.sh; do
    if bash -n "$f" 2>&1; then
        echo "  ✅ $f"
    else
        echo "  ❌ $f"
        fail=1
    fi
done

# ─── Phase 2: shellcheck (optional) ────────────────────────────
echo
echo "📋 Phase 2: shellcheck (optional)"
if command -v shellcheck >/dev/null 2>&1; then
    sc_fail=0
    for f in install.sh scripts/*.sh; do
        if shellcheck -S warning "$f" 2>&1; then
            echo "  ✅ $f"
        else
            echo "  ⚠️  $f（上方為 warning，不視為 fail）"
            warn=1
        fi
    done
else
    echo "  ⏭️  shellcheck 未安裝（macOS 上跑 brew install shellcheck，CI 上會自動裝）"
fi

# ─── Phase 3: Python syntax (py_compile) ───────────────────────
echo
echo "📋 Phase 3: Python syntax (py_compile)"
for f in scripts/*.py tests/*.py; do
    [ -f "$f" ] || continue
    if python3 -m py_compile "$f" 2>&1; then
        echo "  ✅ $f"
    else
        echo "  ❌ $f"
        fail=1
    fi
done

# ─── Phase 4: Sidecar JSON schema 驗證 ─────────────────────────
echo
echo "📋 Phase 4: Sidecar JSON schema"
if python3 -c "import jsonschema" 2>/dev/null; then
    if python3 tests/validate_sidecar.py; then
        :
    else
        fail=1
    fi
else
    echo "  ⏭️  python3 jsonschema 未安裝（跑 pip3 install jsonschema，CI 上會自動裝）"
fi

# ─── Phase 5: 欄位解析邏輯（分機去# / 手機不截斷）──────────────
echo
echo "📋 Phase 5: 欄位解析邏輯（純函式，不需 pdfplumber）"
if python3 tests/test_field_logic.py; then
    :
else
    fail=1
fi

# ─── 結果 ──────────────────────────────────────────────────────
echo
if [ $fail -eq 0 ]; then
    if [ $warn -eq 1 ]; then
        echo "🎉 所有必跑檢查通過（有 shellcheck warning，可忽略）"
    else
        echo "🎉 所有檢查通過"
    fi
    exit 0
else
    echo "💥 有必跑檢查失敗，請修正"
    exit 1
fi

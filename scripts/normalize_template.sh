#!/bin/bash
# =============================================================
# normalize_template.sh — 模板中繼資料正規化（去識別化＋去雜訊）
#
# 解決兩件事：
#   ① Illustrator 存檔時會把「登入帳號」寫進 .ai 表頭的 %%For 欄位。
#      2026-08-24 就是這樣把真實帳號帶進了公開 repo（靠人工安檢才發現）。
#   ② %AI10_OpenToVie／%AI9_OpenToView 記的是「你上次關檔時畫布捲到哪」，
#      每次隨手存檔都會變 → git diff 一直有雜訊，還會巧合連出像電話的數字串。
#
# 作法：等長二進位取代（檔案位元組數完全不變），不重新存檔、不動任何圖形。
#      這是 .ai 這種「PDF 容器內含長度宣告」的檔案唯一安全的改法——
#      長度一變，內部的 /Length 就對不上，檔案會壞。
#
# 用法：
#   normalize_template.sh                    # 處理 templates/ 底下全部 .ai
#   normalize_template.sh a.ai b.ai          # 只處理指定檔案
#   normalize_template.sh --check            # 只檢查不修改（回傳 1 代表有東西該修）
#
# 建議時機：在 Illustrator 改完模板、存檔之後，發版之前跑一次。
# =============================================================
set -uo pipefail
export LC_ALL=C   # 二進位處理一律用 C locale，避免多位元組被當成字元切壞

SKILL_DIR="${SV_CARD_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TPL_DIR="$SKILL_DIR/templates"
BACKUP_DIR="$SKILL_DIR/templates/backups"
OWNER="owner"          # %%For 要被換成的中性值

CHECK_ONLY=0
FILES=()
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    *) FILES+=("$a") ;;
  esac
done
if [ ${#FILES[@]} -eq 0 ]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(ls "$TPL_DIR"/*.ai 2>/dev/null)
fi
[ ${#FILES[@]} -gt 0 ] || { echo "❌ 沒有可處理的 .ai 檔"; exit 2; }

NEED=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "⚠️ 跳過（找不到）：$f"; continue; }
  base=$(basename "$f")
  before=$(stat -f%z "$f")

  # 這支檔案目前的 %%For 值 / OpenToView 值
  cur_for=$(grep -aoE '%%For: \([^)]*\)' "$f" | head -1)
  cur_view=$(grep -aoE '%AI[0-9]+_OpenToVie[w]?: [-0-9.]+ [-0-9.]+' "$f" | head -1)

  dirty=0
  [ -n "$cur_for" ] && [ "$cur_for" != "%%For: ($OWNER)" ] && dirty=1
  [ -n "$cur_view" ] && ! printf '%s' "$cur_view" | grep -qE ': 0[0.]* 0[0.]*$' && dirty=1

  if [ "$dirty" = 0 ]; then
    echo "  ✅ $base 已正規化"
    continue
  fi
  NEED=1
  echo "  ⚠️ $base 需要處理"
  [ -n "$cur_for" ]  && echo "       $cur_for"
  [ -n "$cur_view" ] && echo "       $cur_view"
  [ "$CHECK_ONLY" = 1 ] && continue

  mkdir -p "$BACKUP_DIR"
  cp "$f" "$BACKUP_DIR/$base.$(date +%Y%m%d-%H%M%S).bak"

  perl -0777 -pi -e '
    # ① %%For: (任何值) → (owner)，用空白補到原本長度，總位元組數不變
    s{(%%For: \()([^)]*)(\))}{
      my ($h,$v,$t) = ($1,$2,$3);
      my $new = "'"$OWNER"'";
      $new = substr($new, 0, length($v)) if length($new) > length($v);
      $new .= " " x (length($v) - length($new));
      $h . $new . $t;
    }ge;
    # ② OpenToView 的前兩個座標 → 同長度的 0，畫布一律從原點開啟
    s{(%AI\d+_OpenToVie[w]?: )([-\d.]+)( )([-\d.]+)}{
      $1 . ("0" x length($2)) . $3 . ("0" x length($4));
    }ge;
  ' "$f"

  after=$(stat -f%z "$f")
  if [ "$before" != "$after" ]; then
    echo "  🚫 $base 位元組數變了（$before → $after）——已從備份還原，請人工處理"
    cp "$BACKUP_DIR/$base."*.bak "$f" 2>/dev/null
    exit 3
  fi
  echo "     → 完成（$after bytes，未變）"
done

if [ "$CHECK_ONLY" = 1 ]; then
  [ "$NEED" = 1 ] && { echo "── 有檔案需要正規化，跑一次不帶 --check 即可修 ──"; exit 1; }
  echo "── 全部已正規化 ──"; exit 0
fi

echo "── 完成。建議接著跑 check_templates.sh 確認檔案還開得起來、文字沒跑掉 ──"
exit 0

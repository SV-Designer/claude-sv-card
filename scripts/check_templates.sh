#!/bin/bash
# =============================================================
# check_templates.sh — 模板文字內容安檢（補 grep 的死角）
#
# 為什麼需要這支：
#   .ai 的文字內容存在壓縮區塊裡，grep／git grep 一律看不到，
#   所以發版護欄的敏感字掃描對「名片上印的字」其實是瞎的。
#   （2026-08-24 就是靠人工開檔才發現 saveAs 把帳號寫進 %%For。）
#   這支改用 Illustrator 自己把每支模板的文字欄位讀出來，跟白名單比對。
#
# 用法：
#   check_templates.sh                 # 檢查，有非白名單文字就列出並回傳 1
#   check_templates.sh --update        # 把目前所有模板文字寫成新的白名單（確認過才用）
#   check_templates.sh --dump          # 只印出目前所有模板的文字，不比對
#
# 前提：macOS + 已安裝 Adobe Illustrator。執行中 Illustrator 會被叫到前景。
# 注意：本腳本只開檔讀取、關檔時一律不儲存，不會改到任何模板。
#
# 實作備註（踩過的坑）：
#   ① 一支模板一次 osascript ＝ 每次都吃 AppleScript 預設 120 秒上限，7 支必爆。
#      所以改成「產生一支 .jsx → 一次 do javascript 跑完全部 → 寫結果檔」。
#   ② 一定要關對話框（DONTDISPLAYALERTS），不然缺字提示會卡住整支腳本等人按確定。
# =============================================================
set -uo pipefail
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

SKILL_DIR="${SV_CARD_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TPL_DIR="$SKILL_DIR/templates"
ALLOWLIST="$SKILL_DIR/scripts/templates_allowlist.txt"
JSX="/tmp/sv_card_check_templates.jsx"
OUT="/tmp/sv_card_check_templates.txt"

MODE="check"
case "${1:-}" in
  --update) MODE="update" ;;
  --dump)   MODE="dump" ;;
  "")       ;;
  *) echo "未知參數：$1（可用：--update / --dump）"; exit 2 ;;
esac

[ -d "$TPL_DIR" ] || { echo "❌ 找不到模板資料夾：$TPL_DIR"; exit 2; }
ls "$TPL_DIR"/*.ai >/dev/null 2>&1 || { echo "❌ $TPL_DIR 裡沒有任何 .ai 模板"; exit 2; }

# ---------- 產生 jsx：一次跑完所有模板 ----------
rm -f "$OUT"
{
  echo "var files = ["
  for f in "$TPL_DIR"/*.ai; do
    # 單引號在檔名裡會壞掉字串，先轉義
    printf "  '%s',\n" "$(printf '%s' "$f" | sed "s/'/\\\\'/g")"
  done
  echo "];"
  cat <<'JSXBODY'
var prevUIL = app.userInteractionLevel;
app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;
var lines = [];
for (var i = 0; i < files.length; i++) {
  var d = null;
  try {
    d = app.open(new File(files[i]));
    for (var j = 0; j < d.textFrames.length; j++) {
      var t = d.textFrames[j].contents;
      t = t.replace(/[\r\n\t]+/g, ' ');
      t = t.replace(/^\s+|\s+$/g, '');
      if (t.length > 0) lines.push(t);
    }
  } catch (e) {
    lines.push('__ERROR__ ' + files[i] + ' : ' + e);
  }
  if (d !== null) { try { d.close(SaveOptions.DONOTSAVECHANGES); } catch (e2) {} }
}
app.userInteractionLevel = prevUIL;
var out = new File('/tmp/sv_card_check_templates.txt');
out.encoding = 'UTF-8';
out.lineFeed = 'Unix';          // 不設的話換行會被吃掉，整份擠成一行
out.open('w');
for (var k = 0; k < lines.length; k++) { out.writeln(lines[k]); }
out.close();
'done=' + lines.length;
JSXBODY
} > "$JSX"

echo "── 讀取模板文字（Illustrator 會被叫到前景，過程中請不要操作它）──"
osascript <<OSA >/dev/null 2>&1
with timeout of 600 seconds
  tell application "Adobe Illustrator" to do javascript file "$JSX"
end timeout
OSA

[ -s "$OUT" ] || { echo "❌ 一個字都沒讀到——Illustrator 沒開？或 osascript 被系統權限擋了（系統設定 → 隱私權與安全性 → 自動化）"; exit 2; }

if grep -q "^__ERROR__" "$OUT"; then
  echo "🚫 有模板開檔失敗："
  grep "^__ERROR__" "$OUT" | sed 's/^/    /'
  exit 2
fi

CURRENT=$(sed '/^[[:space:]]*$/d' "$OUT" | sort -u)
N_TPL=$(ls -1 "$TPL_DIR"/*.ai 2>/dev/null | wc -l | tr -d ' ')
N_TXT=$(echo "$CURRENT" | wc -l | tr -d ' ')
echo "  ✅ 讀完 $N_TPL 支模板，共 $N_TXT 種不重複文字"

if [ "$MODE" = "dump" ]; then
  echo "$CURRENT"
  exit 0
fi

if [ "$MODE" = "update" ]; then
  [ -f "$ALLOWLIST" ] && cp "$ALLOWLIST" "$ALLOWLIST.bak"
  {
    echo "# claude-sv-card 模板文字白名單（由 check_templates.sh --update 產生）"
    echo "# 一行一種允許出現在模板上的文字。只該有：假人資料（王小明／Ming Wang／假號）"
    echo "# 與公司公開資訊（地址、總機、統編、官網）。真實員工姓名／電話絕不該進來。"
    echo "# 更新前務必人眼看過 diff——這份檔案就是「什麼算乾淨」的定義。"
    echo ""
    echo "$CURRENT"
  } > "$ALLOWLIST"
  echo "  ✅ 已寫入白名單：${ALLOWLIST}（舊檔備份為 .bak）"
  exit 0
fi

# ---------- 比對 ----------
[ -f "$ALLOWLIST" ] || { echo "❌ 還沒有白名單：$ALLOWLIST"; echo "   先人眼確認模板都乾淨，再跑：$0 --update"; exit 2; }
# 註解＝「#」後面一定要有空白。不能只看 "#"——模板裡的分機寫法就是 `#375`，
# 用寬鬆規則會把它當註解濾掉，然後每次檢查都誤報一次（2026-08-24 踩過）。
ALLOWED=$(grep -vE '^[[:space:]]*# |^[[:space:]]*$' "$ALLOWLIST" | sort -u)

NEW=$(comm -23 <(echo "$CURRENT") <(echo "$ALLOWED"))
GONE=$(comm -13 <(echo "$CURRENT") <(echo "$ALLOWED"))

if [ -n "$GONE" ]; then
  echo "── ℹ️ 白名單有、模板已不再出現的文字（模板改版就會這樣，不是錯）──"
  echo "$GONE" | sed 's/^/    /'
fi

if [ -n "$NEW" ]; then
  echo ""
  echo "🚫 模板出現「不在白名單」的文字，請人眼確認是不是真實個資："
  echo "$NEW" | sed 's/^/    /'
  echo ""
  echo "確認乾淨（例如只是改了文案）→ 跑 $0 --update 收進白名單"
  echo "確認是真實個資     → 先在 Illustrator 改掉，不要發版"
  exit 1
fi

echo "  ✅ 模板文字全部在白名單內，沒有夾帶非預期資料"
exit 0

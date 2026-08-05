# Step 0 首次製作：確認名片存放路徑（完整流程）

> 本檔內容自 SKILL.md「Step 0」搬出（逐字保留）。何時觸發：`card_helper.sh check-firstrun` 印 `run-step0` 時。

**a. 用以下精簡訊息問使用者**（不要加贅字）：

```
首次製作名片請先確認：
① 名片製作檔存放路徑（根目錄）：
　A. ~/Documents/名片（預設）
　B. 自訂（請輸入完整路徑）
② 以後都存同路徑？
```

> 這裡確認的是**名片根目錄**（所有版型的共同上層），不是 `SV` 子夾。TW 街聲版做的時候才會在根目錄下自動建 `SV/`，中子各版自動建 `中子` / `中子文化` / `台灣中子` 子夾。

**b. 收到回答後，呼叫子命令**（自動 mkdir + open Finder + 寫 env 含 `SV_OUTPUT_CONFIRMED=1`）：

```bash
# 選 A 或回 "OK"
~/.claude/skills/claude-sv-card/scripts/card_helper.sh confirm-firstrun "~/Documents/名片"
# 選 B
~/.claude/skills/claude-sv-card/scripts/card_helper.sh confirm-firstrun "<使用者輸入路徑>"
```

**c. 告訴使用者**：「資料夾已建立並開啟給您看。以後做名片都會存到這裡，可隨時編輯 `~/.config/sv-card/env` 改設定。」

然後繼續 Step 1。

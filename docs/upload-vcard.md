# Step 9 上傳 vCard：9a–9d 完整分支

> 本檔內容自 SKILL.md「Step 9：上傳 vCard 到 drive.streetvoice.com/vcard/」搬出（逐字保留）。

> **中子版**：整段跳過（沒產 vCard 就不用上傳）。Step 8 收尾後流程結束。

**9a. 預查 server 是否已有同名檔（必跑）**
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard --check-only "$DEST_DIR/<無空格英文名>.vcf"
```
腳本走「拿密碼 + preflight + curl --list-only」流程，不上傳。最後一行印：
- `exists` → 進 **9b GATE**
- `new` → 跳到 **9c 直接上傳**
- 異常（找不到 favorite / 密碼錯）→ 同 9c 處理，由 upload 內邏輯接管

**9b. 🛑 GATE — 偵測到重複時詢問**（僅 `exists` 觸發）

Claude 用此句問使用者（**逐字**，把實際檔名代入）：

> **`<無空格英文名>.vcf` 偵測到相同檔案，請問是否覆蓋？**

- 使用者回 OK / 是 / 覆蓋 → 進 9c
- 使用者回否定 → 跳過 Step 9（vcf 仍在本地 `$DEST_DIR/`，未來可手動跑上傳）

**9c. 上傳（含 retry 邏輯）**
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh upload-vcard "$DEST_DIR/<無空格英文名>.vcf"
```

> **內部流程**：
> 1. 取得密碼：Keychain 有就用；沒有 → 跳 dialog 要密碼 → 存 Keychain
> 2. **preflight 登入檢查**（curl --list-only noop）
>    - 失敗 → 自動刪 Keychain 密碼 + 跳 dialog 重輸 → 再 preflight 一次
>    - 仍失敗 → 印「請洽產品工程部」+ exit 1
> 3. **STOR + retry 一次**：第一次 STOR 失敗 sleep 1 秒再試（ProFTPD 偶有 transient 550，retry 幾乎都會 work）

**9c 結果分支**：

| 印出 | Claude 轉達 |
|---|---|
| `✅ vCard 已上傳 server [並覆蓋舊檔]` + URL | 「✅ vCard 已上傳並驗證成功」+ URL（建議續跑 9d 驗證確認 server 端沒被別人覆蓋回去）|
| `❌ 登入仍失敗` | 「❌ 登入失敗，請洽產品工程部協助確認帳號權限」|
| `❌ STOR 兩次都失敗` | **「❌ 上傳失敗（[Claude 評估當下可能原因]），手動上傳 vcard 至 transmit 覆蓋舊檔。完成後告知我，我會驗證 server」** → 等使用者完成後進 9d |

> **不採 DELE-then-STOR**：實測使用者對「owner 非自己」的檔有 STOR 覆寫權限但沒 DELE 權限，DELE 路徑根本走不通。

**9d. 驗證手動上傳結果**（9c 失敗後使用者手動 Transmit 上傳完，告知 Claude 後跑）
```bash
~/.claude/skills/sv-card/scripts/card_helper.sh verify-vcard "$DEST_DIR/<無空格英文名>.vcf"
```
腳本抓 server 上同名 vcf 內容 cmp 對本地，印：
- `match` → Claude 轉達「✅ vCard 已驗證 server 端與本地一致」+ URL
- `mismatch` → Claude 轉達「❌ 上傳失敗（server 端內容與本地不同，可能被其他人覆蓋），請洽產品工程部協助確認」
- `missing` → Claude 轉達「❌ 上傳失敗（server 上找不到該檔案），請洽產品工程部協助確認」

> 為什麼要驗證：`9c ✅ 上傳成功` 訊息可能 false positive — 實測過 STOR 226 Transfer complete 後，server 端檔案被其他 process / 真實 owner 覆蓋回原版。verify-vcard 用 cmp 二進位比對才能確認 server 端真的是您上傳的內容。

> Step 9 upload-vcard 已自動印出「vCard 已上傳 server [並覆蓋舊檔]」+ 公開 URL，收尾時把這兩行轉達給使用者即可。

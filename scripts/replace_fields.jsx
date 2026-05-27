// StreetVoice 名片：替換 7 個 PH_* 欄位 + 自動存檔
//
// 用法：
//
//   A. 從 sidecar JSON 讀（推薦，由 card_helper.sh init 寫入）：
//      $.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/replace_fields.jsx");
//      → 讀 /tmp/sv_card_fields.json 的 fields 區塊（或 $.global.SIDECAR_PATH 覆寫）
//
//   B. 手動覆寫 $.global.FIELDS（emergency override，需先確保 sidecar 不存在）：
//      $.global.FIELDS = { PH_NAME_CN_SURNAME: "王", ... };
//      $.evalFile(...);
//
// 來源優先級：**sidecar > $.global.FIELDS**（sidecar 是當前流程的權威來源，
// $.global.FIELDS 在 Illustrator session 內會殘留前次設定，不可作為預設來源）
//
// 行為：
//   1. 讀來源 → 對每個 key 在 textFrames 找同名 TextFrame 替換 contents
//   2. 找不到 → 累積到 missing 列表，全部處理完才一次回報（不 throw 中斷）
//   3. 替換完 app.activeDocument.save()
//   4. 順手清 $.global.FIELDS = null，避免汙染下次執行
//
// 回傳：成功 → "OK replaced=N source=sidecar|global"；有缺欄 → "ERROR: missing PH_X, PH_Y"

(function() {
    // 帶到前景，避免 macOS 對背景 GUI app 限速
    try { BridgeTalk.bringToFront(BridgeTalk.appName); } catch (e) {}

    var fields = null;
    var source = "";

    // 1. 優先讀 sidecar
    var sidecarPath = $.global.SIDECAR_PATH || "/tmp/sv_card_fields.json";
    var f = new File(sidecarPath);
    if (f.exists) {
        f.encoding = "UTF-8";
        f.open("r");
        var content = f.read();
        f.close();
        // ExtendScript 沒原生 JSON.parse，用 eval 包成表達式
        var data;
        try { data = eval("(" + content + ")"); }
        catch (e) { return "ERROR: sidecar parse failed: " + e.message; }
        fields = data.fields || data;
        source = "sidecar";
    } else if ($.global.FIELDS) {
        // 2. Fallback：手動覆寫
        fields = $.global.FIELDS;
        source = "global";
    } else {
        return "ERROR: no sidecar " + sidecarPath + " and no $.global.FIELDS";
    }

    var d = app.activeDocument;
    if (!d) { return "ERROR: no active document"; }

    // 建 name → TextFrame 索引（避免每個欄位都全表掃一遍）
    var idx = {};
    for (var i = 0; i < d.textFrames.length; i++) {
        var tf = d.textFrames[i];
        if (tf.name) { idx[tf.name] = tf; }
    }

    var replaced = 0;
    var missing = [];
    for (var key in fields) {
        if (!fields.hasOwnProperty(key)) { continue; }
        var target = idx[key];
        if (target) {
            target.contents = String(fields[key]);
            replaced++;
        } else {
            missing.push(key);
        }
    }

    if (missing.length > 0) {
        return "ERROR: missing " + missing.join(", ");
    }

    d.save();
    // 清掉 $.global.FIELDS，避免下次執行如果 sidecar 缺席時誤用殘留值
    $.global.FIELDS = null;
    return "OK replaced=" + replaced + " source=" + source;
})();

// StreetVoice 名片：替換 7 個 PH_* 欄位 + 自動存檔
//
// 用法：
//   $.global.FIELDS = {
//       PH_NAME_CN_SURNAME: "王",
//       PH_NAME_CN_GIVEN:   "小明",
//       PH_NAME_EN:         "Ming Wang",
//       PH_TITLE:           "美術設計",
//       PH_PHONE_OFFICE:    "+886-2-2741-7065#XXX",
//       PH_PHONE_MOBILE:    "+886-900-000-000",
//       PH_EMAIL:           "mingwang@streetvoice.com"
//   };
//   $.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/replace_fields.jsx");
//
// 行為：
//   1. 對 FIELDS 內每個 key，在 textFrames 找同名 TextFrame 並替換 contents
//   2. 找不到 → 累積到 missing 列表，**全部處理完才一次回報**（不 throw 中斷）
//   3. 替換完 app.activeDocument.save()
//
// 回傳：成功 → "OK replaced=N"；有缺欄 → "ERROR: missing PH_X, PH_Y"

(function() {
    var fields = $.global.FIELDS;
    if (!fields) { return "ERROR: FIELDS not set"; }

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
    return "OK replaced=" + replaced;
})();

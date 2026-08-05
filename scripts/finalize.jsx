// StreetVoice 名片：GATE 後收尾合併
//
// 用法：
//   $.global.FINALIZE_OPTS = {
//       originalTmp: "/tmp/output_original.ai",  // 原檔暫存路徑
//       olTmp:       "/tmp/output_ol.ai"          // OL CS6 暫存路徑
//   };
//   $.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/finalize.jsx");
//
// 取代原本 GATE 後的 2 個 mcp__illustrator__run 呼叫：
//   1. 清殘留 + saveAs original.ai
//   2. createOutline 全部 textFrames + saveAs OL CS6
//
// 一次跑完，減少 mcp call 次數。中文路徑問題仍由外層 card_helper.sh finalize 用 mv 處理。
//
// 回傳：成功 → "OK removed=N original=path ol=path"；失敗 → "ERROR: ..."

(function() {
    // 帶到前景，避免 macOS 對背景 GUI app 限速（saveAs 大檔特別明顯）
    try { BridgeTalk.bringToFront(BridgeTalk.appName); } catch (e) {}

    var opts = $.global.FINALIZE_OPTS || {};
    var originalTmp = opts.originalTmp || "/tmp/output_original.ai";
    var olTmp = opts.olTmp || "/tmp/output_ol.ai";

    var d = app.activeDocument;
    if (!d) { return "ERROR: no active document"; }

    // 讀 sidecar 拿 template_type（v0.10.3+：中子版要跳過清殘留；v0.12.0+ 含台灣中子）
    var templateType = "tw";
    try {
        var sf = new File("/tmp/sv_card_fields.json");
        if (sf.exists) {
            sf.encoding = "UTF-8";
            sf.open("r");
            var sc = sf.read();
            sf.close();
            var sd = eval("(" + sc + ")");
            if (sd && sd.template_type) templateType = sd.template_type;
        }
    } catch (e) {}

    // 1. 清殘留（位置或尺寸超出 1000 的物件，通常是 SVG 匯入殘留）
    //    v0.10.3+：中子系列跳過 — 中子模板有 16383×16383 clip group 內含 PH_*，
    //    清殘留會連帶刪掉 PH_* TextFrame 造成名片資訊全失；且中子系列跳過 Step 3/4
    //    本就無 SVG 殘留可清。v0.12.0+ 改判「僅 tw 才清」，涵蓋 zhongzi-bvi / zhongzi-taiwan
    var removedCount = 0;
    if (templateType === "tw") {
        var top = d.layers[0].pageItems;
        var toRemove = [];
        for (var i = 0; i < top.length; i++) {
            var it = top[i];
            if (Math.abs(it.position[0]) > 1000 || Math.abs(it.position[1]) > 1000
                || it.width > 1000 || it.height > 1000) {
                toRemove.push(it);
            }
        }
        removedCount = toRemove.length;
        for (var j = 0; j < toRemove.length; j++) { toRemove[j].remove(); }
    }

    // 2. saveAs 原檔到 /tmp（中文路徑會 8700，外層用 mv 搬）
    var origOpts = new IllustratorSaveOptions();
    origOpts.pdfCompatible = true;
    origOpts.compressed = true;
    d.saveAs(new File(originalTmp), origOpts);

    // 3. 外框化所有 textFrames
    for (var k = d.textFrames.length - 1; k >= 0; k--) {
        d.textFrames[k].createOutline();
    }

    // 4. saveAs OL CS6 到 /tmp
    var olOpts = new IllustratorSaveOptions();
    olOpts.pdfCompatible = true;
    olOpts.compressed = true;
    olOpts.compatibility = Compatibility.ILLUSTRATOR16;
    d.saveAs(new File(olTmp), olOpts);

    // v0.16.2：收尾後關閉此暫存文件（OL 版已存磁碟，Step 8 用 bash mv 搬走）。
    // 避免連續做名片時 Illustrator 殘留文件累積 → 下一張 init 的 open 被既有文件攔截
    // （current document 變成別的檔）。只關自己這份，不動使用者其他開著的工作檔。
    var closed = "no";
    try { d.close(SaveOptions.DONOTSAVECHANGES); closed = "yes"; } catch (e) {}

    return "OK removed=" + removedCount + " template=" + templateType
        + " original=" + originalTmp + " ol=" + olTmp + " closed=" + closed;
})();

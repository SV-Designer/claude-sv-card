// StreetVoice 名片：QR Code 置入 + 染色
//
// 用法：
//   $.global.QR_OPTS = {
//       svgPath: "/tmp/qr_processed.svg",   // 已剝 id="bg" 的 SVG
//       sizeCm: 1.4,                         // 目標尺寸（cm）
//       cmykBlack: 88                        // K 值 (0~100)；C/M/Y 強制為 0
//   };
//   $.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/place_qr.jsx");
//
// 前置條件：活動文件中必須有命名為 "PH_QRCODE" 的 placeholder（GroupItem / PathItem / 任意 PageItem 皆可）
//
// 行為：
//   1. 找 PH_QRCODE → 記中心點 → 移除
//   2. 開 SVG → 跨文件 duplicate 所有 items → group
//   3. 縮放到 sizeCm × sizeCm，定位到原中心點
//   4. 全部 fill 染成 CMYK(0,0,0,K)，BringToFront
//   5. 將新 group 重新命名為 PH_QRCODE
//
// 回傳：成功 → "OK pos=x,y size=sz"；失敗 → "ERROR: ..."

// ── v0.26.0：整支包 try/catch ＋ 落 log ──────────────────────────
// 為什麼：ExtendScript 出錯時 MCP 只會回一句籠統訊息，看不出是哪一行、哪個階段掛掉；
//        以前只能靠人重跑一次猜。現在錯誤會帶行號回傳，並附加到 /tmp/sv_card_jsx.log，
//        做完名片如果哪裡怪，直接看那支 log 就知道每一步回了什麼。
// log 只寫 /tmp，不影響任何產出檔；寫 log 自己失敗也被吞掉，絕不會拖垮名片流程。
(function() {
    var __result;
    try {
        __result = (function() {

            // 帶到前景，避免 macOS 對背景 GUI app 限速（特別是 app.open + executeMenuCommand）
            try { BridgeTalk.bringToFront(BridgeTalk.appName); } catch (e) {}

            var opts = $.global.QR_OPTS;
            if (!opts) { return "ERROR: QR_OPTS not set"; }
            if (!opts.svgPath) { return "ERROR: QR_OPTS.svgPath missing"; }

            var sizeCm = (typeof opts.sizeCm === "number") ? opts.sizeCm : 1.4;
            var kVal = (typeof opts.cmykBlack === "number") ? opts.cmykBlack : 88;

            var d = app.activeDocument;

            // 1. 找 PH_QRCODE placeholder
            var oldQR = null;
            var top = d.layers[0].pageItems;
            for (var i = 0; i < top.length; i++) {
                if (top[i].name === "PH_QRCODE") { oldQR = top[i]; break; }
            }
            if (!oldQR) { return "ERROR: PH_QRCODE placeholder not found"; }

            var cx = oldQR.position[0] + oldQR.width / 2;
            var cy = oldQR.position[1] - oldQR.height / 2;
            oldQR.remove();

            // 2. 開 SVG → 跨文件 duplicate
            var svgFile = new File(opts.svgPath);
            if (!svgFile.exists) { return "ERROR: SVG not found: " + opts.svgPath; }

            var svgDoc = app.open(svgFile);
            var svgItems = svgDoc.layers[0].pageItems;
            var dupItems = [];
            for (var j = svgItems.length - 1; j >= 0; j--) {
                dupItems.push(svgItems[j].duplicate(d.layers[0], ElementPlacement.PLACEATEND));
            }
            app.activeDocument = d;
            d.selection = dupItems;
            app.executeMenuCommand("group");
            var newQR = d.selection[0];

            // 3. 尺寸 + 定位
            var sz = sizeCm * (72 / 2.54); // cm → pt（1 inch = 72pt = 2.54cm，寫成算式才看得出來歷）
            newQR.width = sz;
            newQR.height = sz;
            newQR.position = [cx - sz / 2, cy + sz / 2];
            newQR.name = "PH_QRCODE";

            svgDoc.close(SaveOptions.DONOTSAVECHANGES);

            // 4. 染色 CMYK K=kVal
            var dark = new CMYKColor();
            dark.cyan = 0; dark.magenta = 0; dark.yellow = 0; dark.black = kVal;

            function paint(it) {
                if (it.typename === "PathItem") {
                    if (it.filled) it.fillColor = dark;
                } else if (it.typename === "CompoundPathItem") {
                    for (var i = 0; i < it.pathItems.length; i++) {
                        if (it.pathItems[i].filled) it.pathItems[i].fillColor = dark;
                    }
                } else if (it.typename === "GroupItem") {
                    for (var i = 0; i < it.pageItems.length; i++) {
                        paint(it.pageItems[i]);
                    }
                }
            }
            paint(newQR);
            newQR.zOrder(ZOrderMethod.BRINGTOFRONT);

            return "OK pos=" + newQR.position[0].toFixed(2) + "," + newQR.position[1].toFixed(2) +
                   " size=" + newQR.width.toFixed(2);
        })();
    } catch (__e) {
        __result = "ERROR: place_qr.jsx line " + (__e.line || "?") + ": " + (__e.message || __e);
    }
    try {
        var __lf = new File("/tmp/sv_card_jsx.log");
        __lf.encoding = "UTF-8"; __lf.lineFeed = "Unix";
        __lf.open("a"); __lf.writeln("[place_qr.jsx] " + __result); __lf.close();
    } catch (__e2) {}
    return __result;
})();

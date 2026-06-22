// StreetVoice 名片產生器
// 透過設定 global var CARD_DATA = {...} 後再 evalFile 執行
// 例:
//   $.global.CARD_DATA = { chineseName: "王小明", englishName: "阿明 Ming Wang", title: "美術設計", extension: "#XXX", mobile: "0909-050-269", email: "mingwang@streetvoice.com" };
//   $.evalFile(Folder("~").fsName + "/.claude/skills/sv-card/scripts/make_card.jsx");

(function() {
    var d = app.activeDocument;
    var data = $.global.CARD_DATA;
    if (!data) { return "ERROR: CARD_DATA not set"; }

    // 將手機 0909-050-269 / 0909050269 → +886-909-050-269
    function fmtMobile(m) {
        var n = "";
        for (var i = 0; i < m.length; i++) {
            var ch = m.charAt(i);
            if (ch >= "0" && ch <= "9") n += ch;
        }
        if (n.charAt(0) === "0") n = n.substring(1);
        return "+886-" + n.substring(0,3) + "-" + n.substring(3,6) + "-" + n.substring(6);
    }

    // 替換姓名物件並保留分段字級
    // 慣例: 中文「姓 名」12pt + 空格 + 英文 7pt
    function setName(t, cn, en) {
        var surname = cn.charAt(0);
        var rest = cn.substring(1);
        var cnFmt = surname + " " + rest;
        var fullText = cnFmt + " " + en;
        var cnSize = t.characters[0].characterAttributes.size;
        var enSize = t.characters[t.characters.length - 1].characterAttributes.size;
        t.contents = fullText;
        var boundary = cnFmt.length + 1; // 含中英之間那個空格
        for (var i = 0; i < t.characters.length; i++) {
            t.characters[i].characterAttributes.size = (i < boundary) ? cnSize : enSize;
        }
    }

    // 對應表（根據先前的探索結果）
    var IDX_PHONE = 0;
    var IDX_EMAIL = 1;
    var IDX_TITLE = 2;
    var IDX_NAME = 9;

    var LF = String.fromCharCode(10);
    var officePhone = "+886-2-2741-7065" + data.extension;
    var mobile = fmtMobile(data.mobile);

    setName(d.textFrames[IDX_NAME], data.chineseName, data.englishName);
    d.textFrames[IDX_TITLE].contents = data.title;
    d.textFrames[IDX_PHONE].contents = officePhone + LF + mobile;
    d.textFrames[IDX_EMAIL].contents = data.email;

    // 用完整選項的 saveAs 取代 save()，避免彈出對話框
    var saveOpts = new IllustratorSaveOptions();
    saveOpts.compatibility = Compatibility.ILLUSTRATOR17; // 對應 CC 2013+，所有現代 AI 都能開
    saveOpts.pdfCompatible = true;
    saveOpts.embedICCProfile = true;
    saveOpts.compressed = true;
    var currentPath = d.fullName;
    d.saveAs(currentPath, saveOpts);

    return "OK: " + d.textFrames[IDX_NAME].contents +
        " / title=" + d.textFrames[IDX_TITLE].contents +
        " / phone=" + officePhone + "|" + mobile +
        " / email=" + d.textFrames[IDX_EMAIL].contents;
})();

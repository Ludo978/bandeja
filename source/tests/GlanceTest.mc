import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The glance: the last saved match, "Last: W 6-4 6-3 · 1h12", from one small value written
// with its history record (LastMatch), never the history itself; a line saying no match was played yet
// when there's none. The tests put the simulator's stored history and glance value back when they're
// done.

(:test)
function glanceLinesTest(logger as Logger) as Boolean {
    // The line: the result's letter and each set's score as the history list writes them (none for a
    // match saved unfinished, the set the match ended in starred), then the duration as the history
    // list has it (left out when the watch gave no timer). Then the same line with the sets won, which
    // the glance shows when the score is too wide for it.
    var won = GlanceTests.text(Rez.Strings.HistoryWon);
    var lost = GlanceTests.text(Rez.Strings.HistoryLost);
    var draw = GlanceTests.text(Rez.Strings.HistoryDraw);
    var dot = LastMatch.SEPARATOR;
    var cases = [
        [new MatchConfig(), "UTUTUTUTUU UTUTUTUUU", null, 4320, won + " 6-4 6-3" + dot + "1h12", won + " 2 - 0" + dot + "1h12"],
        [new MatchConfig(), "UUUUUU TTTTTT TTTTTT", null, 2939, lost + " 6-0 0-6 0-6" + dot + "48 min",
            lost + " 1 - 2" + dot + "48 min"],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u", null, 5050,
            won + " 6-4 3-6 10-8" + dot + "1h24", won + " 2 - 1" + dot + "1h24"],
        [new MatchConfig(), "UUUUUU TTTTTT UTUT", EVENT_END_MATCH, 3600, draw + " 6-0 0-6 2-2*" + dot + "1h00",
            draw + " 1 - 1" + dot + "1h00"],
        [new MatchConfig(), "UTUTUTUTUU UTu", null, 1800, "6-4 1-1*" + dot + "30 min", "1 - 0" + dot + "30 min"],
        [new MatchConfig(), "UTUTUTUTUU UTUTUTUUU", null, null, won + " 6-4 6-3", won + " 2 - 0"],
        [TestKit.preset(PRESET_BEST_OF_5), "UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU", null, 9000,
            won + " 6-0 0-6 6-0 0-6 6-0" + dot + "2h30", won + " 3 - 2" + dot + "2h30"]
    ];
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        for (var i = 0; i < cases.size(); i++) {
            var c = cases[i];
            var record = GlanceTests.record(c[0] as MatchConfig, c[1] as String, c[2] as EventType?);
            record.timer = c[3] as Number?;
            HistoryStore.add(record);
            var lines = LastMatch.lines(LastMatch.read());
            Test.assertEqualMessage(lines.size(), 2, "case " + i);
            Test.assertEqualMessage(lines[0], GlanceTests.last(c[4] as String), "case " + i);
            Test.assertEqualMessage(lines[1], GlanceTests.last(c[5] as String), "case " + i);
            // The history list's own line: its label, then the duration of its sublabel.
            var label = HistoryText.label(record);
            var timer = record.timer;
            Test.assertEqualMessage(lines[0], GlanceTests.last(timer != null ? label + dot + HistoryText.duration(timer) : label),
                "case " + i);
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    // The result codes the glance knows are the stored ones.
    Test.assert(LastMatch.WIN == RESULT_WIN && LastMatch.LOSS == RESULT_LOSS && LastMatch.DRAW == RESULT_DRAW);
    // The task's example, in English.
    if (GlanceTests.text(Rez.Strings.HistoryWon).equals("W")) {
        Test.assertEqual(LastMatch.lines([RESULT_WIN, "6-4 6-3", "2 - 0", 4320])[0], "Last: W 6-4 6-3 · 1h12");
    }
    return true;
}

(:test)
function glanceEmptyTest(logger as Logger) as Boolean {
    // No match saved yet, or a value that can't be read: the one line saying no match was played yet,
    // never a crash. A value with more than the glance reads (a later version's) still shows, and a
    // result it doesn't know shows no letter.
    var empty = [GlanceTests.text(Rez.Strings.HistoryEmpty)];
    var bad = [null, "W 6-4", 3, [], [RESULT_WIN, "6-4", "1 - 0"], ["1", "6-4", "1 - 0", 60], [RESULT_WIN, 64, "1 - 0", 60],
        [RESULT_WIN, "6-4", null, 60], [RESULT_WIN, "6-4", "1 - 0", "60"], [RESULT_WIN, "6-4", "1 - 0", 60.5],
        {"result" => RESULT_WIN}];
    for (var i = 0; i < bad.size(); i++) {
        var lines = LastMatch.lines(bad[i] as Object?);
        Test.assertMessage(lines.size() == 1 && lines[0].equals(empty[0]), "value " + i);
    }
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        Test.assert(LastMatch.read() == null);
        Test.assertEqual(LastMatch.lines(LastMatch.read())[0], empty[0]);
        for (var i = 0; i < bad.size(); i++) {
            var value = bad[i];
            if (value == null) {
                Application.Storage.deleteValue(LastMatch.KEY);
            } else {
                Application.Storage.setValue(LastMatch.KEY, value as Application.Storage.ValueType);
            }
            var lines = LastMatch.lines(LastMatch.read());
            Test.assertMessage(lines.size() == 1 && lines[0].equals(empty[0]), "stored " + i);
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    var won = GlanceTests.text(Rez.Strings.HistoryWon);
    Test.assertEqual(LastMatch.lines([RESULT_WIN, "6-4", "1 - 0", 60, "later"])[0], GlanceTests.last(won + " 6-4" + LastMatch.SEPARATOR + "1 min"));
    Test.assertEqual(LastMatch.lines([7, "6-4", "1 - 0", null])[0], GlanceTests.last("6-4"));
    Test.assertEqual(LastMatch.lines([RESULT_WIN, "6-4", "1 - 0", -5])[0], GlanceTests.last(won + " 6-4" + LastMatch.SEPARATOR + "0 min"));
    return true;
}

(:test)
function glanceInStepTest(logger as Logger) as Boolean {
    // The glance's value is written with the history record, so the glance always shows the history's
    // newest match: after each save, past 20 matches, not for a match saved before its first point
    // (not kept), and gone when the debug menu clears the history; the debug menu's full history shows
    // its newest match.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        var first = HistoryTests.record(new MatchConfig(), "UTUTUTUTUU UTUTUTUUU");
        first.timer = 4320;
        HistoryStore.add(first);
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(first));
        var second = HistoryTests.record(TestKit.preset(PRESET_ONE_SET), "TTTTTT");
        second.timer = 1500;
        HistoryStore.add(second);
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(second));
        var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
        rig.add(EVENT_END_MATCH, null);
        HistoryStore.add(HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY));
        Test.assertEqual(HistoryStore.load().size(), 2);
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(second));
        for (var i = 0; i < HistoryStore.MAX_RECORDS; i++) {
            var record = i % 2 == 0 ? first : second;
            record.start = TestKit.T0 + 3600 * i;
            HistoryStore.add(record);
            Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(record));
        }
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(HistoryStore.load()[0]));
        HistoryStore.clear();
        Test.assert(LastMatch.read() == null && HistoryStore.read() == null);
        HistoryFixtures.fill();
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(HistoryStore.load()[0]));
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(HistoryFixtures.records(TestKit.T0)[0]));
        HistoryStore.clear();
        Test.assert(LastMatch.read() == null);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function glanceOlderHistoryTest(logger as Logger) as Boolean {
    // A history saved by a version before the glance has no glance value: at the app's start, its newest
    // record that can be read gives it, once. A glance value already there stays; no history, no value.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        HistoryStore.restoreLast();
        Test.assert(LastMatch.read() == null);
        var older = HistoryTests.record(new MatchConfig(), "UUUUUU UUUUUT uuuu");
        var newer = HistoryTests.record(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u");
        newer.timer = 5050;
        Application.Storage.setValue(HistoryStore.KEY, [newer.toValue(), older.toValue()] as Array<Application.Storage.ValueType>);
        HistoryStore.restoreLast();
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(newer));
        // Already there: left as it is.
        Application.Storage.setValue(HistoryStore.KEY, [older.toValue()] as Array<Application.Storage.ValueType>);
        HistoryStore.restoreLast();
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(newer));
        // The newest can't be read: the next one gives it.
        Application.Storage.deleteValue(LastMatch.KEY);
        Application.Storage.setValue(HistoryStore.KEY, ["bad", older.toValue()] as Array<Application.Storage.ValueType>);
        HistoryStore.restoreLast();
        Test.assertEqual(GlanceTests.shown(), GlanceTests.linesOf(older));
        // None can be read: no value.
        Application.Storage.deleteValue(LastMatch.KEY);
        Application.Storage.setValue(HistoryStore.KEY, ["bad"] as Array<Application.Storage.ValueType>);
        HistoryStore.restoreLast();
        Test.assert(LastMatch.read() == null);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function glanceSizeTest(logger as Logger) as Boolean {
    // The glance's sizes on this screen, in the area the watch gives it: Bandeja as high as
    // the native glances' titles (the system glance font), within the area, over the line; the line
    // within the area too, at its size or by its fallbacks (it shrinks, down to three quarters of its
    // size, then shows the sets won). In English and in French, whatever language the tests run in.
    var area = GlanceTests.area();
    var width = area[0];
    var height = area[1];
    var dc = (Graphics.createBufferedBitmap({:width => width, :height => height}).get() as Graphics.BufferedBitmap).getDc();
    var scale = BandejaGlance.scale(height);
    var top = BandejaGlance.top(height);
    // On the FR265 and FR265S the glance font is the mockup's title scaled to the area's height, so the
    // mockup fills the area from its top. Elsewhere it never grows past the height, centered in it.
    if (width == 275 || width == 240) {
        Test.assert(scale == height / BandejaGlance.HEIGHT && top == 0.0);
    }
    Test.assert(scale <= height / BandejaGlance.HEIGHT && top >= 0.0);
    var title = BandejaGlance.titleFont();
    Test.assertEqual(Graphics.getFontHeight(title), Graphics.getFontHeight(Graphics.FONT_GLANCE));
    var name = GlanceTests.text(Rez.Strings.AppName);
    Test.assert(dc.getTextWidthInPixels(name, title) <= width);
    var titleBaseline = top + BandejaGlance.TITLE_BASELINE * scale;
    Test.assert(titleBaseline - Graphics.getFontAscent(title) >= 0);
    var size = BandejaGlance.LINE_SIZE * scale;
    var line = BandejaGlance.font(size);
    // The line's capitals start below the title's descender (the j of Bandeja), and its descenders
    // ("yet") end in the area.
    Test.assert(top + (BandejaGlance.LINE_BASELINE - Fonts.CAP_MIDDLE * 2 * BandejaGlance.LINE_SIZE) * scale
        > titleBaseline + Graphics.getFontDescent(title));
    Test.assert(top + BandejaGlance.LINE_BASELINE * scale + Graphics.getFontDescent(line) <= height);
    // The lines as LastMatch writes them in either language (checked against the language running),
    // then what the glance shows of them: whole at full size (0), the score at full size or smaller
    // (1), the sets won (2), or either as long as it fits (3).
    var own = LastMatch.lines([RESULT_LOSS, "0-6 4-6", "0 - 2", 3480])[0];
    Test.assert(own.equals("Last: L 0-6 4-6 · 58 min") || own.equals("Dernier : D 0-6 4-6 · 58 min"));
    var cases = [
        // Two sets, in either language: the user's line from the watch, the mockup's.
        [["Last: L 0-6 4-6 · 58 min", "Last: L 0 - 2 · 58 min"], 0],
        [["Dernier : D 0-6 4-6 · 58 min", "Dernier : D 0 - 2 · 58 min"], 0],
        [["Last: W 6-4 6-3 · 1h12", "Last: W 2 - 0 · 1h12"], 0],
        [["Dernier : V 6-4 6-3 · 1h12", "Dernier : V 2 - 0 · 1h12"], 0],
        [["Dernier : 6-3 2-1* · 48 min", "Dernier : 1 - 0 · 48 min"], 0],
        // Three sets: whole in English; in French, the score, smaller.
        [["Last: L 6-4 3-6 8-10 · 1h24", "Last: L 1 - 2 · 1h24"], 0],
        [["Last: L 6-7 7-6 13-15 · 1h24", "Last: L 1 - 2 · 1h24"], 0],
        [["Dernier : D 6-4 3-6 8-10 · 1h24", "Dernier : D 1 - 2 · 1h24"], 1],
        [["Dernier : N 6-4 4-6 2-2* · 1h08", "Dernier : N 1 - 1 · 1h08"], 1],
        [["Dernier : D 6-7 7-6 13-15 · 1h24", "Dernier : D 1 - 2 · 1h24"], 1],
        // A best of 5: its score smaller, or the sets won.
        [["Last: W 6-4 3-6 7-6 4-6 6-2 · 2h30", "Last: W 3 - 2 · 2h30"], 3],
        [["Dernier : V 6-4 3-6 7-6 4-6 6-2 · 2h30", "Dernier : V 3 - 2 · 2h30"], 3],
        [["Last: L 12-10 10-12 14-12 11-13 16-14 · 2h30", "Last: L 2 - 3 · 2h30"], 2],
        [["Dernier : D 12-10 10-12 14-12 11-13 16-14 · 2h30", "Dernier : D 2 - 3 · 2h30"], 2],
        // A long Free play (the sets won at once), and no match yet.
        [["Last: W 29 - 19 · 0 min", "Last: W 29 - 19 · 0 min"], 0],
        [["Dernier : V 29 - 19 · 0 min", "Dernier : V 29 - 19 · 0 min"], 0],
        [["No matches yet"], 0],
        [["Aucun match"], 0]
    ];
    // The line keeps clear of the Instinct 3 AMOLED's window (lineWidth()): there it only has to fit. The
    // watches of 1.2 have areas taller for their width, where a line whole at full size elsewhere may
    // shrink (measured: a two-set match in French on the Venu 2, 2 Plus, 2S and 3S, the vivoactive 5,
    // the D2 Air X10 and the Approach S50, by one or two pixels of em size).
    var lineWidth = BandejaGlance.lineWidth(dc);
    for (var i = 0; i < cases.size(); i++) {
        var lines = cases[i][0] as Array<String>;
        var shown = lineWidth == width ? cases[i][1] as Number : 3;
        if (shown == 0 && GlanceTests.isLater()) {
            shown = 1;
        }
        var fitted = BandejaGlance.fit(dc, lines, size);
        Test.assertMessage(dc.getTextWidthInPixels(lines[fitted[0]], fitted[2]) <= lineWidth, "case " + i);
        if (shown == 0) {
            Test.assertMessage(fitted[0] == 0 && fitted[1] == size, "case " + i);
        } else if (shown == 1) {
            Test.assertMessage(fitted[0] == 0 && fitted[1] >= size * 3 / 4, "case " + i);
        } else if (shown == 2) {
            Test.assertMessage(fitted[0] == 1 && fitted[1] == size, "case " + i);
        }
    }
    return true;
}

(:test :noScoreButtons)
function glanceRoundEdgeTest(logger as Logger) as Boolean {
    // The watches added in 1.2 draw their glance at the top of the round screen, and their areas reach
    // its right edge: the line ends 4 px inside the circle at the top of its capitals. The geometry first:
    // a 416 px screen (radius 208), the area's left at x 128 and its top at y 8. A row 78.6 px down the
    // area is 121.4 px above the screen's middle, where the circle is 168.9 px wide each side of it: it
    // ends at x 376.9, 248.9 px into the area, 244 with the margin. From the screen's middle down the
    // circle's own right end, 416: 284 px into the area with the margin.
    Test.assertEqual(BandejaGlance.roundEnd(416, 128, 8, 78.6), 244);
    Test.assertEqual(BandejaGlance.roundEnd(416, 128, 8, 200.0), 284);
    Test.assertEqual(BandejaGlance.roundEnd(416, 128, 8, 300.0), 284);
    // A higher row ends sooner, and so does an area further right.
    Test.assert(BandejaGlance.roundEnd(416, 128, 8, 60.0) < 244 && BandejaGlance.roundEnd(416, 138, 8, 78.6) == 234);
    // Each 1.2 watch's area has its place on the screen; another area has none, and no limit.
    var later = GlanceTests.laterAreas().values();
    for (var i = 0; i < later.size(); i++) {
        Test.assertMessage(BandejaGlance.areaOrigin(later[i][0], later[i][1]) != null, later[i][0] + " x " + later[i][1]);
    }
    Test.assert(BandejaGlance.areaOrigin(275, 120) == null && BandejaGlance.roundLimit(275, 120) == 275);
    var venu2 = BandejaGlance.areaOrigin(288, 133) as [Number, Number];
    Test.assert(venu2[0] == 128 && venu2[1] == 8);
    // This watch: the line's width is the area's or the circle's end, whichever comes first, never
    // less than half the area, and every line the glance shows ends within it.
    var area = GlanceTests.area();
    var width = area[0];
    var height = area[1];
    var dc = (Graphics.createBufferedBitmap({:width => width, :height => height}).get() as Graphics.BufferedBitmap).getDc();
    var limit = BandejaGlance.roundLimit(width, height);
    var lineWidth = BandejaGlance.lineWidth(dc);
    Test.assertEqual(lineWidth, limit < width ? limit : width);
    Test.assert(lineWidth > width / 2 && lineWidth <= width);
    var origin = BandejaGlance.areaOrigin(width, height) as [Number, Number];
    var row = BandejaGlance.top(height)
        + (BandejaGlance.LINE_BASELINE - BandejaGlance.CAP_HEIGHT * BandejaGlance.LINE_SIZE) * BandejaGlance.scale(height);
    Test.assertEqual(limit, BandejaGlance.roundEnd(System.getDeviceSettings().screenWidth, origin[0], origin[1], row));
    var size = BandejaGlance.LINE_SIZE * BandejaGlance.scale(height);
    var shown = [["Dernier : V 6-4 6-3 · 1h08", "Dernier : V 2 - 0 · 1h08"], ["Last: W 6-4 6-3 · 1h08", "Last: W 2 - 0 · 1h08"],
        ["Dernier : D 0-6 4-6 · 58 min", "Dernier : D 0 - 2 · 58 min"]];
    for (var i = 0; i < shown.size(); i++) {
        var fitted = BandejaGlance.fit(dc, shown[i], size);
        Test.assertMessage(dc.getTextWidthInPixels(shown[i][fitted[0]], fitted[2]) <= lineWidth, "line " + i);
    }
    return true;
}

(:test)
module GlanceTests {

    // The stored values the glance tests change.
    function keys() as Array<String> {
        return [HistoryStore.KEY, LastMatch.KEY];
    }

    // A match played with serve tracking (Me serving first), then the event that ends it early (or
    // none), saved with no activity values.
    function record(config as MatchConfig, moves as String, end as EventType?) as HistoryRecord {
        var rig = new TestKit.Rig(config, "Me", false);
        rig.play(moves);
        if (end != null) {
            rig.add(end, null);
        }
        return HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY);
    }

    // The glance's lines for a record, as its value gives them, joined.
    function linesOf(record as HistoryRecord) as String {
        return join(LastMatch.lines(HistoryText.glanceValue(record)));
    }

    // The glance's lines for the stored value, joined.
    function shown() as String {
        return join(LastMatch.lines(LastMatch.read()));
    }

    // The glance's line for the match shown writes: "Last: " then shown in English, "Dernier : " in French.
    function last(shown as String) as String {
        return Lang.format(text(Rez.Strings.GlanceLast), [shown]);
    }

    // The area the watch gives the glance, width and height (the device files' glance content area),
    // by the watch's part number: the FR265S, Forerunner 165, FR265, Forerunner 965, fenix 9 Pro 51 mm,
    // Descent G2, Instinct 3 AMOLED 45 mm and 50 mm; the FR265's on another watch.
    function area() as [Number, Number] {
        var areas = {"006-B4258-00" => [240, 104], "006-B4432-00" => [261, 124], "006-B4257-00" => [275, 120],
            "006-B4315-00" => [299, 148], "006-B4954-00" => [359, 130], "006-B4588-00" => [248, 103],
            "006-B4586-00" => [320, 99], "006-B4587-00" => [346, 106]} as Dictionary<String, [Number, Number]>;
        var area = areas[System.getDeviceSettings().partNumber];
        if (area == null) {
            area = laterAreas()[System.getDeviceSettings().partNumber];
        }
        return area != null ? area : [275, 120];
    }

    // The areas of the watches 1.2 adds, the watches without UP and DOWN (their device files): Venu 2, 2 Plus,
    // 2S, 3, 3S, 4 41 and 45 mm, vivoactive 5 and 6, D2 Air X10, Approach S50, S70 42 and 47 mm, S72 43 and
    // 47 mm.
    function laterAreas() as Dictionary<String, [Number, Number]> {
        return {"006-B3703-00" => [288, 133], "006-B3851-00" => [288, 133], "006-B3704-00" => [249, 115],
            "006-B4260-00" => [303, 164], "006-B4261-00" => [260, 141], "006-B4644-00" => [274, 128],
            "006-B4643-00" => [318, 150], "006-B4426-00" => [260, 141], "006-B4625-00" => [274, 146],
            "006-B4125-00" => [288, 133], "006-B4656-00" => [260, 141], "006-B4233-00" => [248, 103],
            "006-B4234-00" => [274, 103], "006-B4874-00" => [292, 130], "006-B4875-00" => [318, 150]}
            as Dictionary<String, [Number, Number]>;
    }

    // This watch is one 1.2 adds.
    function isLater() as Boolean {
        return laterAreas().hasKey(System.getDeviceSettings().partNumber);
    }

    // The lines as one string, to compare them.
    function join(lines as Array<String>) as String {
        var joined = "";
        for (var i = 0; i < lines.size(); i++) {
            joined += (i == 0 ? "" : " | ") + lines[i];
        }
        return joined;
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

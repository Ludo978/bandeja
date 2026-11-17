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
    // The line keeps clear of the Instinct 3 AMOLED's window (lineWidth()): there it only has to fit.
    var lineWidth = BandejaGlance.lineWidth(dc);
    for (var i = 0; i < cases.size(); i++) {
        var lines = cases[i][0] as Array<String>;
        var shown = lineWidth == width ? cases[i][1] as Number : 3;
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
        return area != null ? area : [275, 120];
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

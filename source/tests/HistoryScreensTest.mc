import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The history screens: the list's lines, newest first, each the result and the
// score over the date, the duration and the format, one line saying so when the history is empty;
// a stored match's summary, read only, the same as the one the match showed. The tests put the
// simulator's stored history back when they're done.

(:test)
function historyLineLabelTest(logger as Logger) as Boolean {
    // The label: the result's letter (W, L, D; none for a match saved unfinished), then each set's
    // score our side first, as the summary's table has them, the set the match ended in starred as in
    // the score text. A best of 5 with one-digit sets fits; with a two-digit set, the sets won.
    var won = HistoryScreenTests.text(Rez.Strings.HistoryWon);
    var lost = HistoryScreenTests.text(Rez.Strings.HistoryLost);
    var draw = HistoryScreenTests.text(Rez.Strings.HistoryDraw);
    var cases = [
        [new MatchConfig(), "UUUUUU UUUUUT uuuu", null, null, won + " 6-0 6-1"],
        [new MatchConfig(), "UUUUUU TTTTTT TTTTTT", null, null, lost + " 6-0 0-6 0-6"],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u", null, null, won + " 6-4 3-6 10-8"],
        [new MatchConfig(), "UTUTUTUTUTUT uuuuuuu UUUUUU", null, null, won + " 7-6 6-0"],
        [new MatchConfig(), "UUUUUU TTTTTT UTUT", EVENT_END_MATCH, null, draw + " 6-0 0-6 2-2*"],
        [new MatchConfig(), "UUUUUU UTU", EVENT_END_MATCH, null, won + " 6-0 2-1*"],
        [new MatchConfig(), "TTTTTT UTUTUT", EVENT_END_SET, TEAM_THEM, lost + " 0-6 3-3"],
        [TestKit.preset(PRESET_BEST_OF_5), "UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU", null, null, won + " 6-0 0-6 6-0 0-6 6-0"],
        [new MatchConfig(), "UTUTUTUTUU UTu", null, null, "6-4 1-1*"],
        [new MatchConfig(), "UTUTUTUTUU", null, null, "6-4"],
        [TestKit.custom(), "UUUU TTTT UUUU TTTT uuuuuuuuuu", null, null, won + " 3 - 2"],
        [TestKit.custom(), "UUUU TTTT UUUU TTTT uuuuuuuu", EVENT_END_MATCH, null, won + " 2 - 2"],
        [TestKit.custom(), "UUUU TTTT UUUU TTT", EVENT_END_MATCH, null, won + " 4-0 0-4 4-0 0-3*"]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var rig = new TestKit.Rig(c[0] as MatchConfig, "", false);
        rig.play(c[1] as String);
        if (c[2] != null) {
            rig.add(c[2] as EventType, c[3] as Team?);
        }
        var record = HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY);
        Test.assertEqualMessage(HistoryText.label(record), c[4], "case " + i);
        Test.assertMessage(HistoryText.label(record).length() <= HistoryText.LABEL_MAX, "case " + i);
        // The same score as the FIT Score field.
        Test.assertEqualMessage(HistoryText.score(record), rig.getState().getScoreText(), "case " + i);
    }
    // The longest that shows each set: best of 5, one-digit sets, a letter.
    var record = HistoryTests.record(TestKit.format(3, 6, 6, true), "UUUUUU");
    record.result = RESULT_WIN;
    record.rows = [new SummaryRow(1, false, [7, 6], TEAM_US), new SummaryRow(2, false, [6, 7], TEAM_THEM),
        new SummaryRow(3, false, [7, 6], TEAM_US), new SummaryRow(4, false, [6, 7], TEAM_THEM),
        new SummaryRow(5, false, [7, 6], TEAM_US)];
    Test.assertEqual(HistoryText.label(record), won + " 7-6 6-7 7-6 6-7 7-6");
    return true;
}

(:test)
function historyLineSubLabelTest(logger as Logger) as Boolean {
    // The sublabel: the date (the match start's day, then the month's short name as the watch writes
    // it in its language) and the duration (1h12 from an hour, 48 min under it, minutes rounded down;
    // left out when the watch gave no timer).
    var start = Gregorian.moment({:year => 2026, :month => 11, :day => 12, :hour => 12}).value();
    var month = Gregorian.info(new Time.Moment(start), Time.FORMAT_MEDIUM).month as String;
    var date = "12 " + month;
    Test.assertEqual(HistoryText.date(start), date);
    Test.assertEqual(HistoryText.duration(4320), "1h12");
    Test.assertEqual(HistoryText.duration(3600), "1h00");
    Test.assertEqual(HistoryText.duration(36059), "10h00");
    Test.assertEqual(HistoryText.duration(2939), "48 min");
    Test.assertEqual(HistoryText.duration(59), "0 min");

    var dot = FormatText.SEPARATOR;
    var cases = [[4320, date + dot + "1h12"], [2880, date + dot + "48 min"], [null, date], [9000, date + dot + "2h30"]];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var record = HistoryTests.record(new MatchConfig(), "UUUUUU");
        record.start = start;
        record.timer = c[0] as Number?;
        Test.assertEqualMessage(HistoryText.subLabel(record), c[1], "case " + i);
    }
    return true;
}

(:test)
function historyListTest(logger as Logger) as Boolean {
    // The list: one line per stored match, newest first, each its label over its sublabel; an empty
    // history, one line saying so, with nothing under it. A record that can't be read isn't listed.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        var lines = HistoryText.lines(HistoryStore.load());
        Test.assert(lines.size() == 1 && lines[0][0].equals(HistoryScreenTests.text(Rez.Strings.HistoryEmpty)) && lines[0][1] == null);

        var first = HistoryTests.record(new MatchConfig(), "UUUUUU UUUUUT uuuu");
        var second = HistoryTests.record(TestKit.preset(PRESET_ONE_SET), "TTTTTT");
        first.start = TestKit.T0;
        second.start = TestKit.T0 + 86400;
        HistoryStore.add(first);
        HistoryStore.add(second);
        var stored = Application.Storage.getValue(HistoryStore.KEY) as Array<Application.Storage.ValueType>;
        Application.Storage.setValue(HistoryStore.KEY, [stored[0], "bad", stored[1]] as Array<Application.Storage.ValueType>);
        lines = HistoryText.lines(HistoryStore.load());
        Test.assertEqual(lines.size(), 2);
        Test.assertEqual(lines[0][0], HistoryText.label(second));
        Test.assertEqual(lines[0][1] as String, HistoryText.subLabel(second));
        Test.assertEqual(lines[1][0], HistoryText.label(first));
        Test.assertEqual(lines[1][1] as String, HistoryText.subLabel(first));
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historySavedMatchesTest(logger as Logger) as Boolean {
    // Three matches saved from their summaries (a win, a loss, an early end), as MatchFlow.saved() adds
    // them: the list shows them newest first, and each one's summary, worked out again from the history
    // read back, shows what its own summary showed, page by page. Read again (the app restarted), the
    // same.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        var matches = [
            [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u", null, [5050, 148, 171, 905]],
            [new MatchConfig(), "UUUUUU TTTTTT TTTTTT", null, [3900, 139, 166, 620]],
            [new MatchConfig(), "UTUTUTUTUU TUTUTUTUTT UT", EVENT_END_MATCH, [4410, null, null, 700]]
        ];
        var shown = [] as Array<String>;
        var lines = [] as Array<String>;
        for (var i = 0; i < matches.size(); i++) {
            var m = matches[i];
            var rig = new TestKit.Rig(m[0] as MatchConfig, "Me", false);
            rig.play(m[1] as String);
            if (m[2] != null) {
                rig.add(m[2] as EventType, null);
            }
            Test.assert(rig.getState().matchOver);
            var record = HistoryRecord.of(rig.match, m[3] as Array<Number?>);
            record.start = TestKit.T0 + 3600 * i;
            shown.add(SummaryTests.text(new SummaryModel(record)));
            lines.add(HistoryText.label(record) + " / " + HistoryText.subLabel(record));
            HistoryStore.add(record);
        }
        Test.assertEqual(SummaryTests.text(new SummaryModel(HistoryStore.load()[0])).substring(0, 4) as String, "DRAW");
        for (var run = 0; run < 2; run++) {
            var records = HistoryStore.load();
            var listed = HistoryText.lines(records);
            Test.assertEqual(records.size(), 3);
            for (var i = 0; i < 3; i++) {
                var newest = 2 - i;
                Test.assertEqualMessage(listed[i][0] + " / " + listed[i][1], lines[newest], "line " + i);
                Test.assertEqualMessage(SummaryTests.text(new SummaryModel(records[i])), shown[newest], "summary " + i);
            }
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historySummaryInputTest(logger as Logger) as Boolean {
    // A stored match's summary is read only: DOWN and a swipe up show the page below, UP and a swipe
    // down the one above, never past the first or the last; BACK and a swipe right go back to the list;
    // START, hold UP, the other swipes and touches do nothing. Nothing saves, undoes or discards: the
    // input holds no match and no session, and the history is left as it was.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        HistoryStore.add(HistoryTests.record(TestKit.preset(PRESET_BEST_OF_5), "UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU"));
        var record = HistoryStore.load()[0];
        var model = new SummaryModel(record);
        // Best of 5: the table alone, then the 16 stats, 6 a page.
        Test.assertEqual(model.getPageCount(), 4);
        var input = new HistoryInput(model.getPageCount());
        Test.assert(input.page == 0 && input.key(WatchUi.KEY_UP) == HISTORY_NONE && input.swipe(WatchUi.SWIPE_DOWN) == HISTORY_NONE);
        Test.assert(input.key(WatchUi.KEY_DOWN) == HISTORY_PAGE && input.page == 1);
        Test.assert(input.swipe(WatchUi.SWIPE_UP) == HISTORY_PAGE && input.page == 2);
        Test.assert(input.key(WatchUi.KEY_DOWN) == HISTORY_PAGE && input.page == 3);
        Test.assert(input.key(WatchUi.KEY_DOWN) == HISTORY_NONE && input.swipe(WatchUi.SWIPE_UP) == HISTORY_NONE && input.page == 3);
        Test.assert(input.key(WatchUi.KEY_ENTER) == HISTORY_NONE && input.key(WatchUi.KEY_MENU) == HISTORY_NONE);
        Test.assert(input.swipe(WatchUi.SWIPE_LEFT) == HISTORY_NONE && input.touch() == HISTORY_NONE && input.page == 3);
        Test.assert(input.swipe(WatchUi.SWIPE_DOWN) == HISTORY_PAGE && input.key(WatchUi.KEY_UP) == HISTORY_PAGE && input.page == 1);
        Test.assert(input.key(WatchUi.KEY_UP) == HISTORY_PAGE && input.page == 0);
        Test.assert(input.key(WatchUi.KEY_ESC) == HISTORY_BACK && input.swipe(WatchUi.SWIPE_RIGHT) == HISTORY_BACK);
        var after = HistoryStore.load();
        Test.assert(after.size() == 1 && SummaryTests.text(new SummaryModel(after[0])).equals(SummaryTests.text(model)));
        // One page: nothing to turn.
        input = new HistoryInput(1);
        Test.assert(input.key(WatchUi.KEY_DOWN) == HISTORY_NONE && input.key(WatchUi.KEY_UP) == HISTORY_NONE && input.page == 0);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
module HistoryScreenTests {

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

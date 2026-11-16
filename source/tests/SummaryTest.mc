import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The match summary: WON / LOST in the winner's color (DRAW in white), the
// sets score, a set table with one row per set (SET n, SUPER TB, the set the match ended in starred), a
// 2 x 2 grid (duration, average HR, points, serve points %), and more stats on the pages below (the
// average time per point and the best streak last); START
// saves, BACK undoes the last event and returns to the match with the session as it was, hold UP opens
// Save / Discard / Back to match, UP and DOWN turn the pages.

(:test)
function summaryHeaderTest(logger as Logger) as Boolean {
    // The header and its color for each result; the match's own summary only opens once the match is
    // over, and only the history shows UNFINISHED, in white (a match saved from the pause menu).
    // Won and lost on a point, our side first in the sets score; End match: the early end result,
    // sets, then the unfinished set's games, then the game's points; all level is a draw.
    var results = [RESULT_WIN, RESULT_LOSS, RESULT_DRAW, RESULT_UNFINISHED];
    var strings = [Rez.Strings.SummaryWon, Rez.Strings.SummaryLost, Rez.Strings.SummaryDraw, Rez.Strings.SummaryUnfinished];
    // The winner's color is the theme's.
    var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
    for (var t = 0; t < themes.size(); t++) {
        var theme = themes[t];
        var colors = [Palette.teamColor(theme, TEAM_US), Palette.teamColor(theme, TEAM_THEM), Palette.TEXT, Palette.TEXT];
        for (var i = 0; i < results.size(); i++) {
            Test.assert(SummaryModel.headerString(results[i]) == strings[i] && SummaryModel.headerColor(results[i], theme) == colors[i]);
        }
    }
    Test.assert(SummaryModel.headerColor(RESULT_WIN, THEME_COURT) == Palette.US && SummaryModel.headerColor(RESULT_LOSS, THEME_GRASS) == 0xC084FC);
    var cases = [["UUUUUU UUUUUT uuuu", null, RESULT_WIN, "2 - 0"], ["UUUUUU TTTTTT TTTTTT", null, RESULT_LOSS, "1 - 2"],
        ["UUUUUU TTTTTT ut", EVENT_END_MATCH, RESULT_DRAW, "1 - 1"], ["UTUTUTUTUU UTUTU", EVENT_END_MATCH, RESULT_WIN, "1 - 0"],
        ["UT t", EVENT_END_MATCH, RESULT_LOSS, "0 - 0"]];
    for (var i = 0; i < cases.size(); i++) {
        var model = SummaryTests.model(new MatchConfig(), cases[i][0] as String, cases[i][1] as EventType?, null);
        Test.assertMessage(model.result == cases[i][2] && model.getSetsText().equals(cases[i][3]), "case " + i);
    }
    return true;
}

(:test)
function summaryTableTest(logger as Logger) as Boolean {
    // The mockup: won 6-4 3-6 10-8 with a super tie-break. Each set's winner in its color, the loser in
    // grey. A set won in a tie-break shows its games. End match: the set it ended in, starred, nobody's
    // color (in the middle of a game its games, the points left out, as the score text; in the super
    // tie-break its points); right after a set, no such row; with nothing played, 0-0 starred. End set
    // now at 3-3, given to them, which ends the match: their color says who got it. A long set with no
    // tie-break; best of 5: five rows, or four. The colors are the theme's.
    var superTieBreak = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    var model = SummaryTests.model(superTieBreak, "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u", null, null);
    SummaryTests.assertRows(model, "SET1 6-4 US, SET2 3-6 THEM, STB 10-8 US");
    Test.assert(SummaryModel.scoreColor(model.rows[0], TEAM_US, THEME_COURT) == Palette.US
        && SummaryModel.scoreColor(model.rows[0], TEAM_THEM, THEME_COURT) == Palette.MUTED);
    Test.assert(SummaryModel.scoreColor(model.rows[1], TEAM_US, THEME_COURT) == Palette.MUTED
        && SummaryModel.scoreColor(model.rows[1], TEAM_THEM, THEME_COURT) == Palette.THEM);
    Test.assert(SummaryModel.scoreColor(model.rows[0], TEAM_US, THEME_CLAY) == 0xF5C26B
        && SummaryModel.scoreColor(model.rows[1], TEAM_THEM, THEME_CLAY) == 0xD9532B);
    Test.assert(SummaryModel.scoreColor(model.rows[0], TEAM_US, THEME_GRASS) == 0x7EE07A
        && SummaryModel.scoreColor(model.rows[1], TEAM_THEM, THEME_GRASS) == 0xC084FC
        && SummaryModel.scoreColor(model.rows[1], TEAM_US, THEME_GRASS) == Palette.MUTED);
    var cases = [
        [new MatchConfig(), "UTUTUTUTUTUT uuuuuuu UUUUUU", null, null, "SET1 7-6 US, SET2 6-0 US"],
        [new MatchConfig(), "UTUTUTUTUU UTUTU", EVENT_END_MATCH, null, "SET1 6-4 US, SET2 3-2 *"],
        [new MatchConfig(), "UTUTUTUTUU", EVENT_END_MATCH, null, "SET1 6-4 US"],
        [new MatchConfig(), "", EVENT_END_MATCH, null, "SET1 0-0 *"],
        [new MatchConfig(), "UU tt", EVENT_END_MATCH, null, "SET1 2-0 *"],
        [superTieBreak, "UUUUUU TTTTTT uuuuttt", EVENT_END_MATCH, null, "SET1 6-0 US, SET2 0-6 THEM, STB 4-3 *"],
        [new MatchConfig(), "TTTTTT UTUTUT", EVENT_END_SET, TEAM_THEM, "SET1 0-6 THEM, SET2 3-3 THEM"],
        [TestKit.format(1, 6, 6, false), TestKit.repeat("UT", 10) + " UU", null, null, "SET1 12-10 US"],
        [TestKit.preset(PRESET_BEST_OF_5), "UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU", null, null,
            "SET1 6-0 US, SET2 0-6 THEM, SET3 6-0 US, SET4 0-6 THEM, SET5 6-0 US"],
        [TestKit.preset(PRESET_BEST_OF_5), "UUUUUU TTTTTT UUUUUU " + TestKit.repeat("UT", 6) + " uuuuuuu", null, null,
            "SET1 6-0 US, SET2 0-6 THEM, SET3 6-0 US, SET4 7-6 US"]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        model = SummaryTests.model(c[0] as MatchConfig, c[1] as String, c[2] as EventType?, c[3] as Team?);
        SummaryTests.assertRows(model, c[4] as String);
    }
    model = SummaryTests.model(new MatchConfig(), "UTUTUTUTUU UTUTU", EVENT_END_MATCH, null);
    Test.assert(SummaryModel.scoreColor(model.rows[1], TEAM_US, THEME_COURT) == Palette.MUTED
        && SummaryModel.scoreColor(model.rows[1], TEAM_THEM, THEME_COURT) == Palette.MUTED);
    return true;
}

(:test)
function summaryTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only: WON 1 - 0, one row, its label TIE-BREAK (the banner's word,
    // where the super tie-break's is SUPER TB and a set's SET n), its points; stopped by End match, the
    // row starred, nobody's color. Games 0-0, a tie-break played. A best of 3's super tie-break keeps
    // SUPER TB.
    var model = SummaryTests.model(TestKit.preset(PRESET_TIE_BREAK_7), "uuuuuttttt uu", null, null);
    Test.assert(model.result == RESULT_WIN && model.getSetsText().equals("1 - 0") && model.tieBreakOnly);
    SummaryTests.assertRows(model, "STB 7-5 US");
    Test.assertEqual(model.rowLabel(model.rows[0]), Rez.Strings.BannerTieBreak);
    Test.assert(SummaryModel.scoreColor(model.rows[0], TEAM_US, THEME_COURT) == Palette.US
        && SummaryModel.scoreColor(model.rows[0], TEAM_THEM, THEME_COURT) == Palette.MUTED);
    Test.assertEqual(SummaryTests.statsText(model.getStats(1)),
        "MAX HR --, KCAL --, GAMES 0-0, BREAKS --, DECIDING 0/0, TIE-BREAKS 1/1");
    model = SummaryTests.model(TestKit.preset(PRESET_TIE_BREAK_10), "uuuuutttt", EVENT_END_MATCH, null);
    Test.assert(model.result == RESULT_WIN && model.getSetsText().equals("0 - 0"));
    SummaryTests.assertRows(model, "STB 5-4 *");
    Test.assertEqual(model.rowLabel(model.rows[0]), Rez.Strings.BannerTieBreak);
    model = SummaryTests.model(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT uuuuuuuuuu", null, null);
    Test.assert(!model.tieBreakOnly && model.rowLabel(model.rows[0]) == Rez.Strings.CaptionSet
        && model.rowLabel(model.rows[2]) == Rez.Strings.SummarySuperTb);
    return true;
}

(:test)
function summaryGridTest(logger as Logger) as Boolean {
    // The mockup's grid: duration (the activity timer), average HR, points won-lost, serve points %.
    // Under an hour, the score screen's h:mm:ss; what the watch doesn't give is --. The pages below: max
    // HR, calories, games, breaks (won-conceded), deciding points and tie-breaks (won / played); then
    // break points won and saved, return points %, the longest game, the average time per point (m:ss)
    // and the best streak. Serve tracking off: the serve stats are --; with no game won, no longest
    // game; serve tracking on but no serve yet: no serve %.
    var won = SummaryTests.model(new MatchConfig(), "UUUUUU UUUUUU", null, null);
    var stats = SummaryTests.stats();
    var state = TestKit.matchOf(new MatchConfig(), "", "UUUUUU UUUUUU").getState();
    var model = SummaryTests.of(state, stats, 5050, 148, 171, 905);
    SummaryTests.assertStats(model.getStats(0), "DURATION 1:24:10, AVG HR 148, POINTS 98-91, SERVE 62%");
    SummaryTests.assertStats(model.getStats(1), "MAX HR 171, KCAL 905, GAMES 9-10, BREAKS 3-1, DECIDING 4/7, TIE-BREAKS 1/2");
    SummaryTests.assertStats(model.getStats(2), "BP WON 3/7, BP SAVED 4/6, RETURN 41%, LONGEST 6:12, PER POINT 0:42, STREAK 6");
    model = SummaryTests.of(state, stats, 2537, null, null, null);
    SummaryTests.assertStats(model.getStats(0), "DURATION 0:42:17, AVG HR --, POINTS 98-91, SERVE 62%");
    Test.assertEqual(SummaryTests.of(state, stats, null, 148, 171, 905).getStats(0)[0].value, "--");
    stats = new MatchStats();
    stats.pointsWon = 3;
    stats.pointsLost = 1;
    stats.averagePointTime = 75;
    stats.longestStreak = 2;
    model = SummaryTests.of(state, stats, 60, null, null, 0);
    SummaryTests.assertStats(model.getStats(0), "DURATION 0:01:00, AVG HR --, POINTS 3-1, SERVE --");
    SummaryTests.assertStats(model.getStats(1), "MAX HR --, KCAL 0, GAMES 0-0, BREAKS --, DECIDING 0/0, TIE-BREAKS 0/0");
    SummaryTests.assertStats(model.getStats(2), "BP WON --, BP SAVED --, RETURN --, LONGEST --, PER POINT 1:15, STREAK 2");
    // No point played: no average, a streak of 0. No stats at all: every match stat --.
    SummaryTests.assertStats(SummaryTests.of(state, new MatchStats(), 60, null, null, 0).getStats(2),
        "BP WON --, BP SAVED --, RETURN --, LONGEST --, PER POINT --, STREAK 0");
    SummaryTests.assertStats(SummaryTests.of(state, null, 60, null, null, 0).getStats(2),
        "BP WON --, BP SAVED --, RETURN --, LONGEST --, PER POINT --, STREAK --");
    stats.servePointsPlayed = 0;
    stats.servePointsWon = 0;
    Test.assertEqual(SummaryTests.of(state, stats, 60, null, null, 0).getStats(0)[3].value, "--");
    // From a real match: the stats of its log (TestKit's points 30 s apart, the first at the match
    // start: 1,410 s over 48 points).
    Test.assert(won.getStats(0)[2].value.equals("48-0") && won.getStats(1)[2].value.equals("12-0"));
    Test.assert(won.getStats(2)[4].value.equals("0:29") && won.getStats(2)[5].value.equals("48"));
    return true;
}

(:test)
function summaryPagesTest(logger as Logger) as Boolean {
    // Up to 3 sets: the first page holds the table and the grid, then 6 stats, then 6. 4 or 5 rows (best
    // of 5): the table alone on the first page, the grid's stats first on the next, the last 4 on a
    // fourth page.
    var model = SummaryTests.model(new MatchConfig(), "UUUUUU TTTTTT UUUUUU", null, null);
    Test.assert(model.getPageCount() == 3 && model.getStats(0).size() == 4 && model.getStats(1).size() == 6);
    Test.assert(model.getStats(2).size() == 6 && model.getStats(3).size() == 0);
    var moves = ["UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU", "UUUUUU TTTTTT UUUUUU UUUUUU"];
    for (var i = 0; i < moves.size(); i++) {
        model = SummaryTests.model(TestKit.preset(PRESET_BEST_OF_5), moves[i], null, null);
        Test.assert(model.rows.size() == 5 - i && model.getPageCount() == 4 && model.getStats(0).size() == 0
            && model.getStats(1)[0].label == Rez.Strings.StatDuration);
        Test.assert(model.getStats(1).size() == 6 && model.getStats(2).size() == 6 && model.getStats(3).size() == 4);
        Test.assert(model.getStats(3)[1].label == Rez.Strings.StatLongestGame && model.getStats(3)[3].label == Rez.Strings.StatStreak);
    }

    // DOWN and a swipe up turn to the next page, UP and a swipe down to the one before, never past the
    // first or the last. Other swipes and touches do nothing; nothing ever scores.
    var test = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    var input = test.input;
    var events = test.rig.getState().eventCount;
    var steps = [[WatchUi.KEY_UP, SUMMARY_NONE, 0], [-1, SUMMARY_NONE, 0], [WatchUi.KEY_DOWN, SUMMARY_PAGE, 1], [-2, SUMMARY_PAGE, 2],
        [WatchUi.KEY_DOWN, SUMMARY_NONE, 2], [-2, SUMMARY_NONE, 2], [WatchUi.KEY_UP, SUMMARY_PAGE, 1], [-1, SUMMARY_PAGE, 0],
        [-3, SUMMARY_NONE, 0], [-4, SUMMARY_NONE, 0], [-5, SUMMARY_NONE, 0], [WatchUi.KEY_LAP, SUMMARY_NONE, 0]];
    var swipes = [WatchUi.SWIPE_DOWN, WatchUi.SWIPE_UP, WatchUi.SWIPE_LEFT, WatchUi.SWIPE_RIGHT];
    for (var i = 0; i < steps.size(); i++) {
        var key = steps[i][0] as Number;
        var action = key >= 0 ? input.key(key as WatchUi.Key) : key == -5 ? input.touch() : input.swipe(swipes[-key - 1]);
        Test.assertMessage(action == steps[i][1] && input.page == steps[i][2], "step " + i + ": page " + input.page);
    }
    Test.assert(test.rig.getState().eventCount == events && test.rig.getState().matchOver && test.rig.session.isRecording());
    return true;
}

(:test)
function summaryUndoTest(logger as Logger) as Boolean {
    // BACK after the match point (the session running): the point undone, the match exactly as it was
    // before it, the session still running. Back on the score screen, play goes on: the next
    // point counts, and wins the match again.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UUUUUU UUUUUT uuu");
    var before = rig.getState().copy();
    Test.assert(rig.input.key(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.input.won == WON_MATCH);
    var input = SummaryTests.open(rig);
    input.key(WatchUi.KEY_DOWN);
    Test.assertEqual(input.key(WatchUi.KEY_ESC), SUMMARY_UNDO);
    var undone = input.undone as MatchEvent;
    Test.assert(undone.type == EVENT_POINT_US && ScoreInput.undoneString(undone.type) == Rez.Strings.UndonePointUs);
    TestKit.assertSameState(rig.getState(), before, "BACK after the match point");
    Test.assert(rig.session.isRecording() && !rig.session.isPaused());
    var score = new ScoreInput(rig.match, rig.session);
    Test.assert(score.key(WatchUi.KEY_DOWN, 5000) == INPUT_POINT && score.won == WON_MATCH);
    Test.assertEqual(rig.getState().getScoreText(), "6-0 6-1");

    // End match from the pause menu (the session paused): BACK undoes it, and the session stays paused,
    // as it was when End match was picked; START resumes on the score screen.
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UTUTUTUTUU UTUTU tt");
    before = rig.getState().copy();
    Test.assert(rig.session.pause() && rig.rules.endMatch(TestKit.MENU_TIME));
    input = SummaryTests.open(rig);
    Test.assert(input.key(WatchUi.KEY_ESC) == SUMMARY_UNDO && (input.undone as MatchEvent).type == EVENT_END_MATCH);
    TestKit.assertSameState(rig.getState(), before, "BACK after End match");
    Test.assert(rig.session.isPaused());
    score = new ScoreInput(rig.match, rig.session);
    Test.assert(score.key(WatchUi.KEY_DOWN, 5000) == INPUT_TOAST && score.toast == Rez.Strings.ToastPaused);
    Test.assert(score.key(WatchUi.KEY_ENTER, 5100) == INPUT_RESUME && score.key(WatchUi.KEY_DOWN, 5200) == INPUT_POINT);

    // End set now that ended the match (6-0 5-1, the set to us): BACK gives back 5-1 and its game.
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UUUUUU UUUUUT uu");
    before = rig.getState().copy();
    Test.assert(rig.session.pause() && rig.rules.endSet(null, TestKit.MENU_TIME) && rig.rules.isMatchOver());
    input = SummaryTests.open(rig);
    Test.assert(input.key(WatchUi.KEY_ESC) == SUMMARY_UNDO && (input.undone as MatchEvent).type == EVENT_END_SET);
    TestKit.assertSameState(rig.getState(), before, "BACK after End set now");

    // Back to match in the hold UP menu does the same as BACK.
    rig = new TestKit.Rig(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "", false);
    rig.play("UUUUUU TTTTTT uuuuuuuu ttttttttt");
    before = rig.getState().copy();
    Test.assertEqual(rig.input.key(WatchUi.KEY_UP, 1000), INPUT_POINT);
    input = SummaryTests.open(rig);
    Test.assert(input.key(WatchUi.KEY_MENU) == SUMMARY_MENU && input.backToMatch() == SUMMARY_UNDO);
    Test.assertEqual((input.undone as MatchEvent).type, EVENT_POINT_THEM);
    TestKit.assertSameState(rig.getState(), before, "Back to match");
    return true;
}

(:test)
function summarySaveTest(logger as Logger) as Boolean {
    // START saves: the session ends with the match's fields (then the app exits to the watch face). A
    // save the watch refuses keeps the summary and the session, paused: "Not saved", then START
    // again, or BACK, which still undoes. Hold UP: the menu, nothing else.
    var test = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    Test.assert(test.input.key(WatchUi.KEY_ENTER) == SUMMARY_SAVED && test.rig.session.getPhase() == SESSION_ENDED);
    var values = test.rig.recorder.sessionValues as SessionValues;
    Test.assert(values.result == (RESULT_WIN as Number) && values.score.equals("6-0 6-1"));
    test = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    test.rig.recorder.saveResult = false;
    test.input.key(WatchUi.KEY_DOWN);
    Test.assert(test.input.key(WatchUi.KEY_ENTER) == SUMMARY_NOT_SAVED && test.rig.session.isRecording() && test.rig.session.isPaused());
    Test.assert(test.input.page == 1 && test.input.save() == SUMMARY_NOT_SAVED);
    test.rig.recorder.saveResult = true;
    Test.assert(test.input.save() == SUMMARY_SAVED && test.rig.session.getPhase() == SESSION_ENDED);
    test = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    test.rig.recorder.saveResult = false;
    Test.assert(test.input.key(WatchUi.KEY_ENTER) == SUMMARY_NOT_SAVED && test.input.key(WatchUi.KEY_ESC) == SUMMARY_UNDO);
    Test.assert(!test.rig.getState().matchOver);
    test = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    Test.assert(test.input.key(WatchUi.KEY_MENU) == SUMMARY_MENU && test.rig.getState().matchOver);
    Test.assert(test.rig.session.isRecording() && !test.rig.session.isPaused());
    return true;
}

(:test)
function summaryHandOverTest(logger as Logger) as Boolean {
    // START or hold UP during the match's overlay open their menus over the score screen; when the
    // screen shows again, the match over, the summary takes over at once. A swipe
    // left during it: the data page stays until the player leaves it; a swipe back, or UP or DOWN
    // (refused, "Match over", the score page back), and the summary. The screen showing again with the
    // match going on: no summary.
    var keys = [WatchUi.KEY_ENTER, WatchUi.KEY_MENU];
    for (var i = 0; i < keys.size(); i++) {
        var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
        var motion = rig.motion;
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        Test.assertEqual(rig.press(keys[i], 1200), i == 0 ? INPUT_PAUSE : INPUT_MATCH_MENU);
        Test.assert(!motion.takeSummary(5000));
        motion.startTicks(6000);
        motion.shown(rig.getState(), 6000);
        Test.assert(motion.nextWake(6000, null) == ScoreMotion.MIN_WAIT && motion.takeSummary(6050));
    }
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    var motion = rig.motion;
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.swipe(WatchUi.SWIPE_LEFT, 1200) == INPUT_NEXT_PAGE && motion.page == PAGE_DATA);
    motion.shown(rig.getState(), 3000);
    Test.assert(!motion.takeSummary(9000) && rig.swipe(WatchUi.SWIPE_RIGHT, 9000) == INPUT_PREVIOUS_PAGE && motion.takeSummary(9000));
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    motion = rig.motion;
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.swipe(WatchUi.SWIPE_LEFT, 1200) == INPUT_NEXT_PAGE);
    Test.assert(rig.press(WatchUi.KEY_UP, 4000) == INPUT_TOAST && motion.page == PAGE_SCORE && motion.takeSummary(4000));
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    rig.motion.shown(rig.getState(), 1000);
    Test.assert(!rig.motion.takeSummary(2000));
    return true;
}

(:test)
module SummaryTests {

    // The summary of a match after moves, then the event (End match, End set now for team) that ends
    // it, if any, as MatchFlow.showSummary() makes it, with no activity values.
    function model(config as MatchConfig, moves as String, end as EventType?, team as Team?) as SummaryModel {
        var rig = new TestKit.Rig(config, "", false);
        rig.play(moves);
        if (end != null) {
            rig.add(end, team);
        }
        Test.assert(rig.getState().matchOver);
        return new SummaryModel(HistoryRecord.of(rig.match, NO_ACTIVITY));
    }

    // No activity values: the timer, the heart rates and the calories unknown.
    const NO_ACTIVITY = [null, null, null, null] as Array<Number?>;

    // The summary of state with these stats and activity values, whatever match they come from.
    function of(state as MatchState, stats as MatchStats?, timer as Number?, averageHeartRate as Number?,
            maxHeartRate as Number?, calories as Number?) as SummaryModel {
        return new SummaryModel(new HistoryRecord(TestKit.T0, new MatchConfig(), state.getResult(), HistoryRecord.rowsOf(state),
            stats, [timer, averageHeartRate, maxHeartRate, calories]));
    }

    // The summary opens on the match as it stands: its input.
    function open(rig as TestKit.Rig) as SummaryInput {
        Test.assert(rig.getState().matchOver);
        var model = new SummaryModel(HistoryRecord.of(rig.match, NO_ACTIVITY));
        return new SummaryInput(rig.match, rig.session, model.getPageCount());
    }

    // The mockup's stats and more.
    function stats() as MatchStats {
        var stats = new MatchStats();
        stats.pointsWon = 98;
        stats.pointsLost = 91;
        stats.gamesWon = 9;
        stats.gamesLost = 10;
        stats.servePointsPlayed = 100;
        stats.servePointsWon = 62;
        stats.returnPointsPlayed = 100;
        stats.returnPointsWon = 41;
        stats.breaksWon = 3;
        stats.breaksConceded = 1;
        stats.decidingPointsPlayed = 7;
        stats.decidingPointsWon = 4;
        stats.tieBreaksPlayed = 2;
        stats.tieBreaksWon = 1;
        stats.breakPointsPlayed = 7;
        stats.breakPointsConverted = 3;
        stats.breakPointsFaced = 6;
        stats.breakPointsSaved = 4;
        stats.gameDurations = [134, 372, 200];
        stats.longestGame = 1;
        stats.averagePointTime = 42;
        stats.longestStreak = 6;
        return stats;
    }

    // The rows as "SET1 6-4 US", "STB 10-8 US", "SET2 3-2 *" (the set the match ended in).
    function assertRows(model as SummaryModel, expected as String) as Void {
        Test.assertEqual(rowsText(model), expected);
    }

    function rowsText(model as SummaryModel) as String {
        var text = "";
        for (var i = 0; i < model.rows.size(); i++) {
            var row = model.rows[i];
            var winner = row.winner;
            text += (i == 0 ? "" : ", ") + (row.superTieBreak ? "STB" : "SET" + row.setNumber) + " " + row.score[TEAM_US] + "-"
                + row.score[TEAM_THEM] + " " + (winner == null ? "*" : winner == TEAM_US ? "US" : "THEM");
        }
        return text;
    }

    // The stats as "LABEL value", with short names for the labels.
    function assertStats(stats as Array<SummaryStat>, expected as String) as Void {
        Test.assertEqual(statsText(stats), expected);
    }

    // Everything the summary shows, page by page: "WIN 2 - 0 | SET1 6-0 US, SET2 6-1 US | DURATION --,
    // AVG HR --, ... | MAX HR --, ...".
    function text(model as SummaryModel) as String {
        var result = model.result;
        var text = (result == RESULT_WIN ? "WIN" : result == RESULT_LOSS ? "LOSS" : result == RESULT_DRAW ? "DRAW" : "UNFINISHED")
            + " " + model.getSetsText() + " | " + rowsText(model);
        for (var page = 0; page < model.getPageCount(); page++) {
            text += " | " + statsText(model.getStats(page));
        }
        return text;
    }

    function statsText(stats as Array<SummaryStat>) as String {
        var labels = [Rez.Strings.StatDuration, Rez.Strings.StatAvgHr, Rez.Strings.StatPoints, Rez.Strings.StatServe,
            Rez.Strings.StatMaxHr, Rez.Strings.DataCalories, Rez.Strings.StatGames, Rez.Strings.StatBreaks, Rez.Strings.StatDeciding,
            Rez.Strings.StatTieBreaks, Rez.Strings.StatBreakPointsWon, Rez.Strings.StatBreakPointsSaved, Rez.Strings.StatReturn,
            Rez.Strings.StatLongestGame, Rez.Strings.StatPerPoint, Rez.Strings.StatStreak];
        var names = ["DURATION", "AVG HR", "POINTS", "SERVE", "MAX HR", "KCAL", "GAMES", "BREAKS", "DECIDING", "TIE-BREAKS",
            "BP WON", "BP SAVED", "RETURN", "LONGEST", "PER POINT", "STREAK"];
        var text = "";
        for (var i = 0; i < stats.size(); i++) {
            var index = labels.indexOf(stats[i].label);
            text += (i == 0 ? "" : ", ") + (index < 0 ? "?" : names[index]) + " " + stats[i].value;
        }
        return text;
    }

    // The summary over a match played to its end with no input, recorded through a fake.
    class Summary {

        var rig as TestKit.Rig;
        var input as SummaryInput;

        function initialize(config as MatchConfig, moves as String) {
            rig = new TestKit.Rig(config, "", false);
            rig.play(moves);
            input = open(rig);
        }
    }
}

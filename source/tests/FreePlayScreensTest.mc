import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Free play on the screens: the sets won as a
// number in place of the set pips, the Edit score menu with any number of sets, the longest match kept
// (the point refused with a toast, the menus' items that would log an event left out but End match),
// the summary's table and the history's record with the latest sets, the history line, the glance's
// value and the resume prompt's score.

(:test)
function freePlayScoreModelTest(logger as Logger) as Boolean {
    // No pip: the sets won as a number, in Free play only; a set point is never a match point.
    var rig = new TestKit.Rig(TestKit.preset(PRESET_FREE_PLAY), "Me", false);
    rig.play(TestKit.repeat("U", 18) + TestKit.repeat("T", 6) + "UUUUU uuu");
    var model = new ScoreModel(rig.engine.getConfig(), rig.getState(), true);
    Test.assert(model.pips == 0 && model.setsAsNumber && model.setsWon[TEAM_US] == 3 && model.setsWon[TEAM_THEM] == 1);
    Test.assert(model.banner == BANNER_SET_POINT && model.captionNumber == 5);
    model = new ScoreModel(new MatchConfig(), new MatchState(), true);
    Test.assert(model.pips == 2 && !model.setsAsNumber);
    return true;
}

(:test)
function freePlayFullMatchTest(logger as Logger) as Boolean {
    // The longest match kept: a point is refused with the toast "Match too long", changing
    // nothing; the pause menu keeps Resume, End match, Save, Discard and Settings, the match menu Data page
    // and the settings (no event but End match has room); End match then ends it with its result, and BACK
    // on the summary undoes it.
    var config = DebugMenu.freePlayConfig();
    var log = DebugMenu.freePlayLog(DebugMenu.fullEvents() + DebugMenu.FULL_ROOM, TestKit.T0);
    var engine = ScoringEngine.restore(config, log) as ScoringEngine;
    Test.assert(engine.isFull());
    var resumed = new TestKit.Resumed(new StoredMatch(engine, TestKit.T0, false));
    var match = resumed.match;
    var input = new ScoreInput(match, resumed.session);
    var before = match.getState().copy();
    Test.assert(input.key(WatchUi.KEY_DOWN, 1000) == INPUT_TOAST && input.toast == Rez.Strings.ToastMatchFull);
    Test.assert(input.key(WatchUi.KEY_UP, 3000) == INPUT_TOAST && input.toast == Rez.Strings.ToastMatchFull);
    TestKit.assertSameState(match.getState(), before, "refused");
    var rules = new MatchMenuRules(match, resumed.session);
    TestKit.assertItems(rules.getPauseItems(TestKit.T0), [ITEM_RESUME, ITEM_END_MATCH, ITEM_SAVE, ITEM_DISCARD, ITEM_SETTINGS], "pause");
    TestKit.assertItems(rules.getMatchItems(), [ITEM_DATA_PAGE, ITEM_STATS_PAGE, ITEM_VIBRATION, ITEM_SOUNDS, ITEM_TOUCH_SCORING],
        "match");
    Test.assert(rules.endMatch(TestKit.MENU_TIME) && match.getState().matchOver && match.getState().getResult() == RESULT_WIN);
    Test.assert(input.key(WatchUi.KEY_ESC, 5000) == INPUT_UNDO && !match.getState().matchOver);
    // An undo makes room for a point.
    input.key(WatchUi.KEY_ESC, 6000);
    Test.assert(input.key(WatchUi.KEY_DOWN, 7000) == INPUT_POINT && engine.isFull());
    // One point earlier, every item is back, Edit score while an edit of the score fits.
    engine.undo();
    TestKit.assertItems(rules.getPauseItems(TestKit.T0), [ITEM_RESUME, ITEM_END_MATCH, ITEM_SAVE, ITEM_DISCARD, ITEM_SWAP_SERVER,
        ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE, ITEM_END_SET, ITEM_SETTINGS], "room for one");
    Test.assert(rules.getMatchItems().indexOf(ITEM_EDIT_SCORE) < 0 && !EditScoreRules.fits(engine, 47));
    return true;
}

(:test)
function freePlayEditMenuTest(logger as Logger) as Boolean {
    // Edit score in Free play: a set to add whatever the sets won (no set wins the
    // match), each set's list offering both winners, up to ScoreEdit.MAX sets; the items' IDs after the
    // others, so any number of sets has one.
    var rules = EditMenuTests.rules(TestKit.preset(PRESET_FREE_PLAY), TestKit.repeat("U", 18) + "UT u");
    var s = EditScoreRules.ITEM_SET;
    Test.assertEqual(rules.getItems().toString(), [s, s + 1, s + 2, EditScoreRules.ITEM_GAMES, EditScoreRules.ITEM_POINTS,
        EditScoreRules.ITEM_ADD_SET, EditScoreRules.ITEM_REMOVE_SET, EditScoreRules.ITEM_APPLY].toString());
    var choices = rules.getSetChoices(3);
    // Sets of 6: 6-0 to 6-4, 7-5, 7-6, for each team.
    Test.assert(choices.size() == 14 && choices[0].winner == TEAM_US && choices[13].winner == TEAM_THEM);
    for (var i = 0; i < 9; i++) {
        rules.setSet(rules.sets.size(), choices[i % 7]);
    }
    Test.assert(rules.sets.size() == 12 && rules.getItems().indexOf(s + 11) >= 0 && rules.canAddSet());
    Test.assert(rules.apply(TestKit.MENU_TIME) && rules.match.getState().setScores.size() == 12);
    Test.assertEqual(EditScoreText.label(rules, s + 11), Lang.format(WatchUi.loadResource(Rez.Strings.EditSet) as String, [12]));
    while (rules.sets.size() < ScoreEdit.MAX) {
        rules.setSet(rules.sets.size(), choices[0]);
    }
    Test.assert(!rules.canAddSet());
    return true;
}

(:test)
function freePlayHistoryTest(logger as Logger) as Boolean {
    // The record keeps the summary's latest 5 sets and the sets each team won before
    // them ("earlier", stored only when some are left out, so a record of 5 sets or fewer is stored as
    // before); read back, the rows keep their set numbers and the sets won count them all. The summary's
    // table has its page, its rows SET 6 to SET 10*, its header the sets won; the history line, too long
    // with the sets, shows the sets won, and so does the glance; the resume prompt shows
    // the latest sets that fit a history line. A 600-event match of DebugMenu.freePlayLog(): 9 sets, the
    // 10th at 3-2.
    var config = DebugMenu.freePlayConfig();
    var engine = ScoringEngine.restore(config, DebugMenu.freePlayLog(600, TestKit.T0)) as ScoringEngine;
    Test.assert(engine.add(new MatchEvent(EVENT_END_MATCH, TestKit.nextTime(engine), null)));
    var state = engine.getState();
    var record = new HistoryRecord(TestKit.T0, config, state.getResult(), HistoryRecord.rowsOf(state),
        state.getStats(TestKit.START), [36000, 140, 170, 2800]);
    var value = record.toValue();
    Test.assertEqual((value.get("earlier") as Array).toString(), [3, 2].toString());
    var read = HistoryRecord.fromValue(value) as HistoryRecord;
    var rows = read.rows;
    Test.assert(rows.size() == 5 && rows[0].setNumber == 6 && rows[4].setNumber == 10 && rows[4].winner == null
        && rows[2].score[TEAM_US] == 7 && rows[2].score[TEAM_THEM] == 6);
    Test.assertEqual(read.getSetsWon().toString(), [5, 4].toString());
    var model = new SummaryModel(read);
    Test.assert(model.result == RESULT_WIN && model.getSetsText().equals("5 - 4") && model.rows.size() == 5
        && model.firstStat(1) == 0 && model.getStats(0).size() == 0);
    Test.assertEqual(HistoryText.score(read), ".. 6-4 3-6 7-6 2-6 3-2*");
    Test.assertEqual(HistoryText.label(read), LastMatch.label(RESULT_WIN as Number, "5 - 4"));
    Test.assertEqual(HistoryText.glanceValue(read)[1] as String, "5 - 4");
    Test.assertEqual(ResumePrompt.scoreText(state), ".. 3-6 7-6 2-6 3-2");
    // A record of 5 sets: no "earlier", stored as before.
    var five = new HistoryRecord(TestKit.T0, config, RESULT_LOSS, HistoryRecord.rowsOf(state).slice(0, 5), null, SummaryTests.NO_ACTIVITY);
    Test.assert(!five.hasEarlier() && five.toValue().get("earlier") == null && five.rows[0].setNumber == 1);
    // Bad "earlier": unreadable.
    var bad = [[1], [-1, 2], ["2", 3], 5];
    for (var i = 0; i < bad.size(); i++) {
        value.put("earlier", bad[i] as Application.Storage.ValueType);
        Test.assertMessage(HistoryRecord.fromValue(value) == null, "earlier " + bad[i]);
    }
    return true;
}

(:test)
function currentMatchReleaseTest(logger as Logger) as Boolean {
    // Saved, the match lets its log and undo snapshots go before the history's write:
    // its state stays for the screens, and nothing writes it to storage again (the stored match is
    // cleared at the exit).
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        var rig = new TestKit.Rig(TestKit.preset(PRESET_FREE_PLAY), "Me", false);
        rig.play("UUUUUU UT u");
        var state = rig.getState();
        MatchStore.clear();
        rig.match.release();
        Test.assert(!rig.match.isUnsaved() && rig.engine.getLogSize() == 0 && rig.getState() == state);
        rig.match.save();
        Test.assert(!MatchStore.isStored());
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

import Toybox.Lang;
import Toybox.Test;

// Regression tests for the four defects a review of the engine changes for the Short sets, Best of 5,
// Tie-break only and Free play formats found. Each test failed before its fix.

(:test)
function reviewPausedEditLastLapTest(logger as Logger) as Boolean {
    // Low severity. Edit score is in the match menu, which hold UP opens while the timer is paused too.
    // SessionManager sends the lap in progress's fields to the recorder only where
    // the timer stops, on the belief that nothing changes them during a pause: an edit does. A save
    // that comes with no resume in between (the app stopped, MatchRecovery.stop(); the 3 % battery save,
    // MatchFlow.checkBattery()) then closes the last lap with the set and the score from before the
    // edit, where they should be as edited. Here: 1-1 and 15-0, paused, edited to 6-4 2-1 30-15,
    // saved. The last lap must be set 2 at 2-1 with no outcome; it is set 1 at 1-1.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    rig.play("UT u");
    Test.assert(rig.session.pause());
    Test.assert(rig.match.add(TestKit.editEvent(rig.engine, "6-4 | 2-1 2-1")));
    var expected = LapValues.forUnfinished(rig.getState()).toString();
    Test.assertEqual(expected, "2 2-1 -");
    Test.assert(rig.session.save());
    // The session fields are set again at that save, so they are right.
    Test.assertEqual((rig.recorder.sessionValues as SessionValues).score, "6-4 2-1*");
    var last = rig.recorder.laps[rig.recorder.laps.size() - 1];
    Test.assertEqualMessage(last, expected, "the last lap after an edit made while paused");
    return true;
}

(:test)
function reviewHistoryRowWinnerTypeTest(logger as Logger) as Boolean {
    // Low severity. A stored record with a value of the wrong type is skipped, never a crash.
    // HistoryRecord.rowsFrom() checks a row's winner by comparing it with the two teams, not by its
    // type, so a Float, a Long or a Boolean equal to 0 or 1 passes. The record is then read, and
    // getSetsWon() (the summary, the list's and the glance's sets won, HistoryStore.restoreLast() at
    // launch) throws UnexpectedTypeException when it indexes an array with it.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    rig.play("UUUUUU UU");
    var bad = [1.0, 0.0, 1l, true];
    for (var i = 0; i < bad.size(); i++) {
        var value = HistoryRecord.of(rig.match, [60, null, null, null] as Array<Number?>).toValue();
        // The first row's winner.
        var sets = value.get("sets") as Array;
        sets[2] = bad[i];
        Test.assertMessage(HistoryRecord.fromValue(value) == null, "read a row whose winner is " + bad[i]);
    }
    return true;
}

(:test)
function reviewLastLapSetNumberTest(logger as Logger) as Boolean {
    // Low severity, out of reach in a real match. The lap's set number is a uint8 FIT field,
    // capped at the 200th set. A game's lap is capped (MatchState.finishedGameCode()), but the last
    // lap's, LapValues.forUnfinished(), is the set count as it is: past the 200th set it disagrees with
    // the game laps, and from the 256th it doesn't fit the field. Free play, 256 sets given by End set
    // now: the last lap says set 256.
    var engine = new ScoringEngine(TestKit.preset(PRESET_FREE_PLAY));
    for (var i = 0; i < 256; i++) {
        Test.assert(engine.add(new MatchEvent(EVENT_END_SET, TestKit.nextTime(engine), TEAM_US)));
    }
    var lap = LapValues.forUnfinished(engine.getState());
    Test.assertMessage(lap.setNumber <= FIT_MAX_UINT8, "set number " + lap.setNumber + " in a uint8 lap field");
    return true;
}

(:test)
function reviewEditMenuPastMaxSetsTest(logger as Logger) as Boolean {
    // Low severity, out of reach in a real match. The Edit score menu only offers what an
    // edit accepts, and says "No change" only for the score as it stands. An edit holds 99 finished sets
    // at most (ScoreEdit.MAX), but a Free play can have more (here 99 by an edit, then a set played).
    // The match menu offered Edit score (MatchMenuRules only checked the log's room), and every draft
    // was then refused, as "No change", even one that only changes the game's points. Fixed: with
    // ScoreEdit.MAX finished sets the item shows and an edit applies; past it, the item is left out.
    var rig = new TestKit.Rig(TestKit.preset(PRESET_FREE_PLAY), "", false);
    Test.assert(rig.match.add(TestKit.editEvent(rig.engine, TestKit.repeat("6-4 ", ScoreEdit.MAX) + "| 0-0 0-0")));
    Test.assert(rig.rules.getMatchItems().indexOf(ITEM_EDIT_SCORE) >= 0);
    var rules = new EditScoreRules(rig.match);
    rules.setPair(EditScoreRules.ITEM_POINTS, 1, 0);
    Test.assertMessage(rules.apply(TestKit.MENU_TIME), "an edit at ScoreEdit.MAX finished sets");
    Test.assert(rig.match.undo() != null);
    rig.play("UUUUUU");
    Test.assertEqual(rig.getState().setScores.size(), ScoreEdit.MAX + 1);
    Test.assertMessage(rig.rules.getMatchItems().indexOf(ITEM_EDIT_SCORE) < 0,
        "Edit score offered past the sets an edit holds");
    return true;
}

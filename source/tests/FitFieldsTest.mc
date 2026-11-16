import Toybox.Lang;
import Toybox.Test;

// The values of the FIT developer fields. The 13 session fields are worked out from the
// state and the stats: the compact score, sets, games and points, serve and return points won %,
// breaks won (0xFF, the FIT invalid value, when serve tracking is off), the result code and the
// deciding points. The session gets them where the timer stops, and again at a save from the pause.
// The record field is the point differential, set after every point and undo. Session values are
// written as SessionValues.toString() gives them.

(:test)
function fieldsMatchWonTest(logger as Logger) as Boolean {
    // The stats tests' hand-scored match: won 2-0 1-2 2-1 (the tie-breaks' sets read 1-2 and 2-1,
    // without their points).
    FieldsTests.check(TestKit.handScoredMatch(), "2-0 1-2 2-1 | sets 2-1 games 5-3 points 29-27 | serve 54 return 50 breaks 2"
        + " | result 1 | deciding 2/3", "match won");
    return true;
}

(:test)
function fieldsServeTrackingTest(logger as Logger) as Boolean {
    // No serving team: serve and return points won % and breaks won are 0xFF; the other fields don't
    // need serve tracking. Serve tracking on, but we haven't served yet: no serve points won %, while
    // the return points won % and the breaks won have a value. Saved during the second set without End
    // match: unfinished (2), the set in progress starred: 7 of our 8 service games held to love, 28 of
    // 32 points, 88 %; 2 of their 7 games broken to love, 8 of 28 points, 29 %.
    var engine = new ScoringEngine(TestKit.shortSets());
    TestKit.play(engine, "utttuuu T");
    FieldsTests.check(engine, "1-1* | sets 0-0 games 1-1 points 4-7 | serve 255 return 255 breaks 255 | result 2 | deciding 1/1", "off");
    engine = TestKit.newMatch(new MatchConfig(), "Opponents Me");
    TestKit.play(engine, "T");
    FieldsTests.check(engine, "0-1* | sets 0-0 games 0-1 points 0-4 | serve 255 return 0 breaks 0 | result 2 | deciding 0/0", "they held");
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTUTUTUT UU UUUTT");
    FieldsTests.check(engine, "6-4 3-2* | sets 1-0 games 9-6 points 36-24 | serve 88 return 29 breaks 2 | result 2 | deciding 0/0",
        "unfinished");
    return true;
}

(:test)
function fieldsEarlyEndTest(logger as Logger) as Boolean {
    // End match level: a draw (3). Ended one point down in the third game, which we serve: a loss (0),
    // and that point counts.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UT");
    TestKit.add(engine, EVENT_END_MATCH, null);
    FieldsTests.check(engine, "1-1* | sets 0-0 games 1-1 points 4-4 | serve 100 return 0 breaks 0 | result 3 | deciding 0/0", "draw");
    TestKit.play(engine, "< t");
    TestKit.add(engine, EVENT_END_MATCH, null);
    FieldsTests.check(engine, "1-1* | sets 0-0 games 1-1 points 4-5 | serve 80 return 0 breaks 0 | result 0 | deciding 0/0", "loss");
    return true;
}

(:test)
function fieldsSuperTieBreakTest(logger as Logger) as Boolean {
    // The super tie-break is a set with no games: its points are its score in the text (10-8), starred
    // while in progress, and they count in the points won. Sets of 2 games, tie-break at 2-2.
    var config = TestKit.format(2, 2, 2, true);
    config.superTieBreak = true;
    var engine = new ScoringEngine(config);
    TestKit.play(engine, "UU TT uuu tt");
    FieldsTests.check(engine, "2-0 0-2 3-2* | sets 1-1 games 2-2 points 11-10 | serve 255 return 255 breaks 255 | result 2 | deciding 0/0",
        "in progress");
    TestKit.play(engine, "uuuuu tttttt uu");
    FieldsTests.check(engine, "2-0 0-2 10-8 | sets 2-1 games 2-2 points 18-16 | serve 255 return 255 breaks 255 | result 1 | deciding 0/0",
        "won");
    return true;
}

(:test)
function fieldsTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only: the score is the tie-break's points, 7-5, starred when
    // End match stops it (5-4*); a set won and no games. Me first: our 6 serve points won, 1 of their 6
    // (by turn, two each after the first); no game served, so no break, but serve tracking on: 0.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_7), "Me");
    TestKit.play(engine, "uttuuttuutuu");
    FieldsTests.check(engine, "7-5 | sets 1-0 games 0-0 points 7-5 | serve 100 return 17 breaks 0 | result 1 | deciding 0/0", "won");
    engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_7), "Me");
    TestKit.play(engine, "uuuuutttt");
    TestKit.add(engine, EVENT_END_MATCH, null);
    FieldsTests.check(engine, "5-4* | sets 0-0 games 0-0 points 5-4 | serve 60 return 50 breaks 0 | result 1 | deciding 0/0",
        "End match");
    return true;
}

(:test)
function fieldsScoreFitsTest(logger as Logger) as Boolean {
    // The Score field holds 48 bytes, terminator included: a score beyond any real match is cut to 47
    // characters. Without stats (a log that doesn't replay), the fields that need them are 0xFF. The
    // lap's outcome field: its code, or 0xFF when the lap holds no finished game.
    Test.assertEqual(SessionValues.SCORE_BYTES, 48);
    var values = new SessionValues(MatchEndTests.fiveSets(10000, 9998), null);
    Test.assertEqual(values.score.toUtf8Array().size() + 1, SessionValues.SCORE_BYTES);
    Test.assert(values.result == RESULT_UNFINISHED && values.servePointsWonPercent == 0xFF && values.returnPointsWonPercent == 0xFF);
    Test.assert(values.breaksWon == 0xFF && values.decidingPointsWon == 0xFF && values.decidingPointsPlayed == 0xFF);
    Test.assertEqual(new LapValues(2, [3, 1], LAP_WE_BROKE).getOutcomeCode(), 1);
    Test.assertEqual(new LapValues(3, [10, 8], LAP_TIE_BREAK).getOutcomeCode(), 4);
    Test.assertEqual(new LapValues(1, [2, 2], null).getOutcomeCode(), 0xFF);
    return true;
}

(:test)
function fieldsPointDifferentialTest(logger as Logger) as Boolean {
    // Our points minus theirs, set after every point and undo, and only when it changes. Events that
    // play no point leave it: swap, fix, deuce mode, End set now; the points of the game End set now
    // drops stay. A resumed match starts the new session's chart where the score stands.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    Test.assertEqual(rig.recorder.pointDifferential, 0);
    rig.play("uut<t<<< T");
    FieldsTests.checkDifferential(rig, -4, [1, 2, 1, 2, 1, 2, 1, 0, -1, -2, -3, -4]);
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("uut");
    rig.add(EVENT_SWAP_OUR_SERVER, null);
    rig.add(EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    rig.add(EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    rig.add(EVENT_END_SET, TEAM_US);
    FieldsTests.checkDifferential(rig, 1, [1, 2, 1]);
    rig.play("<<<<<");
    FieldsTests.checkDifferential(rig, 2, [1, 2, 1, 2]);
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTT tt");
    var recorder = new TestKit.FakeRecorder();
    var session = new SessionManager(recorder);
    Test.assert(session.start(false, false));
    new LapCommitter(session).resume(engine.getState());
    Test.assertEqual(recorder.pointDifferential, -6);
    return true;
}

(:test)
function fieldsSessionValuesAtStopTest(logger as Logger) as Boolean {
    // Set while recording, right before the timer stops: with a running timer, once before stop(). The
    // game's lap is written already, so the last lap's values are the set's score with no outcome.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("U");
    rig.recorder.clear();
    Test.assert(rig.session.save());
    TestKit.assertCalls(rig.recorder, ["values 1 1-0 -", "session", "stop", "save", "sensors off"], "save while the timer runs");
    FieldsTests.checkRecorded(rig, "1-0* | sets 0-0 games 1-0 points 4-0 | serve 100 return 255 breaks 0 | result 2 | deciding 0/0");
    // Saved from the pause: set at the pause, then again at the save, the lap's fields with them, since
    // the menus can change them (End match ends the match: a win, no longer unfinished; Edit score).
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("U");
    rig.recorder.clear();
    Test.assert(rig.session.pause());
    TestKit.assertCalls(rig.recorder, ["values 1 1-0 -", "session", "stop"], "pause");
    FieldsTests.checkRecorded(rig, "1-0* | sets 0-0 games 1-0 points 4-0 | serve 100 return 255 breaks 0 | result 2 | deciding 0/0");
    rig.add(EVENT_END_MATCH, null);
    rig.recorder.clear();
    Test.assert(rig.session.save());
    TestKit.assertCalls(rig.recorder, ["values 1 1-0 -", "session", "save", "sensors off"], "save from the pause");
    FieldsTests.checkRecorded(rig, "1-0* | sets 0-0 games 1-0 points 4-0 | serve 100 return 255 breaks 0 | result 1 | deciding 0/0");
    // A save the watch refuses keeps the session: the next save sets them again.
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.recorder.saveResult = false;
    Test.assert(!rig.session.save());
    rig.recorder.saveResult = true;
    rig.recorder.clear();
    Test.assert(rig.session.save());
    TestKit.assertCalls(rig.recorder, ["values 1 0-0 -", "session", "save", "sensors off"], "second save");
    return true;
}

(:test)
function fieldsSessionValuesMatchOnlyTest(logger as Logger) as Boolean {
    // Not in the warm-up, even with the match given (the serve answers come before it ends); not without
    // a match, as before the app gives it. The point differential reaches the recorder only while
    // recording.
    var recorder = new TestKit.FakeRecorder();
    var session = new SessionManager(recorder);
    session.setMatch(TestKit.newMatch(new MatchConfig(), "Me"), TestKit.START);
    Test.assert(session.start(false, true) && session.pause() && session.resume() && session.startMatch());
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "stop", "start", "lap"], "warm-up");
    recorder = new TestKit.FakeRecorder();
    session = new SessionManager(recorder);
    session.setPointDifferential(3);
    Test.assertEqual(recorder.pointDifferentials.size(), 0);
    Test.assert(session.start(false, false) && session.save());
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "stop", "save", "sensors off"], "no match");
    Test.assert(recorder.sessionValues == null);
    recorder = new TestKit.FakeRecorder();
    session = new SessionManager(recorder);
    Test.assert(session.start(false, true));
    session.setPointDifferential(3);
    Test.assertEqual(recorder.pointDifferential, 3);
    return true;
}

(:test)
module FieldsTests {

    // The session values of the engine's match, as the save writes them.
    function check(engine as ScoringEngine, expected as String, message as String) as Void {
        Test.assertEqualMessage(SessionValues.compute(engine, TestKit.START).toString(), expected, message);
    }

    function checkRecorded(rig as TestKit.Rig, expected as String) as Void {
        var values = rig.recorder.sessionValues;
        Test.assert(values != null);
        Test.assertEqual((values as SessionValues).toString(), expected);
    }

    // The value the record field holds, and every value set so far.
    function checkDifferential(rig as TestKit.Rig, value as Number, history as Array<Number>) as Void {
        Test.assertEqual(rig.recorder.pointDifferential, value);
        Test.assertEqual(rig.recorder.pointDifferentials.toString(), history.toString());
    }
}

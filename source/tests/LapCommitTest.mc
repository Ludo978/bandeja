import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The lap commit, with a fake session: one lap per game, written at the point that
// wins it, with its lap values, except the match point, whose game's lap the save closes; lap 1 is the
// warm-up when it's on. The FIT API can't change or remove a lap: undoing a game-winning point leaves
// its lap, the game played again never writes a second one, and the lap keeps its first values.
// RandomMatchTest checks the laps of random matches in every format. Laps are written as
// TestKit.FakeRecorder keeps them, "<set> <games us>-<games them> <outcome code>", "-" for no outcome,
// "none" for the warm-up; matches are played through the app's match holder (TestKit.Rig), "<" an undo.

(:test)
function lapAtGameWinningPointTest(logger as Logger) as Boolean {
    // The values go to the recorder right before the lap closes, at the point that wins the game; the
    // points before it and after it write nothing.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.recorder.clear();
    rig.play("uuu");
    TestKit.assertCalls(rig.recorder, [], "game point");
    Test.assert(!rig.match.lapWritten);
    rig.play("u");
    LapTests.check(rig, ["none", "1 1-0 0"], "game won");
    TestKit.assertCalls(rig.recorder, ["values 1 1-0 0", "lap"], "game won, calls");
    Test.assert(rig.match.lapWritten);
    rig.play("t");
    LapTests.check(rig, ["none", "1 1-0 0"], "next game's first point");
    Test.assert(!rig.match.lapWritten);
    rig.play("ttt");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "second game won");
    Test.assertEqual(rig.laps.getCommitted(), 2);
    return true;
}

(:test)
function lapOutcomeCodesTest(logger as Logger) as Boolean {
    // We serve the first game: we hold (0), break (1), get broken (3), they hold (2); they serve first.
    // No serving team: regular games are 5, a tie-break is still 4.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("UUTT");
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1", "1 2-1 3", "1 2-2 2"], "codes 0 to 3");
    rig = new TestKit.Rig(new MatchConfig(), "Opponents Me", true);
    rig.play("UT");
    LapTests.check(rig, ["none", "1 1-0 1", "1 1-1 3"], "they serve first");
    rig = new TestKit.Rig(TestKit.format(1, 2, 1, true), "", true);
    rig.play("UT U");
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 5", "1 1-1 5", "1 2-1 4"], "serve tracking off");
    return true;
}

(:test)
function lapTieBreaksTest(logger as Logger) as Boolean {
    // A tie-break's lap at its winning point, which wins the set; the set's last game's lap too. The
    // super tie-break ends the match, so its lap is the save's. Outcome 4 for both, and the set's score
    // after them: the games with the tie-break (3-2), the super tie-break's points (10-8). Sets to 2
    // games, tie-break at 2-2, then the super tie-break.
    var config = TestKit.format(2, 2, 2, true);
    config.superTieBreak = true;
    var rig = new TestKit.Rig(config, "Me", true);
    rig.play("UTUT");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2", "1 2-1 0", "1 2-2 2"], "to the tie-break");
    rig.play("uuuuuu");
    Test.assert(!rig.match.lapWritten);
    rig.play("u");
    Test.assert(rig.match.lapWritten && rig.getState().setScores.size() == 1);
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2", "1 2-1 0", "1 2-2 2", "1 3-2 4"], "tie-break's lap");
    rig.play("T T");
    Test.assert(rig.match.lapWritten && rig.getState().setScores.size() == 2);
    var sets = ["none", "1 1-0 0", "1 1-1 2", "1 2-1 0", "1 2-2 2", "1 3-2 4", "2 0-1 2", "2 0-2 3"];
    LapTests.check(rig, sets, "second set won");
    rig.play("uuuuuuuu tttttttt uu");
    Test.assert(rig.getState().matchOver && !rig.match.lapWritten);
    LapTests.check(rig, sets, "super tie-break won: no lap");
    Test.assert(rig.session.save());
    sets.add("3 10-8 4");
    LapTests.check(rig, sets, "super tie-break, at save");
    return true;
}

(:test)
function lapTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only: the match point writes no lap, so the saved activity has
    // the warm-up's lap and one more, closed by the save: set 1, the tie-break's points, outcome 4 (a
    // tie-break). Won 7-5, after the warm-up.
    var rig = new TestKit.Rig(TestKit.preset(PRESET_TIE_BREAK_7), "Me", true);
    rig.play("uuuuuttttt u");
    Test.assert(!rig.getState().matchOver && !rig.match.lapWritten);
    LapTests.check(rig, ["none"], "in play");
    rig.play("u");
    Test.assert(rig.getState().matchOver && !rig.match.lapWritten);
    LapTests.check(rig, ["none"], "won");
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 7-5 4"], "at save");
    // Ended by End match at 5-4: the save's lap has the tie-break's points and no outcome.
    rig = new TestKit.Rig(TestKit.preset(PRESET_TIE_BREAK_10), "Me", true);
    rig.play("uuuuutttt");
    rig.add(EVENT_END_MATCH, null);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 5-4 -"], "End match");
    return true;
}

(:test)
function lapLateFixServingTeamTest(logger as Logger) as Boolean {
    // Serve tracking starts late. A fix between games is for the next game: the game before it keeps 5.
    // A fix during a game covers the whole game, even after the game's first point: its lap is only
    // written at its winning point. Swap, fix, deuce mode and their undo never write a lap.
    var rig = new TestKit.Rig(new MatchConfig(), "", true);
    rig.play("U");
    LapTests.check(rig, ["none", "1 1-0 5"], "no serving team");
    rig.add(EVENT_FIX_SERVING_TEAM, TEAM_US);
    rig.add(EVENT_SWAP_OUR_SERVER, null);
    rig.add(EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    rig.play("<<");
    LapTests.check(rig, ["none", "1 1-0 5"], "fix between games");
    rig.play("T");
    LapTests.check(rig, ["none", "1 1-0 5", "1 1-1 3"], "game after the fix");
    rig.play("u");
    rig.add(EVENT_FIX_SERVING_TEAM, TEAM_US);
    rig.add(EVENT_SWAP_OUR_SERVER, null);
    rig.play("<");
    LapTests.check(rig, ["none", "1 1-0 5", "1 1-1 3"], "fix during a game");
    rig.play("U");
    LapTests.check(rig, ["none", "1 1-0 5", "1 1-1 3", "1 2-1 0"], "game fixed after its first point");
    return true;
}

(:test)
function lapUndoGameWinningPointTest(logger as Logger) as Boolean {
    // Undoing the point that won a game leaves its lap, and writes nothing; the game played again
    // writes no second lap, and the next game's point writes the next one.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("U");
    LapTests.check(rig, ["none", "1 1-0 0"], "game won");
    rig.recorder.clear();
    rig.play("<");
    Test.assert(!rig.match.lapWritten && rig.laps.getCommitted() == 1);
    rig.play("u");
    Test.assert(!rig.match.lapWritten && rig.getState().finishedGames.size() == 1);
    TestKit.assertCalls(rig.recorder, [], "undone, played again");
    LapTests.check(rig, ["none", "1 1-0 0"], "no second lap");
    rig.play("T");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "next game");
    // Won by the other team after all: the lap keeps its first values (we held, 1-0) while the game is
    // theirs (they broke, 0-1): the FIT API can't change a written lap. The laps after it are right.
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("U< ttttt");
    Test.assertEqual(LapValues.forGame(rig.getState(), 0).toString(), "1 0-1 3");
    LapTests.check(rig, ["none", "1 1-0 0"], "first values kept");
    rig.play("U");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 1"], "next lap");
    return true;
}

(:test)
function lapUndoAcrossWrittenLapTest(logger as Logger) as Boolean {
    // Back across two written laps and played again: no second lap for either game.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("UT");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "two games");
    rig.play("<<<<<");
    Test.assertEqual(rig.getState().finishedGames.size(), 0);
    rig.play("uT");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "one lap per game");
    rig.play("U");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2", "1 2-1 0"], "the next game's lap");
    // Saved after undoing a game-winning point: the last lap holds what came after the written lap,
    // with no outcome.
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("U<");
    rig.add(EVENT_END_MATCH, null);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 0", "1 0-0 -"], "saved after the undo");
    return true;
}

(:test)
function lapEndSetNowTest(logger as Logger) as Boolean {
    // Between games: the last game's lap is already written, End set now writes none, nor does the
    // next set's first point.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("UUT");
    rig.add(EVENT_END_SET, null);
    Test.assert(!rig.match.lapWritten);
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1", "1 2-1 3"], "end set now between games");
    rig.play("t");
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1", "1 2-1 3"], "next set's first point");
    // During a game: the game is dropped and gets no lap of its own; its time goes into the next game's
    // lap, which its server opens (they served the dropped game: we break). A set given at 0-0 holds
    // no game.
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("Utt");
    rig.add(EVENT_END_SET, null);
    rig.play("u");
    LapTests.check(rig, ["none", "1 1-0 0"], "dropped game");
    rig.play("uuu");
    LapTests.check(rig, ["none", "1 1-0 0", "2 1-0 1"], "next set's first game");
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.add(EVENT_END_SET, TEAM_US);
    rig.play("U");
    LapTests.check(rig, ["none", "2 1-0 0"], "set given at 0-0");
    // Ending the match during a game, from the pause menu: the last lap holds the dropped game, with
    // the set's score and no outcome. The pause set its values and the save sets them again (an edit
    // made while paused can change them; End set now doesn't here). Between games, the last lap holds
    // the time since the last game, with no outcome.
    rig = new TestKit.Rig(TestKit.preset(PRESET_ONE_SET), "Me", true);
    rig.play("Utt");
    rig.recorder.clear();
    Test.assert(rig.session.pause());
    rig.add(EVENT_END_SET, null);
    Test.assertEqual(LapValues.forUnfinished(rig.getState()).toString(), "1 1-0 -");
    Test.assert(rig.session.save());
    TestKit.assertCalls(rig.recorder, ["values 1 1-0 -", "session", "stop", "values 1 1-0 -", "session", "save", "sensors off"],
        "pause, save");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-0 -"], "match ended by end set now");
    rig = new TestKit.Rig(TestKit.preset(PRESET_ONE_SET), "Me", true);
    rig.play("U");
    rig.add(EVENT_END_SET, null);
    Test.assert(rig.getState().matchOver && rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-0 -"], "match ended by end set now between games");
    return true;
}

(:test)
function lapEndMatchTest(logger as Logger) as Boolean {
    // During a game, the unfinished game gets the last lap, with no outcome; between games the last
    // game's lap is already written, so the last lap holds only the time since, with no outcome; in the
    // super tie-break its points are the set's score. End match and its undo write no lap. Warm-up off:
    // the game laps start the activity.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("UT uu");
    rig.add(EVENT_END_MATCH, null);
    Test.assert(!rig.match.lapWritten);
    rig.play("<");
    rig.add(EVENT_END_MATCH, null);
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "end match");
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2", "1 1-1 -"], "end match during a game, at save");
    rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    rig.play("UT");
    rig.add(EVENT_END_MATCH, null);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["1 1-0 0", "1 1-1 2", "1 1-1 -"], "between games, no warm-up");
    var config = TestKit.format(2, 2, 2, true);
    config.superTieBreak = true;
    rig = new TestKit.Rig(config, "Me", true);
    rig.play("UU TT uuuuuuu ttttt");
    rig.add(EVENT_END_MATCH, null);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1", "2 0-1 3", "2 0-2 2", "3 7-5 -"], "super tie-break");
    return true;
}

(:test)
function lapAtSaveTest(logger as Logger) as Boolean {
    // A match won: the match point writes no lap, so no lap holds the time on the summary; the save
    // closes the last game's, with its values set where the timer stops, or at the pause when it's
    // saved from there. Undone and played again, the match point still writes none. Saved before any
    // point: the match's only lap has the score and no outcome.
    var rig = new TestKit.Rig(TestKit.format(1, 2, 2, true), "Me", true);
    rig.play("UU");
    Test.assert(rig.getState().matchOver && !rig.match.lapWritten);
    LapTests.check(rig, ["none", "1 1-0 0"], "match won");
    rig.play("<u");
    Test.assert(rig.getState().matchOver && !rig.match.lapWritten);
    LapTests.check(rig, ["none", "1 1-0 0"], "match point undone and won again");
    rig.recorder.clear();
    Test.assert(rig.session.save());
    TestKit.assertCalls(rig.recorder, ["values 1 2-0 1", "session", "stop", "save", "sensors off"], "save");
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1"], "at save");
    rig = new TestKit.Rig(TestKit.format(1, 2, 2, true), "Me", true);
    rig.play("UU");
    Test.assert(rig.session.pause() && rig.session.save());
    LapTests.check(rig, ["none", "1 1-0 0", "1 2-0 1"], "saved from the pause");
    rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["none", "1 0-0 -"], "nothing played");
    return true;
}

(:test)
function lapAlertFlagTest(logger as Logger) as Boolean {
    // ScoreInput.lap, which ScoreDelegate gives the feedback: true for the press that wrote a lap, so
    // the watch plays its lap alert there: a game or a set won the first time. False for a
    // point that wins only the point, the match point, an undo, a press the debounce ignores, and the
    // game won again after its winning point was undone (its lap is written already). Sets to 2 games.
    var rig = new TestKit.Rig(TestKit.format(2, 2, 2, true), "Me", false);
    var now = 1000;
    for (var i = 0; i < 3; i++) {
        now += 1000;
        LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_POINT, false, "point " + i);
    }
    now += 1000;
    LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_GAME, true, "game");
    Test.assert(rig.press(WatchUi.KEY_DOWN, now + 300) == INPUT_NONE && !rig.input.lap);
    Test.assert(rig.press(WatchUi.KEY_ESC, now + 400) == INPUT_UNDO && !rig.input.lap);
    now += 500;
    LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_GAME, false, "game won again");
    for (var i = 0; i < 3; i++) {
        now += 1000;
        LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_POINT, false, "set point " + i);
    }
    now += 1000;
    LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_SET, true, "set");
    for (var i = 0; i < 7; i++) {
        now += 1000;
        LapTests.press(rig, WatchUi.KEY_DOWN, now, i == 3 ? WON_GAME : WON_POINT, i == 3, "second set " + i);
    }
    now += 1000;
    LapTests.press(rig, WatchUi.KEY_DOWN, now, WON_MATCH, false, "match");
    Test.assert(rig.press(WatchUi.KEY_ESC, now + 100) == INPUT_UNDO && !rig.input.lap);
    LapTests.press(rig, WatchUi.KEY_UP, now + 200, WON_POINT, false, "match point undone");
    LapTests.check(rig, ["1 1-0 0", "1 2-0 1", "2 1-0 0"], "laps");
    return true;
}

(:test)
function lapWarmUpUntouchedTest(logger as Logger) as Boolean {
    // The warm-up lap is closed by the match start with no lap values, and a pause in the warm-up sets
    // none, even once the serve answer is logged (the START that ends the warm-up asks it).
    var recorder = new TestKit.FakeRecorder();
    var session = new SessionManager(recorder);
    var laps = new LapCommitter(session);
    session.start(false, true);
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    Test.assert(!laps.update(engine.getState()));
    session.pause();
    session.resume();
    session.startMatch();
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "stop", "start", "lap"], "warm-up");
    Test.assert(recorder.laps.toString().equals(["none"].toString()) && laps.getCommitted() == 0);
    TestKit.play(engine, "U");
    Test.assert(laps.update(engine.getState()));
    Test.assert(session.save());
    Test.assertEqual(recorder.laps.toString(), ["none", "1 1-0 0", "1 1-0 -"].toString());
    return true;
}

(:test)
function lapResumeTest(logger as Logger) as Boolean {
    // Resume after a crash: the games before it had their laps in the lost session, so the new one
    // starts with the game in progress, whose winning point writes its lap, and gets no burst of laps.
    // Resumed between games, the next game's point writes the first lap.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTuu");
    var recorder = new TestKit.FakeRecorder();
    var session = new SessionManager(recorder);
    var laps = new LapCommitter(session);
    session.start(false, false);
    laps.resume(engine.getState());
    Test.assertEqual(laps.getCommitted(), 2);
    TestKit.play(engine, "T");
    Test.assert(laps.update(engine.getState()));
    Test.assertEqual(recorder.laps.toString(), ["1 1-2 3"].toString());
    TestKit.play(engine, "u");
    Test.assert(!laps.update(engine.getState()));
    Test.assert(session.save());
    Test.assertEqual(recorder.laps.toString(), ["1 1-2 3", "1 1-2 -"].toString());
    engine = TestKit.matchOf(new MatchConfig(), "Me", "UT");
    recorder = new TestKit.FakeRecorder();
    session = new SessionManager(recorder);
    laps = new LapCommitter(session);
    session.start(false, false);
    laps.resume(engine.getState());
    TestKit.play(engine, "U");
    Test.assert(laps.update(engine.getState()));
    Test.assertEqual(recorder.laps.toString(), ["1 2-1 0"].toString());
    return true;
}

(:test)
module LapTests {

    function check(rig as TestKit.Rig, expected as Array<String>, message as String) as Void {
        Test.assertEqualMessage(rig.recorder.laps.toString(), expected.toString(), message);
    }

    // A point press at now: it counts, wins won, and wrote a lap or not.
    function press(rig as TestKit.Rig, key as WatchUi.Key, now as Number, won as PointWon, lap as Boolean,
            message as String) as Void {
        Test.assertEqualMessage(rig.press(key, now), INPUT_POINT, message);
        Test.assertMessage(rig.input.won == won && rig.input.lap == lap, message + ": won " + rig.input.won
            + ", lap " + rig.input.lap);
    }
}

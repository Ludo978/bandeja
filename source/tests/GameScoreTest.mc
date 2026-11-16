import Toybox.Lang;
import Toybox.Test;

// Points, games and deuce rules: 0, 15, 30, 40, AD, then game; Advantage, Golden, Star
// and Silver; the deuce counter (DEUCE 1, DEUCE 2...); the deciding point; a deuce mode change
// applying from the next game. Each checked step is written as TestKit.game() gives it, "<games>
// <points>", then "deuce <n>" and "deciding"; it's also undone and played again, and compared with a
// full replay (TestKit.checkSteps()).

(:test)
function gameScorePointsTest(logger as Logger) as Boolean {
    // Without a deuce every mode plays the same game, 40-0 and 40-30 included, and the first game is
    // played with the format's mode.
    for (var i = 0; i < TestKit.MODES.size(); i++) {
        var mode = TestKit.MODES[i] as DeuceMode;
        var engine = new ScoringEngine(TestKit.withMode(mode));
        Test.assertEqual(engine.getState().gameDeuceMode, mode);
        TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "0-0 15-0"], ["u", "0-0 30-0"], ["u", "0-0 40-0"], ["u", "1-0 0-0"]]);
        TestKit.play(engine, "tutu");
        TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-0 30-40"], ["t", "1-1 0-0"]]);
        TestKit.play(engine, "uutut");
        TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "2-1 0-0"]]);
        Test.assert(engine.getState().pointsWon[TEAM_US] == 10 && engine.getState().pointsWon[TEAM_THEM] == 6);
    }
    return true;
}

(:test)
function gameScoreAdvantageTest(logger as Logger) as Boolean {
    // Unlimited deuces, win by two, never a deciding point; the counter keeps going.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_ADVANTAGE));
    TestKit.play(engine, "uuutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [
        ["t", "0-0 40-40 deuce 1"], ["u", "0-0 AD-40 deuce 1"], ["t", "0-0 40-40 deuce 2"], ["t", "0-0 40-AD deuce 2"],
        ["u", "0-0 40-40 deuce 3"], ["t", "0-0 40-AD deuce 3"], ["t", "0-1 0-0"]
    ]);
    // Won by us at the first advantage.
    TestKit.play(engine, "tttuu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "0-1 40-40 deuce 1"], ["u", "0-1 AD-40 deuce 1"], ["u", "1-1 0-0"]]);
    // Many deuces: the display stays 40 or AD.
    TestKit.play(engine, "uuuttt" + TestKit.repeat("ut", 9));
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-1 40-AD deuce 10"], ["t", "1-2 0-0"]]);
    return true;
}

(:test)
function gameScoreGoldenPointTest(logger as Logger) as Boolean {
    // At 40-40 the next point wins the game, for either team.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_GOLDEN));
    TestKit.play(engine, "uutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "0-0 40-30"], ["t", "0-0 40-40 deuce 1 deciding"], ["u", "1-0 0-0"]]);
    TestKit.play(engine, "ututu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-0 40-40 deuce 1 deciding"], ["t", "1-1 0-0"]]);
    return true;
}

(:test)
function gameScoreStarPointTest(logger as Logger) as Boolean {
    // Deuce 1 and deuce 2 with advantage, the next point at deuce 3 decides.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_STAR));
    TestKit.play(engine, "uuutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [
        ["t", "0-0 40-40 deuce 1"], ["u", "0-0 AD-40 deuce 1"], ["t", "0-0 40-40 deuce 2"], ["t", "0-0 40-AD deuce 2"],
        ["u", "0-0 40-40 deuce 3 deciding"], ["u", "1-0 0-0"]
    ]);
    // Them winning the Star point; then games won with the advantage after deuce 1 and after deuce 2.
    TestKit.play(engine, "tttuuutuu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-0 40-40 deuce 3 deciding"], ["t", "1-1 0-0"]]);
    TestKit.play(engine, "uuuttt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "1-1 AD-40 deuce 1"], ["u", "2-1 0-0"]]);
    TestKit.play(engine, "uuutttutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "2-2 0-0"]]);
    return true;
}

(:test)
function gameScoreSilverPointTest(logger as Logger) as Boolean {
    // Deuce 1 with advantage, the next point at deuce 2 decides.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_SILVER));
    TestKit.play(engine, "uuutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [
        ["t", "0-0 40-40 deuce 1"], ["t", "0-0 40-AD deuce 1"], ["u", "0-0 40-40 deuce 2 deciding"], ["u", "1-0 0-0"]
    ]);
    TestKit.play(engine, "uuuttt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "1-0 AD-40 deuce 1"], ["t", "1-0 40-40 deuce 2 deciding"], ["t", "1-1 0-0"]]);
    // Won with the advantage after deuce 1.
    TestKit.play(engine, "tttuuut");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-2 0-0"]]);
    return true;
}

(:test)
function gameScoreDeuceModeChangeMidGameTest(logger as Logger) as Boolean {
    // A change during a game applies from the next game; the current game keeps its rule. The format
    // keeps the mode the match started with.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_STAR));
    TestKit.play(engine, "uut");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    var state = engine.getState();
    Test.assert(state.deuceMode == DEUCE_GOLDEN && state.gameDeuceMode == DEUCE_STAR);
    Test.assertEqual(engine.getConfig().deuceMode, DEUCE_STAR);
    // Still the Star point game: no Golden point.
    TestKit.play(engine, "tu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [
        ["t", "0-0 40-40 deuce 1"], ["u", "0-0 AD-40 deuce 1"], ["t", "0-0 40-40 deuce 2"], ["t", "0-0 40-AD deuce 2"],
        ["u", "0-0 40-40 deuce 3 deciding"], ["t", "0-1 0-0"]
    ]);
    // The next game plays the Golden point.
    TestKit.play(engine, "uutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["u", "0-1 40-30"], ["t", "0-1 40-40 deuce 1 deciding"], ["u", "1-1 0-0"]]);

    // Changed on the deciding point itself: that point still decides.
    TestKit.play(engine, "uuuttt");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_ADVANTAGE);
    Test.assertEqual(TestKit.game(engine.getState()), "1-1 40-40 deuce 1 deciding");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-2 0-0"]]);

    // From Advantage to Silver at deuce 3: the game goes on with advantage, Silver comes next.
    TestKit.play(engine, "uuutttutut");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_SILVER);
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-2 40-AD deuce 3"], ["u", "1-2 40-40 deuce 4"]]);
    TestKit.play(engine, "uu uuutttu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "2-2 40-40 deuce 2 deciding"]]);
    return true;
}

(:test)
function gameScoreDeuceModeChangeBeforeGameTest(logger as Logger) as Boolean {
    // A change before a game's first point applies to that game: before the
    // first point of the match, and between games.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_ADVANTAGE));
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    TestKit.play(engine, "uuutt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "0-0 40-40 deuce 1 deciding"], ["u", "1-0 0-0"]]);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_SILVER);
    TestKit.play(engine, "uuutttu");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "1-0 40-40 deuce 2 deciding"]]);

    // Several changes in one game: the last one is the next game's rule. Back to the game's own rule
    // before it ends: the next game keeps that rule too.
    TestKit.play(engine, "t u");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_STAR);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_ADVANTAGE);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    Test.assertEqual(engine.getState().gameDeuceMode, DEUCE_SILVER);
    TestKit.play(engine, "uuu");
    Test.assertEqual(engine.getState().gameDeuceMode, DEUCE_GOLDEN);
    TestKit.play(engine, "t");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_STAR);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    TestKit.play(engine, "ttt");
    Test.assert(engine.getState().games[TEAM_THEM] == 2 && engine.getState().gameDeuceMode == DEUCE_GOLDEN);
    return true;
}

(:test)
function gameScoreUndoTest(logger as Logger) as Boolean {
    // Undo walks back through a game won on a deciding point, a mid-game mode change, deuces and a
    // game boundary, giving back the deuce mode each time, and the match goes on from there.
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_SILVER));
    TestKit.play(engine, "U tttuuut");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    TestKit.play(engine, "ut");
    Test.assert(TestKit.game(engine.getState()).equals("1-1 0-0") && engine.getState().gameDeuceMode == DEUCE_GOLDEN);
    var expected = ["1-0 40-40 deuce 2 deciding", "1-0 40-AD deuce 1", "1-0 40-AD deuce 1", "1-0 40-40 deuce 1", "1-0 30-40"];
    var modes = [DEUCE_GOLDEN, DEUCE_GOLDEN, DEUCE_SILVER, DEUCE_SILVER, DEUCE_SILVER];
    for (var i = 0; i < expected.size(); i++) {
        engine.undo();
        var state = engine.getState();
        Test.assertMessage(TestKit.game(state).equals(expected[i]) && state.deuceMode == modes[i]
            && state.gameDeuceMode == DEUCE_SILVER, "undo " + i + ": " + TestKit.game(state));
    }
    TestKit.play(engine, "<<<<< <");
    Test.assertEqual(TestKit.game(engine.getState()), "0-0 40-0");
    // Played differently from there.
    TestKit.play(engine, "ttt");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "0-0 40-AD deuce 1"], ["t", "0-1 0-0"]]);
    return true;
}

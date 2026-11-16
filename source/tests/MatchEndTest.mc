import Toybox.Lang;
import Toybox.Test;

// Match end: the match is over when a team wins setsToWin sets, End
// set now can end it too; an early end (End match) is won on sets, then games in the unfinished set,
// then points in the current game, or drawn; nothing follows the end, and undo reopens the match
// exactly as it was; the score text, result and totals for the summary and the FIT fields. The match
// is written as TestKit.sets() gives it.

(:test)
function matchEndBestOf3Test(logger as Logger) as Boolean {
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UTUTUTUTUU UUUTTTUU uuu");
    var before = engine.getState().copy();
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "6-4 6-3 | 0-0 0-0 over"]]);
    var state = engine.getState();
    Test.assert(state.getWinner() == TEAM_US && state.getResult() == RESULT_WIN);
    MatchEndTests.checkTotals(state, [2, 0], [12, 7]);
    Test.assertEqual(state.getScoreText(), "6-4 6-3");

    // BACK on the summary undoes the match point: the match is open again, exactly as it
    // was. Played differently from there: they come back and win in three sets.
    engine.undo();
    TestKit.assertSameState(engine.getState(), before, "undo of the match point");
    Test.assert(engine.getState().getResult() == RESULT_UNFINISHED && engine.getState().getWinner() == null);
    TestKit.play(engine, "TTT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "6-4 5-7 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTUTTT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "6-4 5-7 3-6 | 0-0 0-0 over"]]);
    state = engine.getState();
    Test.assert(state.getWinner() == TEAM_THEM && state.getResult() == RESULT_LOSS);
    MatchEndTests.checkTotals(state, [1, 2], [14, 17]);
    Test.assertEqual(state.getScoreText(), "6-4 5-7 3-6");
    return true;
}

(:test)
function matchEndUndoAcrossSetsTest(logger as Logger) as Boolean {
    // Undo across games, a tie-break, sets, the super tie-break and the end of the match, back to the
    // first point: each undo gives back exactly the state the match had.
    var config = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    var played = new ScoringEngine(config);
    TestKit.play(played, TestKit.repeat("UT", 6) + " uuttuuttuuu TTTUTTUT" + TestKit.repeat("ut", 8) + "uu");
    Test.assertEqual(TestKit.sets(played.getState()), "7-6(7-4) 2-6 S10-8 | 0-0 0-0 over");
    var engine = new ScoringEngine(config);
    var states = [engine.getState().copy()];
    var count = played.getState().eventCount;
    for (var i = 0; i < count; i++) {
        Test.assert(engine.add(played.getEvent(i)));
        states.add(engine.getState().copy());
    }
    // 12 games and an 11-point tie-break, 8 games, an 18-point super tie-break.
    Test.assertEqual(count, 109);
    var marks = {
        108 => "7-6(7-4) 2-6 | 0-0 stb 9-8", 91 => "7-6(7-4) 2-6 | 0-0 stb 0-0", 90 => "7-6(7-4) | 2-5 0-40",
        59 => "7-6(7-4) | 0-0 0-0", 58 => "| 6-6 tb 6-4", 48 => "| 6-6 tb 0-0", 47 => "| 6-5 0-40"
    } as Dictionary<Number, String>;
    for (var i = count - 1; i >= 0; i--) {
        var undone = engine.undo();
        Test.assertMessage(undone != null && undone.equals(played.getEvent(i)), "undid " + undone);
        TestKit.assertSameState(engine.getState(), states[i], "undo " + i);
        var mark = marks.get(i);
        Test.assertMessage(mark == null || mark.equals(TestKit.sets(engine.getState())), "undo " + i);
    }
    Test.assert(engine.undo() == null);
    return true;
}

(:test)
function matchEndEndSetEndsMatchTest(logger as Logger) as Boolean {
    // End set now counts like any set won, so it can end the match; nothing follows; undo reopens it.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UTUTUTUTUU UUT uu");
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "6-4 2-1EU | 0-0 0-0 over");
    Test.assert(engine.getState().getResult() == RESULT_WIN && engine.getState().getScoreText().equals("6-4 2-1"));
    MatchEndTests.checkTotals(engine.getState(), [2, 0], [8, 5]);
    MatchEndTests.checkNothingFollows(engine);
    engine.undo();
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 | 2-1 30-0");
    // Them, given the deciding set at 2-2.
    TestKit.play(engine, "TTTTT UTUT");
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_THEM, "6-4 2-6 2-2ET | 0-0 0-0 over");
    Test.assert(engine.getState().getResult() == RESULT_LOSS && engine.getState().getScoreText().equals("6-4 2-6 2-2"));
    return true;
}

(:test)
function matchEndEarlyTest(logger as Logger) as Boolean {
    // Ending early: ahead in sets wins, whatever the unfinished set's games and points;
    // level in sets, its games decide, whatever the points; level in games, the current game's points
    // (an advantage is a point ahead), in a tie-break and the super tie-break their points.
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU TTUT tt", "6-4 | 1-3 0-30 over", RESULT_WIN, "6-4 1-3*");
    MatchEndTests.checkEnd(new MatchConfig(), "TUTUTUTUTT UUUT uu", "4-6 | 3-1 30-0 over", RESULT_LOSS, "4-6 3-1*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UUT tt", "6-4 3-6 | 2-1 0-30 over", RESULT_WIN, "6-4 3-6 2-1*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UTT uu", "6-4 3-6 | 1-2 30-0 over", RESULT_LOSS, "6-4 3-6 1-2*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UTUT uut", "6-4 3-6 | 2-2 30-15 over", RESULT_WIN, "6-4 3-6 2-2*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UTUT uuutttt", "6-4 3-6 | 2-2 40-AD over", RESULT_LOSS, "6-4 3-6 2-2*");
    MatchEndTests.checkEnd(TestKit.preset(PRESET_ONE_SET), "UTUTUTUTUTUT uuttt", "| 6-6 tb 2-3 over", RESULT_LOSS, "6-6*");
    var engine = MatchEndTests.checkEnd(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuuuttttt",
        "6-4 3-6 | 0-0 stb 7-5 over", RESULT_WIN, "6-4 3-6 7-5*");
    MatchEndTests.checkTotals(engine.getState(), [1, 1], [9, 10]);
    return true;
}

(:test)
function matchEndDrawTest(logger as Logger) as Boolean {
    // Level in sets, games and points: a draw, even with nothing played, at deuce, right
    // after a set, in a tie-break or in the super tie-break. Nothing follows the end of the match, not
    // even another End match, and undo reopens it.
    var engine = MatchEndTests.checkEnd(new MatchConfig(), "", "| 0-0 0-0 over", RESULT_DRAW, "0-0*");
    Test.assert(engine.getState().getWinner() == null);
    MatchEndTests.checkTotals(engine.getState(), [0, 0], [0, 0]);
    MatchEndTests.checkNothingFollows(engine);
    engine.undo();
    TestKit.play(engine, "t");
    Test.assertEqual(engine.getState().pointsWon[TEAM_THEM], 1);
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UTUTUT uutt", "6-4 3-6 | 3-3 30-30 over", RESULT_DRAW, "6-4 3-6 3-3*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT UTUTUT uuuttt", "6-4 3-6 | 3-3 40-40 over", RESULT_DRAW, "6-4 3-6 3-3*");
    MatchEndTests.checkEnd(new MatchConfig(), "UTUTUTUTUU UTUTUTTTT", "6-4 3-6 | 0-0 0-0 over", RESULT_DRAW, "6-4 3-6");
    MatchEndTests.checkEnd(TestKit.preset(PRESET_ONE_SET), "UTUTUTUTUTUT uuuutttt", "| 6-6 tb 4-4 over", RESULT_DRAW, "6-6*");
    MatchEndTests.checkEnd(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UTUTUTUTUU UTUTUTTTT uuuuuttttt",
        "6-4 3-6 | 0-0 stb 5-5 over", RESULT_DRAW, "6-4 3-6 5-5*");
    return true;
}

(:test)
function matchEndTieBreakOnlyTest(logger as Logger) as Boolean {
    // End match in Tie-break only: the points decide, sets and games being level, and
    // the tie-break is the unfinished set, starred: 5-4*, a win; 5-5*, a draw; 0-0* with nothing played.
    // No set, no game. Undo reopens it at its match point.
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    var engine = MatchEndTests.checkEnd(config, "uuuuutttt", "| 0-0 stb 5-4 over", RESULT_WIN, "5-4*");
    Test.assert(engine.getState().getWinner() == TEAM_US);
    MatchEndTests.checkTotals(engine.getState(), [0, 0], [0, 0]);
    MatchEndTests.checkNothingFollows(engine);
    MatchEndTests.checkEnd(config, "uuuuuttttt", "| 0-0 stb 5-5 over", RESULT_DRAW, "5-5*");
    MatchEndTests.checkEnd(config, "", "| 0-0 stb 0-0 over", RESULT_DRAW, "0-0*");
    engine = MatchEndTests.checkEnd(TestKit.preset(PRESET_TIE_BREAK_10), "uuuuuuuu ttttttttt", "| 0-0 stb 8-9 over", RESULT_LOSS,
        "8-9*");
    engine.undo();
    TestKit.check(engine, TestKit.VIEW_SITUATION, "MATCH POINT pressure | CHANGE ENDS AT 18 | set T, match T, tie-break", "undone");
    TestKit.play(engine, "t");
    TestKit.check(engine, TestKit.VIEW_SETS, "S8-10 | 0-0 0-0 over", "won after the undo");
    Test.assertEqual(engine.getState().getScoreText(), "8-10");
    return true;
}

(:test)
function matchEndScoreTextTest(logger as Logger) as Boolean {
    // The Score field: our side first, each set's games (a tie-break's set and a set given
    // by End set now too), the super tie-break's points from its first one, and a star on the
    // unfinished set once a point is played in it.
    var engine = new ScoringEngine(new MatchConfig());
    var steps = [["", "0-0*"], ["u", "0-0*"], ["uuu UTUTUTUTU", "6-4"], ["u", "6-4 0-0*"], ["uuu UTUT", "6-4 3-2*"],
        ["TTTT UTUTUTUTUTUT U", "6-4 3-6 7-6"]];
    for (var i = 0; i < steps.size(); i++) {
        TestKit.play(engine, steps[i][0]);
        Test.assertEqual(engine.getState().getScoreText(), steps[i][1]);
    }
    engine = new ScoringEngine(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB));
    TestKit.play(engine, "UTUTUTUTUU UTUTUTTTT u");
    Test.assertEqual(engine.getState().getScoreText(), "6-4 3-6 1-0*");
    TestKit.play(engine, "tttttttt uuuuuuu uu");
    Test.assertEqual(engine.getState().getScoreText(), "6-4 3-6 10-8");
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UTUTUT");
    TestKit.add(engine, EVENT_END_SET, TEAM_THEM);
    TestKit.play(engine, "U");
    Test.assertEqual(engine.getState().getScoreText(), "3-3 1-0*");
    return true;
}

(:test)
function matchEndScoreTextLengthTest(logger as Logger) as Boolean {
    // The Score field holds 48 bytes, so 47 characters and the terminator: long real
    // matches fit whole; a longer score keeps its latest sets after ".." (Free play's many sets,
    // FreePlayTest.mc), here sets beyond any real match.
    Test.assertEqual(MatchState.SCORE_TEXT_MAX, 47);
    var engine = new ScoringEngine(TestKit.format(2, 6, 6, false));
    TestKit.play(engine, TestKit.repeat("UT", 12) + "UU" + TestKit.repeat("UT", 12) + "TT" + TestKit.repeat("UT", 11) + "UU");
    Test.assertEqual(engine.getState().getScoreText(), "14-12 12-14 13-11");
    engine = new ScoringEngine(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB));
    TestKit.play(engine, TestKit.repeat("UT", 6) + "U" + TestKit.repeat("UT", 6) + "T" + TestKit.repeat("ut", 23) + "uu");
    Test.assertEqual(engine.getState().getScoreText(), "7-6 6-7 25-23");
    Test.assertEqual(MatchEndTests.fiveSets(99, 97).getScoreText(), "99-97 97-99 99-97 97-99 99-98*");
    Test.assertEqual(MatchEndTests.fiveSets(10000, 9998).getScoreText(), ".. 9998-10000 10000-9998 9998-10000 10000-9999*");
    return true;
}

(:test)
function matchEndTotalsTest(logger as Logger) as Boolean {
    // Sets and games won and lost: a super tie-break is a set with no games, a tie-break
    // set counts 7-6, the set in progress its games, a set ended now its games.
    var engine = new ScoringEngine(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB));
    TestKit.play(engine, "UTUTUTUTUU UTUTUTTTT uuuuuttt");
    MatchEndTests.checkTotals(engine.getState(), [1, 1], [9, 10]);
    TestKit.play(engine, "tttt uuuu u");
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 3-6 S10-7 | 0-0 0-0 over");
    MatchEndTests.checkTotals(engine.getState(), [2, 1], [9, 10]);
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, TestKit.repeat("UT", 6) + " U UUUTT u");
    MatchEndTests.checkTotals(engine.getState(), [1, 0], [10, 8]);
    TestKit.add(engine, EVENT_END_SET, null);
    MatchEndTests.checkTotals(engine.getState(), [2, 0], [10, 8]);
    return true;
}

(:test)
function matchEndResultCodesTest(logger as Logger) as Boolean {
    // The result values are the FIT Result codes: never renumber. A match in progress is
    // unfinished, even when a team leads.
    Test.assert((RESULT_LOSS as Number) == 0 && (RESULT_WIN as Number) == 1 && (RESULT_UNFINISHED as Number) == 2
        && (RESULT_DRAW as Number) == 3);
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UTUTUTUTUU UU");
    Test.assert(engine.getState().getResult() == RESULT_UNFINISHED && engine.getState().getWinner() == null);
    return true;
}

(:test)
module MatchEndTests {

    // Four finished sets of high-low, low-high..., then a fifth one unfinished at high-(low + 1).
    function fiveSets(high as Number, low as Number) as MatchState {
        var state = new MatchState();
        for (var i = 0; i < 4; i++) {
            var won = i % 2 == 0;
            state.setScores.add(new SetScore(won ? [high, low] : [low, high], null, false, won ? TEAM_US : TEAM_THEM, false));
        }
        state.games = [high, low + 1];
        return state;
    }

    function checkTotals(state as MatchState, sets as Array<Number>, games as Array<Number>) as Void {
        Test.assertMessage(state.getSetsWon(TEAM_US) == sets[0] && state.getSetsWon(TEAM_THEM) == sets[1]
            && state.getGamesWon(TEAM_US) == games[0] && state.getGamesWon(TEAM_THEM) == games[1], "totals " + TestKit.sets(state));
    }

    // End match after moves: the match it leaves, its result and its score text.
    function checkEnd(config as MatchConfig, moves as String, expected as String, result as MatchResult,
            score as String) as ScoringEngine {
        var engine = new ScoringEngine(config);
        TestKit.play(engine, moves);
        TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_MATCH, null, expected);
        Test.assertMessage(engine.getState().getResult() == result, moves + ": result " + engine.getState().getResult());
        Test.assertEqual(engine.getState().getScoreText(), score);
        return engine;
    }

    // Once the match is over every event is refused.
    function checkNothingFollows(engine as ScoringEngine) as Void {
        var events = TestKit.everyValidEvent();
        for (var i = 0; i < events.size(); i++) {
            TestKit.checkRefused(engine, events[i], "after the end, " + events[i]);
        }
    }
}

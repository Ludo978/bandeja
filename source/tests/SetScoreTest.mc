import Toybox.Lang;
import Toybox.Test;

// Sets and tie-breaks: a set is won with N or more games and a 2-game lead, or by
// winning the tie-break at T-T; tie-breaks to 7 or 10 points, win by two, plain points; the final set
// as a super tie-break to 10, a set with no games; Tie-break only, one tie-break to 7 or 10;
// End set now. The match is written as
// TestKit.sets() gives it, "6-4 7-6(7-5) | 2-1 30-15"; each checked step is also undone and played
// again, compared with a full replay and checked against the set rules (TestKit.checkSteps()).

(:test)
function setSixGamesTest(logger as Logger) as Boolean {
    // 6/6: 6-4 and 7-5 win, 6-5 doesn't, 6-6 goes to a tie-break that wins the set 7-6 (best of 5
    // here, for room).
    var engine = new ScoringEngine(TestKit.format(3, 6, 6, true));
    TestKit.play(engine, "UTUTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "6-4 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTUTUTUT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "6-4 | 6-5 0-0"], ["U", "6-4 7-5 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTUTUTUT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [
        ["T", "6-4 7-5 | 5-6 0-0"], ["U", "6-4 7-5 | 6-6 tb 0-0"], ["T", "6-4 7-5 6-7(0-7) | 0-0 0-0"]
    ]);
    Test.assert(engine.getState().getSetsWon(TEAM_US) == 2 && !engine.getState().matchOver);
    return true;
}

(:test)
function setProSetTest(logger as Logger) as Boolean {
    // Pro set (9/8): 9-7 wins, 8-8 goes to a tie-break, and 9-8 only comes from it. One set, so the
    // set is the match.
    var engine = new ScoringEngine(TestKit.preset(PRESET_PRO_SET));
    TestKit.play(engine, "UTUTUTUTUTUTUT U uuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "9-7 | 0-0 0-0 over"]]);
    Test.assertEqual(engine.getState().getResult(), RESULT_WIN);
    engine.undo();
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "| 8-8 tb 0-0"], ["U", "9-8(7-0) | 0-0 0-0 over"]]);
    Test.assert(engine.getState().getGamesWon(TEAM_US) == 9 && engine.getState().getGamesWon(TEAM_THEM) == 8);
    return true;
}

(:test)
function setShortSetTest(logger as Logger) as Boolean {
    // Short sets (4/4): 4-3 isn't enough, 5-3 and 4-0 win, 4-4 goes to a tie-break.
    var engine = new ScoringEngine(TestKit.format(2, 4, 4, true));
    TestKit.play(engine, "UTUTUT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "| 4-3 0-0"], ["U", "5-3 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "5-3 | 4-4 tb 0-0"], ["T", "5-3 4-5(0-7) | 0-0 0-0"]]);
    TestKit.play(engine, "UUU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "5-3 4-5(0-7) 4-0 | 0-0 0-0 over"]]);
    return true;
}

(:test)
function setFast4Test(logger as Logger) as Boolean {
    // Fast4 (4/3): the tie-break comes at 3-3, before 4 games; 4-2 wins, 4-3 only comes from the
    // tie-break.
    var engine = new ScoringEngine(TestKit.format(2, 4, 3, true));
    TestKit.play(engine, "UTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "4-2 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "4-2 | 3-3 tb 0-0"], ["U", "4-2 4-3(7-0) | 0-0 0-0 over"]]);
    return true;
}

(:test)
function setNoTieBreakTest(logger as Logger) as Boolean {
    // No tie-break: won by two games, with no limit; 6-4 still wins.
    var engine = new ScoringEngine(TestKit.format(2, 6, 6, false));
    TestKit.play(engine, TestKit.repeat("UT", 6));
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "| 7-6 0-0"], ["T", "| 7-7 0-0"], ["U", "| 8-7 0-0"], ["U", "9-7 | 0-0 0-0"]]);
    TestKit.play(engine, TestKit.repeat("UT", 11) + "T");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["T", "9-7 11-13 | 0-0 0-0"]]);
    TestKit.play(engine, "UTUTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "9-7 11-13 6-4 | 0-0 0-0 over"]]);
    return true;
}

(:test)
function setTieBreakToSevenTest(logger as Logger) as Boolean {
    // Plain points to 7, win by two, and no deuce rule: not even Golden Point at 3-3 or 6-6.
    var config = TestKit.withMode(DEUCE_GOLDEN);
    var engine = new ScoringEngine(config);
    TestKit.play(engine, TestKit.repeat("UT", 6) + " uuuttt");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 6-6 tb 4-3"], ["t", "| 6-6 tb 4-4"]]);
    Test.assert(!engine.getState().isDecidingPoint() && engine.getState().getDeuceCount() == 0);
    TestKit.play(engine, "utu");
    // 7 points with a one-point lead don't win.
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [
        ["t", "| 6-6 tb 6-6"], ["u", "| 6-6 tb 7-6"], ["t", "| 6-6 tb 7-7"], ["u", "| 6-6 tb 8-7"], ["u", "7-6(9-7) | 0-0 0-0"]
    ]);
    TestKit.play(engine, TestKit.repeat("UT", 6) + " ttttt uuuuuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "7-6(9-7) 7-6(7-5) | 0-0 0-0 over"]]);
    return true;
}

(:test)
function setTieBreakToTenTest(logger as Logger) as Boolean {
    // Tie-breaks to 10: 7 points aren't enough, and the win is by two beyond 10.
    var config = new MatchConfig();
    config.tieBreakPoints = 10;
    var engine = new ScoringEngine(config);
    TestKit.play(engine, TestKit.repeat("UT", 6) + " uuuuuuuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 6-6 tb 9-0"], ["u", "7-6(10-0) | 0-0 0-0"]]);
    TestKit.play(engine, TestKit.repeat("UT", 6) + TestKit.repeat("ut", 9));
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [
        ["u", "7-6(10-0) | 6-6 tb 10-9"], ["t", "7-6(10-0) | 6-6 tb 10-10"], ["t", "7-6(10-0) | 6-6 tb 10-11"],
        ["t", "7-6(10-0) 6-7(10-12) | 0-0 0-0"]
    ]);
    return true;
}

(:test)
function setSuperTieBreakTest(logger as Logger) as Boolean {
    // The final set is one tie-break to 10, win by two, even when tie-breaks are to 7, with no deuce
    // rule. It counts as a set won, shown with its points, and as zero games.
    var config = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    config.deuceMode = DEUCE_GOLDEN;
    var engine = new ScoringEngine(config);
    TestKit.play(engine, "UTUTUTUTUU UTUTUTTTT");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "6-4 3-6 | 0-0 stb 1-0"]]);
    Test.assert(engine.getState().gameType == GAME_SUPER_TIE_BREAK && engine.getState().isTieBreak());
    TestKit.play(engine, "uuuuuu ttttttt");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["t", "6-4 3-6 | 0-0 stb 7-8"], ["u", "6-4 3-6 | 0-0 stb 8-8"],
        ["u", "6-4 3-6 | 0-0 stb 9-8"], ["u", "6-4 3-6 S10-8 | 0-0 0-0 over"]]);
    var state = engine.getState();
    Test.assert(state.getResult() == RESULT_WIN && state.getSetsWon(TEAM_US) == 2 && state.getSetsWon(TEAM_THEM) == 1);
    Test.assert(state.getGamesWon(TEAM_US) == 9 && state.getGamesWon(TEAM_THEM) == 10);
    Test.assertEqual(state.getScoreText(), "6-4 3-6 10-8");
    var last = state.setScores[2];
    Test.assert(last.superTieBreak && !last.endedEarly && last.winner == TEAM_US);
    Test.assert(last.games[TEAM_US] == 0 && last.games[TEAM_THEM] == 0 && last.getScore(TEAM_US) == 10 && last.getScore(TEAM_THEM) == 8);

    // Win by two beyond 10.
    engine.undo();
    TestKit.play(engine, "tu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["t", "6-4 3-6 | 0-0 stb 10-10"], ["t", "6-4 3-6 | 0-0 stb 10-11"],
        ["t", "6-4 3-6 S10-12 | 0-0 0-0 over"]]);
    Test.assertEqual(engine.getState().getResult(), RESULT_LOSS);

    // Decided in two sets: no super tie-break.
    engine = new ScoringEngine(config);
    TestKit.play(engine, "UTUTUTUTUU UTUTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "6-4 6-4 | 0-0 0-0 over"]]);
    return true;
}

(:test)
function setTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only: the match is one tie-break to 7 or 10, win by two, plain points
    // and no deuce rule (Golden point here), from the first point. Won, it is a set won with zero games,
    // shown with its points: 7-5, 1 set to 0, 0 games each.
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    config.deuceMode = DEUCE_GOLDEN;
    var engine = new ScoringEngine(config);
    var state = engine.getState();
    Test.assert(state.gameType == GAME_SUPER_TIE_BREAK && state.isTieBreak() && state.setScores.size() == 0);
    TestKit.play(engine, "uuuttt");
    state = engine.getState();
    Test.assert(TestKit.game(state).equals("0-0 3-3") && !state.isDecidingPoint() && state.getDeuceCount() == 0);
    TestKit.play(engine, "uutt");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 0-0 stb 6-5"], ["t", "| 0-0 stb 6-6"], ["u", "| 0-0 stb 7-6"],
        ["u", "S8-6 | 0-0 0-0 over"]]);
    Test.assertEqual(engine.getState().getScoreText(), "8-6");
    engine = new ScoringEngine(config);
    TestKit.play(engine, "uuuuuttttt");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 0-0 stb 6-5"], ["u", "S7-5 | 0-0 0-0 over"]]);
    state = engine.getState();
    Test.assert(state.getScoreText().equals("7-5") && state.getResult() == RESULT_WIN && state.getWinner() == TEAM_US);
    Test.assert(state.getSetsWon(TEAM_US) == 1 && state.getSetsWon(TEAM_THEM) == 0
        && state.getGamesWon(TEAM_US) == 0 && state.getGamesWon(TEAM_THEM) == 0);
    var set = state.setScores[0];
    Test.assert(set.superTieBreak && !set.endedEarly && set.winner == TEAM_US && set.games[TEAM_US] == 0
        && set.games[TEAM_THEM] == 0 && set.getScore(TEAM_US) == 7 && set.getScore(TEAM_THEM) == 5);
    // Lost 6-8 after the match point undone, and 7-0 wins.
    engine.undo();
    TestKit.play(engine, "ttt");
    TestKit.check(engine, TestKit.VIEW_SETS, "S6-8 | 0-0 0-0 over", "lost");
    Test.assert(engine.getState().getResult() == RESULT_LOSS && engine.getState().getScoreText().equals("6-8"));
    engine = new ScoringEngine(config);
    TestKit.play(engine, "uuuuuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "S7-0 | 0-0 0-0 over"]]);

    // To 10: 7 points aren't enough, and the win is by two beyond 10.
    config = TestKit.preset(PRESET_TIE_BREAK_10);
    engine = new ScoringEngine(config);
    TestKit.play(engine, "uuuuuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 0-0 stb 7-0"], ["u", "| 0-0 stb 8-0"], ["u", "| 0-0 stb 9-0"],
        ["u", "S10-0 | 0-0 0-0 over"]]);
    engine = new ScoringEngine(config);
    TestKit.play(engine, TestKit.repeat("ut", 9));
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "| 0-0 stb 10-9"], ["t", "| 0-0 stb 10-10"], ["t", "| 0-0 stb 10-11"],
        ["t", "S10-12 | 0-0 0-0 over"]]);
    state = engine.getState();
    Test.assert(state.getScoreText().equals("10-12") && state.getResult() == RESULT_LOSS && state.getSetsWon(TEAM_THEM) == 1
        && state.getGamesWon(TEAM_US) + state.getGamesWon(TEAM_THEM) == 0);
    return true;
}

(:test)
function setEndSetNowTieBreakOnlyTest(logger as Logger) as Boolean {
    // End set now in Tie-break only: the team leading in points gets the set, so the match;
    // level, the player names the team. Its points stay as the set's score.
    var engine = new ScoringEngine(TestKit.preset(PRESET_TIE_BREAK_7));
    TestKit.play(engine, "uuuttt");
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.play(engine, "u");
    Test.assert(engine.getState().getSetLeader() == TEAM_US);
    TestKit.checkRefusedType(engine, EVENT_END_SET, TEAM_US);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "S4-3EU | 0-0 0-0 over");
    var state = engine.getState();
    Test.assert(state.getResult() == RESULT_WIN && state.getScoreText().equals("4-3") && state.getSetsWon(TEAM_US) == 1
        && state.getGamesWon(TEAM_US) == 0);
    engine.undo();
    TestKit.play(engine, "t");
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_THEM, "S4-4ET | 0-0 0-0 over");
    Test.assertEqual(engine.getState().getResult(), RESULT_LOSS);
    return true;
}

(:test)
function setAfterTieBreakTest(logger as Logger) as Boolean {
    // The set after a tie-break starts at 0-0 with a regular game, under the deuce mode chosen last,
    // even when it was chosen during the tie-break.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, TestKit.repeat("UT", 6) + " uuu");
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN, "| 6-6 tb 3-0");
    Test.assertEqual(engine.getState().gameDeuceMode, DEUCE_STAR);
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["U", "7-6(7-0) | 0-0 0-0"]]);
    var state = engine.getState();
    Test.assert(state.gameType == GAME_REGULAR && !state.isTieBreak() && state.gameDeuceMode == DEUCE_GOLDEN);
    TestKit.play(engine, "ututu");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["t", "7-6(7-0) | 0-0 40-40"]]);
    Test.assert(engine.getState().isDecidingPoint());
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["t", "7-6(7-0) | 0-1 0-0"]]);
    return true;
}

(:test)
function setEndSetNowLeaderTest(logger as Logger) as Boolean {
    // End set now gives the set to the team ahead in games and drops the game in progress, whose
    // points stay in the match's points. The event names a team only when games are level.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UUTU ut");
    Test.assert(engine.getState().getSetLeader() == TEAM_US);
    TestKit.checkRefusedType(engine, EVENT_END_SET, TEAM_US);
    TestKit.checkRefusedType(engine, EVENT_END_SET, TEAM_THEM);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "3-1EU | 0-0 0-0");
    Test.assert(engine.getState().pointsWon[TEAM_US] == 13 && engine.getState().pointsWon[TEAM_THEM] == 5);
    // Them ahead.
    TestKit.play(engine, "TTU tt");
    Test.assert(engine.getState().getSetLeader() == TEAM_THEM);
    TestKit.checkRefusedType(engine, EVENT_END_SET, TEAM_THEM);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "3-1EU 1-2ET | 0-0 0-0");
    return true;
}

(:test)
function setEndSetNowLevelTest(logger as Logger) as Boolean {
    // Games level: the player names the team (Us / Them), and the set can't end without one. Points in
    // the game in progress don't count; in a tie-break games are level, and it's dropped like any game.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_US, "0-0EU | 0-0 0-0");
    TestKit.play(engine, "UTUTUT uuut");
    Test.assert(engine.getState().getSetLeader() == null);
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_THEM, "0-0EU 3-3ET | 0-0 0-0");
    TestKit.play(engine, TestKit.repeat("UT", 6) + " uut");
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_US, "0-0EU 3-3ET 6-6EU | 0-0 0-0 over");
    Test.assert(engine.getState().setScores[2].tieBreakPoints == null);
    Test.assertEqual(engine.getState().getScoreText(), "0-0 3-3 6-6");
    return true;
}

(:test)
function setEndSetNowSuperTieBreakTest(logger as Logger) as Boolean {
    // The super tie-break has no games: its points say who is ahead, and they stay as the set's score.
    // Ending it ends the match.
    var engine = new ScoringEngine(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB));
    TestKit.play(engine, "UTUTUTUTUU UTUTUTTTT");
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.play(engine, "uuuuuttt");
    Test.assert(engine.getState().getSetLeader() == TEAM_US);
    TestKit.checkRefusedType(engine, EVENT_END_SET, TEAM_US);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "6-4 3-6 S5-3EU | 0-0 0-0 over");
    var state = engine.getState();
    Test.assert(state.getResult() == RESULT_WIN && state.getScoreText().equals("6-4 3-6 5-3"));
    Test.assert(state.getGamesWon(TEAM_US) == 9 && state.getGamesWon(TEAM_THEM) == 10);
    engine.undo();
    TestKit.play(engine, "tt");
    TestKit.checkRefusedType(engine, EVENT_END_SET, null);
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_THEM, "6-4 3-6 S5-5ET | 0-0 0-0 over");
    Test.assertEqual(engine.getState().getResult(), RESULT_LOSS);
    return true;
}

(:test)
function setScoreCopyAndEqualsTest(logger as Logger) as Boolean {
    // Every field counts, and the copy has its own arrays. A super tie-break shows its points.
    var score = new SetScore([6, 6], [7, 5], false, TEAM_US, false);
    Test.assert(score.getScore(TEAM_US) == 6 && score.copy().equals(score) && !score.equals(null) && !score.equals("6-6"));
    for (var i = 0; i < 8; i++) {
        var copy = score.copy();
        var points = copy.tieBreakPoints as Array<Number>;
        if (i < 2) { copy.games[i] += 1; }
        else if (i < 4) { points[i - 2] += 1; }
        else if (i == 4) { copy.tieBreakPoints = null; }
        else if (i == 5) { copy.superTieBreak = true; }
        else if (i == 6) { copy.winner = TEAM_THEM; }
        else { copy.endedEarly = true; }
        Test.assertMessage(!copy.equals(score) && !score.equals(copy), "field " + i);
    }
    Test.assertEqual(score.toString(), new SetScore([6, 6], [7, 5], false, TEAM_US, false).toString());
    var superSet = new SetScore([0, 0], [10, 8], true, TEAM_US, false);
    Test.assert(superSet.getScore(TEAM_US) == 10 && superSet.getScore(TEAM_THEM) == 8);
    return true;
}

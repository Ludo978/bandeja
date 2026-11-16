import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Edit score: EDIT_SCORE sets the finished sets, the current set's games
// and the game's points, as one event whose stored form spans several pairs of the log. It's taken
// only when the format allows the score (TestKit.possibleEdit(), worked out apart from the engine,
// must agree), never when it would end the match or change nothing. Games and sets follow it; the
// points and the other stats count what was played on the watch; the serve stays as it was; it adds
// no lap; undo and resume give back exactly what a full replay gives. Edits are written as
// TestKit.edit() reads them: "6-4 | 2-1 2-1" is 6-4, then 2-1 and 30-15 (point counts). The random
// matches (RandomMatchTest) play edits with every other event too.

(:test)
function editScoreStoredFormTest(logger as Logger) as Boolean {
    // The stored form: the code, 7 + 100 x (finished sets + 1), and the time, then
    // a pair per finished set, (games us x 100 + them) x 10 + flags (1 them, 2 given by End set now,
    // 4 super tie-break) and the tie-break's points (-1 for none), then the current set's games and
    // points. Matches stored by this version must keep loading: never change these numbers.
    var t = TestKit.T0;
    var texts = ["6-4 6-7(5-7) 3-2EU | 1-0 4-3", "S10-8 S5-3EU S4-4ET | 0-0 0-0", "| 0-0 0-0", "| 6-6 12-11",
        "99-97 7-6(99-97) | 99-99 99-98"];
    var stored = [[407, t, 6040, -1, 6071, 507, 3022, -1, 100, 403], [407, t, 4, 1008, 6, 503, 7, 404, 0, 0],
        [107, t, 0, 0], [107, t, 606, 1211], [307, t, 99970, -1, 7060, 9997, 9999, 9998]];
    for (var i = 0; i < texts.size(); i++) {
        var event = MatchEvent.editScore(t, TestKit.edit(texts[i] as String));
        var log = [] as Array<Application.Storage.ValueType>;
        event.addTo(log);
        Test.assertEqualMessage(log.toString(), stored[i].toString(), texts[i] as String);
        Test.assertMessage(event.isValid() && event.getSize() == log.size() && event.getCode() == stored[i][0]
            && event.equals(MatchEvent.fromLog(stored[i], 0)), texts[i] as String);
        // Inside a log, between two points.
        var longer = [0, t - 30] as Array<Application.Storage.ValueType>;
        longer.addAll(log);
        longer.add(1);
        longer.add(t + 30);
        Test.assertMessage(event.equals(MatchEvent.fromLog(longer, 2)), texts[i] + " in a log");
        Test.assert(MatchEvent.sizeAt(longer, 2) == log.size() && MatchEvent.sizeAt(longer, 0) == 2);
        Test.assertMessage(MatchEvent.fromLog(longer, 2 + log.size()) != null, texts[i] + ": the next event");
    }
    // Not all of it there, a value that isn't a Number or out of the stored form's range.
    var malformed = [
        [7, t, 0, 0], [107, t, 0], [107, t], [207, t, 0, 0], [207, t, 6040, -1, 0],
        [107, t, 0, 10000], [107, t, 10000, 0], [107, t, -1, 0], [107, t, 0, -1], [207, t, 6048, -1, 0, 0],
        [207, t, 6049, -1, 0, 0], [207, t, 6040, -2, 0, 0], [207, t, 6040, 10000, 0, 0], [207, t, 100000, -1, 0, 0],
        [207, t, -10, -1, 0, 0], [107, t, 0.0, 0], [107, t, 0, null], [107, null, 0, 0], [107, t, "0", 0],
        [107, t, 0l, 0], [107, -1, 0, 0], [207, t, 6040, 5.0, 0, 0], [-93, t, 0, 0]
    ] as Array<Array<Object?> >;
    for (var i = 0; i < malformed.size(); i++) {
        Test.assertMessage(MatchEvent.fromLog(malformed[i], 0) == null, "accepted " + malformed[i]);
    }
    // equals() compares the score too.
    var event = TestKit.editEvent(new ScoringEngine(new MatchConfig()), "6-4 | 1-0 4-3");
    var others = ["6-4 | 1-0 4-2", "6-4 | 0-1 4-3", "4-6 | 1-0 4-3", "6-4EU | 1-0 4-3", "| 1-0 4-3", "6-4 6-4 | 1-0 4-3"];
    for (var i = 0; i < others.size(); i++) {
        Test.assertMessage(!event.equals(MatchEvent.editScore(event.time, TestKit.edit(others[i] as String))), others[i] as String);
    }
    Test.assert(event.equals(MatchEvent.editScore(event.time, TestKit.edit("6-4 | 1-0 4-3"))));
    Test.assert(!event.equals(MatchEvent.editScore(event.time + 1, TestKit.edit("6-4 | 1-0 4-3"))));
    Test.assert(!event.equals(new MatchEvent(EVENT_EDIT_SCORE, event.time, null)) && !event.equals(new MatchEvent(EVENT_POINT_US, event.time, null)));
    return true;
}

(:test)
function editScoreSetDefinitionsTest(logger as Logger) as Boolean {
    // Every set definition: the finished sets the format allows, won by games, in the
    // tie-break or given by End set now, and the set in progress, with its tie-break at T-T; refused
    // when a set isn't won as the rules say, the set in progress is already won or past its tie-break,
    // or the score would end the match. Then the match plays on from the edit by the usual rules.
    var definitions = [new MatchConfig(), TestKit.format(2, 9, 8, true), TestKit.format(2, 4, 4, true),
        TestKit.format(2, 4, 3, true), TestKit.format(2, 6, 6, false)];
    var cases = [
        // 6/6, tie-break to 7.
        [["6-4 | 2-1 2-1", "6-4 | 2-1 30-15"], ["7-5 4-6 | 0-0 0-0", "7-5 4-6 | 0-0 0-0"],
            ["7-6(7-5) | 6-5 3-0", "7-6(7-5) | 6-5 40-0"], ["6-7(10-12) | 0-0 0-0", "6-7(10-12) | 0-0 0-0"],
            ["7-6(13-10) | 0-0 0-0", null], ["7-6(7-6) | 0-0 0-0", null], ["7-6(5-7) | 0-0 0-0", null],
            ["7-6 | 0-0 0-0", null], ["8-6 | 0-0 0-0", null], ["6-5 | 0-0 0-0", null], ["6-6U | 0-0 0-0", null],
            ["7-5(7-3) | 0-0 0-0", null], ["| 6-6 3-2", "| 6-6 tb 3-2"], ["| 6-5 0-0", "| 6-5 0-0"],
            ["| 7-5 0-0", null], ["| 7-6 0-0", null], ["| 6-6 7-5", null], ["| 6-6 9-9", "| 6-6 tb 9-9"],
            ["6-4 6-4 | 0-0 0-0", null], ["6-4 4-6 6-3 | 0-0 0-0", null], ["3-2EU | 0-0 0-0", "3-2EU | 0-0 0-0"],
            ["2-3EU | 0-0 0-0", null], ["3-3ET | 1-0 0-0", "3-3ET | 1-0 0-0"], ["6-6EU | 0-0 0-0", "6-6EU | 0-0 0-0"],
            ["6-6(3-2)EU | 0-0 0-0", null], ["7-5EU | 0-0 0-0", null]],
        // 9/8.
        [["9-7 | 8-7 2-0", "9-7 | 8-7 30-0"], ["9-8(7-4) | 8-8 4-4", "9-8(7-4) | 8-8 tb 4-4"], ["9-6 | 0-0 0-0", "9-6 | 0-0 0-0"],
            ["10-8 | 0-0 0-0", null], ["9-8 | 0-0 0-0", null], ["| 9-7 0-0", null], ["| 9-8 0-0", null],
            ["| 8-8 0-0", "| 8-8 tb 0-0"]],
        // 4/4.
        [["4-2 | 0-0 0-0", "4-2 | 0-0 0-0"], ["5-3 | 0-0 0-0", "5-3 | 0-0 0-0"], ["5-4(7-2) | 4-4 6-6", "5-4(7-2) | 4-4 tb 6-6"],
            ["6-4 | 0-0 0-0", null], ["4-3 | 0-0 0-0", null], ["| 4-3 0-0", "| 4-3 0-0"], ["| 5-3 0-0", null], ["| 5-4 0-0", null]],
        // 4/3.
        [["4-2 | 0-0 0-0", "4-2 | 0-0 0-0"], ["4-3(7-5) | 0-0 0-0", "4-3(7-5) | 0-0 0-0"], ["5-3 | 0-0 0-0", null],
            ["4-3 | 0-0 0-0", null], ["| 3-3 2-2", "| 3-3 tb 2-2"], ["| 4-3 0-0", null], ["| 3-2 0-0", "| 3-2 0-0"],
            ["| 4-2 0-0", null]],
        // No tie-break.
        [["8-6 | 0-0 0-0", "8-6 | 0-0 0-0"], ["12-10 | 0-0 0-0", "12-10 | 0-0 0-0"], ["7-6 | 0-0 0-0", null],
            ["12-9 | 0-0 0-0", null], ["7-6(7-5) | 0-0 0-0", null], ["| 6-6 3-0", "| 6-6 40-0"], ["| 15-14 0-0", "| 15-14 0-0"],
            ["| 8-6 0-0", null], ["6-6EU | 0-0 0-0", "6-6EU | 0-0 0-0"]]
    ];
    // From an edit one point from the set, the next point wins it by the usual rules.
    var playOn = [["| 6-5 3-0", "| 6-5 40-0", "7-5 | 0-0 0-0"], ["| 8-8 6-5", "| 8-8 tb 6-5", "9-8(7-5) | 0-0 0-0"],
        ["| 4-3 3-0", "| 4-3 40-0", "5-3 | 0-0 0-0"], ["| 3-3 6-5", "| 3-3 tb 6-5", "4-3(7-5) | 0-0 0-0"],
        ["| 7-6 3-0", "| 7-6 40-0", "8-6 | 0-0 0-0"]];
    for (var d = 0; d < definitions.size(); d++) {
        var config = definitions[d];
        var list = cases[d] as Array<Array<String?> >;
        for (var i = 0; i < list.size(); i++) {
            EditTests.check(TestKit.newMatch(config, "Me"), list[i][0] as String, list[i][1]);
        }
        var engine = TestKit.newMatch(config, "Me");
        EditTests.add(engine, playOn[d][0] as String, TestKit.VIEW_SETS, playOn[d][1] as String);
        TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", playOn[d][2] as String]]);
    }
    // A one-set match: an edit can't win its set, and the point after one can.
    var proSet = TestKit.preset(PRESET_PRO_SET);
    EditTests.check(TestKit.newMatch(proSet, "Me"), "9-7 | 0-0 0-0", null);
    var engine = TestKit.newMatch(proSet, "Me");
    EditTests.check(engine, "| 8-7 3-0", "| 8-7 40-0");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "9-7 | 0-0 0-0 over"]]);
    return true;
}

(:test)
function editScoreTieBreakTest(logger as Logger) as Boolean {
    // An edit into a tie-break: the serving team stays as it was, the team of the
    // tie-break's first point, so who serves now follows from the edited points (5 played: their turn,
    // from the left); the players don't change ends at the edit, then do at the 6th point played. The
    // tie-break won on the watch passes the serve as usual, and counts as a tie-break played. Me serve
    // first, 1-1 in games: we serve the third game, Partner.
    var config = new MatchConfig();
    var engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UT");
    Test.assertEqual(TestKit.serveFlags(engine.getState()), "PARTNER R new");
    EditTests.add(engine, "| 6-6 3-2", TestKit.VIEW_SERVE, "THEM L new");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break", "tie-break");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM R ends"], ["u", "PARTNER L new"], ["u", "PARTNER R"],
        ["u", "THEM R new ends"]]);
    TestKit.check(engine, TestKit.VIEW_SETS, "7-6(7-2) | 0-0 0-0", "tie-break won");
    // Points, durations and serve stats for what the watch played: two games and four tie-break points
    // (two served by them, from the 6th point), the edited points not. Games and sets from the score.
    Test.assertEqual(TestKit.stats(TestKit.computeStats(engine, TestKit.START)),
        "points 8-4 67%, games 7-6, sets 1-0, deciding 0/0, tie-breaks 1/1, durations 135 120 150, longest 2, per point 34 s, streak 4"
        + " | serve 6/6 100%, return 2/6 33%, held 1/1, conceded 0, broke 0/1, break points 0/0, saved 0/0");

    // A set the edit says was won in a tie-break moves no serve: Partner still serves the next game.
    engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UT");
    EditTests.add(engine, "7-6(7-4) | 0-0 0-0", TestKit.VIEW_SERVE, "PARTNER R");
    // Out of a tie-break: its first point's team serves the game, Partner for us.
    engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UT");
    EditTests.add(engine, "| 6-6 3-2", TestKit.VIEW_SERVE, "THEM L new");
    EditTests.add(engine, "| 5-5 1-0", TestKit.VIEW_SERVE, "PARTNER L new");
    // In a tie-break to 10, at 9 points played: the 12th brings the change of ends.
    config.tieBreakPoints = 10;
    engine = TestKit.newMatch(config, "Opponents Me");
    EditTests.add(engine, "| 6-6 5-4", TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "ME R"], ["t", "THEM L new"], ["t", "THEM R ends"]]);
    return true;
}

(:test)
function editScoreSuperTieBreakTest(logger as Logger) as Boolean {
    // The super tie-break: an edit puts it after one set each, with points and no games; its
    // points can't be won by the edit, nor can the two sets that end the match. Played on from 7-5 to
    // 10-5, it ends the match as a set (10-5 in the score text) and a tie-break played, and its lap is
    // the save's, "3 10-5 4". They serve first.
    var config = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    var refused = ["6-4 3-6 | 1-0 7-5", "6-4 3-6 | 0-0 10-8", "6-4 6-3 | 0-0 0-0", "6-4 3-6 S10-8 | 0-0 0-0",
        "6-4 S3-6 | 0-0 0-0", "S6-4 | 0-0 0-0", "6-4 3-6 S5-3EU | 0-0 0-0"];
    for (var i = 0; i < refused.size(); i++) {
        EditTests.check(TestKit.newMatch(config, "Opponents Me"), refused[i] as String, null);
    }
    var rig = new TestKit.Rig(config, "Opponents Me", false);
    rig.play("TU");
    Test.assert(rig.match.add(TestKit.editEvent(rig.engine, "6-4 3-6 | 0-0 7-5")) && !rig.match.lapWritten);
    var engine = rig.engine;
    TestKit.check(engine, TestKit.VIEW_SETS, "6-4 3-6 | 0-0 stb 7-5", "super tie-break");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 18 | tie-break", "super tie-break");
    // 12 points played: the team of its first point serves, them.
    Test.assertEqual(TestKit.serve(engine.getState()), "THEM R");
    rig.play("u");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 18 | tie-break", "8-5");
    rig.play("u");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break", "9-5");
    rig.play("u");
    var state = engine.getState();
    TestKit.check(engine, TestKit.VIEW_SETS, "6-4 3-6 S10-5 | 0-0 0-0 over", "won");
    Test.assert(state.getScoreText().equals("6-4 3-6 10-5") && state.getResult() == RESULT_WIN);
    var stats = TestKit.computeStats(engine, rig.match.start);
    Test.assert(stats.tieBreaksPlayed == 1 && stats.tieBreaksWon == 1 && stats.gamesWon == 9 && stats.gamesLost == 10
        && stats.setsWon == 2 && stats.setsLost == 1);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["1 0-1 2", "1 1-1 0", "3 10-5 4"], "laps");
    return true;
}

(:test)
function editScoreTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only: an edit can only set the tie-break's points, short of its
    // length to 7 or 10 (past it, level or one ahead); no finished set (one wins the match), no games.
    // Who serves follows from the edited points, as in any tie-break, and the caption with them. Played
    // on, it ends the match as a set with no games and a tie-break played on the watch, its lap the
    // save's, "1 8-6 4".
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    var refused = ["| 0-0 7-5", "| 0-0 8-6", "| 0-0 0-7", "| 1-0 0-0", "| 0-1 3-2", "S7-5 | 0-0 0-0", "S3-2EU | 0-0 0-0",
        "7-5 | 0-0 0-0", "| 0-0 0-0"];
    for (var i = 0; i < refused.size(); i++) {
        EditTests.check(TestKit.newMatch(config, "Me"), refused[i] as String, null);
    }
    var rig = new TestKit.Rig(config, "Me", false);
    rig.play("ut");
    var engine = rig.engine;
    // 9 points played: their turn, from the left (they served the second and third, so no new server).
    EditTests.add(engine, "| 0-0 5-4", TestKit.VIEW_SERVE, "THEM L");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break", "5-4");
    EditTests.add(engine, "| 0-0 6-6", TestKit.VIEW_SERVE, "PARTNER R new");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 18 | tie-break", "6-6");
    rig.play("u");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break", "7-6");
    rig.play("u");
    var state = engine.getState();
    TestKit.check(engine, TestKit.VIEW_SETS, "S8-6 | 0-0 0-0 over", "won");
    Test.assert(state.getScoreText().equals("8-6") && state.getResult() == RESULT_WIN);
    var stats = TestKit.computeStats(engine, rig.match.start);
    Test.assert(stats.tieBreaksPlayed == 1 && stats.tieBreaksWon == 1 && stats.pointsWon == 3 && stats.pointsLost == 1
        && stats.gamesWon == 0 && stats.gamesLost == 0 && stats.setsWon == 1);
    Test.assert(rig.session.save());
    LapTests.check(rig, ["1 8-6 4"], "laps");
    // To 10: 9-8 and 12-11 are in progress, 10-8 and 12-10 won.
    config = TestKit.preset(PRESET_TIE_BREAK_10);
    EditTests.check(TestKit.newMatch(config, "Me"), "| 0-0 9-8", "| 0-0 stb 9-8");
    EditTests.check(TestKit.newMatch(config, "Me"), "| 0-0 12-11", "| 0-0 stb 12-11");
    EditTests.check(TestKit.newMatch(config, "Me"), "| 0-0 10-8", null);
    EditTests.check(TestKit.newMatch(config, "Me"), "| 0-0 12-10", null);
    return true;
}

(:test)
function editScorePointsTest(logger as Logger) as Boolean {
    // The game's points as counts: 3-3 is 40-40 at deuce 1, 4-3 AD-40 after it, n + 2 each
    // deuce n, so an edit can put the game at any deuce its deuce mode reaches, a deciding point
    // included, never past it; a won game is refused in every mode. We serve.
    var cases = [
        [DEUCE_GOLDEN, "| 0-0 3-2", "0-0 40-30"], [DEUCE_GOLDEN, "| 0-0 3-3", "0-0 40-40 deuce 1 deciding"],
        [DEUCE_GOLDEN, "| 0-0 4-3", null], [DEUCE_SILVER, "| 0-0 4-3", "0-0 AD-40 deuce 1"],
        [DEUCE_SILVER, "| 0-0 4-4", "0-0 40-40 deuce 2 deciding"], [DEUCE_SILVER, "| 0-0 5-4", null],
        [DEUCE_STAR, "| 0-0 3-3", "0-0 40-40 deuce 1"], [DEUCE_STAR, "| 0-0 5-4", "0-0 AD-40 deuce 2"],
        [DEUCE_STAR, "| 0-0 5-5", "0-0 40-40 deuce 3 deciding"], [DEUCE_STAR, "| 0-0 6-5", null],
        [DEUCE_ADVANTAGE, "| 0-0 20-19", "0-0 AD-40 deuce 17"], [DEUCE_ADVANTAGE, "| 0-0 21-19", null],
        [DEUCE_ADVANTAGE, "| 0-0 4-2", null], [DEUCE_STAR, "| 0-0 0-4", null], [DEUCE_SILVER, "| 0-0 5-3", null]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var engine = TestKit.newMatch(TestKit.withMode(cases[i][0] as DeuceMode), "Me");
        var expected = cases[i][2] as String?;
        if (expected != null) {
            EditTests.add(engine, cases[i][1] as String, TestKit.VIEW_GAME, expected);
        } else {
            EditTests.check(engine, cases[i][1] as String, null);
        }
    }
    // The banners follow: the deuce counter, then the deciding point (their break point too).
    var engine = TestKit.newMatch(TestKit.withMode(DEUCE_STAR), "Me");
    EditTests.add(engine, "| 0-0 5-4", TestKit.VIEW_SITUATION, "DEUCE 2 info | SET 1 | -");
    EditTests.add(engine, "| 0-0 5-5", TestKit.VIEW_SITUATION, "STAR POINT deciding | RECEIVERS CHOOSE | break T, deciding");
    TestKit.checkSteps(engine, TestKit.VIEW_GAME, [["t", "0-1 0-0"]]);

    // The game in progress keeps its rule: a deuce mode changed during it waits for the next game, also
    // through an edit; an edit to 0-0 takes the mode chosen last, as any game before its first point.
    engine = TestKit.newMatch(TestKit.withMode(DEUCE_STAR), "Me");
    TestKit.play(engine, "uu");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    EditTests.add(engine, "| 0-0 3-3", TestKit.VIEW_GAME, "0-0 40-40 deuce 1");
    Test.assert(engine.getState().gameDeuceMode == DEUCE_STAR && !engine.canAdd(TestKit.editEvent(engine, "| 0-0 6-5")));
    EditTests.add(engine, "| 0-0 0-0", TestKit.VIEW_GAME, "0-0 0-0");
    Test.assert(engine.getState().gameDeuceMode == DEUCE_GOLDEN);
    EditTests.add(engine, "| 0-0 3-3", TestKit.VIEW_GAME, "0-0 40-40 deuce 1 deciding");
    Test.assert(!engine.canAdd(TestKit.editEvent(engine, "| 0-0 4-3")));
    return true;
}

(:test)
function editScoreRefusedTest(logger as Logger) as Boolean {
    // Refused, changing nothing: an edit to the score as it stands (an undo would change nothing), any
    // edit once the match is over, and the invalid events of TestKit (counts the stored form can't hold).
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UT u");
    EditTests.check(engine, "| 1-1 1-0", null);
    EditTests.check(engine, "| 1-1 2-0", "| 1-1 30-0");
    EditTests.check(engine, "| 1-1 2-0", null);
    TestKit.add(engine, EVENT_END_MATCH, null);
    EditTests.check(engine, "| 1-1 3-0", null);
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UUUUUU UUUUUU");
    Test.assert(engine.getState().matchOver);
    EditTests.check(engine, "6-0 | 0-0 0-0", null);
    return true;
}

(:test)
function editScoreRestTest(logger as Logger) as Boolean {
    // What an edit leaves as it was: the points won and the point differential,
    // the serve, the game in progress (its points so far, its start), and the laps: none for the games
    // it adds, while the next game's lap has the edited set and score. Played through the app's match
    // holder after a warm-up. 1-1 and 30-0, Partner serving, then the edit to 6-4 2-1 30-15.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", true);
    rig.play("UT uu");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2"], "before");
    rig.recorder.clear();
    Test.assert(rig.match.add(TestKit.editEvent(rig.engine, "6-4 | 2-1 2-1")) && !rig.match.lapWritten);
    var state = rig.getState();
    TestKit.check(rig.engine, TestKit.VIEW_SERVE, "PARTNER L", "the serve");
    TestKit.check(rig.engine, TestKit.VIEW_SETS, "6-4 | 2-1 30-15", "the score");
    rig.assertPoints(6, 4, "edited");
    Test.assert(rig.recorder.pointDifferential == 2 && state.finishedGames.size() == 2 && state.gameStartTime == TestKit.T0 + 240);
    TestKit.assertCalls(rig.recorder, [], "no lap");
    Test.assertEqual(state.getScoreText(), "6-4 2-1*");
    // The lap in progress, which a pause or the save writes, holds the edited set.
    Test.assert(rig.session.pause() && rig.session.resume());
    TestKit.assertCalls(rig.recorder, ["values 2 2-1 -", "session", "stop", "start"], "the lap in progress");
    rig.play("uu");
    LapTests.check(rig, ["none", "1 1-0 0", "1 1-1 2", "2 3-1 0"], "the next game's lap");
    // The games and sets as edited, the rest as played: 3 games, all of their points.
    Test.assertEqual(TestKit.stats(TestKit.computeStats(rig.engine, rig.match.start)),
        "points 8-4 67%, games 9-5, sets 1-0, deciding 0/0, tie-breaks 0/0, durations 120 120 150, longest 2, per point 33 s, streak 4"
        + " | serve 8/8 100%, return 0/4 0%, held 2/2, conceded 0, broke 0/1, break points 0/0, saved 0/0");
    // Resumed, the games so far count as written: the new session's first lap is the next game, broken.
    var resumed = new TestKit.Resumed(TestKit.storedOf(rig.match));
    TestKit.assertSameState(resumed.match.getState(), rig.getState(), "resumed");
    Test.assert(resumed.laps.getCommitted() == 3 && resumed.recorder.pointDifferential == 4);
    resumed.play("U");
    Test.assertEqual(resumed.recorder.laps.toString(), ["2 4-1 1"].toString());

    // The first event, before the serve is known: Fix serving team starts the rotation after it.
    var engine = new ScoringEngine(new MatchConfig());
    EditTests.add(engine, "6-3 | 1-1 0-0", TestKit.VIEW_SERVE, "?");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_US, "ME R new");
    TestKit.play(engine, "U");
    TestKit.check(engine, TestKit.VIEW_SETS, "6-3 | 2-1 0-0", "after the fix");
    StatsTests.checkServe(engine, "serve 4/4 100%, return 0/0 -, held 1/1, conceded 0, broke 0/0, break points 0/0, saved 0/0");

    // After End set now: the set it gave stays as it is, or the edit replaces it; it can't go to the
    // team behind. The dropped game's points still count.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UUU uu");
    TestKit.add(engine, EVENT_END_SET, null);
    TestKit.check(engine, TestKit.VIEW_SETS, "3-0EU | 0-0 0-0", "end set");
    EditTests.check(engine, "3-0ET | 2-1 0-0", null);
    EditTests.add(engine, "3-0EU | 2-1 0-0", TestKit.VIEW_SETS, "3-0EU | 2-1 0-0");
    EditTests.add(engine, "6-4 | 2-1 0-0", TestKit.VIEW_SETS, "6-4 | 2-1 0-0");
    Test.assert(TestKit.computeStats(engine, TestKit.START).pointsWon == 14);
    return true;
}

(:test)
function editScoreUndoTest(logger as Logger) as Boolean {
    // Undo across edits: 90 events with edits at 31 (the snapshot after 32 events
    // holds it), 39 (it replaces the sets that snapshot has), 63 and 64 (two in a row, the second
    // shrinking the sets), games won between them. getEvent() finds each event; undone one by one back
    // to the start, each undo gives back its event, the log as it was and the exact state before it,
    // its stats and serve included, equal to a full replay. Advantage: the points between the bursts
    // keep the score level, so they end no game.
    var config = TestKit.withMode(DEUCE_ADVANTAGE);
    var edits = {31 => "6-4 | 2-1 2-1", 39 => "4-6 | 3-3 0-0", 63 => "6-4 4-6 | 5-5 1-1", 64 => "6-4 | 1-1 2-2"};
    var bursts = [1, 41, 66];
    var engine = new ScoringEngine(config);
    var events = [] as Array<MatchEvent>;
    var states = [engine.getState().copy()];
    var sizes = [0];
    for (var i = 0; i < 90; i++) {
        var time = TestKit.T0 + 30 * i;
        var state = engine.getState();
        var event = new MatchEvent(EVENT_FIX_SERVING_TEAM, time, TEAM_US);
        var text = edits.get(i) as String?;
        if (text != null) {
            event = MatchEvent.editScore(time, TestKit.edit(text));
        } else if (i > 0) {
            var us = state.gamePoints[TEAM_US] <= state.gamePoints[TEAM_THEM];
            for (var b = 0; b < bursts.size(); b++) {
                if (i >= bursts[b] && i < bursts[b] + 24) {
                    us = (i - bursts[b]) % 8 < 4;
                }
            }
            event = new MatchEvent(us ? EVENT_POINT_US : EVENT_POINT_THEM, time, null);
        }
        Test.assertMessage(engine.add(event), "refused " + i + " " + event + " at " + TestKit.sets(state));
        events.add(event);
        states.add(engine.getState().copy());
        sizes.add(engine.getLog().size());
    }
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 | 4-3 0-0");
    Test.assert(engine.getState().finishedGames.size() == 16 && engine.getLog().size() == 2 * 90 + 4 + 4 + 6 + 4);
    TestKit.assertMatchesReplay(engine, "90 events");
    for (var i = 0; i < events.size(); i++) {
        Test.assertMessage(engine.getEvent(i).equals(events[i]), "event " + i);
    }
    for (var i = events.size() - 1; i >= 0; i--) {
        var undone = engine.undo();
        Test.assertMessage(undone != null && undone.equals(events[i]), "undid " + undone + ", not " + events[i]);
        Test.assertEqual(engine.getLog().size(), sizes[i]);
        TestKit.assertSameState(engine.getState(), states[i], "after undoing event " + i);
        if (i % 4 == 0 || edits.hasKey(i) || edits.hasKey(i - 1)) {
            TestKit.assertMatchesReplay(engine, "after undoing event " + i);
            TestKit.computeStats(engine, TestKit.START);
        }
    }
    Test.assert(engine.undo() == null);
    return true;
}

(:test)
function editScoreResumeTest(logger as Logger) as Boolean {
    // Resume: a log holding edits replays to the same engine, in one go and a step of
    // 100 events at a time, an edit counting as one: with edits at 99 and 100 the first step ends
    // right after one and the second starts with the other, never cutting it. Through the stored match
    // and its load a step at a time too, and the resumed session's laps start with the game in progress.
    // Advantage: the points between the bursts keep the score level, so they end no game.
    var config = TestKit.withMode(DEUCE_ADVANTAGE);
    var edits = {99 => "6-4 | 2-1 2-1", 100 => "6-4 | 3-3 1-0", 199 => "6-4 4-6 | 1-0 0-0"};
    var bursts = [1, 110, 210];
    var engine = new ScoringEngine(config);
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    for (var i = 1; i < 250; i++) {
        var text = edits.get(i) as String?;
        var time = TestKit.T0 + 30 * i;
        var state = engine.getState();
        var us = state.gamePoints[TEAM_US] <= state.gamePoints[TEAM_THEM];
        for (var b = 0; b < bursts.size(); b++) {
            if (i >= bursts[b] && i < bursts[b] + 16) {
                us = (i - bursts[b]) % 8 < 4;
            }
        }
        Test.assertMessage(engine.add(text != null ? MatchEvent.editScore(time, TestKit.edit(text))
            : new MatchEvent(us ? EVENT_POINT_US : EVENT_POINT_THEM, time, null)), "event " + i);
    }
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 4-6 | 3-2 40-40");
    Test.assert(engine.getState().eventCount == 250 && engine.getState().finishedGames.size() == 12);
    var log = engine.getLog();
    var offsets = TestKit.offsetsOf(log);
    TestKit.assertSameState((ScoringEngine.restore(config, log) as ScoringEngine).getState(), engine.getState(), "restored");
    var resumed = new ScoringEngine(config);
    var ends = [100, 200, 250];
    for (var step = 0; step < ends.size(); step++) {
        var left = resumed.addFromLog(log, MatchLoad.STEP_EVENTS);
        Test.assertMessage(resumed.getState().eventCount == ends[step] && resumed.getLog().size() == offsets[ends[step]]
            && left == (log.size() - offsets[ends[step]]) / 2, "step " + step + ": " + left + " left");
    }
    Test.assertEqual(resumed.getLog().toString(), log.toString());
    TestKit.assertSameState(resumed.getState(), engine.getState(), "in steps");
    Test.assert(resumed.getEvent(99).equals(engine.getEvent(99)) && resumed.getEvent(100).type == EVENT_EDIT_SCORE);
    for (var i = 0; i < 60; i++) {
        resumed.undo();
        engine.undo();
    }
    TestKit.assertSameState(resumed.getState(), engine.getState(), "undone");

    // The stored match, read back a step at a time, and resumed on a new session.
    var restored = ScoringEngine.restore(config, log) as ScoringEngine;
    var load = new MatchLoad(MatchStore.toValue(restored, TestKit.T0, false, null), false);
    var steps = 1;
    var progress = 0.0;
    while (!load.step()) {
        Test.assert(load.getProgress() > progress);
        progress = load.getProgress();
        steps++;
    }
    Test.assertEqual(steps, 3);
    var stored = load.getStored() as StoredMatch;
    TestKit.assertSameState(stored.engine.getState(), restored.getState(), "loaded");
    var session = new TestKit.Resumed(stored);
    var state = session.match.getState();
    Test.assert(session.laps.getCommitted() == state.finishedGames.size()
        && session.recorder.pointDifferential == state.pointsWon[TEAM_US] - state.pointsWon[TEAM_THEM]);

    // A log as this version stores it: Opponents serve first, a point for us, the edit to 6-4 2-1 15-15,
    // a point for them. And the same log without the edit, as earlier versions stored them.
    var t = TestKit.T0;
    var replayed = ScoringEngine.replay(new MatchConfig(), [203, t, 0, t + 30, 207, t + 60, 6040, -1, 201, 101, 1, t + 90]) as MatchState;
    Test.assertEqual(TestKit.sets(replayed), "6-4 | 2-1 15-30");
    Test.assert(replayed.eventCount == 4 && replayed.pointsWon[TEAM_US] == 1 && replayed.pointsWon[TEAM_THEM] == 1
        && replayed.servingTeam == TEAM_THEM && replayed.lastEventTime == t + 90);
    Test.assertEqual(TestKit.sets(ScoringEngine.replay(new MatchConfig(), [203, t, 0, t + 30, 1, t + 90]) as MatchState),
        "| 0-0 15-15");
    return true;
}

(:test)
module EditTests {

    // The edit after the moves so far: refused when expected is null, by the engine and by
    // possibleEdit(), changing nothing; otherwise taken (add()), with the score then expected
    // (TestKit.sets()).
    function check(engine as ScoringEngine, text as String, expected as String?) as Void {
        if (expected != null) {
            add(engine, text, TestKit.VIEW_SETS, expected);
            return;
        }
        var event = TestKit.editEvent(engine, text);
        Test.assertMessage(!TestKit.possibleEdit(engine.getConfig(), engine.getState(), event.edit as ScoreEdit),
            text + ": possibleEdit takes it");
        TestKit.checkRefused(engine, event, text);
    }

    // The edit, which possibleEdit() and the engine must take: it changes the state, its undo gives back
    // the state before it, then the view reads as expected, with a full replay and the set rules.
    function add(engine as ScoringEngine, text as String, view as Number, expected as String) as Void {
        var event = TestKit.editEvent(engine, text);
        Test.assertMessage(TestKit.possibleEdit(engine.getConfig(), engine.getState(), event.edit as ScoreEdit),
            text + ": possibleEdit refuses it");
        TestKit.checkUndo(engine, event, text);
        Test.assert(engine.add(event));
        TestKit.check(engine, view, expected, text);
    }
}

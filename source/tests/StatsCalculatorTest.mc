import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Match stats, added up by the state as the events come (MatchTally) and always equal to a
// replay of the whole log (StatsCalculator, the reference), so they agree with undo: points won and
// lost, games and sets, each game's duration and the longest game, deciding points and tie-breaks,
// the average time per point and our longest streak of points won in a row; with serve tracking, serve and return points, service games held, breaks won and conceded, break
// points converted and saved. Serve stats are null with serve tracking off, and cover the games whose
// serving team is known when they end, all their points included. Every check
// compares the state's stats with the reference (TestKit.computeStats()), as RandomMatchTest does in
// random matches of every format.
//
// Stats are written as TestKit.stats() gives them, won / played, "-" for null. Events are 30 s apart
// and the match starts 15 s before the first one (TestKit.START).

(:test)
function statsHandScoredMatchTest(logger as Logger) as Boolean {
    // Best of 3 sets of 2 games, tie-break at 1-1, Golden Point, Me serving first: ME, THEM, PARTNER,
    // THEM... A tie-break is one game of the rotation: its first point is served by the next server,
    // then two points each. Break points only exist in regular games.
    var engine = TestKit.newMatch(TestKit.shortSets(), "Me");

    // Set 1, 2-0. We hold from 15-40: break points saved at 15-40, 30-40 and on the Golden Point (won,
    // a deciding point). Then we break at our second break point: saved at 40-0, converted at 40-15.
    // Point n is at T0 + 30 n and START at T0 - 15: the games end at points 7 and 12, and a point took
    // (360 + 15) / 12 = 31.25 s.
    TestKit.play(engine, TestKit.HAND_SCORED_SETS[0] as String);
    StatsTests.check(engine, "points 8-4 67%, games 2-0, sets 1-0, deciding 1/1, tie-breaks 0/0, durations 225 150, longest 0"
        + ", per point 31 s, streak 6 | serve 4/7 57%, return 4/5 80%, held 1/1, conceded 0, broke 1/1, break points 1/2, saved 3/3", "set 1");

    // Set 2, 1-2. PARTNER is broken to love (a break point faced at 0-40, lost). We break back on a
    // Golden Point (our break point, converted). Then we lose the tie-break 3-7: we serve its points 1,
    // 4, 5, 8 and 9 and win the 4th and the 8th; they serve the 2nd, 3rd (won by us), 6th, 7th and
    // 10th. Games end at points 16, 23 and 33.
    TestKit.play(engine, TestKit.HAND_SCORED_SETS[1] as String);
    StatsTests.check(engine, "points 15-18 45%, games 3-2, sets 1-1, deciding 2/2, tie-breaks 0/1, durations 225 150 120 210 300, longest 4"
        + ", per point 30 s, streak 6 | serve 6/16 38%, return 9/17 53%, held 1/2, conceded 1, broke 2/2, break points 2/3, saved 3/4", "set 2");

    // Set 3, 2-1. The pair that didn't serve first in the tie-break opens: they hold on a Golden Point
    // (our break point, lost), PARTNER holds to love, then we win the tie-break 7-5: they serve its
    // points 1, 4, 5, 8, 9 and 12 (we win the 1st, 5th and 12th), we serve the 2nd, 3rd, 6th, 7th,
    // 10th and 11th (we win the 2nd, 6th, 7th and 11th). Games end at points 40, 44 and 56.
    TestKit.play(engine, TestKit.HAND_SCORED_SETS[2] as String);
    Test.assert(TestKit.sets(engine.getState()).equals("2-0 1-2(3-7) 2-1(7-5) | 0-0 0-0 over"));
    // Points: 4 + 4 + 0 + 4 + 3 + 3 + 4 + 7 = 29 won, 3 + 1 + 4 + 3 + 7 + 4 + 0 + 5 = 27 lost, the last
    // one at T0 + 1680: (1680 + 15) / 56 = 30.3 s a point. Our longest streak is 6, twice across a game
    // end: the last 3 points of the first game and the first 3 of the second, and in the third set the
    // 4 of PARTNER's hold and the first 2 of the tie-break.
    // Serve: our games 4 of 7, 0 of 4, 4 of 4, our tie-break points 2 of 5 and 4 of 6: 14 of 26.
    // Return: their games 4 of 5, 4 of 7, 3 of 7, their tie-break points 1 of 5 and 3 of 6: 15 of 30.
    // Break points: 2 of 4 converted (40-0 and the Golden Point of the 6th game missed), 3 of 4 saved.
    // Deciding points: 2 of 3 won. Tie-breaks: 1 of 2. The longest game is the last tie-break.
    StatsTests.check(engine, TestKit.HAND_SCORED, "match");
    return true;
}

(:test)
function statsServeTrackingOffTest(logger as Logger) as Boolean {
    // The hand-scored match with serve tracking off: the same points at the same times, without the
    // answer to "Who serves first?". Every serve stat is null, the rest is the same.
    var tracked = TestKit.handScoredMatch();
    var engine = ScoringEngine.restore(tracked.getConfig(), tracked.getLog().slice(ScoringEngine.LOG_NUMBERS_PER_EVENT, null))
        as ScoringEngine;
    Test.assert(engine.getState().matchOver && engine.getState().getFinishedGameServer(0) == null);
    var stats = TestKit.computeStats(engine, TestKit.START);
    TestKit.checkServeNull(stats, "tracking off");
    Test.assertEqual(TestKit.statsMatch(stats), TestKit.statsMatch(TestKit.computeStats(tracked, TestKit.START)));
    return true;
}

(:test)
function statsBreakPointsTest(logger as Logger) as Boolean {
    // A break point is the receivers' game point in a regular game, a deciding point included:
    // converted when the receivers win it, which breaks, saved when the
    // server wins it.

    // Advantage. We hold, saving all five break points (0-40, 15-40, 30-40 and two of their
    // advantages); then we break at our fifth (40-0, 40-15, 40-30, our advantage twice).
    var engine = TestKit.newMatch(TestKit.withMode(DEUCE_ADVANTAGE), "Me");
    TestKit.play(engine, "tttuuututuuu uuutttutuu");
    StatsTests.checkServe(engine, "serve 7/12 58%, return 6/10 60%, held 1/1, conceded 0, broke 1/1, break points 1/5, saved 5/5");

    // Star Point: at 40-0, 40-15, 40-30 and our advantage after deuce 1 they save; we convert the Star
    // Point, a deciding point won. Then Silver Point on our serve: we save 0-40, 15-40, 30-40 and their
    // advantage after deuce 1, and lose the Silver Point, which breaks us.
    engine = TestKit.newMatch(new MatchConfig(), "Opponents Me");
    TestKit.play(engine, "uuutttuttuu");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_SILVER);
    TestKit.play(engine, "tttuuutut");
    StatsTests.checkServe(engine, "serve 4/9 44%, return 6/11 55%, held 0/1, conceded 1, broke 1/1, break points 1/5, saved 4/5");

    // None in a tie-break, whose game points are set points. Shortest sets, Me first: we hold, they
    // hold, then the tie-break goes 0-6 to them.
    engine = TestKit.newMatch(TestKit.format(2, 2, 1, true), "Me");
    TestKit.play(engine, "UT tttttt");
    StatsTests.checkServe(engine, "serve 4/7 57%, return 0/7 0%, held 1/1, conceded 0, broke 0/1, break points 0/0, saved 0/0");
    return true;
}

(:test)
function statsDecidingPointsTest(logger as Logger) as Boolean {
    // Deciding points played and won in Golden, Silver and Star games, none in Advantage; a deuce mode
    // change applies from the next game. No serve tracking needed.
    var engine = new ScoringEngine(new MatchConfig());
    var modes = [DEUCE_GOLDEN, DEUCE_SILVER, DEUCE_STAR, DEUCE_ADVANTAGE];
    var games = ["uuutttu", "uuuttt ut t", "uuuttt ut ut u", "uuuttt ut ut uu"];
    var expected = ["1/1", "1/2", "2/3", "2/3"];
    for (var i = 0; i < modes.size(); i++) {
        TestKit.add(engine, EVENT_SET_DEUCE_MODE, modes[i]);
        TestKit.play(engine, games[i]);
        StatsTests.checkDeciding(engine, expected[i], "mode " + modes[i]);
    }
    // Golden chosen at deuce 1 of an Advantage game: that game keeps Advantage, the next one is Golden,
    // and its deciding point is lost.
    TestKit.play(engine, "uuuttt");
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN);
    TestKit.play(engine, "ut uu");
    StatsTests.checkDeciding(engine, "2/3", "mode changed mid-game");
    TestKit.play(engine, "tttuuut");
    StatsTests.checkDeciding(engine, "2/4", "golden again");
    Test.assertEqual(TestKit.sets(engine.getState()), "| 4-2 0-0");
    TestKit.checkServeNull(TestKit.computeStats(engine, TestKit.START), "tracking off");
    return true;
}

(:test)
function statsTieBreaksTest(logger as Logger) as Boolean {
    // Tie-breaks played to the end and won, the super tie-break included; a tie-break dropped by End
    // set now, and a super tie-break left unfinished by End match, are not played. Shortest sets: a
    // tie-break at 1-1, the third set a super tie-break.
    var config = TestKit.format(2, 2, 1, true);
    config.superTieBreak = true;
    var engine = new ScoringEngine(config);
    TestKit.play(engine, "UTU TUT U");
    Test.assertEqual(engine.getState().getScoreText(), "2-1 1-2 10-0");
    var stats = TestKit.computeStats(engine, TestKit.START);
    Test.assert(stats.tieBreaksWon == 2 && stats.tieBreaksPlayed == 3 && stats.setsWon == 2 && stats.gamesLost == 3);
    engine = new ScoringEngine(config);
    TestKit.play(engine, "UT uuu");
    TestKit.add(engine, EVENT_END_SET, TEAM_US);
    TestKit.play(engine, "UTT uuu");
    TestKit.add(engine, EVENT_END_MATCH, null);
    Test.assertEqual(TestKit.sets(engine.getState()), "1-1EU 1-2(0-7) | 0-0 stb 3-0 over");
    stats = TestKit.computeStats(engine, TestKit.START);
    Test.assert(stats.tieBreaksWon == 0 && stats.tieBreaksPlayed == 1);
    return true;
}

(:test)
function statsTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only counts as a tie-break: won 7-5, one tie-break played and won, a
    // set and no games, one game lasting from the match start to the match point. Its points are serve
    // or return points by turn (ME, then two each: THEM, PARTNER, THEM, ME...); it is no one's service
    // game, so nothing is held or broken and no point is a break point. Its match point undone and
    // played again gives the same stats. Left unfinished by End match, it is no tie-break played and no
    // game, its points still counted.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_7), "Me");
    TestKit.play(engine, "uttuuttuutu");
    StatsTests.checkUndo(engine, TestKit.point(engine, "u"), "match point");
    Test.assertEqual(engine.getState().getScoreText(), "7-5");
    StatsTests.check(engine, "points 7-5 58%, games 0-0, sets 1-0, deciding 0/0, tie-breaks 1/1, durations 375, longest 0"
        + ", per point 31 s, streak 2 | serve 6/6 100%, return 1/6 17%, held 0/0, conceded 0, broke 0/0, break points 0/0"
        + ", saved 0/0", "won");
    engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_10), "Me");
    TestKit.play(engine, "uuuuuttt");
    TestKit.add(engine, EVENT_END_MATCH, null);
    var stats = TestKit.computeStats(engine, TestKit.START);
    Test.assert(stats.tieBreaksPlayed == 0 && stats.gameDurations.size() == 0 && stats.setsWon == 0 && stats.gamesWon == 0
        && stats.pointsWon == 5 && stats.pointsLost == 3);
    return true;
}

(:test)
function statsGameDurationsTest(logger as Logger) as Boolean {
    // A game lasts from the end of the game before it (its winning point, or End set now) to its own
    // winning point; the first game from the match start, the START that ended the warm-up, which isn't
    // in the log. Other events don't move a game's start. The current game's start is in the state, for
    // the data page. Times in seconds after T0, the match start.
    var engine = new ScoringEngine(new MatchConfig());
    StatsTests.checkDurations(engine, "-", null, null);
    // The serve answer 10 s after START, then a game won 170 s after START.
    StatsTests.addAt(engine, EVENT_FIX_SERVING_TEAM, 10, TEAM_US);
    StatsTests.playAt(engine, "uuuu", [40, 80, 120, 170]);
    StatsTests.checkDurations(engine, "170", 0, 170);
    // A server swap and a deuce mode change between games don't move the next game's start.
    StatsTests.addAt(engine, EVENT_SWAP_OUR_SERVER, 200, null);
    StatsTests.addAt(engine, EVENT_SET_DEUCE_MODE, 210, DEUCE_GOLDEN);
    StatsTests.playAt(engine, "tttt", [260, 300, 350, 400]);
    StatsTests.playAt(engine, "uuuu", [450, 520, 600, 760]);
    StatsTests.checkDurations(engine, "170 230 360", 2, 760);
    // End set now drops the game in progress: no duration for it, and the next game starts then. One
    // as long as the longest: the first one stays the longest.
    StatsTests.playAt(engine, "uu", [800, 830]);
    StatsTests.addAt(engine, EVENT_END_SET, 900, null);
    StatsTests.checkDurations(engine, "170 230 360", 2, 900);
    StatsTests.playAt(engine, "uuuu", [950, 1000, 1100, 1260]);
    StatsTests.checkDurations(engine, "170 230 360 360", 2, 1260);
    // The watch's clock went back during a game: it lasts 0, never less. End match leaves the game in
    // progress unfinished: no duration either.
    StatsTests.playAt(engine, "tttt", [1300, 1350, 1100, 1150]);
    StatsTests.playAt(engine, "u", [1400]);
    StatsTests.addAt(engine, EVENT_END_MATCH, 1450, null);
    StatsTests.checkDurations(engine, "170 230 360 360 0", 2, 1150);
    // The match start only moves the first game.
    Test.assertEqual(TestKit.durationsText(TestKit.computeStats(engine, TestKit.T0 - 100)), "270 230 360 360 0");
    return true;
}

(:test)
function statsAveragePointTimeTest(logger as Logger) as Boolean {
    // The average time per point runs from the match start (the START that ended the warm-up) to the
    // last point, divided by the points played: the time before the first point, the
    // changeovers and the pauses count; the events after the last point don't, nor are End set now and
    // End match points. Whole seconds, halves rounded up; null with no point played. Times in seconds
    // after T0, the match start.
    var engine = new ScoringEngine(new MatchConfig());
    StatsTests.checkPointTime(engine, null, "no point");
    StatsTests.addAt(engine, EVENT_FIX_SERVING_TEAM, 10, TEAM_US);
    StatsTests.checkPointTime(engine, null, "the serve answer only");
    StatsTests.playAt(engine, "u", [45]);
    StatsTests.checkPointTime(engine, 45, "first point");
    // 170 / 4 = 42.5.
    StatsTests.playAt(engine, "tuu", [80, 120, 170]);
    StatsTests.checkPointTime(engine, 43, "half rounded up");
    StatsTests.playAt(engine, "u", [210]);
    StatsTests.checkPointTime(engine, 42, "game won");
    // The changeover before the next game's first point, then a 10-minute pause: 950 / 7 = 135.7.
    StatsTests.playAt(engine, "t", [300]);
    StatsTests.checkPointTime(engine, 50, "changeover");
    StatsTests.playAt(engine, "t", [950]);
    StatsTests.checkPointTime(engine, 136, "pause");
    StatsTests.addAt(engine, EVENT_SWAP_OUR_SERVER, 1000, null);
    StatsTests.addAt(engine, EVENT_SET_DEUCE_MODE, 1010, DEUCE_GOLDEN);
    StatsTests.addAt(engine, EVENT_END_SET, 1100, null);
    StatsTests.checkPointTime(engine, 136, "after other events");
    // The dropped game's two points still count: 1150 / 8 = 143.75.
    StatsTests.playAt(engine, "u", [1150]);
    StatsTests.addAt(engine, EVENT_END_MATCH, 1300, null);
    StatsTests.checkPointTime(engine, 144, "end match");
    // A match start 100 s earlier: 1250 / 8 = 156.25. A match start after the last point (the watch's
    // clock went back): 0, never less.
    Test.assert(TestKit.computeStats(engine, TestKit.T0 - 100).averagePointTime == 156);
    Test.assert(TestKit.computeStats(engine, TestKit.T0 + 2000).averagePointTime == 0);
    return true;
}

(:test)
function statsLongestStreakTest(logger as Logger) as Boolean {
    // Our longest run of points won in a row: it runs across games, tie-breaks and sets, and
    // only a point they win breaks it, never End set now nor any other event. Theirs isn't kept. 0
    // until we win a point. Undo and resume bring it back with the rest of the state: an undone point
    // that broke a run joins it up again. Shortest sets, Golden Point: a tie-break at 1-1.
    var engine = TestKit.newMatch(TestKit.shortSets(), "Me");
    StatsTests.checkStreak(engine, 0, "no point");
    TestKit.play(engine, "T tt");
    StatsTests.checkStreak(engine, 0, "their 6 points");
    // From 0-30, 2 points, broken at 30-40; then deuce, the Golden Point and 3 points of the tie-break: 5.
    TestKit.play(engine, "uut");
    StatsTests.checkStreak(engine, 2, "broken");
    TestKit.play(engine, "uu uuu");
    StatsTests.checkStreak(engine, 5, "into the tie-break");
    // The tie-break and the set won 7-0, then 2 points of the next set, a server swap, a deuce mode
    // change and End set now giving that set to them, and 2 points in the third set: 13.
    TestKit.play(engine, "uuuu uu");
    StatsTests.checkStreak(engine, 11, "into the next set");
    TestKit.add(engine, EVENT_SWAP_OUR_SERVER, null);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_ADVANTAGE);
    TestKit.add(engine, EVENT_END_SET, TEAM_THEM);
    TestKit.play(engine, "uu");
    Test.assertEqual(TestKit.sets(engine.getState()), "2-1(7-0) 0-0ET | 0-0 30-0");
    StatsTests.checkStreak(engine, 13, "across End set now");
    TestKit.play(engine, "tu");
    StatsTests.checkStreak(engine, 13, "broken again");
    TestKit.play(engine, "<<u");
    StatsTests.checkStreak(engine, 14, "the point that broke it undone");
    StatsTests.checkUndo(engine, TestKit.point(engine, "u"), "longest");

    // Undo across a snapshot: 40 points in turn (one long Advantage game), then 5 of ours from event
    // 42, past the snapshot at 32 events, and 3 of them undone.
    engine = TestKit.newMatch(TestKit.withMode(DEUCE_ADVANTAGE), "Me");
    TestKit.play(engine, TestKit.repeat("ut", 20));
    StatsTests.checkStreak(engine, 1, "in turn");
    TestKit.play(engine, "uuuuu");
    StatsTests.checkStreak(engine, 5, "after the snapshot");
    TestKit.play(engine, "<<<");
    StatsTests.checkStreak(engine, 2, "undone past the snapshot");
    return true;
}

(:test)
function statsUnfinishedGamesTest(logger as Logger) as Boolean {
    // A game dropped by End set now, or left unfinished by End match, has no winner: it counts in no
    // game stat (games, service games, breaks, tie-breaks, durations), but its points were played and
    // count in every point stat, serve points and break points saved included.
    var engine = TestKit.newMatch(TestKit.withMode(DEUCE_ADVANTAGE), "Me");
    // ME holds, they hold, then PARTNER saves break points at 0-40 and 15-40 before End set now gives
    // us the set at 1-1. The 13 points end at T0 + 390: 31.2 s a point.
    TestKit.play(engine, "UT tttuu");
    TestKit.add(engine, EVENT_END_SET, TEAM_US);
    StatsTests.check(engine, "points 6-7 46%, games 1-1, sets 1-0, deciding 0/0, tie-breaks 0/0, durations 135 120, longest 0"
        + ", per point 31 s, streak 4 | serve 6/9 67%, return 0/4 0%, held 1/1, conceded 0, broke 0/1, break points 0/0, saved 2/2", "end set");
    // PARTNER, who never had the dropped game, holds the next one. Then End match at 30-0 on their serve.
    // End set now doesn't break our streak: the 2 points before it, the 4 of the hold and 2 more make
    // 8. Neither End set now nor End match is a point: 19 points to T0 + 600, 32.4 s a point.
    TestKit.play(engine, "U uu");
    TestKit.add(engine, EVENT_END_MATCH, null);
    StatsTests.check(engine, "points 12-7 63%, games 2-1, sets 1-0, deciding 0/0, tie-breaks 0/0, durations 135 120 120, longest 0"
        + ", per point 32 s, streak 8 | serve 10/13 77%, return 2/6 33%, held 2/2, conceded 0, broke 0/1, break points 0/0, saved 2/2", "end match");
    return true;
}

(:test)
function statsLateFixServingTeamTest(logger as Logger) as Boolean {
    // The serve stats count the games whose serving team is known when they end, and all of their
    // points, those before a Fix serving team in that game included: the serving team doesn't change
    // during a game, so the fix holds for the whole game. Games ended before the
    // first fix count in no serve stat.

    // Serve tracking starts between games: the first two games count in the match stats only. We break
    // at 40-15, then ME holds from 0-15. 18 points to T0 + 540: 30.8 s a point.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UT");
    TestKit.checkServeNull(TestKit.computeStats(engine, TestKit.START), "before the fix");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.play(engine, "uutuu tuuuu");
    StatsTests.check(engine, "points 12-6 67%, games 3-1, sets 0-0, deciding 0/0, tie-breaks 0/0, durations 105 120 180 150, longest 2"
        + ", per point 31 s, streak 4 | serve 4/5 80%, return 4/5 80%, held 1/1, conceded 0, broke 1/1, break points 1/1, saved 0/0", "between games");

    // Serve tracking starts at 15-15: all five points of their hold are return points.
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "U tu");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.play(engine, "ttt");
    StatsTests.checkServe(engine, "serve 0/0 -, return 1/5 20%, held 0/0, conceded 0, broke 0/1, break points 0/0, saved 0/0");

    // A correction: shown as our serve, they actually serve, fixed at 15-40. The game's points are all
    // return points, and their game points at 0-40, 15-40 and 30-40 weren't break points; our
    // advantage after deuce 1 was one, converted.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "tttu");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.play(engine, "uuuu");
    StatsTests.checkServe(engine, "serve 0/0 -, return 5/8 63%, held 0/0, conceded 0, broke 1/1, break points 1/1, saved 0/0");

    // In a tie-break a fix shifts all its turns, those before it included. Shortest sets, Me first: we
    // hold, they hold; the tie-break's first point is shown as ours, the second as theirs, and we fix
    // it to us: they served the first point. We win it 7-0: we served the 2nd, 3rd, 6th and 7th
    // points, they the 1st, 4th and 5th.
    engine = TestKit.newMatch(TestKit.format(2, 2, 1, true), "Me");
    TestKit.play(engine, "UT u");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_US);
    TestKit.play(engine, "uuuuuu");
    StatsTests.checkServe(engine, "serve 8/8 100%, return 3/7 43%, held 1/1, conceded 0, broke 0/1, break points 0/0, saved 0/0");
    return true;
}

(:test)
function statsUndoTest(logger as Logger) as Boolean {
    // Stats come from the log alone: after an undo they equal the stats of the shortened log, the stats
    // before the undone event. On the hand-scored match: a point within a game, a point that wins a
    // game (a deciding point), one that wins a set, one that wins a tie-break and a set, and the match
    // point, which BACK on the summary undoes; then a late Fix serving team, which turns
    // the serve stats on, and End set now.
    var engine = TestKit.newMatch(TestKit.shortSets(), "Me");
    var moves = ["utt", "uu", "uuut", "tttt tttuuuu ttuutttut", "tttuuut uuuu uuttuuuttt u"];
    var points = ["t", "u", "u", "t", "u"];
    for (var i = 0; i < moves.size(); i++) {
        TestKit.play(engine, moves[i]);
        StatsTests.checkUndo(engine, TestKit.point(engine, points[i]), "undo " + i);
    }
    StatsTests.check(engine, TestKit.HAND_SCORED, "match point played again");
    // Back on the summary: the match goes on, the tie-break in progress at 6-5 (its points so far
    // credited by turn), the games before it unchanged.
    engine.undo();
    Test.assertEqual(TestKit.sets(engine.getState()), "2-0 1-2(3-7) | 1-1 tb 6-5");
    StatsTests.check(engine, "points 28-27 51%, games 4-3, sets 1-1, deciding 2/3, tie-breaks 0/1, durations 225 150 120 210 300 210 120, longest 4"
        + ", per point 30 s, streak 6 | serve 14/26 54%, return 14/29 48%, held 2/3, conceded 1, broke 2/3, break points 2/4, saved 3/4", "undone");
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "U tu");
    StatsTests.checkUndo(engine, new MatchEvent(EVENT_FIX_SERVING_TEAM, TestKit.nextTime(engine), TEAM_THEM), "fix");
    StatsTests.checkUndo(engine, new MatchEvent(EVENT_END_SET, TestKit.nextTime(engine), null), "end set");
    return true;
}

(:test)
function statsLongMatchTest(logger as Logger) as Boolean {
    // A 1,000-event match (DebugMenu.longLog(), into the third set): the stats the state added up equal
    // a replay of the whole log, and still do after undos across undo snapshots. The pause, the summary
    // and the save read them without a replay, and an undo replays fewer than SNAPSHOT_EVERY events, so
    // neither grows with the match; the times, next to the full replays the app used to run, go to the
    // test log.
    var events = 1000;
    var start = TestKit.START;
    var config = DebugMenu.longConfig();
    var log = DebugMenu.longLog(events, start + 15);
    var memory = System.getSystemStats().usedMemory;
    var timer = System.getTimer();
    var engine = ScoringEngine.restore(config, log) as ScoringEngine;
    var restore = System.getTimer() - timer;
    memory = System.getSystemStats().usedMemory - memory;
    timer = System.getTimer();
    ScoringEngine.replay(config, log);
    var replay = System.getTimer() - timer;
    timer = System.getTimer();
    StatsCalculator.compute(config, log, start);
    var full = System.getTimer() - timer;
    timer = System.getTimer();
    var values = SessionValues.compute(engine, start);
    var pause = System.getTimer() - timer;
    var stats = TestKit.computeStats(engine, start);
    Test.assertEqual((stats.servePointsPlayed as Number) + (stats.returnPointsPlayed as Number), events - 1);
    Test.assertEqual(values.points[TEAM_US] + values.points[TEAM_THEM], events - 1);
    // 999 points, the last 29,985 s after the match start: 30.0 s a point. Each game ends with the
    // winner's 3 points and the next one's loser takes its first: our longest streak is 4, across games.
    Test.assertEqual(TestKit.statsPoints(stats), "per point 30 s, streak 4");
    // Resumed as the launch does, MatchLoad.STEP_EVENTS events a step: the same stats.
    var resumed = new ScoringEngine(config);
    var left = events as Number?;
    while (left != null && left > 0) {
        left = resumed.addFromLog(log, MatchLoad.STEP_EVENTS);
    }
    Test.assertEqual(TestKit.stats(TestKit.computeStats(resumed, start)), TestKit.stats(stats));
    // Undos through a whole snapshot interval and more: the slowest replays SNAPSHOT_EVERY - 1 events.
    var slowest = 0;
    for (var i = 0; i < ScoringEngine.SNAPSHOT_EVERY + 8; i++) {
        timer = System.getTimer();
        engine.undo();
        var time = System.getTimer() - timer;
        slowest = time > slowest ? time : slowest;
    }
    TestKit.computeStats(engine, start);
    logger.debug("1000 events: restore " + restore + " ms (" + MatchLoad.STEP_EVENTS + " a step: "
        + restore * MatchLoad.STEP_EVENTS / events + " ms), full replay " + replay + " ms, stats replay " + full
        + " ms, pause values " + pause + " ms, slowest undo " + slowest + " ms; the engine "
        + memory + " B, a snapshot " + engine.getState().pack().size() + " values");
    return true;
}

(:test)
function statsEmptyTest(logger as Logger) as Boolean {
    // Nothing played: no percentage, no game, no serve stat, even once the serve answer is logged.
    var engine = new ScoringEngine(new MatchConfig());
    StatsTests.check(engine, "points 0-0 -, games 0-0, sets 0-0, deciding 0/0, tie-breaks 0/0, durations -, longest -"
        + ", per point -, streak 0 | serve - -, return - -, held -, conceded -, broke -, break points -, saved -", "empty");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_US);
    TestKit.checkServeNull(TestKit.computeStats(engine, TestKit.START), "answer only");
    return true;
}

(:test)
module StatsTests {

    function check(engine as ScoringEngine, expected as String, message as String) as Void {
        Test.assertEqualMessage(TestKit.stats(TestKit.computeStats(engine, TestKit.START)), expected, message);
    }

    function checkServe(engine as ScoringEngine, expected as String) as Void {
        Test.assertEqual(TestKit.statsServe(TestKit.computeStats(engine, TestKit.START)), expected);
    }

    function checkDeciding(engine as ScoringEngine, expected as String, message as String) as Void {
        var stats = TestKit.computeStats(engine, TestKit.START);
        Test.assertEqualMessage(stats.decidingPointsWon + "/" + stats.decidingPointsPlayed, expected, message);
    }

    // The average time per point in seconds, with the match starting at T0.
    function checkPointTime(engine as ScoringEngine, expected as Number?, message as String) as Void {
        var time = TestKit.computeStats(engine, TestKit.T0).averagePointTime;
        Test.assertMessage(time == expected, message + ": " + time);
    }

    function checkStreak(engine as ScoringEngine, expected as Number, message as String) as Void {
        Test.assertEqualMessage(TestKit.computeStats(engine, TestKit.START).longestStreak, expected, message);
    }

    // The game durations and the longest game, with the match starting at T0, and the current game's
    // start in seconds after T0 (null: the match start).
    function checkDurations(engine as ScoringEngine, durations as String, longest as Number?, gameStart as Number?) as Void {
        var t = TestKit.T0;
        var stats = TestKit.computeStats(engine, t);
        Test.assertEqual(TestKit.durationsText(stats), durations);
        Test.assertMessage(stats.longestGame == longest, "longest " + stats.longestGame);
        var start = gameStart == null ? null : t + gameStart;
        Test.assertMessage(engine.getState().gameStartTime == start, "game start " + engine.getState().gameStartTime);
        Test.assertEqual(engine.getState().getGameStartTime(t), start == null ? t : start);
    }

    // Adds the event, then undoes it: the stats change with it, and after the undo equal both those
    // before it and those of the log without it. The event is then added again.
    function checkUndo(engine as ScoringEngine, event as MatchEvent, message as String) as Void {
        var before = TestKit.stats(TestKit.computeStats(engine, TestKit.START));
        Test.assertMessage(engine.add(event), message + ": refused");
        Test.assertMessage(!TestKit.stats(TestKit.computeStats(engine, TestKit.START)).equals(before), message + ": no change");
        var log = engine.getLog();
        var shortened = StatsCalculator.compute(engine.getConfig(), log.slice(0, log.size() - event.getSize()),
            TestKit.START);
        Test.assertMessage(engine.undo() != null, message);
        Test.assertEqualMessage(TestKit.stats(TestKit.computeStats(engine, TestKit.START)), before, message + ": undone");
        Test.assertEqualMessage(TestKit.stats(shortened as MatchStats), before, message + ": shortened log");
        Test.assertMessage(engine.add(event), message + ": refused again");
    }

    // Plays the points of a string such as "uutu" (u us, t them) at these times, in seconds after T0.
    function playAt(engine as ScoringEngine, points as String, times as Array<Number>) as Void {
        for (var i = 0; i < points.length(); i++) {
            var us = (points.substring(i, i + 1) as String).equals("u");
            addAt(engine, us ? EVENT_POINT_US : EVENT_POINT_THEM, times[i], null);
        }
    }

    function addAt(engine as ScoringEngine, type as EventType, seconds as Number, payload as Number?) as Void {
        Test.assert(engine.add(new MatchEvent(type, TestKit.T0 + seconds, payload)));
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Free play: no set to win, sets of 6 with a tie-break at 6-6, so the sets go on until
// End match, which ends it with the early end's result (sets, then the unfinished set's games, then the
// points, else a draw); no match point. The longest match kept: the log holds
// ScoringEngine.LOG_MAX Numbers, every event but End match leaving room for one. The score text keeps
// its latest sets. The match is written as TestKit.sets() gives it.

(:test)
function freePlayPresetTest(logger as Logger) as Boolean {
    // The last preset, after Tie-break to 10: stored as no set to win (setsToWin 0) with sets of 6, a
    // tie-break at 6-6 to 7 and no super tie-break, over any structure; the deuce mode, singles and mixed
    // go with it. Its only valid structure, so it is never Custom; another preset brings its own back.
    var presets = MatchConfig.presets();
    Test.assertEqual(presets[presets.size() - 1], PRESET_FREE_PLAY);
    var bases = [new MatchConfig(), TestKit.custom(), TestKit.preset(PRESET_TIE_BREAK_10), TestKit.preset(PRESET_PRO_SET)];
    for (var b = 0; b < bases.size(); b++) {
        var config = bases[b].copy();
        config.applyPreset(PRESET_FREE_PLAY);
        var message = "base " + b;
        Test.assertMessage(config.setsToWin == 0 && config.gamesToWin == 6 && config.tieBreakAt == 6 && config.hasTieBreak
            && config.tieBreakPoints == 7 && !config.superTieBreak && config.deuceMode == bases[b].deuceMode
            && config.doubles == bases[b].doubles && config.mixed == bases[b].mixed, message);
        Test.assertMessage(config.isValid() && config.isFreePlay() && config.getPreset() == PRESET_FREE_PLAY
            && !config.isTieBreakOnly() && config.maxSets() == 0 && !config.isSuperTieBreakSet(0)
            && !config.isSuperTieBreakSet(4) && !config.winsMatch(0) && !config.winsMatch(3) && !config.winsMatch(99), message);
        var loaded = MatchConfig.fromDictionary(config.toDictionary());
        Test.assertMessage(loaded != null && (loaded as MatchConfig).equals(config)
            && (loaded as MatchConfig).getPreset() == PRESET_FREE_PLAY, message + ": stored");
        config.applyPreset(PRESET_BEST_OF_3);
        Test.assertMessage(config.getPreset() == PRESET_BEST_OF_3 && !config.isFreePlay() && config.winsMatch(2)
            && !config.winsMatch(1), message + ": best of 3");
    }
    // As this version stores it, and one field away: no format (no set to win with another structure).
    var data = TestKit.storedBestOf3();
    data.put("setsToWin", 0);
    var loaded = MatchConfig.fromDictionary(data);
    Test.assert(loaded != null && (loaded as MatchConfig).getPreset() == PRESET_FREE_PLAY && (loaded as MatchConfig).deuceMode == DEUCE_STAR);
    var changes = [["gamesToWin", 4], ["tieBreakAt", 5], ["hasTieBreak", false], ["tieBreakPoints", 10], ["superTieBreak", true]];
    for (var i = 0; i < changes.size(); i++) {
        var other = TestKit.storedBestOf3();
        other.put("setsToWin", 0);
        other.put(changes[i][0] as String, changes[i][1]);
        Test.assertMessage(MatchConfig.fromDictionary(other) == null, "change " + changes[i]);
    }
    return true;
}

(:test)
function freePlaySetsGoOnTest(logger as Logger) as Boolean {
    // Sets of 6 that go on after 2 and after 3 are won, by one team or both; a set point is never a match
    // point; a tie-break at 6-6 wins the set 7-6 and the next set starts; the sets and games add up.
    var config = TestKit.preset(PRESET_FREE_PLAY);
    var engine = TestKit.newMatch(config, "Me");
    var sixLove = TestKit.repeat("U", 6);
    TestKit.play(engine, sixLove + sixLove + TestKit.repeat("U", 5) + "uuu");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "SET POINT pressure | SET 3 | break U, set U", "5-0 40-0 in set 3");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "6-0 6-0 6-0 | 0-0 0-0"]]);
    MatchEndTests.checkTotals(engine.getState(), [3, 0], [18, 0]);
    Test.assert(engine.getState().getResult() == RESULT_UNFINISHED && engine.getState().getWinner() == null);
    // Them, three sets in a row, then a tie-break set: 3-3 in sets, then 4-3.
    TestKit.play(engine, TestKit.repeat("T", 18) + TestKit.repeat("UT", 6));
    TestKit.check(engine, TestKit.VIEW_SITUATION, "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break", "the tie-break");
    TestKit.play(engine, "uuuuuu");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break", "6-0 in it");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "6-0 6-0 6-0 0-6 0-6 0-6 7-6(7-0) | 0-0 0-0"]]);
    TestKit.play(engine, "UUUUU");
    TestKit.check(engine, TestKit.VIEW_SETS, "6-0 6-0 6-0 0-6 0-6 0-6 7-6(7-0) | 5-0 0-0", "set 8");
    MatchEndTests.checkTotals(engine.getState(), [4, 3], [30, 24]);
    Test.assertEqual(engine.getState().getScoreText(), "6-0 6-0 6-0 0-6 0-6 0-6 7-6 5-0*");
    // Undo back across the sets: each undo gives back the state a replay gives, back to the start.
    for (var i = engine.getState().eventCount; i > 0; i--) {
        Test.assert(engine.undo() != null);
        if (i % 7 == 0) {
            TestKit.assertMatchesReplay(engine, "undo " + i);
        }
    }
    Test.assertEqual(TestKit.sets(engine.getState()), "| 0-0 0-0");
    return true;
}

(:test)
function freePlayEndMatchTest(logger as Logger) as Boolean {
    // End match: more sets won wins, whatever the set in progress; level in sets, the set's
    // games, then the game's points; all level, a draw. Nothing follows, undo reopens the match. End set
    // now gives a set and the match goes on.
    var config = TestKit.preset(PRESET_FREE_PLAY);
    var sets = TestKit.repeat("U", 6) + TestKit.repeat("T", 6) + TestKit.repeat("U", 6);
    var engine = MatchEndTests.checkEnd(config, sets + "TTT tt", "6-0 0-6 6-0 | 0-3 0-30 over", RESULT_WIN, "6-0 0-6 6-0 0-3*");
    MatchEndTests.checkNothingFollows(engine);
    engine.undo();
    Test.assertEqual(TestKit.sets(engine.getState()), "6-0 0-6 6-0 | 0-3 0-30");
    MatchEndTests.checkEnd(config, sets + TestKit.repeat("T", 6) + "UTT uu", "6-0 0-6 6-0 0-6 | 1-2 30-0 over", RESULT_LOSS,
        "6-0 0-6 6-0 0-6 1-2*");
    MatchEndTests.checkEnd(config, sets + TestKit.repeat("T", 6) + "UT uuut", "6-0 0-6 6-0 0-6 | 1-1 40-15 over", RESULT_WIN,
        "6-0 0-6 6-0 0-6 1-1*");
    MatchEndTests.checkEnd(config, sets + TestKit.repeat("T", 6) + "UT uuuttt", "6-0 0-6 6-0 0-6 | 1-1 40-40 over", RESULT_DRAW,
        "6-0 0-6 6-0 0-6 1-1*");
    // Right after a set, level in sets: a draw, and no set in progress in the score.
    MatchEndTests.checkEnd(config, sets + TestKit.repeat("T", 6), "6-0 0-6 6-0 0-6 | 0-0 0-0 over", RESULT_DRAW, "6-0 0-6 6-0 0-6");
    MatchEndTests.checkEnd(config, "", "| 0-0 0-0 over", RESULT_DRAW, "0-0*");
    // End set now: the leader's set, then the next one.
    engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, sets + "UU");
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, null, "6-0 0-6 6-0 2-0EU | 0-0 0-0");
    TestKit.checkEvent(engine, TestKit.VIEW_SETS, EVENT_END_SET, TEAM_THEM, "6-0 0-6 6-0 2-0EU 0-0ET | 0-0 0-0");
    Test.assert(!engine.getState().matchOver && engine.getState().getSetsWon(TEAM_US) == 3);
    return true;
}

(:test)
function freePlayEditTest(logger as Logger) as Boolean {
    // Edit score in Free play: any number of finished sets, a team with 3 or more won
    // included (they would end a best of 3 or 5), up to ScoreEdit.MAX; the sets of 6 rules otherwise.
    // Undo gives the state back.
    var config = TestKit.preset(PRESET_FREE_PLAY);
    var engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UU u");
    TestKit.checkUndo(engine, TestKit.editEvent(engine, "6-4 6-3 7-6(7-5) | 2-1 2-1"), "3 sets to us");
    Test.assert(engine.add(TestKit.editEvent(engine, "6-4 6-3 7-6(7-5) 6-0 6-1 | 5-4 3-0")));
    TestKit.check(engine, TestKit.VIEW_SITUATION, "SET POINT pressure | SET 6 | set U", "edited");
    TestKit.checkSteps(engine, TestKit.VIEW_SETS, [["u", "6-4 6-3 7-6(7-5) 6-0 6-1 6-4 | 0-0 0-0"]]);
    TestKit.checkRefused(engine, TestKit.editEvent(engine, "6-4 6-6 | 0-0 0-0"), "a set not won");
    TestKit.checkRefused(engine, TestKit.editEvent(engine, "6-4 | 7-0 0-0"), "a set in progress won");
    // ScoreEdit.MAX sets at most.
    var words = TestKit.repeat("6-0 ", ScoreEdit.MAX);
    TestKit.checkUndo(engine, TestKit.editEvent(engine, words + "| 0-0 0-0"), ScoreEdit.MAX + " sets");
    TestKit.checkRefused(engine, TestKit.editEvent(engine, words + "6-0 | 0-0 0-0"), (ScoreEdit.MAX + 1) + " sets");
    return true;
}

(:test)
function freePlayScoreTextTest(logger as Logger) as Boolean {
    // The Score field past its 47 characters keeps the latest sets after "..", the set in
    // progress and its star included; the resume prompt's shorter line too (getScoreTextIn()).
    var engine = new ScoringEngine(TestKit.preset(PRESET_FREE_PLAY));
    TestKit.play(engine, TestKit.repeat("UTUTUTUTUU", 11));
    Test.assertEqual(engine.getState().getScoreText(), "6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4");
    TestKit.play(engine, "UTUTUTUTUU UT u");
    Test.assertEqual(engine.getState().getScoreText(), ".. 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 1-1*");
    Test.assertEqual(engine.getState().getScoreText().length(), 47);
    Test.assertEqual(engine.getState().getScoreTextIn(21), ".. 6-4 6-4 6-4 1-1*");
    TestKit.add(engine, EVENT_END_MATCH, null);
    Test.assertEqual(engine.getState().getScoreText(), ".. 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 6-4 1-1*");
    // An edit's sets, a tie-break in progress, and shorter lines: as many sets as fit, else the text cut.
    engine = new ScoringEngine(TestKit.preset(PRESET_FREE_PLAY));
    Test.assert(engine.add(TestKit.editEvent(engine, TestKit.repeat("7-6(7-5) 6-0 ", 4) + "| 6-6 10-9")));
    Test.assertEqual(engine.getState().getScoreText(), "7-6 6-0 7-6 6-0 7-6 6-0 7-6 6-0 6-6*");
    Test.assertEqual(engine.getState().getScoreTextIn(10), ".. 6-6*");
    Test.assertEqual(engine.getState().getScoreTextIn(5), ".. 6-");
    return true;
}

(:test)
function freePlayLogLimitTest(logger as Logger) as Boolean {
    // The longest match kept: the log holds ScoringEngine.LOG_MAX Numbers. A point that would
    // leave no room for an End match after it is refused, changing nothing; End match then still ends
    // the match, and undo makes room again. An edit counts its whole size. A stored log is resumed
    // whatever its size. The debug build's full Free play match (DebugMenu.freePlayLog(), fullEvents())
    // has room for DebugMenu.FULL_ROOM points.
    var config = DebugMenu.freePlayConfig();
    var log = DebugMenu.freePlayLog(DebugMenu.fullEvents(), TestKit.T0);
    Test.assertEqual(log.size(), ScoringEngine.LOG_MAX - 2 * (1 + DebugMenu.FULL_ROOM));
    var engine = ScoringEngine.restore(config, log) as ScoringEngine;
    var state = engine.getState();
    Test.assert(!state.matchOver && state.setScores.size() == 47 && engine.getLog().size() == log.size());
    // A big edit fits only while there's room for it.
    var sets = TestKit.sets(state);
    var edit = TestKit.editEvent(engine, sets.substring(0, sets.find("|") as Number) + "| 0-0 0-0");
    Test.assert(!engine.hasRoom(edit) && ScoringEngine.canApply(config, state, edit));
    TestKit.checkRefused(engine, edit, "a big edit");
    for (var i = 0; i < DebugMenu.FULL_ROOM; i++) {
        Test.assert(!engine.isFull() && engine.add(TestKit.point(engine, i % 2 == 0 ? "u" : "t")));
    }
    Test.assert(engine.isFull() && engine.getLog().size() == ScoringEngine.LOG_MAX - 2);
    var points = [new MatchEvent(EVENT_POINT_US, TestKit.nextTime(engine), null), new MatchEvent(EVENT_SWAP_OUR_SERVER, TestKit.nextTime(engine), null),
        new MatchEvent(EVENT_END_SET, TestKit.nextTime(engine), null), TestKit.editEvent(engine, "| 0-0 0-0")];
    for (var i = 0; i < points.size(); i++) {
        TestKit.checkRefused(engine, points[i], "full: " + points[i]);
    }
    var end = new MatchEvent(EVENT_END_MATCH, TestKit.nextTime(engine), null);
    Test.assert(engine.hasRoom(end));
    TestKit.checkUndo(engine, end, "End match when full");
    Test.assert(engine.add(end) && engine.getLog().size() == ScoringEngine.LOG_MAX && engine.getState().matchOver);
    engine.undo();
    engine.undo();
    Test.assert(!engine.isFull() && engine.add(TestKit.point(engine, "u")) && engine.isFull());
    // A stored log at the limit, End match included, resumes: in one go, and as the launch reads it from
    // storage (its parts, the array taken as it is).
    Test.assert(engine.add(new MatchEvent(EVENT_END_MATCH, TestKit.nextTime(engine), null)));
    Test.assertEqual(engine.getLogSize(), ScoringEngine.LOG_MAX);
    var resumed = ScoringEngine.restore(config, engine.getLog());
    Test.assert(resumed != null && resumed.getState().matchOver);
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        MatchStore.clear();
        MatchStore.save(engine, TestKit.T0, false, null);
        var stored = TestKit.loadStored();
        Test.assert(stored != null);
        var loaded = (stored as StoredMatch).engine;
        TestKit.assertSameState(loaded.getState(), engine.getState(), "loaded at the limit");
        // Undone back into the match: a point is refused, End match fits again.
        Test.assert(loaded.undo() != null && loaded.isFull()
            && !loaded.add(new MatchEvent(EVENT_POINT_US, TestKit.nextTime(engine), null))
            && loaded.add(new MatchEvent(EVENT_END_MATCH, TestKit.nextTime(engine), null)));
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function freePlayLongMatchTest(logger as Logger) as Boolean {
    // The 3,000-event Free play match (DebugMenu.freePlayLog(), 47 sets and the 48th in
    // progress): resumed a step at a time as the launch does, it is the match a replay gives; the pause's
    // session values, the score text (its latest sets) and the summary's record (the latest 5 sets, the 43
    // before them as sets won) need no replay; its stats, added up with the score, equal a full replay of
    // the log, also after undos across undo snapshots (each replays fewer than SNAPSHOT_EVERY events). The
    // times and the memory go to the test log; the app's own peak is measured in the simulator.
    var events = DebugMenu.FREE_PLAY_EVENTS;
    var start = TestKit.START;
    var config = DebugMenu.freePlayConfig();
    var memory = System.getSystemStats().usedMemory;
    var log = DebugMenu.freePlayLog(events, start + 15);
    var logMemory = System.getSystemStats().usedMemory - memory;
    memory = System.getSystemStats().usedMemory;
    var timer = System.getTimer();
    var engine = new ScoringEngine(config);
    var left = events as Number?;
    var steps = 0;
    while (left != null && left > 0) {
        left = engine.addFromLog(log, MatchLoad.STEP_EVENTS);
        steps++;
    }
    var resume = System.getTimer() - timer;
    memory = System.getSystemStats().usedMemory - memory;
    Test.assert(left == 0 && steps == events / MatchLoad.STEP_EVENTS);
    var state = engine.getState();
    TestKit.assertSameState(state, ScoringEngine.replay(config, log) as MatchState, "resumed");
    Test.assert(state.setScores.size() == 47 && !state.matchOver && !engine.isFull());
    timer = System.getTimer();
    var values = SessionValues.compute(engine, start);
    var pause = System.getTimer() - timer;
    Test.assert(values.sets[TEAM_US] == 28 && values.sets[TEAM_THEM] == 19 && values.points[TEAM_US] + values.points[TEAM_THEM] == events - 1);
    Test.assertEqual(values.score, ".. 7-6 2-6 7-5 6-4 3-6 7-6 2-6 7-5 6-4 3-6 2-1*");
    var record = new HistoryRecord(start, config, state.getResult(), HistoryRecord.rowsOf(state), state.getStats(start),
        [3600, null, null, null]);
    Test.assert(record.rows.size() == HistoryRecord.ROWS_MAX && record.rows[0].setNumber == 44 && record.rows[4].winner == null
        && record.earlier[TEAM_US] == 26 && record.earlier[TEAM_THEM] == 17);
    Test.assertEqual(record.getSetsWon().toString(), [28, 19].toString());
    timer = System.getTimer();
    var stats = TestKit.computeStats(engine, start);
    var full = System.getTimer() - timer;
    Test.assert(stats.setsWon == 28 && stats.setsLost == 19);
    var slowest = 0;
    for (var i = 0; i < ScoringEngine.SNAPSHOT_EVERY + 8; i++) {
        timer = System.getTimer();
        engine.undo();
        var time = System.getTimer() - timer;
        slowest = time > slowest ? time : slowest;
    }
    TestKit.computeStats(engine, start);
    logger.debug("free play, " + events + " events: resume " + resume + " ms in " + steps + " steps, stats replay " + full
        + " ms, pause values " + pause + " ms, slowest undo " + slowest + " ms; the log " + logMemory + " B, the engine "
        + memory + " B");
    return true;
}

(:test)
function freePlaySessionValuesTest(logger as Logger) as Boolean {
    // The FIT session fields of a long Free play: a count past what a uint8 field holds (254)
    // is written invalid (255, Connect shows none), never wrapped round; the points are uint16; the score
    // keeps its latest sets.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_FREE_PLAY), "Me");
    Test.assert(engine.add(TestKit.editEvent(engine, TestKit.repeat("6-0 ", 42) + TestKit.repeat("0-6 ", 2) + "| 5-0 0-0")));
    var values = SessionValues.compute(engine, TestKit.START);
    Test.assert(values.games[TEAM_US] == FIT_INVALID_UINT8 && values.games[TEAM_THEM] == 12 && values.sets[TEAM_US] == 42
        && values.sets[TEAM_THEM] == 2);
    Test.assert(values.score.length() == MatchState.SCORE_TEXT_MAX && values.score.find("..") == 0);
    // 254 games still show.
    engine.undo();
    Test.assert(engine.add(TestKit.editEvent(engine, TestKit.repeat("6-0 ", 42) + "| 2-0 0-0")));
    Test.assertEqual(SessionValues.compute(engine, TestKit.START).games[TEAM_US], FIT_MAX_UINT8);
    return true;
}

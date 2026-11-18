import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

// Events, the log, replay and undo: events carry their type, payload and wall
// clock time, and a fixed stored code; the state is a replay of the config and the log; a new event
// is applied to the current state and must give the same state as a full replay (see also
// RandomMatchTest); undo removes the last event of any type, unlimited, back to the start; a log the
// engine would never have built doesn't replay, so resume offers Discard only.

(:test)
function matchEventTest(logger as Logger) as Boolean {
    // Valid events round-trip through their stored form, a score edit's included; invalid ones are
    // refused; equals compares type, time and payload.
    var valid = TestKit.everyValidEvent();
    for (var i = 0; i < valid.size(); i++) {
        var log = [] as Array<Application.Storage.ValueType>;
        valid[i].addTo(log);
        var loaded = MatchEvent.fromLog(log, 0);
        Test.assertMessage(valid[i].isValid() && valid[i].equals(loaded) && valid[i].getSize() == log.size(), valid[i].toString());
        if (valid[i].type != EVENT_EDIT_SCORE) {
            Test.assertMessage(valid[i].equals(MatchEvent.fromCode(valid[i].getCode(), valid[i].time)), valid[i].toString());
        }
    }
    var invalid = TestKit.invalidEvents();
    for (var i = 0; i < invalid.size(); i++) {
        Test.assertMessage(!invalid[i].isValid(), invalid[i].toString());
    }
    var t = TestKit.T0;
    var event = new MatchEvent(EVENT_END_SET, t, TEAM_US);
    Test.assert(event.equals(new MatchEvent(EVENT_END_SET, t, TEAM_US)));
    Test.assert(!event.equals(new MatchEvent(EVENT_END_SET, t, TEAM_THEM)) && !event.equals(new MatchEvent(EVENT_END_SET, t, null)));
    Test.assert(!event.equals(new MatchEvent(EVENT_END_SET, t + 1, TEAM_US)) && !event.equals(new MatchEvent(EVENT_END_MATCH, t, null)));
    Test.assert(!event.equals(null) && !event.equals(event.getCode()));

    // MatchEvent.now() stamps the wall clock in seconds (Time.now()), not the system timer.
    var before = Time.now().value();
    event = MatchEvent.now(EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    Test.assert(event.type == EVENT_FIX_SERVING_TEAM && event.payload == TEAM_THEM);
    Test.assert(event.time >= before && event.time <= Time.now().value());
    return true;
}

(:test)
function matchEventStoredCodesTest(logger as Logger) as Boolean {
    // Logs stored by earlier versions must keep loading: the codes are fixed, never renumbered.
    var t = TestKit.T0;
    var codes = [0, 1, 2, 103, 203, 104, 204, 304, 404, 5, 105, 205, 6];
    var events = TestKit.everyValidEvent();
    for (var i = 0; i < codes.size(); i++) {
        var expected = new MatchEvent(events[i].type, t, events[i].payload);
        Test.assertEqual(expected.getCode(), codes[i]);
        Test.assertMessage(expected.equals(MatchEvent.fromCode(codes[i], t)), "code " + codes[i]);
    }
    var malformed = [
        // Not Numbers.
        [null, t], [0, null], [0.0, t], [0l, t], ["0", t], [true, t], [[0], t], [0, t.toLong()], [0, t.toString()],
        // Unknown type, negative code or time.
        [7, t], [99, t], [-1, t], [-97, t], [0, -1],
        // Payload unexpected, missing or out of range.
        [100, t], [102, t], [106, t], [3, t], [4, t], [303, t], [504, t], [305, t], [10000, t]
    ] as Array<Array<Object?> >;
    for (var i = 0; i < malformed.size(); i++) {
        Test.assertMessage(MatchEvent.fromCode(malformed[i][0], malformed[i][1]) == null, "accepted " + malformed[i]);
    }
    return true;
}

(:test)
function scoringEngineNewMatchTest(logger as Logger) as Boolean {
    var config = TestKit.withMode(DEUCE_GOLDEN);
    var engine = new ScoringEngine(config);
    var state = engine.getState();
    Test.assertEqual(TestKit.game(state), "0-0 0-0");
    Test.assert(state.deuceMode == DEUCE_GOLDEN && state.gameDeuceMode == DEUCE_GOLDEN);
    Test.assert(state.servingTeam == null && state.ourServer == PLAYER_ME && !state.matchOver);
    Test.assert(state.eventCount == 0 && state.lastEventTime == null && state.gameStartTime == null);
    TestKit.assertSameState(ScoringEngine.replay(config, []), state, "replay of no events");
    // The engine keeps its own copy of the format, and there's nothing to undo.
    config.deuceMode = DEUCE_SILVER;
    Test.assertEqual(engine.getConfig().deuceMode, DEUCE_GOLDEN);
    Test.assert(engine.undo() == null);
    TestKit.assertSameState(engine.getState(), state, "undo with no events");
    return true;
}

(:test)
function scoringEngineReplayTest(logger as Logger) as Boolean {
    // A replay of the log gives the state the events added one by one give, every time, and leaves
    // the format and the log alone: a deuce mode change lives in the state only.
    var t = TestKit.T0;
    var config = new MatchConfig();
    var events = [
        new MatchEvent(EVENT_FIX_SERVING_TEAM, t, TEAM_THEM), new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 1, null),
        new MatchEvent(EVENT_POINT_US, t + 40, null), new MatchEvent(EVENT_POINT_US, t + 75, null),
        new MatchEvent(EVENT_POINT_THEM, t + 110, null), new MatchEvent(EVENT_SET_DEUCE_MODE, t + 130, DEUCE_SILVER),
        new MatchEvent(EVENT_POINT_US, t + 160, null), new MatchEvent(EVENT_FIX_SERVING_TEAM, t + 170, TEAM_US),
        new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 171, null), new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 172, null),
        new MatchEvent(EVENT_POINT_THEM, t + 200, null)
    ];
    var log = TestKit.logOf(events);
    var state = ScoringEngine.replay(config, log) as MatchState;
    Test.assertEqual(TestKit.game(state), "0-0 40-30");
    Test.assert(state.deuceMode == DEUCE_SILVER && state.servingTeam == TEAM_US && state.ourServer == PLAYER_PARTNER);
    Test.assert(state.eventCount == 11 && state.lastEventTime == t + 200 && !state.matchOver);
    TestKit.assertSameState(ScoringEngine.replay(config, log), state, "second replay");
    Test.assert(config.equals(new MatchConfig()) && log.size() == 22);
    var engine = new ScoringEngine(config);
    for (var i = 0; i < events.size(); i++) {
        Test.assert(engine.add(events[i]));
    }
    TestKit.assertSameState(engine.getState(), state, "incremental");
    return true;
}

(:test)
function scoringEngineRefusedEventsTest(logger as Logger) as Boolean {
    // A refused event changes nothing and canAdd() says so beforehand: an invalid event, a change that
    // changes nothing (it could never be undone visibly), a swap in singles, anything once the match
    // is over (TestKit.checkRefused()).
    var t = TestKit.T0;
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "u");
    var refused = [new MatchEvent(EVENT_SET_DEUCE_MODE, t, DEUCE_STAR), new MatchEvent(EVENT_FIX_SERVING_TEAM, t, TEAM_US)];
    refused.addAll(TestKit.invalidEvents());
    for (var i = 0; i < refused.size(); i++) {
        TestKit.checkRefused(engine, refused[i], "event " + i);
    }
    var singles = new MatchConfig();
    singles.doubles = false;
    engine = new ScoringEngine(singles);
    TestKit.checkRefused(engine, new MatchEvent(EVENT_SWAP_OUR_SERVER, t, null), "singles swap");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.add(engine, EVENT_SET_DEUCE_MODE, DEUCE_ADVANTAGE);
    return true;
}

(:test)
function scoringEngineUndoEveryEventTypeTest(logger as Logger) as Boolean {
    // Undo removes the last event whatever its type and gives it back for the toast. Each
    // event is undone right after it's added, then the whole log is undone from the end.
    var config = new MatchConfig();
    var events = TestKit.oneOfEachType();
    var engine = new ScoringEngine(config);
    var states = [engine.getState().copy()];
    var typeSeen = [false, false, false, false, false, false, false];
    for (var i = 0; i < events.size(); i++) {
        TestKit.checkUndo(engine, events[i], "event " + i + " " + events[i]);
        Test.assert(engine.add(events[i]));
        states.add(engine.getState().copy());
        typeSeen[events[i].type] = true;
    }
    Test.assertEqual(typeSeen.indexOf(false), -1);
    for (var i = events.size() - 1; i >= 0; i--) {
        var undone = engine.undo();
        Test.assertMessage(undone != null && undone.equals(events[i]), "undid " + undone + ", not " + events[i]);
        Test.assertEqual(engine.getLog().size(), i * ScoringEngine.LOG_NUMBERS_PER_EVENT);
        TestKit.assertSameState(engine.getState(), states[i], "after undoing event " + i);
        TestKit.assertMatchesReplay(engine, "after undoing event " + i);
    }
    Test.assert(engine.undo() == null);
    TestKit.assertSameState(engine.getState(), ScoringEngine.newState(config), "start of the match");
    return true;
}

(:test)
function scoringEngineUndoToStartTest(logger as Logger) as Boolean {
    // Unlimited undo: 300 events, more points than a long three-set match, undone one by one back to
    // the start, each giving back the exact state before it. Alternating points with Advantage stay at
    // deuce, so the game never ends.
    var t = TestKit.T0;
    var engine = new ScoringEngine(TestKit.withMode(DEUCE_ADVANTAGE));
    var count = 300;
    var states = [engine.getState().copy()];
    for (var i = 0; i < count; i++) {
        Test.assert(engine.add(new MatchEvent(i % 2 == 0 ? EVENT_POINT_US : EVENT_POINT_THEM, t + 30 * i, null)));
        states.add(engine.getState().copy());
    }
    TestKit.assertMatchesReplay(engine, "long log");
    for (var i = count - 1; i >= 0; i--) {
        var undone = engine.undo();
        Test.assert(undone != null && (undone as MatchEvent).time == t + 30 * i);
        TestKit.assertSameState(engine.getState(), states[i], "after undoing event " + i);
    }
    Test.assert(engine.undo() == null && engine.getLog().size() == 0);
    return true;
}

(:test)
function scoringEngineServeSetUpTest(logger as Logger) as Boolean {
    // The log holds only the serve's set-up while it's empty or every event in it is FIX_SERVING_TEAM or
    // SWAP_OUR_SERVER (the "Who serves first?" answers, a correction before anything else). An event of
    // any other type ends it, a score edit too, the serve events after it included, until it's undone.
    var t = TestKit.T0;
    var engine = new ScoringEngine(new MatchConfig());
    Test.assert(engine.isServeSetUpOnly());
    Test.assert(engine.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, t, TEAM_THEM)));
    Test.assert(engine.add(new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 1, null)));
    Test.assert(engine.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, t + 2, TEAM_US)));
    Test.assert(engine.isServeSetUpOnly());
    var others = [new MatchEvent(EVENT_POINT_US, t + 10, null), new MatchEvent(EVENT_POINT_THEM, t + 10, null),
        new MatchEvent(EVENT_SET_DEUCE_MODE, t + 10, DEUCE_GOLDEN), new MatchEvent(EVENT_END_SET, t + 10, TEAM_US),
        new MatchEvent(EVENT_END_MATCH, t + 10, null), MatchEvent.editScore(t + 10, TestKit.edit("| 2-1 2-1"))];
    for (var i = 0; i < others.size(); i++) {
        Test.assertMessage(engine.add(others[i]), "add " + others[i]);
        Test.assertMessage(!engine.isServeSetUpOnly(), "after " + others[i]);
        if (!engine.getState().matchOver) {
            Test.assert(engine.add(new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 20, null)));
            Test.assertMessage(!engine.isServeSetUpOnly(), "serve event after " + others[i]);
            engine.undo();
        }
        engine.undo();
        Test.assertMessage(engine.isServeSetUpOnly(), "undone " + others[i]);
    }
    return true;
}

(:test)
function scoringEngineTieBreakOnlyUndoResumeTest(logger as Logger) as Boolean {
    // Tie-break only undoes and resumes like any match. A tie-break to 10 won
    // 22-20, 44 events, past an undo snapshot: resumed from its log with the format read back from its
    // stored form, in one go and a step at a time, it is the same match; undone back to the serve
    // answers, each undo gives back the state before it, the first one reopening the match at its match
    // point.
    var config = TestKit.preset(PRESET_TIE_BREAK_10);
    var engine = TestKit.newMatch(config, "Partner");
    var moves = TestKit.repeat("ut", 20) + "uu";
    var states = [] as Array<MatchState>;
    for (var i = 0; i < moves.length(); i++) {
        states.add(engine.getState().copy());
        TestKit.play(engine, moves.substring(i, i + 1) as String);
    }
    var state = engine.getState();
    Test.assert(state.matchOver && state.getScoreText().equals("22-20") && state.getResult() == RESULT_WIN
        && state.eventCount == 44);
    var stored = MatchConfig.fromDictionary(config.toDictionary()) as MatchConfig;
    Test.assert(stored.getPreset() == PRESET_TIE_BREAK_10);
    var restored = ScoringEngine.restore(stored, engine.getLog());
    Test.assert(restored != null);
    TestKit.assertSameState((restored as ScoringEngine).getState(), state, "restored");
    var steps = new ScoringEngine(stored);
    var left = steps.addFromLog(engine.getLog(), 7) as Number?;
    while (left != null && left > 0) {
        left = steps.addFromLog(engine.getLog(), 7);
    }
    Test.assert(left == 0);
    TestKit.assertSameState(steps.getState(), state, "a step at a time");
    for (var i = moves.length() - 1; i >= 0; i--) {
        Test.assert(engine.undo() != null);
        TestKit.assertSameState(engine.getState(), states[i], "undo " + i);
        if (i == moves.length() - 1) {
            TestKit.check(engine, TestKit.VIEW_SITUATION, "MATCH POINT pressure | CHANGE ENDS AT 42 | set U, match U, tie-break",
                "match point undone");
        }
    }
    Test.assertEqual(engine.getState().eventCount, 2);
    return true;
}

(:test)
function scoringEngineStoredLogTest(logger as Logger) as Boolean {
    // The log is kept as it's stored: two Numbers per event, its code and its time, oldest
    // first (a score edit spans more, EditScoreTest). Logs stored by earlier versions must keep
    // loading: this one is Opponents serve first, Partner first for us, Golden Point from the next game,
    // 1-1 in points, a set ended level and given to them, the end of the match.
    var events = TestKit.oneOfEachType();
    var engine = new ScoringEngine(new MatchConfig());
    for (var i = 0; i < events.size(); i++) {
        Test.assert(engine.add(events[i]));
    }
    Test.assertEqual(ScoringEngine.LOG_NUMBERS_PER_EVENT, 2);
    Test.assertEqual(engine.getLog().toString(), TestKit.logOf(events).toString());
    Test.assert(engine.getEvent(3).equals(events[3]));

    var t = TestKit.T0;
    var stored = [203, t, 2, t + 1, 204, t + 5, 0, t + 40, 1, t + 70, 205, t + 95, 6, t + 100];
    engine = ScoringEngine.restore(new MatchConfig(), stored) as ScoringEngine;
    var state = engine.getState();
    Test.assert(state.servingTeam == TEAM_THEM && state.ourServer == PLAYER_PARTNER && state.deuceMode == DEUCE_GOLDEN);
    Test.assertEqual(TestKit.sets(state), "0-0ET | 0-0 0-0 over");
    Test.assert(state.pointsWon[TEAM_US] == 1 && state.pointsWon[TEAM_THEM] == 1 && state.matchOver);
    Test.assert(state.eventCount == 7 && state.lastEventTime == t + 100);
    return true;
}

(:test)
function scoringEngineRejectsBadLogTest(logger as Logger) as Boolean {
    // Whatever is in storage, a log the engine would never have built gives null, never a crash, so
    // resume offers Discard only: not two Numbers per event, a bad event anywhere, an event
    // the engine refuses (after the end of the match, a change that changes nothing, End set now
    // naming a team when one leads or none when level, a swap in singles).
    var t = TestKit.T0;
    var config = new MatchConfig();
    var game = TestKit.logOf([new MatchEvent(EVENT_POINT_US, t, null), new MatchEvent(EVENT_POINT_US, t, null),
        new MatchEvent(EVENT_POINT_US, t, null), new MatchEvent(EVENT_POINT_US, t, null)]);
    var bad = [
        null, 0, "log", {}, {0 => t}, [0], [0, t, 1], [[0, t]], [[0, t], [1, t]],
        [7, t, 0, t], [0, t, 1, null], [0, t, 1, t.toLong()], [0, t, 3, t], [0, t, 1, -1],
        [6, t, 0, t], [6, t, 6, t], [304, t], [103, t, 103, t], [5, t], game.slice(0, null).addAll([105, t]),
        game.slice(0, null).addAll([205, t])
    ] as Array<Object?>;
    for (var i = 0; i < bad.size(); i++) {
        Test.assertMessage(ScoringEngine.replay(config, bad[i]) == null, "replayed " + bad[i]);
        Test.assertMessage(ScoringEngine.restore(config, bad[i]) == null, "restored " + bad[i]);
    }
    Test.assertEqual(TestKit.sets(ScoringEngine.replay(config, game.slice(0, null).addAll([5, t])) as MatchState), "1-0EU | 0-0 0-0");
    var swap = [2, t];
    Test.assert(ScoringEngine.replay(config, swap) != null);
    config.doubles = false;
    Test.assert(ScoringEngine.replay(config, swap) == null);
    return true;
}

(:test)
function scoringEngineTimestampsTest(logger as Logger) as Boolean {
    // The engine never reads the clock: each event brings its time, kept as recorded, even when the
    // watch's clock was set back or two presses fall in the same second.
    var t = TestKit.T0;
    var engine = new ScoringEngine(new MatchConfig());
    var times = [t + 100, t + 60, t + 60];
    for (var i = 0; i < times.size(); i++) {
        Test.assert(engine.add(new MatchEvent(EVENT_POINT_US, times[i], null)));
        Test.assert(engine.getState().lastEventTime == times[i]);
    }
    engine.undo();
    engine.undo();
    Test.assert(engine.getState().lastEventTime == t + 100);
    engine.undo();
    Test.assert(engine.getState().lastEventTime == null);
    return true;
}

(:test)
function matchStateCopyAndEqualsTest(logger as Logger) as Boolean {
    // Every field counts in equals(), which every same-state check relies on, and a copy has its own
    // arrays, finished sets and stats.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "Me");
    TestKit.play(engine, "UTUTUTUTUTUT uuuuuuu UUUUUT tt");
    var busy = engine.getState().copy();
    busy.deuceMode = DEUCE_SILVER;
    busy.servingTeam = TEAM_THEM;
    busy.ourServer = PLAYER_PARTNER;
    var text = busy.toString();
    Test.assert(busy.copy().equals(busy) && !busy.equals(null) && !busy.equals("state"));
    for (var i = 0; i < 25; i++) {
        var copy = busy.copy();
        if (i == 0) { copy.pointsWon[TEAM_US] += 1; }
        else if (i == 1) { copy.pointsWon[TEAM_THEM] += 1; }
        else if (i == 2) { copy.gamePoints[TEAM_US] += 1; }
        else if (i == 3) { copy.gamePoints[TEAM_THEM] += 1; }
        else if (i == 4) { copy.games[TEAM_US] += 1; }
        else if (i == 5) { copy.games[TEAM_THEM] += 1; }
        else if (i == 6) { copy.deuceMode = DEUCE_ADVANTAGE; }
        else if (i == 7) { copy.gameDeuceMode = DEUCE_SILVER; }
        else if (i == 8) { copy.servingTeam = TEAM_US; }
        else if (i == 9) { copy.servingTeam = null; }
        else if (i == 10) { copy.ourServer = PLAYER_ME; }
        else if (i == 11) { copy.matchOver = true; }
        else if (i == 12) { copy.eventCount += 1; }
        else if (i == 13) { copy.lastEventTime = null; }
        else if (i == 14) { copy.gameStartTime = null; }
        else if (i == 15) { copy.gameType = GAME_TIE_BREAK; }
        else if (i == 16) { copy.setScores.add(new SetScore([6, 0], null, false, TEAM_US, false)); }
        else if (i == 17) { copy.setScores[0].games[TEAM_US] += 1; }
        else if (i == 18) { copy.setScores[0].winner = TEAM_THEM; }
        else if (i == 19) { copy.doubles = false; }
        else if (i == 20) { copy.serverChanged = !copy.serverChanged; }
        else if (i == 21) { copy.changeOfEnds = !copy.changeOfEnds; }
        else if (i == 22) { copy.finishedGames.add(0); }
        else if (i == 23) { copy.finishedGames[0] = 11; }
        else { copy.tally.gameEnded(copy, 0, TestKit.T0, TestKit.T0); }
        Test.assertMessage(!copy.equals(busy) && !busy.equals(copy), "field " + i);
    }
    Test.assertEqual(busy.toString(), text);
    return true;
}

(:test)
function matchStatePackTest(logger as Logger) as Boolean {
    // The undo snapshots' form: every value of the state, without its lists: unpack() takes the finished
    // sets from the list the snapshot keeps (it only grows until an edit replaces it), the others from a
    // later state of the match, as its own copies.
    var engine = TestKit.newMatch(new MatchConfig(), "Opponents Partner");
    TestKit.play(engine, "UTUTUTUTUTUT uuu");
    var state = engine.getState().copy();
    TestKit.assertSameState(MatchState.unpack(state.pack(), state.setScores, state), state, "unpacked");
    var sets = engine.getState().setScores;
    TestKit.play(engine, "uuuu UU tt");
    var later = engine.getState();
    var unpacked = MatchState.unpack(state.pack(), sets, later);
    TestKit.assertSameState(unpacked, state, "unpacked from a later state");
    later.finishedGames.add(1);
    Test.assertEqual(unpacked.finishedGames.size(), 12);
    Test.assert(state.pack().size() < 60);
    var start = ScoringEngine.newState(new MatchConfig());
    TestKit.assertSameState(MatchState.unpack(start.pack(), start.setScores, state), start, "new state");
    return true;
}

(:test)
function scoringEngineLogArrayTest(logger as Logger) as Boolean {
    // The log is never copied whole: its array grows ahead (64, then twice the log, up
    // to LOG_MAX: a copy of the log each time, so it ends early in a long match), an undo shortens it in
    // place and the next events write over what it took off, and getLog() gives exactly the log
    // (getLogSize(), getLogPart()). getLogKept() says how much of the log is as it was at markLog(). A
    // resume can take the stored array as it is (takeLog()): the same match, the log not held twice, and
    // room for the next events added at once.
    Test.assert(ScoringEngine.capacityFor(0) == 64 && ScoringEngine.capacityFor(31) == 64 && ScoringEngine.capacityFor(64) == 128
        && ScoringEngine.capacityFor(3000) == 6000 && ScoringEngine.capacityFor(3100) == ScoringEngine.LOG_MAX
        && ScoringEngine.capacityFor(ScoringEngine.LOG_MAX) == ScoringEngine.LOG_MAX + ScoringEngine.LOG_NUMBERS_PER_EVENT);
    var config = new MatchConfig();
    var played = TestKit.newMatch(config, "Me");
    TestKit.play(played, "UTUTUT uut");
    var log = played.getLog().slice(0, null);
    Test.assert(played.getLogSize() == log.size() && log.size() == 2 * played.getState().eventCount);
    Test.assertEqual(played.getLogPart(4, 8).toString(), log.slice(4, 8).toString());
    Test.assertEqual(played.getLogPart(log.size() - 2, log.size() + 50).toString(), log.slice(log.size() - 2, null).toString());
    played.markLog();
    Test.assertEqual(played.getLogKept(), log.size());
    // Undo, then other events: the log is exactly the new one, the kept part ends at the undo.
    TestKit.play(played, "<<<");
    Test.assert(played.getLogSize() == log.size() - 6 && played.getLogKept() == log.size() - 6);
    TestKit.play(played, "tt");
    Test.assertEqual(played.getLog().size(), log.size() - 2);
    Test.assertEqual(played.getLog().slice(0, log.size() - 6).toString(), log.slice(0, log.size() - 6).toString());
    TestKit.assertMatchesReplay(played, "after undos");
    // Taken as it is: the same match, its next events added after it.
    var stored = played.getLog().slice(0, null);
    var taken = new ScoringEngine(config);
    taken.takeLog(stored);
    var left = taken.addFromLog(stored, 3) as Number;
    while (left > 0) {
        left = taken.addFromLog(stored, 3) as Number;
    }
    TestKit.assertSameState(taken.getState(), played.getState(), "taken");
    Test.assert(stored.size() == ScoringEngine.capacityFor(played.getLogSize()) && taken.getLogSize() == played.getLogSize());
    Test.assertEqual(taken.getLog().toString(), played.getLog().toString());
    TestKit.play(taken, "uuuu");
    TestKit.play(played, "uuuu");
    Test.assertEqual(taken.getLog().toString(), played.getLog().toString());
    TestKit.assertMatchesReplay(taken, "taken, then played");
    // Released after a save: no log, no undo, the state as it was.
    var state = taken.getState();
    taken.release();
    Test.assert(taken.getLogSize() == 0 && taken.getLog().size() == 0 && taken.getState() == state);
    return true;
}

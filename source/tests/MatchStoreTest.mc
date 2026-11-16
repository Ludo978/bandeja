import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// The match being played, in Application.Storage: its format, its log, its start and Indoor
// / Outdoor, read back as they were saved, and anything else read as no match rather than a crash.
// The tests put the simulator's stored values back when they're done.

(:test)
function matchStoreRoundTripTest(logger as Logger) as Boolean {
    // The stored form gives back the format, the start, Indoor / Outdoor and the log, so the same
    // state: here a custom format, a tie-break and undos. Saved, then loaded as the app does at launch
    // (it stays stored: it goes only at exit), cleared at exit (Save or Discard).
    var config = TestKit.custom();
    config.hasTieBreak = true;
    var engine = new ScoringEngine(config);
    TestKit.play(engine, "UTUTUT ttt<<");
    for (var outdoor = 0; outdoor < 2; outdoor++) {
        var match = MatchStore.fromValue(MatchStore.toValue(engine, TestKit.T0, outdoor == 1, null)) as StoredMatch;
        Test.assert(match.engine.getConfig().equals(config) && match.start == TestKit.T0 && match.outdoor == (outdoor == 1));
        Test.assertEqual(match.engine.getLog().toString(), engine.getLog().toString());
        TestKit.assertSameState(match.engine.getState(), engine.getState(), "outdoor " + outdoor);
    }
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        MatchStore.clear();
        Test.assert(!MatchStore.isStored() && TestKit.loadStored() == null);
        MatchStore.save(engine, TestKit.T0, true, null);
        var loaded = TestKit.loadStored() as StoredMatch;
        TestKit.assertSameState(loaded.engine.getState(), engine.getState(), "loaded");
        Test.assert(loaded.outdoor && MatchStore.isStored());
        MatchStore.clear();
        Test.assert(!MatchStore.isStored() && TestKit.loadStored() == null);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function matchStoreBadDataTest(logger as Logger) as Boolean {
    // Whatever is stored, a bad or partial match reads as null, never a crash: the prompt
    // then offers Discard only. Directly and through storage.
    var t = TestKit.T0;
    var config = TestKit.storedBestOf3();
    var good = TestKit.storedValue(config, t, false, [0, t, 1, t + 30]);
    Test.assert(MatchStore.fromValue(good) != null);
    var badConfig = TestKit.storedBestOf3();
    badConfig.put("tieBreakAt", 4);
    var values = [
        null, 42, "match", [], {},
        // A key missing.
        MatchStoreTests.without(good, "config"), MatchStoreTests.without(good, "start"),
        MatchStoreTests.without(good, "outdoor"), MatchStoreTests.without(good, "log"),
        // A key of the wrong type, or an invalid format.
        TestKit.storedValue("Best of 3", t, false, []), TestKit.storedValue(badConfig, t, false, []),
        TestKit.storedValue(config, t.toString(), false, []), TestKit.storedValue(config, t.toFloat(), false, []),
        TestKit.storedValue(config, t, 1, []), TestKit.storedValue(config, t, false, "0,1"),
        // A log that doesn't replay: half an event, an unknown event, one the engine refuses.
        TestKit.storedValue(config, t, false, [0, t, 1]), TestKit.storedValue(config, t, false, [0, t, 7, t]),
        TestKit.storedValue(config, t, false, [6, t, 0, t])
    ] as Array<Object?>;
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        for (var i = 0; i < values.size(); i++) {
            Test.assertMessage(MatchStore.fromValue(values[i]) == null, "read " + values[i]);
            if (i > 0) {
                Application.Storage.setValue(MatchStore.KEY, values[i] as Application.Storage.ValueType);
                Test.assertMessage(MatchStore.isStored() && TestKit.loadStored() == null, "loaded " + values[i]);
            }
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function matchStoreReplayGuardTest(logger as Logger) as Boolean {
    // A replay that ends the app (the watchdog or the memory, which no try/catch catches) leaves its
    // mark: the next launch reads the match as bad, so it offers Discard only and never replays it
    // again (no crash loop). A replay that ends removes the mark; Discard clears both.
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        var engine = new ScoringEngine(new MatchConfig());
        TestKit.play(engine, "U");
        MatchStore.save(engine, TestKit.T0, false, null);
        Test.assert(TestKit.loadStored() != null && Application.Storage.getValue(MatchStore.REPLAY_KEY) == null);
        Application.Storage.setValue(MatchStore.REPLAY_KEY, true);
        Test.assert(MatchStore.isStored() && TestKit.loadStored() == null && TestKit.loadStored() == null);
        MatchStore.clear();
        Test.assert(Application.Storage.getValue(MatchStore.REPLAY_KEY) == null && !MatchStore.isStored());
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function matchStoreLongLoadTest(logger as Logger) as Boolean {
    // The launch replay of a 1,000-event match runs MatchLoad.STEP_EVENTS events a step, each within the
    // watchdog's limit, the replay mark set from the start to the end: the same match as
    // a replay in one go. Left before the end (BACK, the app stopped), the mark goes, so the next launch
    // replays it again. The debug build's long stored matches (DebugMenu): Best of 3 with Advantage, Me
    // serving first, the asked number of events, every one accepted, into the third set.
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        var events = 1000;
        var start = TestKit.T0;
        var log = DebugMenu.longLog(events, start);
        Application.Storage.setValue(MatchStore.KEY,
            TestKit.storedValue(DebugMenu.longConfig().toDictionary(), start, false, log) as Application.Storage.ValueType);
        var load = MatchStore.startLoad();
        var steps = 0;
        var progress = 0.0;
        while (!load.step()) {
            steps++;
            Test.assert(Application.Storage.getValue(MatchStore.REPLAY_KEY) != null && load.getProgress() > progress);
            progress = load.getProgress();
        }
        Test.assertEqual(steps + 1, (events + MatchLoad.STEP_EVENTS - 1) / MatchLoad.STEP_EVENTS);
        Test.assert(Application.Storage.getValue(MatchStore.REPLAY_KEY) == null && load.getProgress() == 1.0);
        var stored = load.getStored() as StoredMatch;
        Test.assert(stored.start == start && !stored.outdoor);
        TestKit.assertSameState(stored.engine.getState(), ScoringEngine.replay(DebugMenu.longConfig(), log) as MatchState, "loaded");
        // Its stats, with the stored match start, equal the reference's: the average time per
        // point and the longest streak included.
        Test.assertEqual(TestKit.statsPoints(TestKit.computeStats(stored.engine, stored.start)), "per point 30 s, streak 4");
        load = MatchStore.startLoad();
        Test.assert(!load.step());
        MatchStore.endLoad();
        Test.assert(Application.Storage.getValue(MatchStore.REPLAY_KEY) == null && TestKit.loadStored() != null);
    } finally {
        TestKit.restore(keys, saved);
    }
    var counts = DebugMenu.LONG_EVENTS;
    for (var i = 0; i < counts.size(); i++) {
        var log = DebugMenu.longLog(counts[i], TestKit.T0);
        var state = ScoringEngine.replay(DebugMenu.longConfig(), log) as MatchState;
        Test.assertMessage(state.eventCount == counts[i] && state.setScores.size() == 2 && !state.matchOver
            && state.getSetsWon(TEAM_US) == 1, counts[i] + " events");
        Test.assertEqual(log[log.size() - 1], TestKit.T0 + 30 * (counts[i] - 1));
    }
    return true;
}

(:test)
module MatchStoreTests {

    // The stored match is engine's, its log in parts full parts and a rest of rest Numbers.
    function checkStored(engine as ScoringEngine, parts as Number, rest as Number, message as String) as Void {
        var value = Application.Storage.getValue(MatchStore.KEY) as Dictionary;
        var stored = value.get("parts") as Number?;
        var size = (value.get("log") as Array).size();
        Test.assertMessage(stored == parts && size == rest, message + ": " + stored + " parts, " + size);
        for (var part = 0; part < parts; part++) {
            var numbers = Application.Storage.getValue(MatchStore.PART_KEY + part) as Array;
            Test.assertMessage(numbers.size() == MatchStore.PART_NUMBERS, message + ": part " + part);
        }
        var log = MatchStore.readLog(parts, value.get("log") as Array);
        Test.assertMessage(log != null && log.toString().equals(engine.getLog().toString()), message + ": log");
    }

    function without(value as Dictionary<String, Object?>, key as String) as Dictionary<String, Object?> {
        var other = {} as Dictionary<String, Object?>;
        var keys = value.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (!keys[i].equals(key)) {
                other.put(keys[i], value.get(keys[i]));
            }
        }
        return other;
    }
}

(:test)
function matchStorePartsTest(logger as Logger) as Boolean {
    // A long log is stored in parts: its full parts of PART_NUMBERS Numbers under
    // PART_KEY + their index, "parts" saying how many, and the rest under "log", so a write takes about a
    // part at most. Each write gives the same match back. An undo back into a stored part, then other
    // events: that part is written again (here with a write in between, then without one). Clear removes
    // every part. A part missing or of the wrong size, or too many parts, reads as no match.
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    var p = MatchStore.PART_NUMBERS;
    try {
        MatchStore.clear();
        var config = DebugMenu.freePlayConfig();
        var engine = ScoringEngine.restore(config, DebugMenu.freePlayLog(1100, TestKit.T0)) as ScoringEngine;
        MatchStore.save(engine, TestKit.T0, false, null);
        MatchStoreTests.checkStored(engine, 2, 200, "1,100 events");
        TestKit.play(engine, "u");
        MatchStore.save(engine, TestKit.T0, false, null);
        MatchStoreTests.checkStored(engine, 2, 202, "a point");
        // Back into the second part, written, then on with other events.
        TestKit.undoTo(engine, 999);
        MatchStore.save(engine, TestKit.T0, false, null);
        MatchStoreTests.checkStored(engine, 1, 998, "undone into part 2");
        TestKit.play(engine, "tttt");
        MatchStore.save(engine, TestKit.T0, false, null);
        MatchStoreTests.checkStored(engine, 2, 6, "on again");
        // The same without a write between the undo and the next events, loaded as at a launch.
        TestKit.undoTo(engine, 998);
        TestKit.play(engine, "uuuuu");
        MatchStore.save(engine, TestKit.T0, false, null);
        MatchStoreTests.checkStored(engine, 2, 6, "undone and on again");
        var loaded = TestKit.loadStored() as StoredMatch;
        TestKit.assertSameState(loaded.engine.getState(), engine.getState(), "loaded");
        MatchStore.loaded(engine, 2);
        // A short match: one value, no parts, as before.
        var short = TestKit.matchOf(config, "Me", "UTU");
        MatchStore.save(short, TestKit.T0, true, null);
        var value = Application.Storage.getValue(MatchStore.KEY) as Dictionary;
        var log = value.get("log") as Array;
        Test.assert((value.get("parts") as Object?) == null && log.toString().equals(short.getLog().toString()));
        // Bad parts.
        MatchStore.save(engine, TestKit.T0, false, null);
        Application.Storage.setValue(MatchStore.PART_KEY + 1, [1, 2]);
        Test.assert(TestKit.loadStored() == null);
        Application.Storage.deleteValue(MatchStore.PART_KEY + 1);
        Test.assert(TestKit.loadStored() == null);
        value = Application.Storage.getValue(MatchStore.KEY) as Dictionary;
        value.put("parts", MatchStore.PARTS_MAX + 1);
        Test.assert(MatchStore.fromValue(value) == null);
        MatchStore.clear();
        for (var part = 0; part <= MatchStore.PARTS_MAX; part++) {
            Test.assert(Application.Storage.getValue(MatchStore.PART_KEY + part) == null);
        }
        Test.assert(!MatchStore.isStored() && p == 1000);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// The history: the last 20 saved matches, newest first, in one Application.Storage value,
// each record holding what its summary shows (never the event log), read back as it was written, and
// anything else skipped rather than a crash. The tests put the simulator's stored history back when
// they're done.

(:test)
function historyRoundTripTest(logger as Logger) as Boolean {
    // Each match's record, written to storage and read back, gives the same summary, page by page (the
    // header, the sets score, the table, every stat), the same stats, its date and its format: won, lost,
    // a super tie-break, a tie-break set, a draw after End match, End set now ending the match, best of 5,
    // a custom format in singles with serve tracking off, and a match saved mid-set from the pause menu
    // (unfinished); with every activity value, none, and some.
    var cases = [
        [new MatchConfig(), "Me", "UUUUUU UUUUUT uuuu", null, null, "WIN 2 - 0 | SET1 6-0 US, SET2 6-1 US"],
        [new MatchConfig(), "Opponents Partner", "UUUUUU TTTTTT TTTTTT", null, null,
            "LOSS 1 - 2 | SET1 6-0 US, SET2 0-6 THEM, SET3 0-6 THEM"],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "Me", "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt u", null, null,
            "WIN 2 - 1 | SET1 6-4 US, SET2 3-6 THEM, STB 10-8 US"],
        [new MatchConfig(), "Partner", "UTUTUTUTUTUT uuuuuuu UUUUUU", null, null, "WIN 2 - 0 | SET1 7-6 US, SET2 6-0 US"],
        [new MatchConfig(), "", "UUUUUU TTTTTT ut", EVENT_END_MATCH, null, "DRAW 1 - 1 | SET1 6-0 US, SET2 0-6 THEM, SET3 0-0 *"],
        [new MatchConfig(), "Opponents Me", "TTTTTT UTUTUT", EVENT_END_SET, TEAM_THEM, "LOSS 0 - 2 | SET1 0-6 THEM, SET2 3-3 THEM"],
        [TestKit.format(3, 6, 6, true), "Partner", "UUUUUU TTTTTT UUUUUU TTTTTT UUUUUU", null, null,
            "WIN 3 - 2 | SET1 6-0 US, SET2 0-6 THEM, SET3 6-0 US, SET4 0-6 THEM, SET5 6-0 US"],
        [TestKit.custom(), "", "UUUU TTTT UUUU TTTT uuuuuuuuuu", null, null,
            "WIN 3 - 2 | SET1 4-0 US, SET2 0-4 THEM, SET3 4-0 US, SET4 0-4 THEM, STB 10-0 US"],
        [new MatchConfig(), "Me", "UTUTUTUTUU UTu", null, null, "UNFINISHED 1 - 0 | SET1 6-4 US, SET2 1-1 *"]
    ];
    var activities = [[5050, 148, 171, 905], SummaryTests.NO_ACTIVITY, [60, null, null, 0]] as Array<Array<Number?> >;
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        for (var i = 0; i < cases.size(); i++) {
            var c = cases[i];
            var config = c[0] as MatchConfig;
            var rig = new TestKit.Rig(config, c[1] as String, false);
            rig.play(c[2] as String);
            if (c[3] != null) {
                rig.add(c[3] as EventType, c[4] as Team?);
            }
            var record = HistoryRecord.of(rig.match, activities[i % activities.size()]);
            var shown = SummaryTests.text(new SummaryModel(record));
            Test.assertEqualMessage(shown.substring(0, (c[5] as String).length()) as String, c[5], "case " + i);
            Application.Storage.setValue(HistoryStore.KEY, [record.toValue()]);
            var loaded = HistoryStore.load();
            Test.assertEqualMessage(loaded.size(), 1, "case " + i);
            var back = loaded[0];
            Test.assertMessage(back.start == rig.match.start && back.config.equals(config) && back.result == rig.getState().getResult(),
                "case " + i);
            Test.assertEqualMessage(SummaryTests.text(new SummaryModel(back)), shown, "case " + i);
            Test.assertEqualMessage(HistoryTests.statsText(back.stats), HistoryTests.statsText(record.stats), "case " + i);
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historyOrderTest(logger as Logger) as Boolean {
    // Newest first. Up to 20 matches all stay; the 21st drops the oldest, and each one after it the
    // oldest left: the last 20 saved.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        Test.assertEqual(HistoryStore.load().size(), 0);
        var record = HistoryTests.record(new MatchConfig(), "UUUUUU UUUUUT uuuu");
        var hour = 3600;
        for (var i = 0; i < 25; i++) {
            record.start = TestKit.T0 + hour * i;
            HistoryStore.add(record);
            if (i == 0 || i == 18 || i == 19 || i == 20 || i == 24) {
                var loaded = HistoryStore.load();
                var count = i < HistoryStore.MAX_RECORDS ? i + 1 : HistoryStore.MAX_RECORDS;
                Test.assertEqualMessage(loaded.size(), count, "after " + (i + 1));
                for (var j = 0; j < count; j++) {
                    Test.assertEqualMessage(loaded[j].start, TestKit.T0 + hour * (i - j), "after " + (i + 1) + ", record " + j);
                }
            }
        }
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historyNoPointTest(logger as Logger) as Boolean {
    // A match saved before its first point isn't kept: the serve answers only, End match at
    // 0-0, End set now at 0-0 with the set given (still no point). One point is enough to keep it.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
        HistoryStore.add(HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY));
        rig.add(EVENT_END_MATCH, null);
        HistoryStore.add(HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY));
        rig = new TestKit.Rig(new MatchConfig(), "", false);
        rig.add(EVENT_END_SET, TEAM_US);
        HistoryStore.add(HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY));
        HistoryStore.add(new HistoryRecord(TestKit.T0, new MatchConfig(), RESULT_DRAW, [] as Array<SummaryRow>, null,
            SummaryTests.NO_ACTIVITY));
        Test.assert(HistoryStore.read() == null && HistoryStore.load().size() == 0);
        rig = new TestKit.Rig(new MatchConfig(), "", false);
        rig.play("t");
        rig.add(EVENT_END_MATCH, null);
        HistoryStore.add(HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY));
        var loaded = HistoryStore.load();
        Test.assert(loaded.size() == 1 && loaded[0].result == RESULT_LOSS);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historyBadDataTest(logger as Logger) as Boolean {
    // Whatever is stored, a record that can't be read is skipped, never a crash: a key missing or of the
    // wrong type, an invalid format, a result, a row, a stat or an activity value out of place. A stored
    // history that isn't a list reads as empty. The next save drops what can't be read and keeps the rest,
    // in order.
    var record = HistoryTests.record(new MatchConfig(), "UUUUUU UUUUUT uuuu");
    var good = record.toValue() as Dictionary<String, Object?>;
    record.start = TestKit.T0 - 86400;
    var older = record.toValue() as Dictionary<String, Object?>;
    var badConfig = TestKit.storedBestOf3();
    badConfig.put("tieBreakAt", 4);
    var stats = good.get("stats") as Array<Object?>;
    var bad = [
        null, 42, "match", [], {},
        MatchStoreTests.without(good, "start"), MatchStoreTests.without(good, "config"), MatchStoreTests.without(good, "result"),
        MatchStoreTests.without(good, "sets"), MatchStoreTests.without(good, "activity"),
        HistoryTests.with(good, "start", "today"), HistoryTests.with(good, "start", 1.5),
        HistoryTests.with(good, "config", "Best of 3"), HistoryTests.with(good, "config", badConfig),
        HistoryTests.with(good, "result", 4), HistoryTests.with(good, "result", -1), HistoryTests.with(good, "result", "WIN"),
        HistoryTests.with(good, "sets", "6-0 6-1"), HistoryTests.with(good, "sets", [6, 0, 0]),
        HistoryTests.with(good, "sets", [6, "0", 0, false]), HistoryTests.with(good, "sets", [6, 0, 2, false]),
        HistoryTests.with(good, "sets", [6, 0, 0, 1]), HistoryTests.with(good, "sets", [-1, 0, 0, false]),
        HistoryTests.with(good, "stats", "48-4"), HistoryTests.with(good, "stats", stats.slice(0, 25)),
        HistoryTests.with(good, "stats", HistoryTests.replaced(stats, 0, null)),
        HistoryTests.with(good, "stats", HistoryTests.replaced(stats, 12, null)),
        HistoryTests.with(good, "stats", HistoryTests.replaced(stats, 3, "1")),
        HistoryTests.with(good, "stats", HistoryTests.replaced(stats, 20, -2)),
        HistoryTests.with(good, "stats", HistoryTests.replaced(stats, 11, 42.0)),
        HistoryTests.with(good, "activity", [5050, 148, 171]), HistoryTests.with(good, "activity", [5050, 148.0, 171, 905]),
        HistoryTests.with(good, "activity", "1:24:10")
    ] as Array<Object?>;
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        Test.assert(HistoryRecord.fromValue(good) != null && HistoryRecord.fromValue(older) != null);
        for (var i = 0; i < bad.size(); i++) {
            Test.assertMessage(HistoryRecord.fromValue(bad[i]) == null, "read " + i + ": " + bad[i]);
        }
        var notLists = [42, "history", {}, good];
        for (var i = 0; i < notLists.size(); i++) {
            Application.Storage.setValue(HistoryStore.KEY, notLists[i] as Application.Storage.ValueType);
            Test.assertEqualMessage(HistoryStore.load().size(), 0, "stored " + i);
        }
        record.start = TestKit.T0 + 3600;
        HistoryStore.add(record);
        Test.assertEqual(HistoryStore.load().size(), 1);

        var list = [good] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < bad.size(); i++) {
            list.add(bad[i] as Application.Storage.ValueType);
        }
        list.add(older as Application.Storage.ValueType);
        Application.Storage.setValue(HistoryStore.KEY, list);
        var loaded = HistoryStore.load();
        Test.assert(loaded.size() == 2 && loaded[0].start == TestKit.T0 && loaded[1].start == TestKit.T0 - 86400);
        HistoryStore.add(record);
        Test.assertEqual((HistoryStore.read() as Array).size(), 3);
        loaded = HistoryStore.load();
        Test.assert(loaded.size() == 3 && loaded[0].start == TestKit.T0 + 3600 && loaded[1].start == TestKit.T0);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historyOlderVersionTest(logger as Logger) as Boolean {
    // A record as the first history version writes it, kept here as written, must keep loading in later versions: the format
    // in the form the first version stores it (MatchConfig.toDictionary()), the set table, the stats in their order and
    // the activity's values. Here the summary mockup's match, won 6-4 3-6 10-8 with every stat, and no
    // team names, which shows US / THEM. Team names, added later, are read (TeamNamesTest.mc); what a later
    // version adds is ignored: a key, a stat after the 26, a format key. A record with serve tracking
    // off, its serve stats null, shows them as --.
    var config = TestKit.storedBestOf3();
    config.put("superTieBreak", true);
    var stored = {
        "start" => TestKit.T0,
        "config" => config,
        "result" => 1,
        "sets" => [6, 4, 0, false, 3, 6, 1, false, 10, 8, 0, true],
        "stats" => [98, 91, 9, 10, 2, 1, 372, 7, 4, 2, 1, 42, 6, 100, 62, 100, 41, 10, 9, 1, 9, 3, 7, 3, 6, 4],
        "activity" => [5050, 148, 171, 905]
    } as Dictionary<String, Object?>;
    var expected = "WIN 2 - 1 | SET1 6-4 US, SET2 3-6 THEM, STB 10-8 US"
        + " | DURATION 1:24:10, AVG HR 148, POINTS 98-91, SERVE 62%"
        + " | MAX HR 171, KCAL 905, GAMES 9-10, BREAKS 3-1, DECIDING 4/7, TIE-BREAKS 1/2"
        + " | BP WON 3/7, BP SAVED 4/6, RETURN 41%, LONGEST 6:12, PER POINT 0:42, STREAK 6";
    var record = HistoryRecord.fromValue(stored) as HistoryRecord;
    Test.assert(record.start == TestKit.T0 && record.config.equals(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB)));
    Test.assert(record.names[TEAM_US] == null && record.names[TEAM_THEM] == null);
    Test.assertEqual(SummaryTests.text(new SummaryModel(record)), expected);
    Test.assertEqual(HistoryTests.statsText(record.stats), "points 98-91, games 9-10, sets 2-1, deciding 4/7, tie-breaks 1/2, longest 372"
        + ", per point 42 s, streak 6 | serve 62/100 62%, return 41/100 41%, held 9/10, conceded 1, broke 3/9, break points 3/7, saved 4/6");

    var later = HistoryTests.with(stored, "names", ["Ana & Bea", "Cris & Dani"]);
    Test.assert("Cris & Dani".equals((HistoryRecord.fromValue(later) as HistoryRecord).names[TEAM_THEM]));
    later.put("future", 1);
    var laterStats = (stored.get("stats") as Array<Object?>).slice(0, null);
    laterStats.add(5);
    later.put("stats", laterStats);
    var laterConfig = HistoryTests.with(config, "future", 2);
    later.put("config", laterConfig);
    Test.assertEqual(SummaryTests.text(new SummaryModel(HistoryRecord.fromValue(later) as HistoryRecord)), expected);

    var serveOff = [98, 91, 9, 10, 2, 1, 372, 7, 4, 2, 1, 42, 6] as Array<Object?>;
    for (var i = 0; i < 13; i++) {
        serveOff.add(null);
    }
    var off = HistoryRecord.fromValue(HistoryTests.with(stored, "stats", serveOff)) as HistoryRecord;
    Test.assertEqual(SummaryTests.text(new SummaryModel(off)), "WIN 2 - 1 | SET1 6-4 US, SET2 3-6 THEM, STB 10-8 US"
        + " | DURATION 1:24:10, AVG HR 148, POINTS 98-91, SERVE --"
        + " | MAX HR 171, KCAL 905, GAMES 9-10, BREAKS --, DECIDING 4/7, TIE-BREAKS 1/2"
        + " | BP WON --, BP SAVED --, RETURN --, LONGEST 6:12, PER POINT 0:42, STREAK 6");
    return true;
}

(:test)
function historyCapacityTest(logger as Logger) as Boolean {
    // 20 of the largest records fit the one value (32 KB): best of 5 with five rows of
    // two-digit scores, every stat and activity value given, plus two team names of 12 characters
    // (Settings.NAME_MAX), so the history has room for them (about 8 KB). A value over the
    // limit ends the run in the simulator (an Out Of Memory Error no try/catch catches), so this write
    // is the check. Through add() too, without the names. The run logs the memory 20 of them take once
    // read back.
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryStore.clear();
        var record = HistoryTests.largest();
        for (var i = 0; i < HistoryStore.MAX_RECORDS; i++) {
            record.start = TestKit.T0 + i;
            HistoryStore.add(record);
        }
        Test.assertEqual(HistoryStore.load().size(), HistoryStore.MAX_RECORDS);
        HistoryStore.clear();
        HistoryStore.write(HistoryTests.largestList(HistoryStore.MAX_RECORDS));
        var before = System.getSystemStats().usedMemory;
        var loaded = HistoryStore.load();
        var used = System.getSystemStats().usedMemory - before;
        Test.assertEqual(loaded.size(), HistoryStore.MAX_RECORDS);
        Test.assertEqual(SummaryTests.text(new SummaryModel(loaded[19])), SummaryTests.text(new SummaryModel(record)));
        loaded = [] as Array<HistoryRecord>;
        before = System.getSystemStats().usedMemory;
        var raw = HistoryStore.read();
        var rawUsed = System.getSystemStats().usedMemory - before;
        Test.assert(raw instanceof Array && (raw as Array).size() == HistoryStore.MAX_RECORDS);
        logger.debug("history: 20 of the largest records read back take " + used + " B as records, " + rawUsed
            + " B as stored values");
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function historyFixtureTest(logger as Logger) as Boolean {
    // The debug build's full history (HistoryFixtures): 20 records, newest first a day apart, each read
    // back as written, with every result (a win, a loss, a draw, a match saved unfinished).
    var records = HistoryFixtures.records(TestKit.T0);
    Test.assertEqual(records.size(), HistoryStore.MAX_RECORDS);
    var results = [] as Array<MatchResult>;
    for (var i = 0; i < records.size(); i++) {
        var back = HistoryRecord.fromValue(records[i].toValue());
        Test.assertMessage(back != null, "record " + i);
        Test.assertEqualMessage(SummaryTests.text(new SummaryModel(back as HistoryRecord)),
            SummaryTests.text(new SummaryModel(records[i])), "record " + i);
        Test.assert(i == 0 || records[i].start == records[i - 1].start - 86400);
        if (results.indexOf(records[i].result) < 0) {
            results.add(records[i].result);
        }
    }
    Test.assertEqual(results.size(), 4);
    var keys = GlanceTests.keys();
    var saved = TestKit.backup(keys);
    try {
        HistoryFixtures.fill();
        Test.assertEqual(HistoryStore.load().size(), HistoryStore.MAX_RECORDS);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
module HistoryTests {

    // The record of a match played with serve tracking (Me serving first), saved with no activity values.
    function record(config as MatchConfig, moves as String) as HistoryRecord {
        var rig = new TestKit.Rig(config, "Me", false);
        rig.play(moves);
        return HistoryRecord.of(rig.match, SummaryTests.NO_ACTIVITY);
    }

    // The largest record: best of 5, five sets with two-digit scores, every stat and activity value.
    function largest() as HistoryRecord {
        var config = TestKit.format(3, 6, 6, false);
        var rows = [] as Array<SummaryRow>;
        var scores = [[12, 10], [10, 12], [14, 12], [11, 13], [16, 14]];
        for (var i = 0; i < scores.size(); i++) {
            rows.add(new SummaryRow(i + 1, false, scores[i], scores[i][0] > scores[i][1] ? TEAM_US : TEAM_THEM));
        }
        var stats = SummaryTests.stats();
        stats.pointsWon = 1234;
        stats.pointsLost = 1198;
        stats.gamesWon = 63;
        stats.gamesLost = 61;
        stats.setsWon = 3;
        stats.setsLost = 2;
        stats.serviceGamesPlayed = 62;
        stats.serviceGamesHeld = 50;
        stats.returnGamesPlayed = 62;
        return new HistoryRecord(TestKit.T0, config, RESULT_WIN, rows, stats, [14400, 151, 188, 2345]);
    }

    // count of the largest records in their stored form, each its own value, with two names of 12 characters.
    function largestList(count as Number) as Array<Application.Storage.ValueType> {
        var record = largest();
        var list = [] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < count; i++) {
            record.start = TestKit.T0 + i;
            var value = record.toValue();
            value["names"] = ["Abcdefghijkl", "Mnopqrstuvwx"];
            list.add(value);
        }
        return list;
    }

    // The stats a record keeps, the longest game as its duration: "points 98-91, games 9-10, sets 2-1,
    // deciding 4/7, tie-breaks 1/2, longest 372, per point 42 s, streak 6 | serve ...", or "none".
    function statsText(m as MatchStats?) as String {
        if (m == null) {
            return "none";
        }
        var longest = m.longestGame;
        return "points " + m.pointsWon + "-" + m.pointsLost + ", games " + m.gamesWon + "-" + m.gamesLost + ", sets " + m.setsWon
            + "-" + m.setsLost + ", deciding " + m.decidingPointsWon + "/" + m.decidingPointsPlayed + ", tie-breaks " + m.tieBreaksWon
            + "/" + m.tieBreaksPlayed + ", longest " + (longest == null ? "-" : m.gameDurations[longest].toString()) + ", "
            + TestKit.statsPoints(m) + " | " + TestKit.statsServe(m);
    }

    // A copy of value with key set to item.
    function with(value as Dictionary<String, Object?>, key as String, item as Object?) as Dictionary<String, Object?> {
        var other = MatchStoreTests.without(value, key);
        other.put(key, item);
        return other;
    }

    // A copy of list with the item at index replaced.
    function replaced(list as Array<Object?>, index as Number, item as Object?) as Array<Object?> {
        var other = list.slice(0, null);
        other[index] = item;
        return other;
    }
}

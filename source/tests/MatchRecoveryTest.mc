import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Resume after a crash, the app stopped while recording, and the low battery save, over a
// fake recorder: the stored match comes back exactly as it was played, on a new session that starts
// with no warm-up and no burst of laps; the launch prompt shows its score. Matches are played through
// the app's match holder (TestKit.Rig), "<" an undo.

(:test)
function matchRecoveryExactStateTest(logger as Logger) as Boolean {
    // Each match, stored and resumed, is the one played: the state (score, server, side, the deuce
    // count), the log, and what the score screen shows from them (points, games, pips, the serve dot,
    // YOU / PARTNER, the banner and the caption): the second set after a tie-break at deuce, undos with
    // our partner serving first, a tie-break just after its change of ends, serve tracking off, over.
    var cases = [
        ["Me", "UTUTUTUTUTUT uuuuuuu UTU uuuttt"], ["Opponents Partner", "UUTT uuuttt<< tu<"], ["Me", "UTUTUTUTUTUT uuuttt"],
        ["", "UTU ut"], ["Opponents Me", "UUUUUU UUUUUT U"]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var played = new TestKit.Rig(new MatchConfig(), cases[i][0], false);
        played.play(cases[i][1]);
        var resumed = new TestKit.Resumed(TestKit.storedOf(played.match));
        var match = resumed.match;
        var message = "case " + i;
        TestKit.assertSameState(match.getState(), played.getState(), message);
        Test.assertEqualMessage(match.engine.getLog().toString(), played.engine.getLog().toString(), message);
        Test.assert(match.engine.getConfig().equals(played.engine.getConfig()) && match.start == played.match.start);
        var a = new ScoreModel(match.engine.getConfig(), match.getState(), true);
        var e = new ScoreModel(played.engine.getConfig(), played.getState(), true);
        Test.assertEqualMessage(TestKit.screen(a), TestKit.screen(e), message);
        Test.assertMessage(a.banner == e.banner && a.bannerNumber == e.bannerNumber && a.caption == e.caption
            && a.captionNumber == e.captionNumber, message + ": banner or caption");
    }
    return true;
}

(:test)
function matchRecoverySessionTest(logger as Logger) as Boolean {
    // Resume starts a new Padel session with no warm-up and writes no lap for the games already played
    // (they went with the lost session): the next lap is the game in progress, written at its winning
    // point. The chart starts at the match's point differential, and the session
    // fields at the save count the whole match. Outdoors the resumed session turns GPS on, as the match
    // had it; indoors never.
    var played = new TestKit.Rig(new MatchConfig(), "Me", false);
    played.play("UUTUT uut");
    var resumed = new TestKit.Resumed(TestKit.storedOf(played.match));
    TestKit.assertCalls(resumed.recorder, ["create", "sensors", "start"], "started");
    Test.assert(resumed.session.getPhase() == SESSION_MATCH && !resumed.session.isPaused() && resumed.laps.getCommitted() == 5);
    Test.assert(resumed.recorder.pointDifferential == played.recorder.pointDifferential && resumed.recorder.pointDifferential == 5);
    // The game in progress (2-1 in points to us) goes to us, then a point opens the next one.
    resumed.play("u");
    Test.assertEqual(resumed.recorder.laps.size(), 0);
    resumed.play("u");
    Test.assertEqual(resumed.recorder.laps.toString(), [LapValues.forGame(resumed.match.getState(), 5).toString()].toString());
    resumed.play("t");
    Test.assert(resumed.session.save() && resumed.recorder.laps.size() == 2);
    var values = resumed.recorder.sessionValues as SessionValues;
    Test.assert(values.points.toString().equals(resumed.match.getState().pointsWon.toString()) && values.score.equals("4-2*"));

    played.match.outdoor = true;
    resumed = new TestKit.Resumed(TestKit.storedOf(played.match));
    TestKit.assertCalls(resumed.recorder, ["create", "sensors+gps", "start"], "outdoors");
    Test.assert(resumed.match.outdoor);
    played.match.outdoor = false;
    resumed = new TestKit.Resumed(TestKit.storedOf(played.match));
    Test.assert(!resumed.recorder.gpsEverOn);
    return true;
}

(:test)
function matchRecoveryFinishedMatchTest(logger as Logger) as Boolean {
    // A match stored after its last point (the app stopped on the summary) comes back over: the
    // summary's save writes its result, and BACK there still undoes the match point. The watch refusing
    // the new session gives no match (the error screen shows), never another sport.
    var played = new TestKit.Rig(new MatchConfig(), "Me", false);
    played.play("UUUUUU UUUUUT U");
    var resumed = new TestKit.Resumed(TestKit.storedOf(played.match));
    var match = resumed.match;
    Test.assert(match.getState().matchOver && match.getState().getResult() == RESULT_WIN);
    Test.assert((match.undo() as MatchEvent).type == EVENT_POINT_US && !match.getState().matchOver);
    resumed.play("u");
    Test.assert(resumed.session.save() && (resumed.recorder.sessionValues as SessionValues).result == 1);
    var recorder = new TestKit.FakeRecorder();
    recorder.createFails = true;
    var session = new SessionManager(recorder);
    Test.assert(MatchRecovery.resume(TestKit.storedOf(played.match), session, new LapCommitter(session)) == null);
    Test.assertEqual(session.getPhase(), SESSION_FAILED);
    return true;
}

(:test)
function matchRecoveryStopTest(logger as Logger) as Boolean {
    // The system stops the app while it records (onStop): the session is saved, so its heart rate, time
    // and laps are kept, and the match stays stored for the resume prompt, with the last event: no
    // history record for it. A match that is over needs no resume: it's cleared, and it goes
    // into the history as after a Save (true). After Save or Discard nothing happens; in the warm-up
    // there's no match: the session is saved, nothing is stored.
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        MatchStore.clear();
        var played = new TestKit.Rig(new MatchConfig(), "Me", false);
        played.play("UUT ut");
        Test.assert(!MatchRecovery.stop(played.session, played.match));
        Test.assert(played.recorder.calls.indexOf("save") >= 0 && played.session.getPhase() == SESSION_ENDED);
        TestKit.assertSameState((TestKit.loadStored() as StoredMatch).engine.getState(), played.getState(), "stored at the stop");
        played.recorder.clear();
        Test.assert(!MatchRecovery.stop(played.session, played.match));
        TestKit.assertCalls(played.recorder, [], "after the save");
        Test.assert(MatchStore.isStored());

        played = new TestKit.Rig(new MatchConfig(), "Me", false);
        played.play("UUUUUU UUUUUU");
        played.match.save();
        Test.assert(MatchRecovery.stop(played.session, played.match));
        Test.assert(played.session.getPhase() == SESSION_ENDED && !MatchStore.isStored());
        Test.assert(!MatchRecovery.stop(played.session, played.match));

        // A save the watch refuses keeps the session and the stored match: no history record either.
        played = new TestKit.Rig(new MatchConfig(), "Me", false);
        played.play("UUUUUU UUUUUU");
        played.recorder.saveResult = false;
        Test.assert(!MatchRecovery.stop(played.session, played.match) && MatchStore.isStored());
        MatchStore.clear();

        var flow = new TestKit.Flow(false, true);
        flow.flow.start(TestKit.T0);
        Test.assert(!MatchRecovery.stop(flow.session, null));
        Test.assert(flow.session.getPhase() == SESSION_ENDED && !MatchStore.isStored());
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function matchRecoverySaveAfterEventTest(logger as Logger) as Boolean {
    // Every event added or undone through the match holder leaves it unsaved until it's written, and a
    // write with nothing new writes nothing (saved after every event).
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        MatchStore.clear();
        var played = new TestKit.Rig(new MatchConfig(), "Me", false);
        var match = played.match;
        Test.assert(match.isUnsaved());
        match.save();
        Test.assert(!match.isUnsaved() && MatchStore.isStored());
        played.play("u");
        Test.assert(match.isUnsaved());
        match.save();
        Test.assertEqual((TestKit.loadStored() as StoredMatch).engine.getState().eventCount, 2);
        played.play("<");
        Test.assert(match.isUnsaved());
        match.save();
        Test.assertEqual((TestKit.loadStored() as StoredMatch).engine.getState().eventCount, 1);
        // A refused event changes nothing, so there's nothing to write.
        Test.assert(!match.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, TestKit.T0, TEAM_US)) && !match.isUnsaved());
        MatchStore.clear();
        match.save();
        Test.assert(!MatchStore.isStored());
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function matchRecoveryLowBatteryTest(logger as Logger) as Boolean {
    // At 3 % or less the app saves the session by itself, unless the watch is charging.
    Test.assert(MatchRecovery.isBatteryLow(3.0, false) && MatchRecovery.isBatteryLow(0.0, false));
    Test.assert(!MatchRecovery.isBatteryLow(3.01, false) && !MatchRecovery.isBatteryLow(100.0, false));
    Test.assert(!MatchRecovery.isBatteryLow(2.0, true));
    return true;
}

(:test)
function resumePromptTest(logger as Logger) as Boolean {
    // "Resume match?" with the score under Resume, then Discard; Discard only when the stored match
    // can't be read. The score is the compact score without the unfinished set's star.
    Test.assert(ResumePrompt.title(true) == Rez.Strings.ResumeTitle && ResumePrompt.title(false) == Rez.Strings.ResumeFailedTitle);
    Test.assertEqual(ResumePrompt.items(true).toString(), [RESUME_ITEM_RESUME, RESUME_ITEM_DISCARD].toString());
    Test.assertEqual(ResumePrompt.items(false).toString(), [RESUME_ITEM_DISCARD].toString());
    var engine = new ScoringEngine(new MatchConfig());
    var steps = [["", "0-0"], ["ut", "0-0"], ["UTUTUTUTUU TTUUT", "6-4 2-3"], ["ut", "6-4 2-3"]];
    for (var i = 0; i < steps.size(); i++) {
        TestKit.play(engine, steps[i][0]);
        Test.assertEqual(ResumePrompt.scoreText(engine.getState()), steps[i][1]);
    }
    engine = new ScoringEngine(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB));
    TestKit.play(engine, "UTUTUTUTUU TUTUTUTTT uuuuuuuuuttttttttu");
    Test.assertEqual(ResumePrompt.scoreText(engine.getState()), "6-4 3-6 10-8");
    return true;
}

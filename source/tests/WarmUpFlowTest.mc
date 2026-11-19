import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// From PLAY to the match, with a fake recorder: the sensor lock records
// nothing and BACK there goes home; START begins recording in the warm-up (lap 1) or, with the Warm-up
// phase off, straight into the match; in the warm-up UP, DOWN and BACK only bring the toast, never a
// point, and never leave; START again starts the match (lap 2) with its start time. Then the match
// holder: its events go through the lap commit.

(:test)
function warmUpLockTest(logger as Logger) as Boolean {
    // Nothing records before START; BACK goes home and turns the sensors off. Outdoors the lock searches
    // GPS, and BACK turns it off.
    var test = new TestKit.Flow(false, true);
    test.flow.lock();
    Test.assertEqual(test.flow.press(), STEP_NONE);
    Test.assertEqual(test.flow.back(), STEP_HOME);
    TestKit.assertCalls(test.recorder, ["sensors", "sensors off"], "back home");
    Test.assert(test.session.getPhase() == SESSION_IDLE && test.flow.getMatch() == null);
    test = new TestKit.Flow(true, true);
    test.flow.lock();
    Test.assert(test.recorder.gps);
    test.flow.back();
    TestKit.assertCalls(test.recorder, ["sensors+gps", "sensors off"], "outdoors");
    Test.assert(!test.recorder.gps);
    return true;
}

(:test)
function warmUpStartTest(logger as Logger) as Boolean {
    // START records the warm-up: lap 1 runs, no match yet. UP and DOWN never score and BACK never leaves
    // while recording: each only brings the toast. START again ends the warm-up: its lap closes (lap 2
    // begins) and the match starts, at that time, once. Two laps at the save: the warm-up and the match.
    var test = new TestKit.Flow(false, true);
    test.flow.lock();
    Test.assertEqual(test.flow.start(TestKit.T0), STEP_WARM_UP);
    TestKit.assertCalls(test.recorder, ["sensors", "create", "start"], "recording");
    Test.assert(test.session.getPhase() == SESSION_WARM_UP && test.flow.getMatch() == null);
    test.recorder.clear();
    for (var i = 0; i < 3; i++) {
        Test.assert(test.flow.press() == STEP_TOAST && test.flow.back() == STEP_TOAST);
    }
    TestKit.assertCalls(test.recorder, [], "no lap, no stop");
    Test.assert(test.session.isRecording() && !test.session.isPaused() && test.flow.getMatch() == null);
    Test.assertEqual(test.flow.start(TestKit.T0 + 300), STEP_MATCH);
    TestKit.assertCalls(test.recorder, ["lap"], "warm-up lap");
    var match = test.flow.getMatch() as CurrentMatch;
    Test.assert(test.session.getPhase() == SESSION_MATCH && match.start == TestKit.T0 + 300 && match.getState().eventCount == 0);
    Test.assert(match.engine.getConfig().equals(test.flow.config));
    Test.assert(test.flow.start(TestKit.T0 + 310) == STEP_NONE && test.flow.getMatch() == match);
    TestKit.assertCalls(test.recorder, ["lap"], "one warm-up lap");
    Test.assert(test.session.save() && test.recorder.laps.size() == 2);
    return true;
}

(:test)
function warmUpSwipeMenuTest(logger as Logger) as Boolean {
    // On the watches without UP and DOWN (the flag on), a swipe up opens the screen's menu, as the menu
    // key does: the warm-up's while recording, and at the sensor lock the lock's (the debug menu in debug
    // builds, none in release). Other swipes do nothing. Off, a swipe up does nothing either.
    var test = new TestKit.Flow(false, true);
    test.flow.lock();
    Test.assertEqual(test.flow.swipe(WatchUi.SWIPE_UP), STEP_NONE);
    test.flow.swipeMenu = true;
    Test.assertEqual(test.flow.swipe(WatchUi.SWIPE_UP), STEP_LOCK_MENU);
    Test.assertEqual(test.flow.start(TestKit.T0), STEP_WARM_UP);
    test.recorder.clear();
    Test.assertEqual(test.flow.swipe(WatchUi.SWIPE_UP), STEP_MENU);
    var others = [WatchUi.SWIPE_DOWN, WatchUi.SWIPE_LEFT, WatchUi.SWIPE_RIGHT] as Array<WatchUi.SwipeDirection>;
    for (var i = 0; i < others.size(); i++) {
        Test.assertEqual(test.flow.swipe(others[i]), STEP_NONE);
    }
    test.flow.swipeMenu = false;
    Test.assertEqual(test.flow.swipe(WatchUi.SWIPE_UP), STEP_NONE);
    TestKit.assertCalls(test.recorder, [], "no lap, no stop");
    Test.assert(test.flow.getMatch() == null && test.session.isRecording());
    return true;
}

(:test)
function warmUpOffTest(logger as Logger) as Boolean {
    // Warm-up phase off: START at the lock starts the match with the recording, no warm-up lap.
    var test = new TestKit.Flow(false, false);
    test.flow.lock();
    Test.assertEqual(test.flow.start(TestKit.T0), STEP_MATCH);
    TestKit.assertCalls(test.recorder, ["sensors", "create", "start"], "no lap");
    Test.assert(test.session.getPhase() == SESSION_MATCH && (test.flow.getMatch() as CurrentMatch).start == TestKit.T0);
    Test.assert(test.session.save() && test.recorder.laps.size() == 1);
    return true;
}

(:test)
function warmUpRefusedTest(logger as Logger) as Boolean {
    // The watch refuses the session: the error screen, never another sport. After Discard (confirmed in
    // the warm-up menu, which discards through the session manager) nothing starts and no match exists.
    var test = new TestKit.Flow(false, true);
    test.recorder.createFails = true;
    Test.assert(test.flow.start(TestKit.T0) == STEP_FAILED && test.session.getPhase() == SESSION_FAILED && test.flow.getMatch() == null);
    test = new TestKit.Flow(false, true);
    test.flow.start(TestKit.T0);
    Test.assert(test.session.discard() && test.flow.start(TestKit.T0 + 60) == STEP_NONE && test.flow.press() == STEP_NONE);
    Test.assert(test.flow.getMatch() == null && test.recorder.laps.size() == 0);
    return true;
}

(:test)
function currentMatchTest(logger as Logger) as Boolean {
    // Events added or undone through the holder reach the lap commit and the record field,
    // with no other call; a refused event (a serving team fix naming no team) changes nothing. The
    // session gets the match at its start, so a pause or save writes its session fields.
    var rig = new TestKit.Rig(new MatchConfig(), "", true);
    rig.play("uuu");
    Test.assert(rig.getState().finishedGames.size() == 0 && rig.recorder.laps.toString().equals(["none"].toString()));
    rig.play("ut");
    Test.assert(rig.recorder.laps.toString().equals(["none", "1 1-0 5"].toString()) && rig.recorder.pointDifferential == 3);
    Test.assert((rig.match.undo() as MatchEvent).type == EVENT_POINT_THEM && rig.recorder.pointDifferential == 4);
    Test.assertEqual(rig.recorder.laps.size(), 2);
    Test.assert(!rig.match.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, TestKit.T0, null)) && rig.getState().eventCount == 4);
    Test.assert(rig.session.pause());
    Test.assertEqual((rig.recorder.sessionValues as SessionValues).points.toString(), [4, 0].toString());
    return true;
}

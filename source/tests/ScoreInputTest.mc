import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Score input, over a match recorded through a
// fake (TestKit.Rig): UP scores THEM and DOWN US (read in onKey, on release on the watch); hold UP
// (KEY_MENU) opens the match menu and never scores; a second point press within the press delay (800 ms
// by default, 0.5 s and 1.2 s too) of the last one that counted is ignored, for either team;
// BACK undoes the last event of any type and names it, and never leaves; START pauses (and resumes);
// while paused UP, DOWN and BACK only bring "Paused"; taps and swipes never score, and a swipe left goes
// to the data page. With touch scoring on a tap on the score page is a point press
// for the half tapped, and the BACK guard (BackGuard, which every touch goes through) lets BACK undo it
// at once. Times are System.getTimer() milliseconds, passed in.

(:test)
function scoreInputKeysTest(logger as Logger) as Boolean {
    // DOWN: a point for US, the bottom half. UP: THEM, the top half. Hold UP: the match menu. START: the
    // pause menu, paused. Other keys: nothing. BACK: the last event undone, named.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assert(input.key(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && input.team == TEAM_US && input.won == WON_POINT);
    Test.assert(input.key(WatchUi.KEY_UP, 3000) == INPUT_POINT && input.team == TEAM_THEM);
    Test.assertEqual(input.key(WatchUi.KEY_MENU, 5000), INPUT_MATCH_MENU);
    Test.assertEqual(input.key(WatchUi.KEY_LAP, 6000), INPUT_NONE);
    Test.assert(input.key(WatchUi.KEY_ENTER, 7000) == INPUT_PAUSE && rig.session.isPaused());
    rig.assertPoints(1, 1, "menu, lap, START");
    Test.assertEqual(input.key(WatchUi.KEY_ENTER, 8000), INPUT_RESUME);
    Test.assert(input.key(WatchUi.KEY_ESC, 9000) == INPUT_UNDO && input.toast == Rez.Strings.UndonePointThem);
    rig.assertPoints(1, 0, "BACK");
    return true;
}

(:test)
function scoreInputMenuNeverScoresTest(logger as Logger) as Boolean {
    // Hold UP gives KEY_MENU and no KEY_UP (tested on the FR265): never a point, at any time, and it doesn't touch
    // the debounce: DOWN 800 ms after the last point still counts.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assertEqual(input.key(WatchUi.KEY_MENU, 1000), INPUT_MATCH_MENU);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 5000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_MENU, 5100), INPUT_MATCH_MENU);
    Test.assertEqual(input.key(WatchUi.KEY_MENU, 5700), INPUT_MATCH_MENU);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 5800), INPUT_POINT);
    rig.assertPoints(2, 0, "hold UP between points");
    return true;
}

(:test)
function scoreInputDebounceSameTeamTest(logger as Logger) as Boolean {
    // A second press within 800 ms of the last point that counted is ignored: 799 ms after, nothing;
    // 800 ms after, a point; for either team. An ignored press doesn't restart the wait.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    var keys = [WatchUi.KEY_DOWN, WatchUi.KEY_UP];
    for (var i = 0; i < keys.size(); i++) {
        var t = 10000 * (i + 1);
        Test.assertEqual(input.key(keys[i], t), INPUT_POINT);
        Test.assertEqual(input.key(keys[i], t + 799), INPUT_NONE);
        Test.assertEqual(input.key(keys[i], t + 800), INPUT_POINT);
    }
    rig.assertPoints(2, 2, "799 and 800 ms");
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 30000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 30500), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 30800), INPUT_POINT);
    rig.assertPoints(4, 2, "ignored press");
    return true;
}

(:test)
function scoreInputDebounceBothTeamsTest(logger as Logger) as Boolean {
    // The wait spans both teams: UP 799 ms after a point for US is ignored, 800 ms after it counts, and
    // the other way round. System.getTimer() wraps around after about 24.8 days of uptime.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 10000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_UP, 10799), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_UP, 10800), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 11599), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 11600), INPUT_POINT);
    var last = 0x7FFFFFFF - 300;
    Test.assertEqual(input.key(WatchUi.KEY_UP, last), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, last + 799), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, last + 800), INPUT_POINT);
    rig.assertPoints(3, 2, "both teams, timer wrap");
    return true;
}

(:test)
function scoreInputDebounceSettingTest(logger as Logger) as Boolean {
    // The Press delay setting: 0.5 s, 0.8 s (the default, criterion 8) or 1.2 s,
    // never off. At each value: a point press 1 ms under it after the last point that counted is
    // ignored, at it counted, for the same team and the other; an ignored press doesn't restart the
    // wait; an undo still ends it, so the press right after a correction counts; and with touch scoring
    // on a tap is in the same wait as the buttons, both ways.
    var values = Settings.debounceChoices();
    Test.assert(values.size() == 3 && values[0] == 500 && values[1] == 800 && values[2] == 1200);
    Test.assert(Settings.DEFAULT_DEBOUNCE == 800);
    for (var i = 0; i < values.size(); i++) {
        var wait = values[i];
        var rig = new TestKit.Rig(new MatchConfig(), "", false);
        var input = rig.input;
        Test.assertEqual(input.debounce, Settings.DEFAULT_DEBOUNCE);
        input.debounce = wait;
        var t = 10000;
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, t), INPUT_POINT);
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, t + wait - 1), INPUT_NONE);
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, t + wait), INPUT_POINT);
        t += wait;
        Test.assertEqual(input.key(WatchUi.KEY_UP, t + wait / 2), INPUT_NONE);
        Test.assertEqual(input.key(WatchUi.KEY_UP, t + wait - 1), INPUT_NONE);
        Test.assertEqual(input.key(WatchUi.KEY_UP, t + wait), INPUT_POINT);
        rig.assertPoints(2, 1, "keys at " + wait);
        t += wait;
        Test.assertEqual(input.key(WatchUi.KEY_ESC, t + 1), INPUT_UNDO);
        Test.assert(input.key(WatchUi.KEY_DOWN, t + 2) == INPUT_POINT && input.team == TEAM_US);
        rig.assertPoints(3, 0, "undo at " + wait);
        t += 2;
        input.touchScoring = true;
        Test.assertEqual(input.tap(100, 416, PAGE_SCORE, t + wait - 1), INPUT_NONE);
        Test.assert(input.tap(100, 416, PAGE_SCORE, t + wait) == INPUT_POINT && input.team == TEAM_THEM);
        t += wait;
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, t + wait - 1), INPUT_NONE);
        Test.assertEqual(input.tap(300, 416, PAGE_SCORE, t + wait - 1), INPUT_NONE);
        Test.assert(input.tap(300, 416, PAGE_SCORE, t + wait) == INPUT_POINT && input.team == TEAM_US);
        t += wait;
        Test.assertEqual(input.key(WatchUi.KEY_UP, t + wait - 1), INPUT_NONE);
        Test.assertEqual(input.key(WatchUi.KEY_UP, t + wait), INPUT_POINT);
        t += wait;
        Test.assertEqual(input.key(WatchUi.KEY_ESC, t + 1), INPUT_UNDO);
        Test.assertEqual(input.tap(100, 416, PAGE_SCORE, t + 2), INPUT_POINT);
        rig.assertPoints(4, 2, "taps at " + wait);
    }
    return true;
}

(:test)
function scoreInputDebounceChangeTest(logger as Logger) as Boolean {
    // The setting is read at each press (ScoreDelegate sets ScoreInput.debounce before it): a press is
    // held to the value it comes with, whatever the value was at the point before it.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    input.debounce = 1200;
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    input.debounce = 500;
    Test.assertEqual(input.key(WatchUi.KEY_UP, 1499), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_UP, 1500), INPUT_POINT);
    input.debounce = 1200;
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 2000), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 2699), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 2700), INPUT_POINT);
    rig.assertPoints(2, 1, "changed between presses");
    return true;
}

(:test)
function scoreInputUndoClearsDebounceTest(logger as Logger) as Boolean {
    // BACK is never debounced, and the point it undoes no longer holds the next one back: DOWN by
    // mistake, BACK, UP at once gives THEM the point. Fast BACK presses each undo one event.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_ESC, 1100), INPUT_UNDO);
    Test.assertEqual(input.key(WatchUi.KEY_UP, 1200), INPUT_POINT);
    rig.assertPoints(0, 1, "corrected");
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 3000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_ESC, 3050), INPUT_UNDO);
    Test.assertEqual(input.key(WatchUi.KEY_ESC, 3100), INPUT_UNDO);
    rig.assertPoints(0, 0, "two fast undos");
    return true;
}

(:test)
function scoreInputUndoToastsTest(logger as Logger) as Boolean {
    // BACK undoes the last event of any type, and the toast names it. With the log empty,
    // BACK says so and nothing else happens.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var events = TestKit.oneOfEachType();
    for (var i = 0; i < events.size(); i++) {
        Test.assertMessage(rig.match.add(events[i]), "add " + events[i]);
    }
    var toasts = {EVENT_FIX_SERVING_TEAM => Rez.Strings.UndoneServingTeam, EVENT_SWAP_OUR_SERVER => Rez.Strings.UndoneServerSwap,
        EVENT_SET_DEUCE_MODE => Rez.Strings.UndoneDeuceMode, EVENT_POINT_US => Rez.Strings.UndonePointUs,
        EVENT_POINT_THEM => Rez.Strings.UndonePointThem, EVENT_END_SET => Rez.Strings.UndoneEndSet,
        EVENT_END_MATCH => Rez.Strings.UndoneEndMatch} as Dictionary<EventType, ResourceId>;
    for (var i = events.size() - 1; i >= 0; i--) {
        Test.assertEqual(rig.input.key(WatchUi.KEY_ESC, 1000 + i), INPUT_UNDO);
        var toast = toasts.get(events[i].type);
        Test.assertMessage((rig.input.undone as MatchEvent).equals(events[i]) && rig.input.toast == toast
            && ScoreInput.undoneString(events[i].type) == toast && rig.getState().eventCount == i, "undo " + i);
    }
    Test.assert(rig.input.key(WatchUi.KEY_ESC, 2000) == INPUT_TOAST && rig.input.toast == Rez.Strings.UndoneNothing);
    Test.assert(rig.input.undone == null);
    return true;
}

(:test)
function scoreInputEmptyLogTest(logger as Logger) as Boolean {
    // BACK with nothing to undo never leaves and never stops the recording (criterion 5): the
    // toast "Nothing to undo", as often as it's pressed.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.recorder.clear();
    for (var i = 0; i < 5; i++) {
        Test.assert(rig.input.key(WatchUi.KEY_ESC, 1000 + i * 100) == INPUT_TOAST && rig.input.toast == Rez.Strings.UndoneNothing);
    }
    Test.assert(rig.getState().eventCount == 0 && rig.session.getPhase() == SESSION_MATCH);
    Test.assert(rig.session.isRecording() && !rig.session.isPaused());
    TestKit.assertCalls(rig.recorder, [], "no stop, no lap");
    return true;
}

(:test)
function scoreInputPausedTest(logger as Logger) as Boolean {
    // START pauses. While paused UP, DOWN and BACK change nothing and bring "Paused", and so
    // does a tap with touch scoring on, a point press too; hold UP and a swipe left still open the
    // match menu and the data page. START resumes.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assertEqual(input.key(WatchUi.KEY_ENTER, 5000), INPUT_PAUSE);
    var keys = [WatchUi.KEY_UP, WatchUi.KEY_DOWN, WatchUi.KEY_ESC];
    for (var i = 0; i < keys.size(); i++) {
        Test.assert(input.key(keys[i], 6000 + i * 1000) == INPUT_TOAST && input.toast == Rez.Strings.ToastPaused);
    }
    input.touchScoring = true;
    Test.assert(input.tap(100, 416, PAGE_SCORE, 8500) == INPUT_TOAST && input.toast == Rez.Strings.ToastPaused);
    Test.assert(input.tap(300, 416, PAGE_SCORE, 8700) == INPUT_TOAST && input.toast == Rez.Strings.ToastPaused);
    rig.assertPoints(1, 0, "paused");
    Test.assertEqual(input.key(WatchUi.KEY_MENU, 9000), INPUT_MATCH_MENU);
    Test.assert(input.swipe(WatchUi.SWIPE_LEFT, 9500) == INPUT_NEXT_PAGE && rig.session.isPaused());
    Test.assert(input.key(WatchUi.KEY_ENTER, 10000) == INPUT_RESUME && !rig.session.isPaused());
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 10100), INPUT_POINT);
    rig.assertPoints(2, 0, "resumed");
    return true;
}

(:test)
function scoreInputTouchTest(logger as Logger) as Boolean {
    // Criterion 10: with touch scoring off (the default), taps anywhere on every page, holds, drags,
    // flicks and releases never score, before or right after a point press (a stray touch),
    // and swipes neither: a swipe left goes to the next page (the data page, then the stats page), a
    // swipe right to the one before, the others do nothing.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assert(!input.touchScoring && !Settings.DEFAULT_TOUCH_SCORING);
    var pages = [PAGE_SCORE, PAGE_DATA, PAGE_STATS] as Array<ScorePage>;
    var ys = [0, 100, 207, 208, 300, 415];
    for (var i = 0; i < 2; i++) {
        var t = 1000 + i * 10000;
        for (var p = 0; p < pages.size(); p++) {
            for (var y = 0; y < ys.size(); y++) {
                Test.assertEqual(input.tap(ys[y], 416, pages[p], t + 100 * p + y), INPUT_NONE);
            }
        }
        Test.assert(input.touch(t + 400) == INPUT_NONE && input.swipe(WatchUi.SWIPE_UP, t + 500) == INPUT_NONE);
        Test.assert(input.swipe(WatchUi.SWIPE_DOWN, t + 600) == INPUT_NONE && input.swipe(WatchUi.SWIPE_RIGHT, t + 700) == INPUT_PREVIOUS_PAGE);
        Test.assertEqual(input.swipe(WatchUi.SWIPE_LEFT, t + 800), INPUT_NEXT_PAGE);
        rig.assertPoints(i, 0, "touch " + i);
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, t + 5000), INPUT_POINT);
    }
    return true;
}

(:test)
function scoreInputTapTest(logger as Logger) as Boolean {
    // Touch scoring on: on the score page a tap is a point press for the half tapped,
    // THEM above the middle, US from it down, on the FR265 (416 px: 207 and 208) and the FR265S (360 px:
    // 179 and 180). Taps on the data page and the stats page do nothing, nor do holds, drags, flicks and
    // swipes, which keep turning the pages. A tap after the match is a refused press: "Match over".
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    input.touchScoring = true;
    var taps = [[0, 416, TEAM_THEM], [207, 416, TEAM_THEM], [208, 416, TEAM_US], [415, 416, TEAM_US],
        [179, 360, TEAM_THEM], [180, 360, TEAM_US]];
    for (var i = 0; i < taps.size(); i++) {
        var tap = taps[i] as Array<Number>;
        Test.assertMessage(input.tap(tap[0], tap[1], PAGE_SCORE, 1000 * (i + 1)) == INPUT_POINT && input.team == tap[2]
            && input.won == WON_POINT && input.toast == null, "tap " + i);
    }
    rig.assertPoints(3, 3, "taps");
    Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, 8000) == INPUT_NEXT_PAGE && rig.tap(300, 9000) == INPUT_NONE);
    Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, 9100) == INPUT_NEXT_PAGE && rig.motion.page == PAGE_STATS);
    Test.assert(rig.tap(100, 10000) == INPUT_NONE && rig.touch(10100) == INPUT_NONE);
    rig.assertPoints(3, 3, "data and stats pages");
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 11000) == INPUT_PREVIOUS_PAGE && rig.swipe(WatchUi.SWIPE_RIGHT, 11100) == INPUT_PREVIOUS_PAGE);
    Test.assert(rig.motion.page == PAGE_SCORE && rig.touch(12000) == INPUT_NONE);
    Test.assert(rig.swipe(WatchUi.SWIPE_UP, 12100) == INPUT_NONE && rig.swipe(WatchUi.SWIPE_DOWN, 12200) == INPUT_NONE);
    rig.assertPoints(3, 3, "other touches");
    Test.assert(rig.tap(400, 13000) == INPUT_POINT && input.team == TEAM_US);
    rig = new TestKit.Rig(TestKit.preset(PRESET_ONE_SET), "", false);
    rig.play("UUUUU uuu");
    rig.input.touchScoring = true;
    Test.assert(rig.tap(300, 1000) == INPUT_POINT && rig.input.won == WON_MATCH);
    Test.assert(rig.tap(100, 2000) == INPUT_TOAST && rig.input.toast == Rez.Strings.ToastMatchOver);
    rig.assertPoints(24, 0, "after the match");
    return true;
}

(:test)
function scoreInputTapDebounceTest(logger as Logger) as Boolean {
    // A tap is a point press for the debounce: within 800 ms of the last point that counted,
    // tapped or pressed, a tap or a key is ignored, for either team, and an ignored tap doesn't restart
    // the wait. An undo ends it, so the right half tapped right after a correction counts.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    input.touchScoring = true;
    Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 1000), INPUT_POINT);
    Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 1150), INPUT_NONE);
    Test.assertEqual(input.key(WatchUi.KEY_UP, 1799), INPUT_NONE);
    Test.assertEqual(input.tap(100, 416, PAGE_SCORE, 1799), INPUT_NONE);
    Test.assert(input.tap(100, 416, PAGE_SCORE, 1800) == INPUT_POINT && input.team == TEAM_THEM);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, 2600), INPUT_POINT);
    Test.assertEqual(input.tap(100, 416, PAGE_SCORE, 3399), INPUT_NONE);
    Test.assert(input.tap(300, 416, PAGE_SCORE, 3400) == INPUT_POINT && input.team == TEAM_US);
    rig.assertPoints(3, 1, "debounced");
    Test.assert(input.key(WatchUi.KEY_ESC, 3500) == INPUT_UNDO && input.toast == Rez.Strings.UndonePointUs);
    Test.assert(input.tap(100, 416, PAGE_SCORE, 3600) == INPUT_POINT && input.team == TEAM_THEM);
    rig.assertPoints(2, 2, "corrected");
    return true;
}

(:test)
function scoreInputTapBackTest(logger as Logger) as Boolean {
    // BACK right after a tapped point, through the BACK guard as ScoreDelegate passes
    // it: the BACK button (its key 80 ms after its key-down) 300 ms after a tap. Touch scoring off, the
    // tap is a touch, and BACK within 800 ms of it does nothing, as before; 800 ms after, it undoes. On,
    // a tap that scored doesn't start that wait, nor do the touches before it (its touch-down) and its
    // release right after it: BACK undoes the tapped point. A tap that didn't score (debounced, on the
    // data page) is a touch, and so is a touch TAP_END_MS or more after the tap. In the simulator BACK
    // sends its key on its key-down: it waits 100 ms and undoes, no touch having come.
    for (var on = 0; on < 2; on++) {
        var rig = new TestKit.Rig(new MatchConfig(), "", false);
        var input = rig.input;
        input.touchScoring = on == 1;
        Test.assertEqual(input.key(WatchUi.KEY_UP, 100), INPUT_POINT);
        Test.assertEqual(input.touch(900), INPUT_NONE);
        Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 1000), on == 1 ? INPUT_POINT : INPUT_NONE);
        Test.assertEqual(input.touch(1050), INPUT_NONE);
        Test.assertEqual(ScoreInputTests.back(rig, 1300, 80), on == 1 ? INPUT_UNDO : INPUT_NONE);
        rig.assertPoints(0, 1, "BACK after the tap, " + on);
        Test.assertEqual(ScoreInputTests.back(rig, 1050 + BackGuard.TOUCH_MS, 80), INPUT_UNDO);
        rig.assertPoints(0, 0, "BACK 800 ms after, " + on);
        if (on == 1) {
            Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 3000), INPUT_POINT);
            Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 3500), INPUT_NONE);
            Test.assertEqual(ScoreInputTests.back(rig, 3600, 80), INPUT_NONE);
            Test.assertEqual(ScoreInputTests.back(rig, 3500 + BackGuard.TOUCH_MS, 80), INPUT_UNDO);
            Test.assertEqual(input.tap(300, 416, PAGE_SCORE, 6000), INPUT_POINT);
            Test.assertEqual(input.touch(6000 + BackGuard.TAP_END_MS), INPUT_NONE);
            Test.assertEqual(ScoreInputTests.back(rig, 6400, 80), INPUT_NONE);
            Test.assertEqual(input.tap(300, 416, PAGE_DATA, 7000), INPUT_NONE);
            Test.assertEqual(ScoreInputTests.back(rig, 7300, 80), INPUT_NONE);
            rig.assertPoints(1, 0, "touches that start the wait");
            Test.assertEqual(input.tap(100, 416, PAGE_SCORE, 9000), INPUT_POINT);
            Test.assertEqual(ScoreInputTests.back(rig, 9300, 0), INPUT_UNDO);
            rig.assertPoints(1, 0, "the simulator's BACK");
        }
    }
    return true;
}

(:test)
function scoreInputEdgeSwipeTest(logger as Logger) as Boolean {
    // The watch's edge swipe right with touch scoring on: its fake BACK (key-down, the key
    // 1 ms later), then its drags and the swipe, never scores and never undoes, on the score page and
    // on the data page. Should the watch end it with a tap, that tap is a touch: within 800 ms of a BACK
    // key that came that soon after its key-down, no tap scores. A tap after them scores again.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    input.touchScoring = true;
    Test.assertEqual(rig.tap(300, 1000), INPUT_POINT);
    var starts = [5000, 9000];
    for (var i = 0; i < starts.size(); i++) {
        var t = starts[i];
        input.back.keyPressed(WatchUi.KEY_ESC, t);
        Test.assertEqual(input.back.check(WatchUi.KEY_ESC, t + 1), BACK_WAIT);
        Test.assert(rig.touch(t + 24) == INPUT_NONE && rig.touch(t + 60) == INPUT_NONE);
        Test.assert(!input.back.untouchedSince(t + 1));
        Test.assertEqual(rig.swipe(WatchUi.SWIPE_RIGHT, t + 180), INPUT_PREVIOUS_PAGE);
        Test.assert(rig.tap(250, t + 190) == INPUT_NONE && rig.tap(100, t + 800) == INPUT_NONE);
        rig.assertPoints(1, i, "edge swipe " + i);
        Test.assert(rig.motion.page == PAGE_SCORE);
        Test.assertEqual(rig.tap(100, t + 801), INPUT_POINT);
        if (i == 0) {
            Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, t + 2000) == INPUT_NEXT_PAGE && rig.motion.page == PAGE_DATA);
        }
    }
    rig.assertPoints(1, 2, "after the edge swipes");
    // The BACK button never makes a tap a touch.
    input.back.keyPressed(WatchUi.KEY_ESC, 12000);
    Test.assertEqual(input.back.check(WatchUi.KEY_ESC, 12080), BACK_NOW);
    Test.assert(input.key(WatchUi.KEY_ESC, 12080) == INPUT_UNDO && rig.tap(300, 12200) == INPUT_POINT);
    return true;
}

(:test)
function scoreInputMatchEndTest(logger as Logger) as Boolean {
    // What a point won: a game, a set, the match. Once the match is over, a point press is refused with
    // "Match over"; BACK undoes the winning point and play goes on.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    var now = 1000;
    for (var point = 1; point <= 48; point++) {
        now += 1000;
        Test.assertEqual(input.key(WatchUi.KEY_DOWN, now), INPUT_POINT);
        var won = point == 48 ? WON_MATCH : point % 24 == 0 ? WON_SET : point % 4 == 0 ? WON_GAME : WON_POINT;
        Test.assertMessage(input.won == won, "point " + point + ": " + input.won);
    }
    Test.assert(input.key(WatchUi.KEY_UP, now + 2000) == INPUT_TOAST && input.toast == Rez.Strings.ToastMatchOver);
    Test.assertEqual(input.key(WatchUi.KEY_DOWN, now + 3000), INPUT_TOAST);
    Test.assert(input.key(WatchUi.KEY_ESC, now + 3100) == INPUT_UNDO && !rig.getState().matchOver);
    Test.assert(input.key(WatchUi.KEY_UP, now + 3200) == INPUT_POINT && input.won == WON_POINT);
    rig.assertPoints(47, 1, "undone, then THEM");
    return true;
}

(:test)
function scoreInputChangeOfEndsTest(logger as Logger) as Boolean {
    // ScoreInput.ends, which ScoreDelegate gives the feedback: true for the point after
    // which the players change ends: games 1 and 3 of a set, the end of a set with an odd game count,
    // every 6 points of a tie-break, a game won again after its winning point was undone. False for any
    // other point, an undo, a press the debounce ignores, and the match point, even with an odd game
    // count. Sets to 2 games, a tie-break at 2-2 (d: DOWN, u: UP, <: BACK; E: the ends change).
    var rig = new TestKit.Rig(TestKit.format(2, 2, 2, true), "Me", false);
    var steps = [
        ["dddd", "...E"], ["<d", ".E"], ["uuuu", "...."], ["uuuu", "...E"], ["dddd", "...."],
        ["dududu", ".....E"], ["dududu", ".....E"], ["dd", ".E"],
        ["dddd", "...E"], ["uuuu", "...."], ["dddd", "...E"], ["uuuu", "...."], ["ddddddd", ".....E."],
        ["<d", ".."]
    ];
    var now = 1000;
    for (var i = 0; i < steps.size(); i++) {
        var keys = steps[i][0].toCharArray();
        var expected = steps[i][1].toCharArray();
        for (var j = 0; j < keys.size(); j++) {
            now += 1000;
            var undo = keys[j] == '<';
            var key = undo ? WatchUi.KEY_ESC : keys[j] == 'd' ? WatchUi.KEY_DOWN : WatchUi.KEY_UP;
            var message = "step " + i + ", press " + j + ": " + TestKit.sets(rig.getState());
            Test.assertEqualMessage(rig.press(key, now), undo ? INPUT_UNDO : INPUT_POINT, message);
            Test.assertEqualMessage(rig.input.ends, expected[j] == 'E', message);
        }
        if (i == 0) {
            Test.assert(rig.press(WatchUi.KEY_DOWN, now + 300) == INPUT_NONE && !rig.input.ends);
        }
    }
    Test.assert(TestKit.sets(rig.getState()).find("3-2(8-6) 3-2(7-0) | ") == 0);
    Test.assert(rig.getState().matchOver);
    Test.assert(rig.press(WatchUi.KEY_DOWN, now + 1000) == INPUT_TOAST && !rig.input.ends);
    return true;
}

(:test)
module ScoreInputTests {

    // A BACK press as ScoreDelegate passes it: its key-down at `at`, its key held ms later, through the
    // BACK guard, then to the input at once (BACK_NOW) or WAIT_MS later when no touch came (BACK_WAIT).
    // INPUT_NONE when the guard drops it.
    function back(rig as TestKit.Rig, at as Number, held as Number) as ScoreAction {
        var input = rig.input;
        input.back.keyPressed(WatchUi.KEY_ESC, at);
        var check = input.back.check(WatchUi.KEY_ESC, at + held);
        if (check == BACK_NOW) {
            return rig.press(WatchUi.KEY_ESC, at + held);
        } else if (check == BACK_WAIT && input.back.untouchedSince(at + held)) {
            return rig.press(WatchUi.KEY_ESC, at + held + BackGuard.WAIT_MS);
        }
        return INPUT_NONE;
    }
}

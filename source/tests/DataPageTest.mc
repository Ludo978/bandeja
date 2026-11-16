import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The data page (mockup "Data page"): its grid's texts, "--" for a value the watch doesn't
// give, this game's duration, and when it asks for a redraw (only when a text shown changed). And how
// the score screen's input works on it: a swipe left turns from the score page to the data
// page (then to the stats page, StatsPageTest), a swipe right back; UP, DOWN and BACK act exactly as on
// the score page, once, and bring the score page back with their flash, overlay or toast; START and hold
// UP open their menus over it.

(:test)
function dataPageGridTest(logger as Logger) as Boolean {
    // The mockup's values: 0:42:17 elapsed, 486 kcal, 2:14 this game. Zeros are values; a game past an
    // hour; a clock that went back during the game. A value the watch doesn't give reads "--" (no
    // activity info, no game once the match is over); the time of day is always there.
    var page = new DataPage();
    Test.assert(page.elapsed.equals("--") && page.calories.equals("--") && page.game.equals("--"));
    Test.assert(page.set(2537000, 486, 134, "10:42"));
    Test.assertEqual(page.elapsed + " " + page.calories + " " + page.game + " " + page.clock, "0:42:17 486 2:14 10:42");
    Test.assert(page.set(0, 0, 0, "10:42"));
    Test.assertEqual(page.elapsed + " " + page.calories + " " + page.game, "0:00:00 0 0:00");
    Test.assert(page.set(4000000, 900, 3723, "11:49") && page.game.equals("1:02:03"));
    Test.assert(page.set(4000000, 900, -30, "11:49") && page.game.equals("0:00"));
    Test.assert(page.set(null, null, null, "9:05"));
    Test.assertEqual(page.elapsed + " " + page.calories + " " + page.game + " " + page.clock, "-- -- -- 9:05");
    Test.assert(page.set(61000, null, 61, "9:05"));
    Test.assertEqual(page.elapsed + " " + page.calories + " " + page.game, "0:01:01 -- 1:01");
    return true;
}

(:test)
function dataPageRedrawTest(logger as Logger) as Boolean {
    // set() at 1 Hz is true only when a text shown changed: a timer read twice in the same second, the
    // same calories and the same minute ask for no redraw. Paused: the timer and the calories stand
    // still, this game's clock runs on (wall clock).
    var page = new DataPage();
    Test.assert(page.set(2537000, 486, 134, "10:42") && !page.set(2537000, 486, 134, "10:42") && !page.set(2537999, 486, 134, "10:42"));
    Test.assert(page.set(2538000, 486, 134, "10:42") && page.set(2538000, 487, 134, "10:42") && page.set(2538000, 487, 135, "10:42"));
    Test.assert(page.set(2538000, 487, 135, "10:43") && page.set(2538000, null, 135, "10:43") && !page.set(2538000, null, 135, "10:43"));
    Test.assert(page.set(2538000, null, 136, "10:43"));
    return true;
}

(:test)
function dataPageGameTimeTest(logger as Logger) as Boolean {
    // This game's duration runs from the end of the game before it (its winning point, or End set now),
    // the first game from the match start; points and the serve answers don't restart it; none
    // once the match is over.
    var test = new TestKit.Flow(false, false);
    Test.assertEqual(test.flow.start(TestKit.T0), STEP_MATCH);
    var match = test.flow.getMatch() as CurrentMatch;
    var t0 = TestKit.T0;
    Test.assertEqual(DataPage.gameSeconds(match.getState(), match.start, t0 + 134) as Number, 134);
    Test.assert(match.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, t0 + 20, TEAM_US)));
    var points = [60, 100, 150, 200];
    for (var i = 0; i < points.size(); i++) {
        Test.assert(match.add(new MatchEvent(EVENT_POINT_US, t0 + points[i], null)));
        if (i == 0) {
            Test.assertEqual(DataPage.gameSeconds(match.getState(), match.start, t0 + 134) as Number, 134);
        }
    }
    // The game won at t0 + 200: the next one from there.
    Test.assertEqual(DataPage.gameSeconds(match.getState(), match.start, t0 + 214) as Number, 14);
    // Its winning point undone: the first game again, from the match start. End set now at t0 + 300
    // (games level, given to us): the next set's first game from there. End match: no game.
    Test.assert(match.undo() != null);
    Test.assertEqual(DataPage.gameSeconds(match.getState(), match.start, t0 + 214) as Number, 214);
    Test.assert(match.add(new MatchEvent(EVENT_END_SET, t0 + 300, TEAM_US)));
    Test.assertEqual(DataPage.gameSeconds(match.getState(), match.start, t0 + 330) as Number, 30);
    Test.assert(match.add(new MatchEvent(EVENT_END_MATCH, t0 + 400, null)));
    Test.assert(DataPage.gameSeconds(match.getState(), match.start, t0 + 410) == null);
    return true;
}

(:test)
function dataPageSwipeTest(logger as Logger) as Boolean {
    // The score page first; a swipe left turns to the data page, a swipe right back to the score page.
    // A swipe right on the score page, other swipes and touches do nothing; a swipe left on the data
    // page turns to the stats page.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    Test.assert(motion.page == PAGE_SCORE && motion.isIdle(INPUT_PREVIOUS_PAGE) && rig.swipe(WatchUi.SWIPE_RIGHT, 900) == INPUT_PREVIOUS_PAGE);
    Test.assert(motion.page == PAGE_SCORE && rig.swipe(WatchUi.SWIPE_LEFT, 1000) == INPUT_NEXT_PAGE && motion.page == PAGE_DATA);
    Test.assert(!motion.isIdle(INPUT_NEXT_PAGE) && !motion.isIdle(INPUT_PREVIOUS_PAGE));
    Test.assert(rig.swipe(WatchUi.SWIPE_UP, 1200) == INPUT_NONE && motion.page == PAGE_DATA);
    Test.assert(rig.touch(1300) == INPUT_NONE && motion.page == PAGE_DATA);
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 1400) == INPUT_PREVIOUS_PAGE && motion.page == PAGE_SCORE && rig.getState().eventCount == 0);
    return true;
}

(:test)
function dataPagePointTest(logger as Logger) as Boolean {
    // UP and DOWN on the data page score as on the score page, once, and the score page comes back with
    // the point's flash. The debounce holds across the pages: a second press 300 ms later is ignored,
    // and leaves the data page up. A point that wins a game: the score page with the game's overlay;
    // the match point: the match's overlay, then the summary. A swipe left during the overlay ends it
    // and shows the data page.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    rig.swipe(WatchUi.SWIPE_LEFT, 1000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && motion.page == PAGE_SCORE);
    ScoreMotionTests.assertFlash(motion, 2000, TEAM_US);
    rig.swipe(WatchUi.SWIPE_LEFT, 2100);
    Test.assert(rig.press(WatchUi.KEY_UP, 2300) == INPUT_NONE && motion.page == PAGE_DATA);
    Test.assert(rig.press(WatchUi.KEY_UP, 2800) == INPUT_POINT && motion.page == PAGE_SCORE);
    ScoreMotionTests.assertFlash(motion, 2800, TEAM_THEM);
    rig.assertPoints(1, 1, "on the data page");
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    rig.swipe(WatchUi.SWIPE_LEFT, 1000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && rig.motion.page == PAGE_SCORE);
    Test.assert((rig.motion.getOverlayAt(2000) as ScoreOverlay).won == WON_GAME && rig.motion.getFlashAt(2000) == null);
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    rig.swipe(WatchUi.SWIPE_LEFT, 1000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && (rig.motion.getOverlayAt(2000) as ScoreOverlay).won == WON_MATCH);
    Test.assert(!rig.motion.takeSummary(3499) && rig.motion.takeSummary(3500));
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.swipe(WatchUi.SWIPE_LEFT, 1200) == INPUT_NEXT_PAGE);
    Test.assert(rig.ended != null && rig.motion.getOverlayAt(1200) == null && rig.motion.page == PAGE_DATA);
    return true;
}

(:test)
function dataPageUndoAndMenusTest(logger as Logger) as Boolean {
    // BACK on the data page undoes the last event with its toast, on the score page; with nothing left,
    // "Nothing to undo" there too. START pauses with the pause menu, hold UP opens the match menu: both
    // over the data page, which stays when they close; START resumes there. Paused, UP, DOWN and BACK
    // bring the score page back with "Paused" and change nothing.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "u");
    rig.swipe(WatchUi.SWIPE_LEFT, 1000);
    Test.assert(rig.press(WatchUi.KEY_ESC, 1100) == INPUT_UNDO && rig.motion.page == PAGE_SCORE && rig.input.toast == Rez.Strings.UndonePointUs);
    rig.swipe(WatchUi.SWIPE_LEFT, 1200);
    Test.assert(rig.press(WatchUi.KEY_ESC, 1300) == INPUT_TOAST && rig.input.toast == Rez.Strings.UndoneNothing && rig.motion.page == PAGE_SCORE);
    rig = ScoreMotionTests.screen(new MatchConfig(), "u");
    var motion = rig.motion;
    rig.swipe(WatchUi.SWIPE_LEFT, 1000);
    Test.assert(rig.press(WatchUi.KEY_MENU, 1100) == INPUT_MATCH_MENU && motion.page == PAGE_DATA);
    Test.assert(rig.press(WatchUi.KEY_ENTER, 1200) == INPUT_PAUSE && motion.page == PAGE_DATA);
    var keys = [WatchUi.KEY_UP, WatchUi.KEY_DOWN, WatchUi.KEY_ESC];
    for (var i = 0; i < keys.size(); i++) {
        if (motion.page == PAGE_SCORE) {
            rig.swipe(WatchUi.SWIPE_LEFT, 1300 + i * 1000);
        }
        Test.assert(rig.press(keys[i], 1500 + i * 1000) == INPUT_TOAST && rig.input.toast == Rez.Strings.ToastPaused && motion.page == PAGE_SCORE);
    }
    rig.assertPoints(1, 0, "paused");
    rig.swipe(WatchUi.SWIPE_LEFT, 5000);
    Test.assert(rig.press(WatchUi.KEY_ENTER, 5100) == INPUT_RESUME && motion.page == PAGE_DATA);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 6000) == INPUT_POINT && motion.page == PAGE_SCORE);
    return true;
}

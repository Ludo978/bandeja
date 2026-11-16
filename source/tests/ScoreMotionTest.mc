import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The score screen's motion: a point flashes the scoring team's half for 200 ms; a
// point that won a game, a set or the match shows the team-color overlay for 1.5 s instead, with the
// set (or TIE-BREAK) and the team, the word and the set's score, our side first, and the CHANGE ENDS
// pill when the players change ends after it; in a tie-break the change of ends toast instead; any
// press that does something during the overlay ends it and still counts, once; an undo never flashes;
// the match's overlay hands over to the summary. And the score screen's one Timer: when it
// wakes up next. Presses go
// through ScoreInput, then ScoreMotion, as ScoreDelegate passes them (TestKit.Rig.press()); times are
// System.getTimer() milliseconds, passed in.

(:test)
function scoreMotionFlashTest(logger as Logger) as Boolean {
    // Every point flashes its team's half for 200 ms; a press the debounce ignores doesn't, and neither
    // does an undo, which ends the flash of the point it takes back, nor "Nothing to undo". The next
    // point flashes (the undo ended the debounce). System.getTimer() wraps around after 24.8 days.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    Test.assert(motion.getFlashAt(1000) == null);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    ScoreMotionTests.assertFlash(motion, 1000, TEAM_US);
    Test.assert(motion.getOverlayAt(1000) == null);
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 2000), INPUT_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 2100), INPUT_NONE);
    ScoreMotionTests.assertFlash(motion, 2000, TEAM_THEM);
    Test.assertEqual(rig.press(WatchUi.KEY_ESC, 2150), INPUT_UNDO);
    Test.assert(motion.getFlashAt(2150) == null && motion.getFlashAt(2199) == null);
    Test.assertEqual(rig.press(WatchUi.KEY_ESC, 2300), INPUT_UNDO);
    Test.assert(rig.press(WatchUi.KEY_ESC, 2400) == INPUT_TOAST && rig.input.toast == Rez.Strings.UndoneNothing);
    Test.assert(motion.getFlashAt(2400) == null && motion.getOverlayAt(2400) == null);
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 2500), INPUT_POINT);
    ScoreMotionTests.assertFlash(motion, 2500, TEAM_THEM);
    var last = 0x7FFFFFFF - 100;
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, last), INPUT_POINT);
    ScoreMotionTests.assertFlash(motion, last, TEAM_US);
    rig.assertPoints(1, 1, "points and undos");
    return true;
}

(:test)
function scoreMotionOverlayTest(logger as Logger) as Boolean {
    // The "Game won" mockup: we lead 4-3 in set 2, 40-30; DOWN wins the game: in our color, SET 2 · US,
    // GAME, 5 - 3, for 1.5 s, with no flash under it. A game they win, 4-4: their color. A set they win
    // 6-2: SET 1 · THEM, SET, 2 - 6 (our side first). A set we win 7-6, 7-5 in the tie-break:
    // TIE-BREAK · US, SET, 7 - 5 (its points tell more than 7-6). The match won 6-0 6-1: SET 2 · US,
    // MATCH, 6 - 1; in the super tie-break, 10-8: the third set, TIE-BREAK · US, MATCH, 10 - 8; Tie-break
    // only the same, its one set. The
    // CHANGE ENDS pill only after the 7-6 set, the one game count that's odd (13); the match point
    // never brings it (6-1, 7 games).
    var cases = [
        [new MatchConfig(), ScoreMotionTests.GAME_POINT, WatchUi.KEY_DOWN, TEAM_US, WON_GAME, false, 2, [5, 3], false],
        [new MatchConfig(), "UTTTTTT UTUTUTU ttt", WatchUi.KEY_UP, TEAM_THEM, WON_GAME, false, 2, [4, 4], false],
        [new MatchConfig(), ScoreMotionTests.THEM_SET_POINT, WatchUi.KEY_UP, TEAM_THEM, WON_SET, false, 1, [2, 6], false],
        [new MatchConfig(), ScoreMotionTests.TIE_BREAK_SET_POINT, WatchUi.KEY_DOWN, TEAM_US, WON_SET, true, 1, [7, 5], true],
        [new MatchConfig(), ScoreMotionTests.MATCH_POINT, WatchUi.KEY_DOWN, TEAM_US, WON_MATCH, false, 2, [6, 1], false],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT uuuuuuuuutttttttt", WatchUi.KEY_DOWN, TEAM_US, WON_MATCH, true, 3, [10, 8], false],
        // Tie-break only: TIE-BREAK · US, MATCH, 7 - 5; to 10, lost 9-11. The 12th point
        // brings no change of ends: it's the match point.
        [TestKit.preset(PRESET_TIE_BREAK_7), "uuuuuttttt u", WatchUi.KEY_DOWN, TEAM_US, WON_MATCH, true, 1, [7, 5], false],
        [TestKit.preset(PRESET_TIE_BREAK_10), TestKit.repeat("ut", 9) + "t", WatchUi.KEY_UP, TEAM_THEM, WON_MATCH, true, 1, [9, 11],
            false]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var rig = ScoreMotionTests.screen(c[0] as MatchConfig, c[1] as String);
        Test.assert(rig.press(c[2] as WatchUi.Key, 1000) == INPUT_POINT && rig.input.won == c[4]);
        ScoreMotionTests.assertOverlay(rig.motion, 1000, c[3] as Team, c[4] as PointWon, c[5] as Boolean, c[6] as Number,
            c[7] as Array<Number>);
        Test.assert(rig.motion.getFlashAt(1000) == null && !rig.motion.endsToast);
        Test.assertEqualMessage((rig.motion.getOverlayAt(1000) as ScoreOverlay).changeEnds, c[8], "case " + i);
    }
    return true;
}

(:test)
function scoreMotionPressDuringOverlayTest(logger as Logger) as Boolean {
    // A press during the overlay ends it and scores exactly once. UP or DOWN 1 s
    // after the point that won the game (past the 800 ms debounce, within the 1.5 s overlay): one point,
    // no game, the overlay gone and the scoring half flashing.
    var keys = [WatchUi.KEY_UP, WatchUi.KEY_DOWN];
    for (var i = 0; i < keys.size(); i++) {
        var team = keys[i] == WatchUi.KEY_UP ? TEAM_THEM : TEAM_US;
        var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        var points = rig.getState().pointsWon[team];
        Test.assert(rig.press(keys[i], 2000) == INPUT_POINT && rig.input.won == WON_POINT);
        var state = rig.getState();
        Test.assert(state.pointsWon[team] == points + 1 && state.games[TEAM_US] == 5 && state.games[TEAM_THEM] == 3);
        Test.assert((rig.ended as ScoreOverlay).won == WON_GAME && rig.motion.getOverlayAt(2000) == null);
        Test.assertEqual(rig.motion.getFlashAt(2000) as Team, team);
    }
    // A press the debounce ignores (500 ms after) and a touch change nothing, so the overlay stays to its
    // end; the press after them counts.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    var overlay = rig.motion.getOverlayAt(1000);
    Test.assert(rig.press(WatchUi.KEY_UP, 1500) == INPUT_NONE && rig.ended == null);
    Test.assert(rig.touch(1600) == INPUT_NONE && rig.ended == null);
    Test.assert(rig.motion.getOverlayAt(2499) == overlay && rig.press(WatchUi.KEY_UP, 2499) == INPUT_POINT);
    Test.assert(rig.ended == overlay && rig.motion.getOverlayAt(2499) == null && rig.getState().gamePoints[TEAM_THEM] == 1);
    return true;
}

(:test)
function scoreMotionDebounceSettingTest(logger as Logger) as Boolean {
    // At each Press delay, all shorter than the 1.5 s overlay: a press the debounce
    // ignores, 1 ms under the value after the point that won the game, leaves the overlay up; the press
    // at the value ends it and scores once.
    var values = Settings.debounceChoices();
    for (var i = 0; i < values.size(); i++) {
        var wait = values[i];
        Test.assert(wait < ScoreMotion.OVERLAY);
        var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
        rig.input.debounce = wait;
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        var overlay = rig.motion.getOverlayAt(1000);
        Test.assert(overlay != null && rig.press(WatchUi.KEY_UP, 1000 + wait - 1) == INPUT_NONE && rig.ended == null);
        Test.assert(rig.motion.getOverlayAt(1000 + wait) == overlay && rig.press(WatchUi.KEY_UP, 1000 + wait) == INPUT_POINT);
        Test.assert(rig.ended == overlay && rig.motion.getOverlayAt(1000 + wait) == null);
        Test.assertMessage(rig.getState().gamePoints[TEAM_THEM] == 1 && rig.getState().games[TEAM_US] == 5, "at " + wait);
    }
    return true;
}

(:test)
function scoreMotionTapDuringOverlayTest(logger as Logger) as Boolean {
    // Touch scoring on: a tap counts like a press. A tap 1 s after the point that won the game
    // ends the overlay and scores once for the half tapped, that half flashing; a tap the debounce
    // ignores and any other touch leave the overlay up, as a press the debounce ignores does. Touch
    // scoring off, a tap leaves it up and scores nothing. A tap that wins game 1 brings the overlay,
    // with the CHANGE ENDS pill, and no flash.
    var ys = [100, 300];
    for (var i = 0; i < ys.size(); i++) {
        var team = i == 0 ? TEAM_THEM : TEAM_US;
        var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
        rig.input.touchScoring = true;
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        var overlay = rig.motion.getOverlayAt(1000);
        var points = rig.getState().pointsWon[team];
        Test.assert(rig.tap(ys[1 - i], 1500) == INPUT_NONE && rig.ended == null && rig.touch(1600) == INPUT_NONE);
        Test.assert(rig.ended == null && rig.motion.getOverlayAt(1999) == overlay);
        Test.assert(rig.tap(ys[i], 2000) == INPUT_POINT && rig.input.team == team && rig.input.won == WON_POINT);
        var state = rig.getState();
        Test.assert(state.pointsWon[team] == points + 1 && state.games[TEAM_US] == 5 && state.games[TEAM_THEM] == 3);
        Test.assert(rig.ended == overlay && rig.motion.getOverlayAt(2000) == null);
        Test.assertEqual(rig.motion.getFlashAt(2000) as Team, team);
    }
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    var events = rig.getState().eventCount;
    Test.assert(rig.tap(100, 2000) == INPUT_NONE && rig.ended == null && rig.motion.getOverlayAt(2000) != null);
    Test.assertEqual(rig.getState().eventCount, events);
    rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    rig.play("uuu");
    rig.input.touchScoring = true;
    Test.assert(rig.tap(400, 1000) == INPUT_POINT && rig.input.won == WON_GAME && rig.input.lap && rig.input.ends);
    ScoreMotionTests.assertOverlay(rig.motion, 1000, TEAM_US, WON_GAME, false, 1, [1, 0]);
    Test.assert((rig.motion.getOverlayAt(1000) as ScoreOverlay).changeEnds && rig.motion.getFlashAt(1000) == null);
    return true;
}

(:test)
function scoreMotionUndoDuringOverlayTest(logger as Logger) as Boolean {
    // BACK during the overlay undoes the point that won the game (or the set) and ends the overlay at
    // once, so it never claims a game that's gone; the toast names the point, and nothing flashes.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assert(rig.press(WatchUi.KEY_ESC, 1100) == INPUT_UNDO && rig.input.toast == Rez.Strings.UndonePointUs);
    Test.assertEqual((rig.ended as ScoreOverlay).won, WON_GAME);
    for (var t = 1100; t < 2600; t += 100) {
        Test.assert(rig.motion.getOverlayAt(t) == null && rig.motion.getFlashAt(t) == null);
    }
    Test.assertEqual(TestKit.game(rig.getState()), "4-3 40-30");
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.THEM_SET_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 1000), INPUT_POINT);
    Test.assert(rig.press(WatchUi.KEY_ESC, 2400) == INPUT_UNDO && (rig.ended as ScoreOverlay).won == WON_SET);
    Test.assert(rig.motion.getOverlayAt(2400) == null && TestKit.sets(rig.getState()).equals("| 2-5 0-40"));
    return true;
}

(:test)
function scoreMotionOtherInputsDuringOverlayTest(logger as Logger) as Boolean {
    // START (pause), hold UP (match menu) and a swipe left (data page) during the overlay each do what
    // they do, end the overlay, and score nothing.
    for (var i = 0; i < 3; i++) {
        var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        var events = rig.getState().eventCount;
        var action = i == 0 ? rig.press(WatchUi.KEY_ENTER, 1200) : i == 1 ? rig.press(WatchUi.KEY_MENU, 1200)
            : rig.swipe(WatchUi.SWIPE_LEFT, 1200);
        Test.assertEqual(action, [INPUT_PAUSE, INPUT_MATCH_MENU, INPUT_NEXT_PAGE][i]);
        Test.assert(rig.ended != null && rig.motion.getOverlayAt(1200) == null && rig.motion.getFlashAt(1200) == null);
        Test.assertEqual(rig.getState().eventCount, events);
    }
    return true;
}

(:test)
function scoreMotionSummaryTest(logger as Logger) as Boolean {
    // The match's overlay hands over to the summary once its 1.5 s are over, once; a press the
    // debounce ignores leaves it, and a late wake-up still hands over.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    var motion = rig.motion;
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 1300), INPUT_NONE);
    Test.assert(!motion.takeSummary(1000) && !motion.takeSummary(2499) && motion.takeSummary(2500) && !motion.takeSummary(2600));
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assert(rig.motion.takeSummary(4000));

    // UP or DOWN during it: refused, the match is over ("Match over"), and the summary at once.
    var keys = [WatchUi.KEY_UP, WatchUi.KEY_DOWN];
    for (var i = 0; i < keys.size(); i++) {
        rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        var events = rig.getState().eventCount;
        Test.assert(rig.press(keys[i], 1900) == INPUT_TOAST && rig.input.toast == Rez.Strings.ToastMatchOver);
        Test.assert((rig.ended as ScoreOverlay).won == WON_MATCH && rig.motion.getOverlayAt(1900) == null);
        Test.assert(rig.getState().eventCount == events && rig.motion.takeSummary(1900) && !rig.motion.takeSummary(2500));
    }

    // BACK during it: the match point undone, play goes on, no summary. START: the pause menu over the
    // score screen, no summary either. A game or a set never hands over.
    keys = [WatchUi.KEY_ESC, WatchUi.KEY_ENTER];
    for (var i = 0; i < keys.size(); i++) {
        rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
        Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
        Test.assertEqual(rig.press(keys[i], 1200), i == 0 ? INPUT_UNDO : INPUT_PAUSE);
        Test.assert(rig.getState().matchOver == (i == 1) && !rig.motion.takeSummary(2500) && !rig.motion.takeSummary(10000));
    }
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.THEM_SET_POINT);
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 1000), INPUT_POINT);
    Test.assert(!rig.motion.takeSummary(2500));
    return true;
}

(:test)
function scoreMotionChangeOfEndsTest(logger as Logger) as Boolean {
    // The change of ends on screen, from ScoreInput.ends: the CHANGE ENDS pill on
    // the overlay of a game or a set after which the players change ends; in a tie-break and the super
    // tie-break, where no overlay shows, the toast on the net. After games 1 and 3 of a set, a game won
    // again after its winning point was undone, a set with an odd game count, every 6 points of a
    // tie-break. Not after games 2 and 4, an undo, a press the debounce ignores, nor the match point (an
    // odd game count, 3-2 7-0); none at all with the Change of ends alert off, where every overlay comes
    // without the pill. Sets to 2 games, a tie-break at 2-2, as ScoreInput's test (d: DOWN, u: UP, <:
    // BACK; P: an overlay with the pill, O: one without, T: the toast, .: neither).
    var steps = [
        ["dddd", "...P"], ["<d", ".P"], ["uuuu", "...O"], ["uuuu", "...P"], ["dddd", "...O"],
        ["dududu", ".....T"], ["dududu", ".....T"], ["dd", ".P"],
        ["dddd", "...P"], ["uuuu", "...O"], ["dddd", "...P"], ["uuuu", "...O"], ["ddddddd", ".....TO"],
        ["<d", ".O"]
    ];
    for (var alert = 1; alert >= 0; alert--) {
        var rig = new TestKit.Rig(TestKit.format(2, 2, 2, true), "Me", false);
        rig.motion.endsAlert = alert == 1;
        var now = 1000;
        for (var i = 0; i < steps.size(); i++) {
            var keys = steps[i][0].toCharArray();
            var expected = steps[i][1].toCharArray();
            for (var j = 0; j < keys.size(); j++) {
                now += 1000;
                var key = keys[j] == '<' ? WatchUi.KEY_ESC : keys[j] == 'd' ? WatchUi.KEY_DOWN : WatchUi.KEY_UP;
                var message = "alert " + alert + ", step " + i + ", press " + j + ": " + TestKit.sets(rig.getState());
                Test.assertMessage(rig.press(key, now) != INPUT_NONE, message);
                var shown = expected[j];
                if (alert == 0) {
                    shown = shown == 'P' ? 'O' : shown == 'T' ? '.' : shown;
                }
                Test.assertEqualMessage(ScoreMotionTests.endsShown(rig.motion, now), shown, message);
            }
            if (i == 0) {
                // The debounce ignores a press 300 ms after the game: the overlay stays, pill and all, and no toast.
                Test.assert(rig.press(WatchUi.KEY_DOWN, now + 300) == INPUT_NONE && rig.ended == null);
                Test.assertEqual(ScoreMotionTests.endsShown(rig.motion, now + 300), alert == 1 ? 'P' : 'O');
            }
        }
        Test.assert(rig.getState().matchOver && TestKit.sets(rig.getState()).find("3-2(8-6) 3-2(7-0) | ") == 0);
    }
    return true;
}

(:test)
function scoreMotionPressDuringChangeOfEndsTest(logger as Logger) as Boolean {
    // A press during the overlay with the pill or during the toast counts once, as
    // without them. UP 1 s after the point that won game 1: the overlay ends, THEM one point (1-0
    // 0-15), their half flashing. DOWN 1 s after a tie-break's 6th point adds the 7th, brings no toast
    // of its own, and leaves the 6th point's toast to its 2 s, which the timer wakes up for.
    var rig = ScoreMotionTests.screen(TestKit.format(2, 2, 2, true), "uuu");
    Test.assertEqual(rig.press(WatchUi.KEY_DOWN, 1000), INPUT_POINT);
    Test.assertEqual(ScoreMotionTests.endsShown(rig.motion, 1000), 'P');
    Test.assert(rig.press(WatchUi.KEY_UP, 2000) == INPUT_POINT && rig.input.won == WON_POINT);
    Test.assert((rig.ended as ScoreOverlay).changeEnds && rig.motion.getOverlayAt(2000) == null && !rig.motion.endsToast);
    Test.assert(TestKit.game(rig.getState()).equals("1-0 0-15") && rig.motion.getFlashAt(2000) == TEAM_THEM);

    rig = ScoreMotionTests.screen(TestKit.format(2, 2, 2, true), "UTUT ututu");
    var toast = new Toast();
    rig.motion.startTicks(10600);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 10000) == INPUT_POINT && rig.input.ends && rig.motion.endsToast);
    toast.showAt("Change ends", 10000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 11000) == INPUT_POINT && !rig.input.ends && !rig.motion.endsToast);
    Test.assert(TestKit.game(rig.getState()).equals("2-2 5-2") && rig.motion.getFlashAt(11000) == TEAM_US);
    ScoreMotionTests.assertWakes(rig.motion, toast, 11000, 12500, [11200, 11600, 12000]);
    Test.assert(toast.getTextAt(11999) != null && toast.getTextAt(12000) == null);
    return true;
}

(:test)
function scoreMotionTickTest(logger as Logger) as Boolean {
    // The 1 Hz tick: a second after the screen shows, then every second on the same beat, from now after
    // a wake-up more than a second late, across the timer's wrap.
    var motion = new ScoreMotion();
    motion.startTicks(10000);
    Test.assert(motion.tickAt == 11000 && !motion.tick(10999) && motion.tick(11000) && motion.tickAt == 12000);
    Test.assert(motion.tick(12040) && motion.tickAt == 13000);
    Test.assert(motion.tick(14500) && motion.tickAt == 15500);
    var start = 0x7FFFFFFF - 400;
    motion.startTicks(start);
    Test.assert(!motion.tick(start + 999) && motion.tick(start + 1000) && motion.tickAt == start + 2000);
    return true;
}

(:test)
function scoreMotionNextWakeTest(logger as Logger) as Boolean {
    // The wait until the first of the tick, the flash's end, the overlay's end and the toast's end,
    // never under 50 ms.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    var motion = rig.motion;
    motion.startTicks(10000);
    Test.assert(motion.nextWake(10000, null) == 1000 && motion.nextWake(10600, null) == 400);
    Test.assert(motion.nextWake(10600, 10700) == 100 && motion.nextWake(10600, 12000) == 400);
    Test.assert(motion.nextWake(10980, null) == ScoreMotion.MIN_WAIT && motion.nextWake(11300, null) == ScoreMotion.MIN_WAIT);
    // The flash: its end, unless the tick comes first.
    Test.assert(motion.tick(11300) && rig.press(WatchUi.KEY_UP, 11300) == INPUT_POINT);
    Test.assert(motion.nextWake(11300, null) == ScoreMotion.FLASH && motion.nextWake(11480, null) == ScoreMotion.MIN_WAIT);
    Test.assertEqual(motion.nextWake(11500, null), 500);
    // The overlay: its end, after the ticks before it. 40-40, AD, then DOWN wins the game.
    Test.assert(motion.tick(12000) && rig.press(WatchUi.KEY_DOWN, 12100) == INPUT_POINT);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 12900) == INPUT_POINT && rig.input.won == WON_GAME);
    Test.assert(motion.nextWake(12900, null) == 100 && motion.tick(13000) && motion.nextWake(13000, null) == 1000);
    Test.assert(motion.tick(14000) && motion.nextWake(14000, null) == 400 && motion.nextWake(14000, 14300) == 300);
    Test.assertEqual(motion.nextWake(14400, null), 600);
    // The match's overlay: the summary's hand-over comes with its end, and stays due until taken.
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    motion = rig.motion;
    motion.startTicks(20000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 20000) == INPUT_POINT && motion.tick(21000) && motion.nextWake(21000, null) == 500);
    Test.assert(motion.nextWake(21600, null) == ScoreMotion.MIN_WAIT && motion.takeSummary(21600) && motion.nextWake(21600, null) == 400);
    return true;
}

(:test)
function scoreMotionOneTimerTest(logger as Logger) as Boolean {
    // The score screen's one Timer through a busy minute: the undo toast, a flash, then a set won by
    // them. It wakes up for each end in turn and for the ticks, and for nothing else. The set wrote its
    // lap, so Feedback plays nothing for it (the watch's lap alert does); won again after an undo, or
    // for the match, it plays the 3 long pulses on its own Timer, 1150 ms after the press: 2
    // Timers at most on the score screen (the toast has none of its own there), under the 3 Connect IQ
    // starts by default.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.THEM_SET_POINT);
    var motion = rig.motion;
    var toast = new Toast();
    motion.startTicks(10000);
    // BACK at 10100: their last point undone, 2-5 0-30, the toast until 12100.
    Test.assertEqual(rig.press(WatchUi.KEY_ESC, 10100), INPUT_UNDO);
    toast.showAt("Undone: point THEM", 10100);
    ScoreMotionTests.assertWakes(motion, toast, 10100, 10400, [] as Array<Number>);
    // UP at 10400: 0-40 again, their flash. UP at 12300: their set, its overlay until 13800.
    Test.assertEqual(rig.press(WatchUi.KEY_UP, 10400), INPUT_POINT);
    ScoreMotionTests.assertWakes(motion, toast, 10400, 12300, [10600, 11000, 12000, 12100]);
    Test.assert(rig.press(WatchUi.KEY_UP, 12300) == INPUT_POINT && rig.input.won == WON_SET);
    ScoreMotionTests.assertWakes(motion, toast, 12300, 15500, [13000, 13800, 14000, 15000]);
    var channels = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    Test.assert(rig.input.lap && !rig.input.ends && FeedbackPlan.point(TEAM_THEM, WON_SET, rig.input.lap, rig.input.ends, channels).isEmpty());
    var plan = FeedbackPlan.point(TEAM_THEM, WON_SET, false, false, channels);
    Test.assert(plan.calls.size() == 2 && plan.starts[1] == 1150);
    return true;
}

(:test)
module ScoreMotionTests {

    // Positions, one press from what the tests need. The "Game won" mockup: 1-6, 4-3, 40-30; DOWN wins
    // the game. 2-5, 0-40; UP wins the set for them. 6-6, 6-5 in the tie-break; DOWN wins it 7-5. 6-0,
    // 5-1, 40-0; DOWN wins the match.
    const GAME_POINT = "UTTTTTT UTUTUTU ututu";
    const THEM_SET_POINT = "UTTUTTT ttt";
    const TIE_BREAK_SET_POINT = "UTUTUTUTUTUT uuuuuuttttt";
    const MATCH_POINT = "UUUUUU UUUUUT uuu";

    // The score screen over a match started through the warm-up flow (Warm-up phase off), after moves.
    function screen(config as MatchConfig, moves as String) as TestKit.Rig {
        var rig = new TestKit.Rig(config, "", false);
        rig.play(moves);
        return rig;
    }

    // The team's half flashes from at for ScoreMotion.FLASH ms, not before, not after.
    function assertFlash(motion as ScoreMotion, at as Number, team as Team) as Void {
        Test.assert(motion.getFlashAt(at - 1) != team && motion.getFlashAt(at) == team);
        Test.assert(motion.getFlashAt(at + ScoreMotion.FLASH - 1) == team && motion.getFlashAt(at + ScoreMotion.FLASH) == null);
    }

    // The overlay shows from at for ScoreMotion.OVERLAY ms, for the team (drawn in its color), with these
    // text keys and numbers.
    function assertOverlay(motion as ScoreMotion, at as Number, team as Team, won as PointWon, tieBreak as Boolean,
            setNumber as Number, score as Array<Number>) as Void {
        var overlay = motion.getOverlayAt(at) as ScoreOverlay;
        Test.assert(overlay.team == team);
        Test.assert(overlay.won == won && ScoreOverlay.wordString(overlay.won)
            == (won == WON_GAME ? Rez.Strings.OverlayGame : won == WON_SET ? Rez.Strings.OverlaySet : Rez.Strings.OverlayMatch));
        Test.assert(overlay.tieBreak == tieBreak
            && ScoreOverlay.contextString(overlay.tieBreak) == (tieBreak ? Rez.Strings.BannerTieBreak : Rez.Strings.CaptionSet));
        Test.assertMessage(overlay.setNumber == setNumber && overlay.score[TEAM_US] == score[0] && overlay.score[TEAM_THEM] == score[1],
            "set " + overlay.setNumber + ", score " + overlay.score);
        Test.assert(motion.getOverlayAt(at - 1) == null && motion.getOverlayAt(at + ScoreMotion.OVERLAY - 1) == overlay);
        Test.assert(motion.getOverlayAt(at + ScoreMotion.OVERLAY) == null);
    }

    // What the change of ends puts on screen at now (scoreMotionChangeOfEndsTest): P an overlay with the
    // CHANGE ENDS pill, O one without, T the toast the last input brought, . neither.
    function endsShown(motion as ScoreMotion, now as Number) as Char {
        var overlay = motion.getOverlayAt(now);
        if (overlay != null) {
            return overlay.changeEnds ? 'P' : 'O';
        }
        return motion.endsToast ? 'T' : '.';
    }

    // Runs the score screen's timer from `from` until `to`, as ScoreView does (at each wake-up the tick,
    // then the next wake-up), and checks when it woke up.
    function assertWakes(motion as ScoreMotion, toast as Toast, from as Number, to as Number, expected as Array<Number>) as Void {
        var wakes = [] as Array<Number>;
        var now = from;
        while (wakes.size() <= expected.size()) {
            now += motion.nextWake(now, toast.getEndAt(now));
            if (now > to) {
                break;
            }
            motion.tick(now);
            wakes.add(now);
        }
        Test.assertMessage(wakes.toString().equals(expected.toString()), "woke up at " + wakes + ", expected " + expected);
    }
}

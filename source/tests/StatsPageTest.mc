import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The stats page (mockup "Stats page"): the points won %, the serve points won %, the
// average time per point and our best streak, "--" for what serve tracking off or an empty match
// doesn't give; the ring split between our points and theirs; the values following every point and
// undo, read from the tally (MatchState.getStats(), no replay). And how the score screen's input works
// on it: the third page, a swipe left from the data page, a swipe right back to it; UP,
// DOWN and BACK act as on the score page, once, and bring the score page back; START and hold UP open
// their menus over it. The match menu's Stats page shows it from the score page and the data page.

(:test)
function statsPageTextsTest(logger as Logger) as Boolean {
    // The mockup's: 21-17 points (55 %), 14 of 21 serve points (67 %), 0:42 a point, a best streak of 6.
    // The average as the data page writes a duration, m:ss (h:mm:ss past an hour, which no point lasts).
    var page = new StatsPage();
    Test.assertEqual(StatsPageTests.texts(page), "-- -- -- 0");
    var stats = new MatchStats();
    stats.pointsWon = 21;
    stats.pointsLost = 17;
    stats.servePointsPlayed = 21;
    stats.servePointsWon = 14;
    stats.averagePointTime = 42;
    stats.longestStreak = 6;
    page.set(stats);
    Test.assertEqual(StatsPageTests.texts(page), "55% 67% 0:42 6");
    Test.assert(page.won == 21 && page.lost == 17);
    stats.averagePointTime = 75;
    page.set(stats);
    Test.assertEqual(page.average, "1:15");
    stats.averagePointTime = 3725;
    page.set(stats);
    Test.assertEqual(page.average, "1:02:05");
    stats.averagePointTime = 0;
    page.set(stats);
    Test.assertEqual(page.average, "0:00");
    // Serve tracking off: no serve stats, the others as with it on. We haven't served yet: no serve %.
    // They won every point: 0 %, a streak of 0.
    stats = new MatchStats();
    stats.pointsLost = 3;
    stats.averagePointTime = 31;
    page.set(stats);
    Test.assertEqual(StatsPageTests.texts(page), "0% -- 0:31 0");
    stats.servePointsPlayed = 0;
    stats.servePointsWon = 0;
    page.set(stats);
    Test.assertEqual(StatsPageTests.texts(page), "0% -- 0:31 0");
    // An empty match: no percentage, no average, a streak of 0.
    page.set(new MatchStats());
    Test.assertEqual(StatsPageTests.texts(page), "-- -- -- 0");
    Test.assert(page.won == 0 && page.lost == 0);

    // The "Mockup: stats" fixture shows the mockup's values: 42 s a point from the match start.
    var fixtures = ScoreFixtures.all();
    var fixture = fixtures[fixtures.size() - 1];
    Test.assertEqual(fixture.name, "Mockup: stats");
    var engine = fixture.engine(TestKit.T0);
    page.set(engine.getState().getStats(TestKit.T0));
    Test.assertEqual(StatsPageTests.texts(page), "55% 67% 0:42 6");
    Test.assert(page.won == 21 && page.lost == 17);
    return true;
}

(:test)
function statsPageRingTest(logger as Logger) as Boolean {
    // The data page's ring, 240° from 210° (bottom left) to -30° (bottom right): our points from its
    // left end in our color, theirs after a 3° gap in their color, split as the points are (21-17: at
    // 77.4°). One team only: the whole ring in its color. No point: the whole ring INACTIVE. A team's
    // part shorter than 1° once the gap is taken out isn't drawn. The same in each theme, in its
    // team colors.
    var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
    for (var i = 0; i < themes.size(); i++) {
        var theme = themes[i];
        Test.assertEqual(StatsPageTests.ring(theme, 21, 17), "US 78.9 210.0, THEM -30.0 75.9");
        Test.assertEqual(StatsPageTests.ring(theme, 1, 1), "US 91.5 210.0, THEM -30.0 88.5");
        Test.assertEqual(StatsPageTests.ring(theme, 0, 0), "INACTIVE -30.0 210.0");
        Test.assertEqual(StatsPageTests.ring(theme, 5, 0), "US -30.0 210.0");
        Test.assertEqual(StatsPageTests.ring(theme, 0, 4), "THEM -30.0 210.0");
        Test.assertEqual(StatsPageTests.ring(theme, 1, 199), "THEM -30.0 207.3");
        Test.assertEqual(StatsPageTests.ring(theme, 199, 1), "US -27.3 210.0");
        Test.assertEqual(StatsPageTests.ring(theme, 1, 59), "US 207.5 210.0, THEM -30.0 204.5");
        Test.assertEqual(StatsPageTests.ring(theme, 1, 99), "THEM -30.0 206.1");
    }
    return true;
}

(:test)
function statsPageFollowsTest(logger as Logger) as Boolean {
    // The page's values follow every point and undo (TestKit's events 30 s apart, the match started
    // with the first): worked out again from the tally only when the state changed, and always equal
    // to the full replay's (StatsCalculator). Serve tracking on, we serve first.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    var page = new StatsPage();
    var steps = [
        ["", "-- -- -- 0"],
        ["u", "100% 100% 0:30 1"],
        ["t", "50% 50% 0:30 1"],
        ["<", "100% 100% 0:30 1"],
        ["uuu", "100% 100% 0:30 4"],
        ["tuuu", "88% 100% 0:30 4"],
        ["<<<<<", "100% 100% 0:30 3"],
        ["<<<", "-- -- -- 0"]
    ];
    for (var i = 0; i < steps.size(); i++) {
        rig.play(steps[i][0] as String);
        var state = rig.getState();
        Test.assertMessage(page.show(state, rig.match.start) == (i == 0 || !(steps[i][0] as String).equals("")),
            "step " + i + " worked out");
        Test.assert(!page.show(state, rig.match.start));
        Test.assertEqualMessage(StatsPageTests.texts(page), steps[i][1], "step " + i);
        var reference = new StatsPage();
        reference.set(StatsCalculator.compute(rig.engine.getConfig(), rig.engine.getLog(), rig.match.start) as MatchStats);
        Test.assertEqualMessage(StatsPageTests.texts(page), StatsPageTests.texts(reference), "step " + i + ", replay");
    }
    // A menu's event changes the state under the page: Fix serving team to them makes our serve points
    // theirs.
    rig.play("uut");
    Test.assert(page.show(rig.getState(), rig.match.start));
    Test.assertEqual(StatsPageTests.texts(page), "67% 67% 0:30 2");
    rig.add(EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    Test.assert(page.show(rig.getState(), rig.match.start));
    Test.assertEqual(StatsPageTests.texts(page), "67% -- 0:30 2");
    return true;
}

(:test)
function statsPageSwipeTest(logger as Logger) as Boolean {
    // The third page: a swipe left on the data page, a swipe right back to the data page, then to the
    // score page. A swipe left on the stats page, other swipes and touches do nothing. The match menu's
    // Data page shows the data page from the stats page and from the score page, nothing on it.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, 1000) == INPUT_NEXT_PAGE && motion.page == PAGE_DATA);
    Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, 1100) == INPUT_NEXT_PAGE && motion.page == PAGE_STATS);
    Test.assert(motion.isIdle(INPUT_NEXT_PAGE) && rig.swipe(WatchUi.SWIPE_LEFT, 1200) == INPUT_NEXT_PAGE && motion.page == PAGE_STATS);
    Test.assert(rig.swipe(WatchUi.SWIPE_UP, 1300) == INPUT_NONE && rig.swipe(WatchUi.SWIPE_DOWN, 1400) == INPUT_NONE);
    Test.assert(rig.touch(1500) == INPUT_NONE && motion.page == PAGE_STATS);
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 1600) == INPUT_PREVIOUS_PAGE && motion.page == PAGE_DATA);
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 1700) == INPUT_PREVIOUS_PAGE && motion.page == PAGE_SCORE);
    Test.assert(motion.isIdle(INPUT_PREVIOUS_PAGE) && rig.getState().eventCount == 0);
    motion.page = PAGE_STATS;
    Test.assert(motion.showPage(PAGE_DATA) && motion.page == PAGE_DATA && !motion.showPage(PAGE_DATA) && motion.page == PAGE_DATA);
    motion.page = PAGE_SCORE;
    Test.assert(motion.showPage(PAGE_DATA) && motion.page == PAGE_DATA);
    return true;
}

(:test)
function statsPageMenuItemTest(logger as Logger) as Boolean {
    // The match menu's Stats page (after Data page, 2026-11-13) shows the stats page from the score page
    // and from the data page, nothing on it; Data page brings the data page back from it. The page so
    // shown works as when swiped to: a swipe right turns to the data page, a swipe left does nothing,
    // DOWN scores once with the score page back.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    Test.assert(motion.showPage(PAGE_STATS) && motion.page == PAGE_STATS);
    Test.assert(!motion.showPage(PAGE_STATS) && motion.page == PAGE_STATS);
    Test.assert(motion.showPage(PAGE_DATA) && motion.page == PAGE_DATA);
    Test.assert(motion.showPage(PAGE_STATS) && motion.page == PAGE_STATS);
    Test.assert(motion.isIdle(INPUT_NEXT_PAGE) && rig.swipe(WatchUi.SWIPE_LEFT, 1000) == INPUT_NEXT_PAGE && motion.page == PAGE_STATS);
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 1100) == INPUT_PREVIOUS_PAGE && motion.page == PAGE_DATA);
    Test.assert(motion.showPage(PAGE_STATS) && rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && motion.page == PAGE_SCORE);
    ScoreMotionTests.assertFlash(motion, 2000, TEAM_US);
    rig.assertPoints(1, 0, "from the menu's stats page");

    // At the match end, hold UP during the match's overlay, then Stats page: it stays when the screen
    // shows again, as the data page does, until the player is back on the score page: the summary then.
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    motion = rig.motion;
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.press(WatchUi.KEY_MENU, 1200) == INPUT_MATCH_MENU);
    Test.assert(motion.showPage(PAGE_STATS));
    motion.shown(rig.getState(), 3000);
    Test.assert(!motion.takeSummary(9000) && rig.swipe(WatchUi.SWIPE_RIGHT, 9000) == INPUT_PREVIOUS_PAGE);
    Test.assert(motion.page == PAGE_DATA && !motion.takeSummary(9000));
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 9100) == INPUT_PREVIOUS_PAGE && motion.takeSummary(9100));
    return true;
}

(:test)
function statsPagePointTest(logger as Logger) as Boolean {
    // UP and DOWN on the stats page score as on the score page, once, and the score page comes back with
    // the point's flash; a second press within the debounce is ignored and leaves the stats page up. A
    // point that wins a game: the score page with the game's overlay. BACK undoes with its toast, on the
    // score page.
    var rig = ScoreMotionTests.screen(new MatchConfig(), "");
    var motion = rig.motion;
    StatsPageTests.turnTo(rig, 1000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && motion.page == PAGE_SCORE);
    ScoreMotionTests.assertFlash(motion, 2000, TEAM_US);
    StatsPageTests.turnTo(rig, 2100);
    Test.assert(rig.press(WatchUi.KEY_UP, 2300) == INPUT_NONE && motion.page == PAGE_STATS);
    Test.assert(rig.press(WatchUi.KEY_UP, 2800) == INPUT_POINT && motion.page == PAGE_SCORE);
    ScoreMotionTests.assertFlash(motion, 2800, TEAM_THEM);
    rig.assertPoints(1, 1, "on the stats page");
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.GAME_POINT);
    StatsPageTests.turnTo(rig, 1000);
    Test.assert(rig.press(WatchUi.KEY_DOWN, 2000) == INPUT_POINT && rig.motion.page == PAGE_SCORE);
    Test.assert((rig.motion.getOverlayAt(2000) as ScoreOverlay).won == WON_GAME && rig.motion.getFlashAt(2000) == null);
    rig = ScoreMotionTests.screen(new MatchConfig(), "u");
    StatsPageTests.turnTo(rig, 1000);
    Test.assert(rig.press(WatchUi.KEY_ESC, 1100) == INPUT_UNDO && rig.motion.page == PAGE_SCORE);
    Test.assert(rig.input.toast == Rez.Strings.UndonePointUs);
    rig.assertPoints(0, 0, "undone on the stats page");

    // START pauses with the pause menu and hold UP opens the match menu, over the stats page, which
    // stays; paused, UP brings the score page with "Paused" and changes nothing; START resumes there.
    rig = ScoreMotionTests.screen(new MatchConfig(), "u");
    motion = rig.motion;
    StatsPageTests.turnTo(rig, 1000);
    Test.assert(rig.press(WatchUi.KEY_MENU, 1100) == INPUT_MATCH_MENU && motion.page == PAGE_STATS);
    Test.assert(rig.press(WatchUi.KEY_ENTER, 1200) == INPUT_PAUSE && motion.page == PAGE_STATS);
    Test.assert(rig.press(WatchUi.KEY_UP, 1300) == INPUT_TOAST && rig.input.toast == Rez.Strings.ToastPaused);
    Test.assert(motion.page == PAGE_SCORE);
    rig.assertPoints(1, 0, "paused");
    StatsPageTests.turnTo(rig, 1400);
    Test.assert(rig.press(WatchUi.KEY_ENTER, 1500) == INPUT_RESUME && motion.page == PAGE_STATS);
    return true;
}

(:test)
function statsPageMatchOverTest(logger as Logger) as Boolean {
    // At the match end, the stats page reached during the match's overlay stays, as the data page does,
    // until the player is back on the score page: the summary then. UP or DOWN there: "Match over" on
    // the score page, and the summary.
    var rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    var motion = rig.motion;
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT && rig.swipe(WatchUi.SWIPE_LEFT, 1200) == INPUT_NEXT_PAGE);
    Test.assert(rig.swipe(WatchUi.SWIPE_LEFT, 1300) == INPUT_NEXT_PAGE && motion.page == PAGE_STATS);
    motion.shown(rig.getState(), 3000);
    Test.assert(!motion.takeSummary(9000) && rig.swipe(WatchUi.SWIPE_RIGHT, 9000) == INPUT_PREVIOUS_PAGE);
    Test.assert(motion.page == PAGE_DATA && !motion.takeSummary(9000));
    Test.assert(rig.swipe(WatchUi.SWIPE_RIGHT, 9100) == INPUT_PREVIOUS_PAGE && motion.takeSummary(9100));
    rig = ScoreMotionTests.screen(new MatchConfig(), ScoreMotionTests.MATCH_POINT);
    motion = rig.motion;
    Test.assert(rig.press(WatchUi.KEY_DOWN, 1000) == INPUT_POINT);
    StatsPageTests.turnTo(rig, 1200);
    Test.assert(rig.press(WatchUi.KEY_UP, 4000) == INPUT_TOAST && rig.input.toast == Rez.Strings.ToastMatchOver);
    Test.assert(motion.page == PAGE_SCORE && motion.takeSummary(4000));
    return true;
}

(:test)
module StatsPageTests {

    // "55% 67% 0:42 6": the points won %, the serve points won %, the average time per point and the
    // best streak as the page shows them.
    function texts(page as StatsPage) as String {
        var points = page.points + (page.points.equals(StatsPage.NONE) ? "" : "%");
        return points + " " + page.serve + " " + page.average + " " + page.streak;
    }

    // The ring's arcs for the points won and lost in a theme, as "US 78.9 210.0, THEM -30.0 75.9", US
    // and THEM the theme's team colors.
    function ring(theme as ThemeSetting, won as Number, lost as Number) as String {
        var arcs = StatsPage.ringArcs(won, lost, theme);
        var text = "";
        for (var i = 0; i < arcs.size(); i++) {
            var arc = arcs[i];
            var color = arc[0] == Palette.teamColor(theme, TEAM_US) ? "US" : arc[0] == Palette.teamColor(theme, TEAM_THEM) ? "THEM"
                : arc[0] == Palette.INACTIVE ? "INACTIVE" : "?";
            text += (i == 0 ? "" : ", ") + color + " " + arc[1].format("%.1f") + " " + arc[2].format("%.1f");
        }
        return text;
    }

    // Two swipes left from the score page at now: the stats page.
    function turnTo(rig as TestKit.Rig, now as Number) as Void {
        Test.assert(rig.motion.page == PAGE_SCORE);
        rig.swipe(WatchUi.SWIPE_LEFT, now);
        rig.swipe(WatchUi.SWIPE_LEFT, now + 10);
        Test.assert(rig.motion.page == PAGE_STATS);
    }
}

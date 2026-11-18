import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The pause menu (START) and the match menu (hold UP) without their native menus:
// which items show for the match as it stands, the value under the items that set one, and what each
// item logs through the match holder, so that BACK on the score screen undoes it with its toast and
// gives back the exact state before (TestKit.Rig.assertUndone()). Swap our server order isn't
// offered in singles, and no event item once the match is over (the engine refuses them). End set now gives
// the set to the team ahead and asks Us / Them when the set is level; End match ends with
// the early end result. Save from the pause writes the result as it stands.
//
// Logged events are written as their codes (MatchEvent.getCode()): 2 SWAP_OUR_SERVER, 103 / 203
// FIX_SERVING_TEAM Us / Them, 104 / 204 SET_DEUCE_MODE Advantage / Golden point, 5 END_SET to the team
// ahead, 105 / 205 END_SET given to Us / Them, 6 END_MATCH.

(:test)
function matchMenuItemsTest(logger as Logger) as Boolean {
    // Doubles: every pause menu item in its order; the match menu's, Stats page after Data page, Edit score in the
    // match menu only, Touch scoring last. The server is unknown (no serve answer): Fix serving team is there, it starts serve
    // tracking. Once the match is over (End match, or a point that wins it) only what logs nothing,
    // Edit score gone too, the settings kept; BACK brings the rest back. Singles: no Swap our server
    // order, our only player serves our games.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var pause = [ITEM_RESUME, ITEM_END_MATCH, ITEM_SAVE, ITEM_DISCARD, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE,
        ITEM_END_SET, ITEM_SETTINGS] as Array<MatchMenuItem>;
    var match = [ITEM_DATA_PAGE, ITEM_STATS_PAGE, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE, ITEM_EDIT_SCORE,
        ITEM_VIBRATION, ITEM_SOUNDS, ITEM_TOUCH_SCORING] as Array<MatchMenuItem>;
    TestKit.assertItems(rig.rules.getPauseItems(TestKit.MENU_TIME), pause, "pause, doubles");
    TestKit.assertItems(rig.rules.getMatchItems(), match, "match, doubles");
    Test.assert(rig.rules.endMatch(TestKit.MENU_TIME));
    MatchMenuTests.assertOverItems(rig, "End match");
    Test.assertEqual(rig.input.key(WatchUi.KEY_ESC, 0), INPUT_UNDO);
    TestKit.assertItems(rig.rules.getMatchItems(), match, "End match undone");
    var singles = new MatchConfig();
    singles.doubles = false;
    rig = new TestKit.Rig(singles, "", false);
    pause.remove(ITEM_SWAP_SERVER);
    match.remove(ITEM_SWAP_SERVER);
    TestKit.assertItems(rig.rules.getPauseItems(TestKit.MENU_TIME), pause, "pause, singles");
    TestKit.assertItems(rig.rules.getMatchItems(), match, "match, singles");
    rig = new TestKit.Rig(TestKit.preset(PRESET_ONE_SET), "", false);
    rig.play("UUUUUU");
    Test.assert(rig.rules.isMatchOver());
    MatchMenuTests.assertOverItems(rig, "won 6-0");
    return true;
}

(:test)
function matchMenuLabelsTest(logger as Logger) as Boolean {
    // Each item's label; the values under the items that set one: our player for our current or next
    // service game, the team serving now (none while unknown), the deuce mode chosen for the next
    // games. The others have none (Vibration's comes from the settings).
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var rules = rig.rules;
    var items = [ITEM_RESUME, ITEM_END_MATCH, ITEM_SAVE, ITEM_DISCARD, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE,
        ITEM_END_SET, ITEM_SETTINGS, ITEM_DATA_PAGE, ITEM_VIBRATION, ITEM_SOUNDS, ITEM_EDIT_SCORE, ITEM_TOUCH_SCORING,
        ITEM_STATS_PAGE] as Array<MatchMenuItem>;
    var labels = [Rez.Strings.Resume, Rez.Strings.MenuEndMatch, Rez.Strings.Save, Rez.Strings.Discard, Rez.Strings.MenuSwapServer,
        Rez.Strings.MenuFixServingTeam, Rez.Strings.MenuDeuceMode, Rez.Strings.MenuEndSet, Rez.Strings.MenuSettings,
        Rez.Strings.MenuDataPage, Rez.Strings.MenuVibration, Rez.Strings.MenuSounds, Rez.Strings.MenuEditScore,
        Rez.Strings.MenuTouchScoring, Rez.Strings.MenuStatsPage] as Array<ResourceId>;
    for (var i = 0; i < items.size(); i++) {
        Test.assertMessage(rules.getLabel(items[i]) == labels[i], "label of item " + items[i]);
        Test.assertMessage(i == 4 || i == 5 || i == 6 || rules.getValue(items[i]) == null, "value of item " + items[i]);
    }
    MatchMenuTests.assertValues(rules, Rez.Strings.ServeMe, null, Rez.Strings.DeuceStar, "start");
    Test.assert(rules.fixServingTeam(TEAM_US, TestKit.MENU_TIME) && rules.swapServer(TestKit.MENU_TIME));
    Test.assert(rules.setDeuceMode(DEUCE_GOLDEN, TestKit.MENU_TIME));
    MatchMenuTests.assertValues(rules, Rez.Strings.ServePartner, Rez.Strings.TeamUs, Rez.Strings.DeuceGolden, "set");
    // After our game PARTNER served, they serve and ME serves our next one.
    rig.play("U");
    MatchMenuTests.assertValues(rules, Rez.Strings.ServeMe, Rez.Strings.TeamThem, Rez.Strings.DeuceGolden, "game");
    Test.assert(MatchMenuRules.teamName(TEAM_US) == Rez.Strings.TeamUs && MatchMenuRules.teamName(TEAM_THEM) == Rez.Strings.TeamThem);
    return true;
}

(:test)
function matchMenuServeItemsTest(logger as Logger) as Boolean {
    // Swap: we serve, I do: my partner serves now, and BACK gives me the serve back; they serve: our
    // order for our next game, mid-game too; refused in singles, nothing logged. Fix serving team:
    // from unknown Us starts serve tracking; before anything else it and a swap after it are the
    // serve's set-up, which BACK keeps. The team already serving logs nothing, the other one is
    // logged; in a tie-break it names the team serving the point, which changes within it.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var rules = rig.rules;
    Test.assert(rules.getServingTeam() == null);
    Test.assert(rules.fixServingTeam(TEAM_US, TestKit.MENU_TIME) && rules.getServingTeam() == TEAM_US);
    Test.assert(rules.swapServer(TestKit.MENU_TIME) && rig.getState().getServingPlayer() == PLAYER_PARTNER);
    Test.assert(rig.input.key(WatchUi.KEY_ESC, 0) == INPUT_TOAST && rig.input.toast == Rez.Strings.UndoneNothing);
    Test.assert(rig.getState().eventCount == 2 && rig.getState().getServingPlayer() == PLAYER_PARTNER);
    Test.assert(rules.swapServer(TestKit.MENU_TIME) && rig.getState().getServingPlayer() == PLAYER_ME);
    rig.play("u");
    var before = rig.getState().copy();
    Test.assert(rules.swapServer(TestKit.MENU_TIME) && rig.getState().getServingPlayer() == PLAYER_PARTNER);
    rig.assertUndone(before, 2, Rez.Strings.UndoneServerSwap, "swap, we serve");
    rig.play("U ut");
    before = rig.getState().copy();
    Test.assert(!rules.fixServingTeam(TEAM_THEM, TestKit.MENU_TIME));
    TestKit.assertSameState(rig.getState(), before, "fix to the team serving");
    Test.assert(rules.swapServer(TestKit.MENU_TIME) && rig.getState().ourServer == PLAYER_ME);
    rig.assertUndone(before, 2, Rez.Strings.UndoneServerSwap, "swap, they serve");
    Test.assert(rules.fixServingTeam(TEAM_US, TestKit.MENU_TIME) && rules.getServingTeam() == TEAM_US);
    rig.assertUndone(before, 103, Rez.Strings.UndoneServingTeam, "fix mid-game");
    rig.play("TUTUTUTUTUT tu");
    Test.assert(rig.getState().isTieBreak());
    var serving = rules.getServingTeam() as Team;
    before = rig.getState().copy();
    Test.assert(!rules.fixServingTeam(serving, TestKit.MENU_TIME));
    Test.assert(rules.fixServingTeam(MatchState.otherTeam(serving), TestKit.MENU_TIME));
    Test.assert(rules.getServingTeam() == MatchState.otherTeam(serving));
    rig.assertUndone(before, serving == TEAM_US ? 203 : 103, Rez.Strings.UndoneServingTeam, "fix in a tie-break");
    var singles = new MatchConfig();
    singles.doubles = false;
    rig = new TestKit.Rig(singles, "", false);
    Test.assert(!rig.rules.swapServer(TestKit.MENU_TIME) && rig.getState().eventCount == 0);
    return true;
}

(:test)
function matchMenuDeuceModeTest(logger as Logger) as Boolean {
    // The mode already chosen: nothing logged. Before the game's first point it applies to this game;
    // once a point is played, from the next game: this one keeps its rule.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var rules = rig.rules;
    Test.assert(rules.getDeuceMode() == DEUCE_STAR && !rules.setDeuceMode(DEUCE_STAR, TestKit.MENU_TIME) && rig.getState().eventCount == 0);
    var before = rig.getState().copy();
    Test.assert(rules.setDeuceMode(DEUCE_GOLDEN, TestKit.MENU_TIME) && rig.getState().gameDeuceMode == DEUCE_GOLDEN);
    rig.assertUndone(before, 204, Rez.Strings.UndoneDeuceMode, "deuce mode at 0-0");
    rig.play("u");
    before = rig.getState().copy();
    Test.assert(rules.setDeuceMode(DEUCE_ADVANTAGE, TestKit.MENU_TIME) && rules.getDeuceMode() == DEUCE_ADVANTAGE);
    Test.assertEqual(rig.getState().gameDeuceMode, DEUCE_STAR);
    rig.assertUndone(before, 104, Rez.Strings.UndoneDeuceMode, "deuce mode mid-game");
    return true;
}

(:test)
function matchMenuEndSetTest(logger as Logger) as Boolean {
    // A team ahead: the set goes to it, the game in progress dropped, with no question; a team
    // named when one leads is refused (the menu never asks then). Level: End set now asks; without an
    // answer nothing is logged; Them or Us gets it. A tie-break counts its set's games: level at 6-6
    // whatever its points.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UUUT u");
    var before = rig.getState().copy();
    Test.assert(!rig.rules.isSetLevel() && !rig.rules.endSet(TEAM_THEM, TestKit.MENU_TIME));
    TestKit.assertSameState(rig.getState(), before, "End set now naming the team behind");
    Test.assert(rig.rules.endSet(null, TestKit.MENU_TIME) && !rig.rules.isMatchOver());
    Test.assertEqual(TestKit.sets(rig.getState()), "3-1EU | 0-0 0-0");
    rig.assertUndone(before, 5, Rez.Strings.UndoneEndSet, "End set now, us ahead");
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UUUTTT tu");
    before = rig.getState().copy();
    Test.assert(rig.rules.isSetLevel() && !rig.rules.endSet(null, TestKit.MENU_TIME));
    TestKit.assertSameState(rig.getState(), before, "End set now level, no answer");
    Test.assert(rig.rules.endSet(TEAM_THEM, TestKit.MENU_TIME));
    Test.assertEqual(TestKit.sets(rig.getState()), "3-3ET | 0-0 0-0");
    rig.assertUndone(before, 205, Rez.Strings.UndoneEndSet, "End set now level, Them");
    Test.assert(rig.rules.endSet(TEAM_US, TestKit.MENU_TIME));
    rig.assertUndone(before, 105, Rez.Strings.UndoneEndSet, "End set now level, Us");
    rig.play("UTUTUT uu");
    Test.assert(rig.getState().isTieBreak() && rig.rules.isSetLevel());
    return true;
}

(:test)
function matchMenuEndSetEndsMatchTest(logger as Logger) as Boolean {
    // Best of 3, the first set ours, ahead 2-1 in the second: End set now wins the match. The super
    // tie-break is scored in points: their lead gives them the set, and the match. One set, level: the
    // team named gets the set and the match.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UUUUUU UUT");
    var before = rig.getState().copy();
    Test.assert(rig.rules.endSet(null, TestKit.MENU_TIME) && rig.rules.isMatchOver() && rig.getState().getResult() == RESULT_WIN);
    MatchMenuTests.assertOverItems(rig, "End set now won the match");
    rig.assertUndone(before, 5, Rez.Strings.UndoneEndSet, "End set now, match");
    rig = new TestKit.Rig(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "", false);
    rig.play("UUUUUU TTTTTT ttu");
    Test.assert(!rig.rules.isSetLevel() && rig.rules.endSet(null, TestKit.MENU_TIME));
    Test.assert(rig.getState().getResult() == RESULT_LOSS && rig.getState().getScoreText().equals("6-0 0-6 1-2"));
    rig = new TestKit.Rig(TestKit.preset(PRESET_ONE_SET), "", false);
    rig.play("UT");
    Test.assert(rig.rules.isSetLevel() && rig.rules.endSet(TEAM_US, TestKit.MENU_TIME) && rig.getState().getResult() == RESULT_WIN);
    return true;
}

(:test)
function matchMenuEndMatchTest(logger as Logger) as Boolean {
    // The early end result: sets, then the unfinished set's games, then the game's points; all
    // level is a draw. Each End match is undone by BACK, and the match goes on. Nothing can follow it,
    // End match included.
    var cases = [["", RESULT_DRAW, "0-0*"], ["UUUUUU TT", RESULT_WIN, "6-0 0-2*"], ["UT tt", RESULT_LOSS, "1-1*"],
        ["UUUUUU TTTTTT ut", RESULT_DRAW, "6-0 0-6 0-0*"]];
    for (var i = 0; i < cases.size(); i++) {
        var rig = new TestKit.Rig(new MatchConfig(), "", false);
        rig.play(cases[i][0] as String);
        var before = rig.getState().copy();
        Test.assert(rig.rules.endMatch(TestKit.MENU_TIME));
        Test.assertMessage(rig.getState().getResult() == cases[i][1] && rig.getState().getScoreText().equals(cases[i][2]),
            cases[i][0] + ": " + rig.getState().getScoreText());
        rig.assertUndone(before, 6, Rez.Strings.UndoneEndMatch, cases[i][0] + ": End match");
    }
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var rules = rig.rules;
    var t = TestKit.MENU_TIME;
    Test.assert(rules.endMatch(t) && !rules.endMatch(t) && !rules.endSet(TEAM_US, t) && !rules.fixServingTeam(TEAM_US, t));
    Test.assert(!rules.setDeuceMode(DEUCE_GOLDEN, t) && !rules.swapServer(t) && rig.getState().eventCount == 1);
    return true;
}

(:test)
function matchMenuSaveTest(logger as Logger) as Boolean {
    // Save from the pause menu mid-match: the session ends with the result unfinished; after End match
    // in the pause menu, the early end result. A save the watch refuses keeps the session, paused;
    // Resume starts the timer again.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UU u");
    Test.assert(rig.session.pause() && rig.rules.save() && rig.session.getPhase() == SESSION_ENDED);
    var values = rig.recorder.sessionValues as SessionValues;
    Test.assert(values.result == (RESULT_UNFINISHED as Number) && values.score.equals("2-0*"));
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("UU");
    Test.assert(rig.session.pause() && rig.rules.endMatch(TestKit.MENU_TIME) && rig.rules.save());
    Test.assertEqual((rig.recorder.sessionValues as SessionValues).result, RESULT_WIN as Number);
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.recorder.saveResult = false;
    rig.play("u");
    Test.assert(rig.session.pause() && !rig.rules.save() && rig.session.isRecording() && rig.session.isPaused());
    Test.assert(rig.rules.resume() && !rig.session.isPaused() && !rig.rules.resume());
    return true;
}

(:test)
function matchMenuTouchScreenTest(logger as Logger) as Boolean {
    // Touch scoring is in the match menu on a watch with a touchscreen only, as monkey.jungle builds
    // it for each watch. The simulators run with touch on, so it matches the device file there.
    Test.assertEqual(Settings.hasTouchScreen(), System.getDeviceSettings().isTouchScreen);
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    Test.assertEqual(rig.rules.getMatchItems().indexOf(ITEM_TOUCH_SCORING) >= 0, Settings.hasTouchScreen());
    return true;
}

(:test)
module MatchMenuTests {

    // Once the match is over: Resume, Save, Discard and Settings when paused; Data page, Stats page,
    // Vibration, Sounds and Touch scoring from hold UP.
    function assertOverItems(rig as TestKit.Rig, message as String) as Void {
        TestKit.assertItems(rig.rules.getPauseItems(TestKit.MENU_TIME), [ITEM_RESUME, ITEM_SAVE, ITEM_DISCARD, ITEM_SETTINGS],
            message + ", pause");
        TestKit.assertItems(rig.rules.getMatchItems(), [ITEM_DATA_PAGE, ITEM_STATS_PAGE, ITEM_VIBRATION, ITEM_SOUNDS,
            ITEM_TOUCH_SCORING], message + ", match");
    }

    // Under Swap our server order, Fix serving team and Deuce mode.
    function assertValues(rules as MatchMenuRules, swap as ResourceId, fix as ResourceId?, deuce as ResourceId,
            message as String) as Void {
        Test.assertMessage(rules.getValue(ITEM_SWAP_SERVER) == swap && rules.getValue(ITEM_FIX_SERVING_TEAM) == fix
            && rules.getValue(ITEM_DEUCE_MODE) == deuce, message + ": values");
    }
}

import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// The rules of the watches without UP and DOWN, each a flag on its class (InputFlags): set all at
// once from the watch's build, and the build's Settings.hasScoreButtons() as the watch reports its
// buttons, so a wrong monkey.jungle line fails here.

(:test)
function inputFlagsTest(logger as Logger) as Boolean {
    // Each class's flags, on and off, and the BACK guard's with the score screen's input.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    var input = rig.input;
    Test.assert(!input.touchAlways && !input.swipeMenu && !input.pageBack);
    Test.assert(!input.back.menuCancels && input.back.wait == BackGuard.WAIT_MS && !rig.motion.wrap);
    for (var on = 1; on >= 0; on--) {
        var flag = on == 1;
        InputFlags.setScore(input, flag);
        Test.assert(input.touchAlways == flag && input.swipeMenu == flag && input.pageBack == flag);
        Test.assert(input.back.menuCancels == flag && input.back.wait == (flag ? BackGuard.LONG_WAIT_MS : BackGuard.WAIT_MS));
        InputFlags.setMotion(rig.motion, flag);
        Test.assert(rig.motion.wrap == flag);
        var guard = new BackGuard();
        InputFlags.setBack(guard, flag);
        Test.assert(guard.menuCancels == flag && guard.wait == (flag ? BackGuard.LONG_WAIT_MS : BackGuard.WAIT_MS));
        var flow = new TestKit.Flow(false, true).flow;
        InputFlags.setWarmUp(flow, flag);
        Test.assert(flow.swipeMenu == flag);
        var rules = new MatchMenuRules(rig.match, rig.session);
        for (var tones = 0; tones < 2; tones++) {
            InputFlags.setMenus(rules, flag, tones == 1);
            Test.assert(rules.eventsLast == flag && rules.gestureItem == flag && rules.noSounds == (tones == 0));
        }
    }
    var summary = new SummaryTests.Summary(new MatchConfig(), "UUUUUU UUUUUU");
    InputFlags.setSummary(summary.input, true);
    Test.assert(summary.input.swipeMenu);
    InputFlags.setSummary(summary.input, false);
    Test.assert(!summary.input.swipeMenu);
    Test.assert(BackGuard.WAIT_MS == 100 && BackGuard.LONG_WAIT_MS == 300);
    return true;
}

(:test)
function inputFlagsBuildTest(logger as Logger) as Boolean {
    // The build gives a watch the rules of the watches without UP and DOWN exactly when it reports no UP
    // or no DOWN button (its device file's keys), and every watch with them plays tones, so Sounds stays
    // in their menus. The watches without them all have a touchscreen.
    var buttons = System.getDeviceSettings().inputButtons;
    var upDown = (buttons & System.BUTTON_INPUT_UP) != 0 && (buttons & System.BUTTON_INPUT_DOWN) != 0;
    Test.assertEqual(Settings.hasScoreButtons(), upDown);
    Test.assertEqual(InputFlags.touchOnly(), !upDown);
    Test.assertEqual(InputFlags.hasTones(), Attention has :playTone);
    Test.assert(!Settings.hasScoreButtons() || InputFlags.hasTones());
    Test.assert(Settings.hasScoreButtons() || (Settings.hasTouchScreen() && System.getDeviceSettings().isTouchScreen));
    return true;
}

import Toybox.Attention;
import Toybox.Lang;

// The rules of the watches whose apps get START, BACK and touch only (Settings.hasScoreButtons() false:
// the Venu, vivoactive 5 and 6, D2 Air X10, Approach S50, S70 and S72), each a flag on its class, off by
// default, so the watches with UP and DOWN keep theirs. Each screen sets its classes' flags here when it
// makes them, from touchOnly():
// - Touch scoring always on, by tap or by hold (the Touch scoring setting's gesture); one hold, one point
//   (ScoreInput). BACK on the data and stats pages brings the score page back (ScoreInput), and the
//   BACK guard lets the BACK button undo a held point (BackGuard).
// - A swipe up opens each screen's menu (ScoreInput, SummaryInput on its last page, WarmUpFlow); the
//   watch's own menu key opens it too, hold BACK's key-down then cancelled (BackGuard).
// - A swipe left on the stats page goes round to the score page (ScoreMotion).
// - The match menu's items that log nothing first, Touch scoring with its gesture (MatchMenuRules).
// - A quick BACK key waits longer for the edge swipe's touches (BackGuard).
// And on any watch, Sounds left out of the menus without tones (hasTones()), which every watch with UP
// and DOWN has.
module InputFlags {

    // This watch takes the rules: no UP and DOWN.
    function touchOnly() as Boolean {
        return !Settings.hasScoreButtons();
    }

    // The watch plays tones (Attention.playTone): the Sounds setting does something.
    function hasTones() as Boolean {
        return Attention has :playTone;
    }

    // The score screen's input and its BACK guard.
    function setScore(input as ScoreInput, on as Boolean) as Void {
        input.touchAlways = on;
        input.swipeMenu = on;
        input.pageBack = on;
        setBack(input.back, on);
    }

    // A BACK guard, the score screen's or the summary's.
    function setBack(guard as BackGuard, on as Boolean) as Void {
        guard.menuCancels = on;
        guard.wait = on ? BackGuard.LONG_WAIT_MS : BackGuard.WAIT_MS;
    }

    // The score screen's pages.
    function setMotion(motion as ScoreMotion, on as Boolean) as Void {
        motion.wrap = on;
    }

    function setSummary(input as SummaryInput, on as Boolean) as Void {
        input.swipeMenu = on;
    }

    // The sensor lock and the warm-up.
    function setWarmUp(flow as WarmUpFlow, on as Boolean) as Void {
        flow.swipeMenu = on;
    }

    // The pause and match menus, tones as hasTones() gives them.
    function setMenus(rules as MatchMenuRules, on as Boolean, tones as Boolean) as Void {
        rules.eventsLast = on;
        rules.gestureItem = on;
        rules.noSounds = !tones;
    }
}

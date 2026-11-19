import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Only the BACK button undoes. The watch turns a swipe right from the left edge into a fake BACK
// press, key-down then key 1 ms later, then the swipe's drags (FR265, 2026-10-31)
// (BackGuard).
(:test)
function backGuardTest(logger as Logger) as Boolean {
    // The BACK button on the watch: the key on release, 80 ms after the key-down: at once.
    var guard = new BackGuard();
    guard.keyPressed(WatchUi.KEY_ESC, 1000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1080) == BACK_NOW);
    // One key-down counts once.
    Test.assert(guard.check(WatchUi.KEY_ESC, 1200) == BACK_IGNORE);
    // A held BACK (3 s) too.
    guard.keyPressed(WatchUi.KEY_ESC, 2000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 5000) == BACK_NOW);

    // The edge swipe, as measured: key-down 52686, key 52687, release 52709, first drag 52710.
    guard = new BackGuard();
    guard.keyPressed(WatchUi.KEY_ESC, 52686);
    Test.assert(guard.check(WatchUi.KEY_ESC, 52687) == BACK_WAIT);
    guard.touched(52710);
    Test.assert(!guard.untouchedSince(52687));

    // A quick BACK with no touch after it (the simulator sends the key on the key-down): it waits,
    // then undoes.
    guard = new BackGuard();
    guard.keyPressed(WatchUi.KEY_ESC, 3000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 3000 + BackGuard.PRESS_MS - 1) == BACK_WAIT);
    Test.assert(guard.untouchedSince(3000 + BackGuard.PRESS_MS - 1));
    guard.keyPressed(WatchUi.KEY_ESC, 4000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 4000 + BackGuard.PRESS_MS) == BACK_NOW);

    // A KEY_ESC with no key-down: nothing. One within TOUCH_MS of a touch: nothing.
    guard = new BackGuard();
    Test.assert(guard.check(WatchUi.KEY_ESC, 100) == BACK_IGNORE);
    guard.touched(5000);
    guard.keyPressed(WatchUi.KEY_ESC, 5000 + BackGuard.TOUCH_MS - 100);
    Test.assert(guard.check(WatchUi.KEY_ESC, 5000 + BackGuard.TOUCH_MS - 1) == BACK_IGNORE);
    guard.keyPressed(WatchUi.KEY_ESC, 5000 + BackGuard.TOUCH_MS - 100);
    Test.assert(guard.check(WatchUi.KEY_ESC, 5000 + BackGuard.TOUCH_MS) == BACK_NOW);

    // Other keys always act at once.
    guard = new BackGuard();
    guard.touched(100);
    Test.assert(guard.check(WatchUi.KEY_UP, 150) == BACK_NOW);
    Test.assert(guard.check(WatchUi.KEY_DOWN, 150) == BACK_NOW);
    Test.assert(guard.check(WatchUi.KEY_ENTER, 150) == BACK_NOW);
    Test.assert(guard.check(WatchUi.KEY_MENU, 150) == BACK_NOW);
    return true;
}

// Touch scoring: a tap that scored doesn't start the 800 ms wait, so the BACK button
// right after it undoes the point; the touches of that tap neither, the touch-down before it and a
// release less than TAP_END_MS after it. Any other touch still does. Within 800 ms of a BACK key sent
// less than PRESS_MS after its key-down (the edge swipe's), a tap is the swipe's: isEdgeSwipe().
(:test)
function backGuardTapTest(logger as Logger) as Boolean {
    // A tap that didn't score is a touch: BACK 300 ms after it does nothing.
    var guard = new BackGuard();
    guard.touched(1000);
    guard.keyPressed(WatchUi.KEY_ESC, 1220);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1300) == BACK_IGNORE);
    // A tap that scored, its touch-down 80 ms before it and its release 10 ms after: BACK 300 ms later
    // acts at once.
    guard = new BackGuard();
    guard.touched(1920);
    guard.tapScored(2000);
    guard.touched(2010);
    guard.keyPressed(WatchUi.KEY_ESC, 2220);
    Test.assert(guard.check(WatchUi.KEY_ESC, 2300) == BACK_NOW);
    // The last of its touches at TAP_END_MS - 1, then a touch at TAP_END_MS: that one starts the wait.
    guard.tapScored(4000);
    guard.touched(4000 + BackGuard.TAP_END_MS - 1);
    guard.keyPressed(WatchUi.KEY_ESC, 4300);
    Test.assert(guard.check(WatchUi.KEY_ESC, 4380) == BACK_NOW);
    guard.touched(4000 + BackGuard.TAP_END_MS);
    guard.keyPressed(WatchUi.KEY_ESC, 4500);
    Test.assert(guard.check(WatchUi.KEY_ESC, 4580) == BACK_IGNORE);
    // A scored tap is still a touch for a quick BACK waiting: it drops it.
    guard = new BackGuard();
    guard.keyPressed(WatchUi.KEY_ESC, 6000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 6001) == BACK_WAIT);
    guard.tapScored(6050);
    Test.assert(!guard.untouchedSince(6001));

    // The edge swipe: its BACK key 1 ms after its key-down, then 800 ms of swipe. The BACK button
    // never starts one, nor a BACK key with no key-down.
    guard = new BackGuard();
    Test.assert(!guard.isEdgeSwipe(0) && !guard.isEdgeSwipe(10000));
    guard.keyPressed(WatchUi.KEY_ESC, 10000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 10080) == BACK_NOW && !guard.isEdgeSwipe(10100));
    Test.assert(guard.check(WatchUi.KEY_ESC, 10200) == BACK_IGNORE && !guard.isEdgeSwipe(10300));
    guard.keyPressed(WatchUi.KEY_ESC, 20000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 20001) == BACK_WAIT);
    Test.assert(!guard.isEdgeSwipe(20000) && guard.isEdgeSwipe(20001));
    Test.assert(guard.isEdgeSwipe(20001 + BackGuard.TOUCH_MS - 1) && !guard.isEdgeSwipe(20001 + BackGuard.TOUCH_MS));
    // One that comes within 800 ms of a touch does nothing, and is still the edge swipe's.
    guard = new BackGuard();
    guard.touched(30000);
    guard.keyPressed(WatchUi.KEY_ESC, 30500);
    Test.assert(guard.check(WatchUi.KEY_ESC, 30501) == BACK_IGNORE && guard.isEdgeSwipe(30600));
    // System.getTimer() wraps around after about 24.8 days.
    guard = new BackGuard();
    var last = 0x7FFFFFFF - 100;
    guard.tapScored(last);
    guard.touched(last + 50);
    guard.keyPressed(WatchUi.KEY_ESC, last + 300);
    Test.assert(guard.check(WatchUi.KEY_ESC, last + 380) == BACK_NOW);
    guard.keyPressed(WatchUi.KEY_ESC, last + 400);
    Test.assert(guard.check(WatchUi.KEY_ESC, last + 401) == BACK_WAIT && guard.isEdgeSwipe(last + 900));
    return true;
}

// Touch scoring by hold (the watches without UP and DOWN): a hold that scored doesn't start the 800 ms
// wait, nor do its own touches, those before it and those within HOLD_MS after it (its drags, its
// release), so the BACK button after a held point undoes it whether the watch sends the release or not.
// A touch past HOLD_MS starts the wait again.
(:test)
function backGuardHoldTest(logger as Logger) as Boolean {
    // Its touch-down, the hold, drags, the release 600 ms later, BACK 300 ms after it: at once.
    var guard = new BackGuard();
    guard.touched(900);
    guard.holdScored(1000);
    guard.touched(1100);
    guard.touched(1600);
    guard.keyPressed(WatchUi.KEY_ESC, 1900);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1980) == BACK_NOW);
    // No release: a drag at HOLD_MS - 1, then BACK. A touch at HOLD_MS starts the wait.
    guard.holdScored(4000);
    guard.touched(4000 + BackGuard.HOLD_MS - 1);
    guard.keyPressed(WatchUi.KEY_ESC, 6100);
    Test.assert(guard.check(WatchUi.KEY_ESC, 6180) == BACK_NOW);
    guard.touched(4000 + BackGuard.HOLD_MS);
    guard.keyPressed(WatchUi.KEY_ESC, 6300);
    Test.assert(guard.check(WatchUi.KEY_ESC, 6380) == BACK_IGNORE);
    // A held point is still a touch for a quick BACK waiting: it drops it.
    guard = new BackGuard();
    guard.keyPressed(WatchUi.KEY_ESC, 8000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 8001) == BACK_WAIT);
    guard.holdScored(8050);
    Test.assert(!guard.untouchedSince(8001));
    // System.getTimer() wraps around after about 24.8 days.
    guard = new BackGuard();
    var last = 0x7FFFFFFF - 100;
    guard.holdScored(last);
    guard.touched(last + 1500);
    guard.keyPressed(WatchUi.KEY_ESC, last + 1700);
    Test.assert(guard.check(WatchUi.KEY_ESC, last + 1780) == BACK_NOW);
    return true;
}

// Hold BACK, the menu key of the Venu 2, 3, vivoactive 5, D2 Air X10 and Approach S50: BACK's key-down,
// then the menu key (KEY_MENU, as a key-down or a key). With the flag on, the menu key cancels that
// key-down, so a BACK key after it (the release) does nothing. Off, as on the watches with UP and DOWN
// (whose menu key is hold UP), nothing changes.
(:test)
function backGuardMenuKeyTest(logger as Logger) as Boolean {
    var guard = new BackGuard();
    Test.assert(!guard.menuCancels && guard.wait == BackGuard.WAIT_MS);
    guard.keyPressed(WatchUi.KEY_ESC, 1000);
    Test.assert(guard.check(WatchUi.KEY_MENU, 1600) == BACK_NOW && guard.check(WatchUi.KEY_ESC, 1700) == BACK_NOW);
    guard = new BackGuard();
    guard.menuCancels = true;
    guard.keyPressed(WatchUi.KEY_ESC, 1000);
    Test.assert(guard.check(WatchUi.KEY_MENU, 1600) == BACK_NOW && guard.check(WatchUi.KEY_ESC, 1700) == BACK_IGNORE);
    guard.keyPressed(WatchUi.KEY_ESC, 2000);
    guard.keyPressed(WatchUi.KEY_MENU, 2600);
    Test.assert(guard.check(WatchUi.KEY_ESC, 2700) == BACK_IGNORE);
    // The next BACK press acts, the BACK button's at once, a quick one after the wait.
    guard.keyPressed(WatchUi.KEY_ESC, 3000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 3080) == BACK_NOW);
    guard.keyPressed(WatchUi.KEY_ESC, 4000);
    Test.assert(guard.check(WatchUi.KEY_ESC, 4001) == BACK_WAIT);
    return true;
}

// The release that ends a hold that scored closes the hold: the release itself starts no wait, a touch
// after it does, though still within HOLD_MS of the hold. A release past HOLD_MS is a touch like any
// other, and a release is still a touch for a quick BACK waiting.
(:test)
function backGuardHoldReleaseTest(logger as Logger) as Boolean {
    var guard = new BackGuard();
    guard.holdScored(1000);
    guard.touched(1200);
    guard.holdReleased(1400);
    guard.keyPressed(WatchUi.KEY_ESC, 1500);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1580) == BACK_NOW);
    guard.touched(1700);
    guard.keyPressed(WatchUi.KEY_ESC, 1900);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1980) == BACK_IGNORE);
    guard.keyPressed(WatchUi.KEY_ESC, 1700 + BackGuard.TOUCH_MS);
    Test.assert(guard.check(WatchUi.KEY_ESC, 1700 + BackGuard.TOUCH_MS + 80) == BACK_NOW);
    guard = new BackGuard();
    guard.holdScored(5000);
    guard.holdReleased(5000 + BackGuard.HOLD_MS);
    guard.keyPressed(WatchUi.KEY_ESC, 5000 + BackGuard.HOLD_MS + 100);
    Test.assert(guard.check(WatchUi.KEY_ESC, 5000 + BackGuard.HOLD_MS + 180) == BACK_IGNORE);
    guard = new BackGuard();
    guard.holdScored(8000);
    guard.keyPressed(WatchUi.KEY_ESC, 8100);
    Test.assert(guard.check(WatchUi.KEY_ESC, 8101) == BACK_WAIT);
    guard.holdReleased(8150);
    Test.assert(!guard.untouchedSince(8101));
    return true;
}

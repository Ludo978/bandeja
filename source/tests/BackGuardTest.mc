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

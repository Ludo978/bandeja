import Toybox.Lang;
import Toybox.WatchUi;

// What a KEY_ESC should do (BackGuard.check()).
enum BackCheck {
    BACK_NOW,     // the BACK button: act at once
    BACK_WAIT,    // act after BackGuard.WAIT_MS unless a touch comes first (untouchedSince())
    BACK_IGNORE   // not a BACK press: do nothing
}

// Tells the BACK button from the watch's swipe right from the screen's left edge. The
// watch turns that swipe into a whole fake BACK press, key-down, key and release, before the
// swipe's drags reach the app (measured on the FR265, 2026-10-31: key-down, key 1 ms later, release
// 23 ms, first drag 24 ms). The BACK button sends its key when released, 50 ms or more after its
// key-down, and no drag follows. So a KEY_ESC acts at once when it came PRESS_MS or more after its
// key-down; one that came sooner (the gesture, or the simulator, which sends the key on the key-down)
// waits WAIT_MS and acts only if no touch came meanwhile. A KEY_ESC with no key-down before it, or
// within TOUCH_MS of a touch, does nothing.
//
// Touch scoring: a tap that scored doesn't start the TOUCH_MS wait (tapScored()), nor do the
// touches of that tap, so BACK right after a tapped point undoes it. And the TOUCH_MS after a quick
// KEY_ESC are the edge swipe's (isEdgeSwipe()): a tap then never scores, whatever the watch makes of
// the swipe's end.
class BackGuard {

    static const PRESS_MS = 25;
    static const WAIT_MS = 100;
    static const TOUCH_MS = 800;
    // A tap's own touches that may reach the app after its onTap (its release, if the watch sends one),
    // timed when their handlers run, after the point's work and its redraw.
    static const TAP_END_MS = 200;

    private var _pressedAt as Number? = null;
    // The last touch of any kind (untouchedSince()), and the last one that starts the TOUCH_MS wait:
    // every touch but a tap that scored and its own.
    private var _touchAt as Number? = null;
    private var _waitFrom as Number? = null;
    // The last tap that scored.
    private var _tapAt as Number? = null;
    // The last KEY_ESC that came within PRESS_MS of its key-down: the edge swipe's (or the simulator's).
    private var _quickAt as Number? = null;

    // From onKeyPressed; now is System.getTimer().
    function keyPressed(key as WatchUi.Key, now as Number) as Void {
        if (key == WatchUi.KEY_ESC) {
            _pressedAt = now;
        }
    }

    // From every touch (tap, hold, release, drag, swipe, flick) but a tap that scored.
    function touched(now as Number) as Void {
        _touchAt = now;
        var tapAt = _tapAt;
        if (tapAt == null || !within(now, tapAt, TAP_END_MS)) {
            _waitFrom = now;
        }
    }

    // A tap that scored (touch scoring, ScoreInput.tap()): no TOUCH_MS wait from it or from its touches,
    // those before it (its touch-down) and those TAP_END_MS after it.
    function tapScored(now as Number) as Void {
        _touchAt = now;
        _waitFrom = null;
        _tapAt = now;
    }

    // From onKey. Other keys are always BACK_NOW.
    function check(key as WatchUi.Key, now as Number) as BackCheck {
        if (key != WatchUi.KEY_ESC) {
            return BACK_NOW;
        }
        var pressedAt = _pressedAt;
        _pressedAt = null;
        if (pressedAt == null) {
            return BACK_IGNORE;
        }
        var held = now - pressedAt;
        var quick = held >= 0 && held < PRESS_MS;
        if (quick) {
            _quickAt = now;
        }
        var waitFrom = _waitFrom;
        if (waitFrom != null && within(now, waitFrom, TOUCH_MS)) {
            return BACK_IGNORE;
        }
        return quick ? BACK_WAIT : BACK_NOW;
    }

    // For a BACK_WAIT checked at `at`, WAIT_MS later: true when no touch came since.
    function untouchedSince(at as Number) as Boolean {
        return _touchAt == null || (_touchAt as Number) < at;
    }

    // True within TOUCH_MS of a KEY_ESC that came within PRESS_MS of its key-down: the watch's edge
    // swipe is under way (on the watch, the BACK button never sends its key that soon), and a tap then
    // is its end, never a point.
    function isEdgeSwipe(now as Number) as Boolean {
        var quickAt = _quickAt;
        return quickAt != null && within(now, quickAt, TOUCH_MS);
    }

    // now is at or after then, by less than ms (System.getTimer() differences, wrap-safe).
    private static function within(now as Number, then as Number, ms as Number) as Boolean {
        var since = now - then;
        return since >= 0 && since < ms;
    }
}

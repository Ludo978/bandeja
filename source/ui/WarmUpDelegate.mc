import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The input of the sensor lock and the warm-up, as WarmUpFlow decides it.
// START begins recording, then ends the warm-up. UP and DOWN never score: while recording they
// bring the toast, read as keys (on release on the watch), so hold UP opens the menu without it.
// BACK and a swipe right bring the same toast while recording, and go home at the lock. Hold UP
// while recording: Start match / Discard / Settings. Taps and other swipes do nothing. The toast
// never takes a press: every press keeps acting as above while it shows. Hold DOWN is the watch's.
// Debug builds, at the lock: hold UP opens the debug menu (DebugMenu: the score screen fixtures, a
// session the watch refuses), a tap opens the design test screen.
class WarmUpDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WarmUpView;

    function initialize(view as WarmUpView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // The behaviors come first: START and a tap both give onSelect, UP and a swipe down
    // onPreviousPage, DOWN and a swipe up onNextPage. Passed on to onKey, onTap and onSwipe.
    function onSelect() as Boolean {
        return false;
    }

    function onNextPage() as Boolean {
        return false;
    }

    function onPreviousPage() as Boolean {
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            start();
            return true;
        } else if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            act(_view.flow.press());
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        act(_view.flow.back());
        return true;
    }

    function onMenu() as Boolean {
        if (_view.flow.isRecording()) {
            WarmUpMenu.open(self);
        } else {
            debugMenu();
        }
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!_view.flow.isRecording()) {
            debugDesignTest();
        }
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }

    function getFlow() as WarmUpFlow {
        return _view.flow;
    }

    // START, or Start match in the warm-up menu.
    function start() as Void {
        act(_view.flow.start(Time.now().value()));
    }

    private function act(step as WarmUpStep) as Void {
        if (step == STEP_TOAST) {
            _view.toast.show(_view.toastText);
        } else if (step == STEP_WARM_UP) {
            _view.refresh();
            WatchUi.requestUpdate();
        } else if (step == STEP_MATCH) {
            MatchFlow.startMatch(_view.flow.getMatch() as CurrentMatch);
        } else if (step == STEP_FAILED) {
            showSessionError(getSessionManager());
        } else if (step == STEP_HOME) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }

    (:debug)
    private function debugMenu() as Void {
        DebugMenu.open(self);
    }

    (:release)
    private function debugMenu() as Void {
    }

    // Debug builds only: the next START gets a session the watch refuses, started at once.
    (:debug)
    function debugRefusedSession() as Void {
        (Application.getApp() as BandejaApp).simulateRefusedSession();
        var session = getSessionManager();
        if (!session.start(_view.flow.outdoor, _view.flow.warmUp)) {
            showSessionError(session);
        }
    }

    // Debug builds only: a canned match on the score screen (ScoreFixtures).
    (:debug)
    function debugFixture(fixture as ScoreFixture) as Void {
        ScoreFixtures.start(fixture, _view.flow);
    }

    // Debug builds only: the design foundation's test screen.
    (:debug)
    private function debugDesignTest() as Void {
        var view = new DesignTestView();
        WatchUi.pushView(view, new DesignTestDelegate(view), WatchUi.SLIDE_LEFT);
    }

    (:release)
    private function debugDesignTest() as Void {
    }
}

import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// A stored match's summary's input: an InputDelegate, like the match's own summary, so
// every key, swipe and touch comes here and is consumed. HistoryInput decides what each does; this
// turns the pages and goes back to the list, once.
//
// The watch turns a swipe right from the screen's left edge into a fake BACK press before the swipe
// (BackGuard): both mean back here, so BackGuard keeps the fake press from acting when the swipe
// follows, and the screen leaves on the swipe alone, never twice (which would take the list with it).
class HistoryDelegate extends WatchUi.InputDelegate {

    private var _view as SummaryView;
    private var _input as HistoryInput;
    private var _back as BackGuard = new BackGuard();
    // A quick BACK waiting for the edge swipe's drags (BackGuard), and when it came.
    private var _backTimer as Timer.Timer? = null;
    private var _backAt as Number = 0;
    // The list is showing again: later inputs, and a BACK still waiting, do nothing.
    private var _left as Boolean = false;

    function initialize(view as SummaryView, input as HistoryInput) {
        InputDelegate.initialize();
        _view = view;
        _input = input;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        _back.keyPressed(keyEvent.getKey(), System.getTimer());
        return false;
    }

    // A quick BACK waits BackGuard.WAIT_MS for the edge swipe's drags (backDue()).
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var now = System.getTimer();
        var check = _back.check(keyEvent.getKey(), now);
        if (check == BACK_NOW) {
            act(_input.key(keyEvent.getKey()));
        } else if (check == BACK_WAIT) {
            _backAt = now;
            if (_backTimer == null) {
                _backTimer = new Timer.Timer();
            }
            (_backTimer as Timer.Timer).start(method(:backDue), BackGuard.WAIT_MS, false);
        }
        return true;
    }

    function backDue() as Void {
        if (_back.untouchedSince(_backAt)) {
            act(_input.key(WatchUi.KEY_ESC));
        }
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        _back.touched(System.getTimer());
        act(_input.swipe(swipeEvent.getDirection()));
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touched();
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touched();
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touched();
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        return touched();
    }

    function onFlick(flickEvent as WatchUi.FlickEvent) as Boolean {
        return touched();
    }

    private function touched() as Boolean {
        _back.touched(System.getTimer());
        act(_input.touch());
        return true;
    }

    private function act(action as HistoryAction) as Void {
        if (_left) {
            return;
        }
        if (action == HISTORY_PAGE) {
            _view.page = _input.page;
            WatchUi.requestUpdate();
        } else if (action == HISTORY_BACK) {
            _left = true;
            var timer = _backTimer;
            if (timer != null) {
                timer.stop();
            }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
}

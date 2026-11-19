import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The summary's input: an InputDelegate, so no behavior turns BACK into leaving the
// screen, a tap into START or a swipe into a page change of its own. Every key, tap, swipe, touch
// hold, release, drag and flick is consumed (returns true): the summary leaves only through Save,
// Discard or BACK, which goes back to the match. SummaryInput decides what each input does; this
// shows it and opens the next screens through MatchFlow.
class SummaryDelegate extends WatchUi.InputDelegate {

    private var _view as SummaryView;
    private var _input as SummaryInput;
    private var _match as CurrentMatch;
    private var _back as BackGuard = new BackGuard();
    // A quick BACK waiting for the edge swipe's drags (BackGuard), and when it came.
    private var _backTimer as Timer.Timer? = null;
    private var _backAt as Number = 0;

    function initialize(view as SummaryView, input as SummaryInput, match as CurrentMatch) {
        InputDelegate.initialize();
        _view = view;
        _input = input;
        _match = match;
        InputFlags.setBack(_back, InputFlags.touchOnly());
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        _back.keyPressed(keyEvent.getKey(), System.getTimer());
        return false;
    }

    // The edge swipe's fake BACK does nothing (BackGuard): only the BACK button undoes. A quick BACK
    // waits the guard's wait for the swipe's drags (backDue()).
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
            (_backTimer as Timer.Timer).start(method(:backDue), _back.wait, false);
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
        return true;
    }

    private function act(action as SummaryAction) as Void {
        if (action == SUMMARY_PAGE) {
            _view.page = _input.page;
            WatchUi.requestUpdate();
        } else if (action == SUMMARY_SAVED) {
            MatchFlow.saved(MatchFlow.historyRecord(_match));
        } else if (action == SUMMARY_NOT_SAVED) {
            _view.toast.show(WatchUi.loadResource(Rez.Strings.SaveFailed) as String);
        } else if (action == SUMMARY_UNDO) {
            MatchFlow.backToMatch(_match, _input.undone as MatchEvent);
        } else if (action == SUMMARY_MENU) {
            SummaryMenu.open(_input, _match);
        }
    }
}

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The score screen's input: an InputDelegate, not a BehaviorDelegate, so no
// behavior turns a tap into START, a swipe into a page change or a swipe right into BACK. Every
// key, tap, swipe, touch hold, release, drag and flick is consumed (returns true), so nothing ever
// leaves the screen by itself: BACK only undoes. ScoreInput decides what each input does;
// this shows it and opens the next screens through MatchFlow. The data page and the stats page are
// the view's second and third pages, with this same input: the view turns between them.
// With touch scoring on, a tap on the score page is a point press, scored from onTap only:
// never from a touch-down, a drag, a hold or a swipe.
//
// Every input that does something also ends the game / set overlay: the press counts
// once, as it would without it. After a change the redraw is requested first (the score on
// screen within 100 ms of the release), then the slower work. requestUpdate() only queues the
// redraw, which runs once the handler returns, so the storage write of the match (about 35 ms on
// the FR265) isn't done here: the view does it at its timer's next wake-up, once the
// change is drawn (ScoreView).
class ScoreDelegate extends WatchUi.InputDelegate {

    private var _view as ScoreView;
    private var _match as CurrentMatch;
    private var _input as ScoreInput;
    // ScoreInput's, which every touch goes through.
    private var _back as BackGuard;
    // When the last quick BACK came (BACK_WAIT), for backDue().
    private var _backAt as Number = 0;

    function initialize(view as ScoreView, match as CurrentMatch) {
        InputDelegate.initialize();
        _view = view;
        _match = match;
        _input = new ScoreInput(match, getSessionManager());
        _back = _input.back;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        InputLog.add("press", keyEvent.getKey(), keyEvent.getType(), null);
        _back.keyPressed(keyEvent.getKey(), System.getTimer());
        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        InputLog.add("release", keyEvent.getKey(), keyEvent.getType(), null);
        return false;
    }

    // UP, DOWN and BACK arrive on release on the watch, START on press; hold UP as KEY_MENU. The
    // edge swipe's fake BACK does nothing (BackGuard): only the BACK button undoes. A quick BACK waits
    // for the swipe's drags on the view's timer (backDue()). The press delay is read at each key, so a
    // change in the Settings menu applies to the next press.
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        var now = System.getTimer();
        var check = _back.check(key, now);
        InputLog.add("key", key, keyEvent.getType(), check == BACK_NOW ? "ok" : check == BACK_WAIT ? "wait" : "blocked");
        if (check == BACK_NOW) {
            _input.debounce = Settings.getDebounce();
            act(_input.key(key, now));
        } else if (check == BACK_WAIT) {
            _backAt = now;
            _view.deferBack(now + BackGuard.WAIT_MS, method(:backDue));
        }
        return true;
    }

    // A quick BACK, BackGuard.WAIT_MS later: the undo, unless the screen was touched meanwhile.
    function backDue() as Void {
        var undo = _back.untouchedSince(_backAt);
        InputLog.add("back", null, null, undo ? "undo" : "dropped");
        if (undo) {
            act(_input.key(WatchUi.KEY_ESC, System.getTimer()));
        }
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        InputLog.add("swipe", swipeEvent.getDirection(), null, null);
        act(_input.swipe(swipeEvent.getDirection(), System.getTimer()));
        return true;
    }

    // A point press with touch scoring on, on the score page (ScoreInput.tap()); the settings are read at
    // each tap, so the match menu's toggle applies at once.
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var now = System.getTimer();
        var y = (clickEvent.getCoordinates() as Array<Number>)[1];
        _input.touchScoring = Settings.isTouchScoring();
        _input.debounce = Settings.getDebounce();
        var action = _input.tap(y, System.getDeviceSettings().screenHeight, _view.getPage(), now);
        InputLog.add("tap", y, null, action == INPUT_POINT ? (_input.team == TEAM_US ? "US" : "THEM") : null);
        act(action);
        return true;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        InputLog.add("hold", null, null, null);
        return touch();
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        InputLog.add("up", null, null, null);
        return touch();
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        InputLog.add("drag", dragEvent.getType(), null, null);
        return touch();
    }

    function onFlick(flickEvent as WatchUi.FlickEvent) as Boolean {
        InputLog.add("flick", null, null, null);
        return touch();
    }

    private function touch() as Boolean {
        act(_input.touch(System.getTimer()));
        return true;
    }

    private function act(action as ScoreAction) as Void {
        // The redraw first, with the flash or the overlay a point brings, without the overlay the
        // input ends, or another page (a swipe left or right; UP, DOWN and BACK on the data or stats page
        // bring the score page back). After the match's overlay the view hands over to the summary.
        _view.input(action, _input.team, _input.won, _input.ends);
        if (action == INPUT_POINT) {
            getFeedback().point(_input.team as Team, _input.won, _input.lap, _input.ends);
        } else if (action == INPUT_UNDO) {
            // The toast requests the redraw.
            showToast();
            getFeedback().undo();
        } else if (action == INPUT_TOAST) {
            showToast();
        } else if (action == INPUT_PAUSE) {
            MatchFlow.openPauseMenu(_match);
        } else if (action == INPUT_RESUME) {
            WatchUi.requestUpdate();
        } else if (action == INPUT_MATCH_MENU) {
            MatchFlow.openMatchMenu(_match);
        }
    }

    private function showToast() as Void {
        _view.showToast(WatchUi.loadResource(_input.toast as ResourceId) as String);
    }
}

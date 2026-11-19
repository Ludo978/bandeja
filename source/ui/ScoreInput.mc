import Toybox.Lang;
import Toybox.WatchUi;

// What the score screen does after an input (ScoreInput). Every input is consumed, whatever it gives.
enum ScoreAction {
    INPUT_NONE,        // nothing happens (a touch, a debounced press)
    INPUT_POINT,       // a point was added: ScoreInput.team won it, ScoreInput.won says what it won
    INPUT_UNDO,        // the last event was undone (ScoreInput.undone), the toast names it
    INPUT_TOAST,       // nothing changed, the toast says why: Paused, Nothing to undo, Match over, Match too long
    INPUT_PAUSE,       // START: the session is paused, the pause menu opens
    INPUT_RESUME,      // START while paused: the session runs again
    INPUT_MATCH_MENU,  // hold UP: the match menu, nothing scored
    INPUT_NEXT_PAGE,     // swipe left: the next page, the data page then the stats page (nothing on the last)
    INPUT_PREVIOUS_PAGE, // swipe right: the page before, back to the score page (nothing on the score page)
    INPUT_SCORE_PAGE     // BACK on the data or the stats page (ScoreInput.pageBack): the score page, nothing undone
}

// What a point won, for the feedback and the overlay.
enum PointWon {
    WON_POINT,  // only the point
    WON_GAME,
    WON_SET,    // a super tie-break too
    WON_MATCH
}

// The score screen's input rules, without the screen, so they're
// unit-tested: ScoreDelegate passes every input here and shows what comes back.
//
// UP scores a point for THEM (the top half), DOWN for US, read in onKey, which the watch sends on
// release: hold UP gives KEY_MENU (the match menu) and no KEY_UP, so it never scores (tested on the FR265). A
// point press less than debounce ms (the Press delay setting) after the last point that counted is
// ignored, for either team.
// BACK undoes the last event of any type, never debounced, and the point it takes back no longer
// holds the next press. It never undoes the serve's set-up, the serve events logged before any other
// (the "Who serves first?" answers): with only those left it says "Nothing to undo". START pauses, or resumes when paused. While paused, UP, DOWN and BACK change
// nothing and bring the toast "Paused". A swipe left turns to the next page (the data page, then the
// stats page) and a swipe right to the one before, other swipes do nothing. The data page and the
// stats page take the same input.
//
// Touches never score, but with touch scoring on a tap on the score page is a
// point press: the upper half for THEM, the lower half for US, with the same debounce, refusals and
// toasts, so a tap during the overlay counts as UP or DOWN would. Holds, drags, flicks and swipes
// never score, nor taps on the data page and the stats page. Every touch goes through the BACK guard
// (back), which the delegate's BACK keys go through too: a tap that scored doesn't hold BACK back, so
// BACK right after it undoes it, and a tap at the end of the watch's edge swipe never scores.
//
// The watches without UP and DOWN (InputFlags) set three flags. touchAlways: touch scoring is always on,
// the Touch scoring setting doesn't apply, and its gesture does (touchGesture): by tap as above, or by
// hold, where the watch's touch hold on a half of the score page is the point press and a tap does
// nothing. One hold, one point: hold events after a hold that scored do nothing until its finger lifts
// (release()) or BackGuard.HOLD_MS has passed, or an undo. pageBack: BACK on the data and stats pages
// brings the score page back and undoes nothing (pageKey()), any BACK key, the BACK guard not asked
// (keyCheck()). swipeMenu: a swipe up opens the match menu, from any page, as hold UP does.
class ScoreInput {

    // The last action's details: the team, what it won, whether it wrote its game's lap, which
    // the watch answers with its own lap alert (INPUT_POINT), and whether the players
    // change ends after it (INPUT_POINT, MatchState.changeOfEnds, so never at the match point,
    // and never after an undo, which describes the event left last), the event undone (INPUT_UNDO),
    // the toast's string (INPUT_UNDO, INPUT_TOAST). Cleared by the next input.
    var team as Team? = null;
    var won as PointWon = WON_POINT;
    var lap as Boolean = false;
    var ends as Boolean = false;
    var undone as MatchEvent? = null;
    var toast as ResourceId? = null;
    // The Touch scoring setting, which the delegate reads at each tap.
    var touchScoring as Boolean = Settings.DEFAULT_TOUCH_SCORING;
    // The watches without UP and DOWN: touch scoring always on, by touchGesture (the setting's gesture,
    // which the delegate reads at each touch); then BACK on the data and stats pages (pageBack), and a
    // swipe up for the match menu (swipeMenu). InputFlags sets them.
    var touchAlways as Boolean = false;
    var touchGesture as TouchGesture = Settings.DEFAULT_TOUCH_GESTURE;
    var pageBack as Boolean = false;
    var swipeMenu as Boolean = false;
    // The Press delay setting, in System.getTimer() milliseconds, which the delegate
    // reads at each key and each tap: a press is held to the value it comes with.
    var debounce as Number = Settings.DEFAULT_DEBOUNCE;
    // Tells the BACK button from the edge swipe's fake BACK: the delegate passes it the BACK
    // keys, the touches come through here.
    var back as BackGuard = new BackGuard();

    private var _match as CurrentMatch;
    private var _session as SessionManager;
    // System.getTimer() at the last point that counted; null before the first and after an undo.
    private var _lastPoint as Number? = null;
    // The last hold that scored, until its finger lifts (release()) or an undo: holds within
    // BackGuard.HOLD_MS of it are its own.
    private var _holdAt as Number? = null;

    function initialize(match as CurrentMatch, session as SessionManager) {
        _match = match;
        _session = session;
    }

    // What the BACK guard makes of a key on the page showing, which the delegate asks before pageKey().
    // With pageBack, a BACK key on the data page or the stats page acts at once whatever the guard says:
    // it undoes nothing there, so a watch that sends a swipe right as a BACK key still goes back. The
    // guard sees the key all the same (a quick one is the edge swipe's for the taps after it).
    function keyCheck(button as WatchUi.Key, page as ScorePage, now as Number) as BackCheck {
        var check = back.check(button, now);
        return pageBack && button == WatchUi.KEY_ESC && page != PAGE_SCORE ? BACK_NOW : check;
    }

    // A button on the page showing: with pageBack, BACK on the data page or the stats page brings the
    // score page back, nothing undone; else key().
    function pageKey(button as WatchUi.Key, page as ScorePage, now as Number) as ScoreAction {
        if (pageBack && button == WatchUi.KEY_ESC && page != PAGE_SCORE) {
            clear();
            return INPUT_SCORE_PAGE;
        }
        return key(button, now);
    }

    // A button, as onKey gets it; now is System.getTimer().
    function key(key as WatchUi.Key, now as Number) as ScoreAction {
        clear();
        if (key == WatchUi.KEY_UP) {
            return point(TEAM_THEM, now);
        } else if (key == WatchUi.KEY_DOWN) {
            return point(TEAM_US, now);
        } else if (key == WatchUi.KEY_ESC) {
            return undo();
        } else if (key == WatchUi.KEY_ENTER) {
            return startStop();
        } else if (key == WatchUi.KEY_MENU) {
            return INPUT_MATCH_MENU;
        }
        return INPUT_NONE;
    }

    // A swipe left or right turns the pages; up, with swipeMenu, opens the match menu.
    function swipe(direction as WatchUi.SwipeDirection, now as Number) as ScoreAction {
        clear();
        back.touched(now);
        if (direction == WatchUi.SWIPE_LEFT) {
            return INPUT_NEXT_PAGE;
        } else if (direction == WatchUi.SWIPE_RIGHT) {
            return INPUT_PREVIOUS_PAGE;
        }
        return swipeMenu && direction == WatchUi.SWIPE_UP ? INPUT_MATCH_MENU : INPUT_NONE;
    }

    // A drag, a flick, a hold or a release that scores nothing: never a point.
    function touch(now as Number) as ScoreAction {
        clear();
        back.touched(now);
        return INPUT_NONE;
    }

    // A touch's release: the finger lifted, so the next hold is a new one. The release of a hold that
    // scored is that hold's last touch, which doesn't start the BACK guard's wait; any other is a touch.
    function release(now as Number) as ScoreAction {
        if (_holdAt == null) {
            return touch(now);
        }
        _holdAt = null;
        clear();
        back.holdReleased(now);
        return INPUT_NONE;
    }

    // A touch hold (onHold) y pixels from the top of a screen height high, on the page showing. With
    // touch scoring by hold (touchAlways, GESTURE_HOLD), on the score page, a point press for the half
    // held as tap() has it, once: a hold within BackGuard.HOLD_MS of one that scored, its finger not
    // lifted since, is its own. A hold that scored doesn't start the BACK guard's wait. Otherwise, and
    // during the watch's edge swipe, a touch.
    function hold(y as Number, height as Number, page as ScorePage, now as Number) as ScoreAction {
        var holdAt = _holdAt;
        if (!scores(GESTURE_HOLD) || page != PAGE_SCORE || back.isEdgeSwipe(now)
                || (holdAt != null && now - holdAt >= 0 && now - holdAt < BackGuard.HOLD_MS)) {
            return touch(now);
        }
        clear();
        var action = point(y * 2 < height ? TEAM_THEM : TEAM_US, now);
        if (action == INPUT_POINT) {
            _holdAt = now;
            back.holdScored(now);
        } else {
            back.touched(now);
        }
        return action;
    }

    // A tap (onTap: a touch neither held nor moved more than a few pixels, never a swipe, a drag or a
    // hold) y pixels from the top of a screen height high, on the page showing. With touch scoring on, on
    // the score page, a point press for the half tapped: THEM above the middle, US from it down, which
    // doesn't start the BACK guard's wait when it scored. Otherwise, and at the end of the watch's
    // edge swipe, a touch like any other.
    function tap(y as Number, height as Number, page as ScorePage, now as Number) as ScoreAction {
        if (!scores(GESTURE_TAP) || page != PAGE_SCORE || back.isEdgeSwipe(now)) {
            return touch(now);
        }
        clear();
        var action = point(y * 2 < height ? TEAM_THEM : TEAM_US, now);
        if (action == INPUT_POINT) {
            back.tapScored(now);
        } else {
            back.touched(now);
        }
        return action;
    }

    // Whether gesture scores: by tap with touch scoring on; on the watches without UP and DOWN
    // (touchAlways) the setting's gesture, tap or hold.
    private function scores(gesture as TouchGesture) as Boolean {
        return touchAlways ? touchGesture == gesture : touchScoring && gesture == GESTURE_TAP;
    }

    // The "Undone" toast's string for an event type.
    static function undoneString(type as EventType) as ResourceId {
        if (type == EVENT_POINT_US) {
            return Rez.Strings.UndonePointUs;
        } else if (type == EVENT_POINT_THEM) {
            return Rez.Strings.UndonePointThem;
        } else if (type == EVENT_SWAP_OUR_SERVER) {
            return Rez.Strings.UndoneServerSwap;
        } else if (type == EVENT_FIX_SERVING_TEAM) {
            return Rez.Strings.UndoneServingTeam;
        } else if (type == EVENT_SET_DEUCE_MODE) {
            return Rez.Strings.UndoneDeuceMode;
        } else if (type == EVENT_END_SET) {
            return Rez.Strings.UndoneEndSet;
        } else if (type == EVENT_EDIT_SCORE) {
            return Rez.Strings.UndoneScoreEdit;
        }
        return Rez.Strings.UndoneEndMatch;
    }

    private function point(team as Team, now as Number) as ScoreAction {
        if (_session.isPaused()) {
            return showToast(Rez.Strings.ToastPaused);
        }
        // The difference stays right when the timer wraps around.
        var last = _lastPoint;
        if (last != null && now - last < debounce) {
            return INPUT_NONE;
        }
        var state = _match.getState();
        var games = state.finishedGames.size();
        var sets = state.setScores.size();
        // Only refused once the match is over, or at the longest match kept: End match and
        // Save, in the pause menu, still work then.
        var event = MatchEvent.now(team == TEAM_US ? EVENT_POINT_US : EVENT_POINT_THEM, null);
        if (!_match.engine.hasRoom(event)) {
            return showToast(Rez.Strings.ToastMatchFull);
        }
        if (!_match.add(event)) {
            return showToast(Rez.Strings.ToastMatchOver);
        }
        _lastPoint = now;
        state = _match.getState();
        self.team = team;
        won = state.matchOver ? WON_MATCH
            : state.setScores.size() > sets ? WON_SET
            : state.finishedGames.size() > games ? WON_GAME
            : WON_POINT;
        lap = _match.lapWritten;
        ends = state.changeOfEnds;
        return INPUT_POINT;
    }

    private function undo() as ScoreAction {
        if (_session.isPaused()) {
            return showToast(Rez.Strings.ToastPaused);
        }
        // The serve's set-up stays: undone, it would leave the server unknown before the first point,
        // so a stray BACK at 0-0 would lose the serve tracker. Fix serving team and Swap our server
        // order (the match menu) change it.
        var event = _match.engine.isServeSetUpOnly() ? null : _match.undo();
        if (event == null) {
            return showToast(Rez.Strings.UndoneNothing);
        }
        _lastPoint = null;
        _holdAt = null;
        undone = event;
        toast = undoneString(event.type);
        return INPUT_UNDO;
    }

    private function startStop() as ScoreAction {
        if (_session.isPaused()) {
            return _session.resume() ? INPUT_RESUME : INPUT_NONE;
        }
        return _session.pause() ? INPUT_PAUSE : INPUT_NONE;
    }

    private function showToast(id as ResourceId) as ScoreAction {
        toast = id;
        return INPUT_TOAST;
    }

    private function clear() as Void {
        team = null;
        won = WON_POINT;
        lap = false;
        ends = false;
        undone = null;
        toast = null;
    }
}

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
    INPUT_PREVIOUS_PAGE  // swipe right: the page before, back to the score page (nothing on the score page)
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
// holds the next press. START pauses, or resumes when paused. While paused, UP, DOWN and BACK change
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

    function initialize(match as CurrentMatch, session as SessionManager) {
        _match = match;
        _session = session;
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

    function swipe(direction as WatchUi.SwipeDirection, now as Number) as ScoreAction {
        clear();
        back.touched(now);
        if (direction == WatchUi.SWIPE_LEFT) {
            return INPUT_NEXT_PAGE;
        }
        return direction == WatchUi.SWIPE_RIGHT ? INPUT_PREVIOUS_PAGE : INPUT_NONE;
    }

    // A touch hold or its release, a drag, a flick: never a point.
    function touch(now as Number) as ScoreAction {
        clear();
        back.touched(now);
        return INPUT_NONE;
    }

    // A tap (onTap: a touch neither held nor moved more than a few pixels, never a swipe, a drag or a
    // hold) y pixels from the top of a screen height high, on the page showing. With touch scoring on, on
    // the score page, a point press for the half tapped: THEM above the middle, US from it down, which
    // doesn't start the BACK guard's wait when it scored. Otherwise, and at the end of the watch's
    // edge swipe, a touch like any other.
    function tap(y as Number, height as Number, page as ScorePage, now as Number) as ScoreAction {
        if (!touchScoring || page != PAGE_SCORE || back.isEdgeSwipe(now)) {
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
        var event = _match.undo();
        if (event == null) {
            return showToast(Rez.Strings.UndoneNothing);
        }
        _lastPoint = null;
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

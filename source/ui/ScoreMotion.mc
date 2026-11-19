import Toybox.Lang;

// The score screen's pages, left to right: a swipe left turns to the next one.
enum ScorePage {
    PAGE_SCORE,
    PAGE_DATA,
    PAGE_STATS
}

// The full team-color overlay after a point that won a game, a set or the match (mockup
// "Game won + change ends"), as numbers and resource IDs: ScoreView loads the strings and
// draws it. A context line (SET n, or TIE-BREAK, then the team), the word (GAME, SET, MATCH) and
// the score of the set the point was played in, our side first: its games, or the tie-break's
// points when a tie-break or the super tie-break decided it. Under them, the CHANGE ENDS pill when
// the players change ends after that game or set and the Change of ends alert is on.
class ScoreOverlay {

    var team as Team;
    // WON_GAME, WON_SET or WON_MATCH.
    var won as PointWon;
    // The set was decided by a tie-break or the super tie-break: the context says TIE-BREAK and the
    // score is its points.
    var tieBreak as Boolean = false;
    // n of SET n, from 1.
    var setNumber as Number;
    // Indexed by Team.
    var score as Array<Number>;
    // The CHANGE ENDS pill shows.
    var changeEnds as Boolean;

    function initialize(team as Team, won as PointWon, state as MatchState, changeEnds as Boolean) {
        self.team = team;
        self.won = won;
        self.changeEnds = changeEnds;
        var sets = state.setScores;
        if (won == WON_GAME || sets.size() == 0) {
            setNumber = sets.size() + 1;
            score = [state.games[TEAM_US], state.games[TEAM_THEM]];
            return;
        }
        var set = sets[sets.size() - 1];
        setNumber = sets.size();
        var points = set.tieBreakPoints;
        tieBreak = points != null;
        score = points != null ? [points[TEAM_US], points[TEAM_THEM]] : [set.games[TEAM_US], set.games[TEAM_THEM]];
    }

    // GAME, SET or MATCH.
    static function wordString(won as PointWon) as ResourceId {
        return won == WON_GAME ? Rez.Strings.OverlayGame : won == WON_SET ? Rez.Strings.OverlaySet
            : Rez.Strings.OverlayMatch;
    }

    // SET $1$ (the score screen's caption) or TIE-BREAK (its banner), before the team's name.
    static function contextString(tieBreak as Boolean) as ResourceId {
        return tieBreak ? Rez.Strings.BannerTieBreak : Rez.Strings.CaptionSet;
    }
}

// The score screen's motion and the timing of its one Timer, without the screen, so
// they're unit-tested: times in (System.getTimer() milliseconds, compared by difference so they
// stay right when the timer wraps around), what to draw and when to wake up out.
//
// A point flashes the scoring team's half to its 35 % tint for FLASH ms. A point that won a game, a
// set or the match shows the overlay instead, for OVERLAY ms: it covers the whole screen at once, so
// a flash under it would never be seen. Every input that does something (any ScoreAction but
// INPUT_NONE) ends the overlay, and ScoreInput has already acted on it, so the press counts once: UP
// and DOWN score, BACK undoes, START pauses, hold UP opens the match menu, and with touch scoring on
// a tap scores as UP or DOWN would. A press the debounce ignores and any other touch do
// nothing, so the overlay stays. An undo ends the flash too: the point it showed is gone, and an undo
// never flashes.
//
// The change of ends comes with the point after which the players change ends
// (ScoreInput.ends), while the Change of ends alert is on (endsAlert): the CHANGE ENDS pill on the
// game or set overlay; in a tie-break or the super tie-break, where a point brings no overlay, the
// toast on the net (endsToast, which ScoreView shows on its Toast, timed by the same Timer). Like
// the overlay, they take no input: the next press counts as it would without them.
//
// The match's overlay hands over to the summary once it has run its time, or at once when UP
// or DOWN, refused once the match is over, ends it. BACK undoes the match point instead, and START
// and hold UP open their menus over the score screen: when they close and the screen shows again
// (shown()), the summary takes over. A swipe left shows the data page, which stays, like the stats
// page after it, until the player leaves them (swipes back to the score page, or UP or DOWN, which
// bring it back): the summary then.
//
// One Timer serves the whole screen: the 1 Hz tick (elapsed time, heart rate), the end of the flash,
// the overlay and the toast, and the summary's hand-over. nextWake() gives the wait until the first
// of them.
//
// It also says which page shows: the score page, or in its place the data
// page or the stats page after it. A swipe left turns to the next page, a swipe right to the one
// before; toward no page (left on the stats page, right on the score page) it does nothing. UP, DOWN
// and BACK answer on the score page, so a point, an undo or a toast brings it back, with its flash,
// overlay or toast; START and hold UP open their menus over the page showing, which stays. On the
// watches without UP and DOWN (InputFlags), BACK on the data or stats page brings the score page back
// (INPUT_SCORE_PAGE), and a swipe left on the stats page goes round to the score page (wrap).
class ScoreMotion {

    static const FLASH = 200;
    static const OVERLAY = 1500;
    static const TICK = 1000;
    // The shortest Timer wait (Timer docs: 50 ms on most devices).
    static const MIN_WAIT = 50;

    // When the next 1 Hz tick is due.
    var tickAt as Number = 0;
    // The page showing: the score page, the data page or the stats page. The match menu's
    // Data page and Stats page show theirs (showPage()).
    var page as ScorePage = PAGE_SCORE;
    // The Change of ends alert setting, which the screen reads when it shows: off, a change
    // of ends brings neither the pill nor the toast.
    var endsAlert as Boolean = true;
    // A swipe left on the stats page turns to the score page (InputFlags).
    var wrap as Boolean = false;
    // The last input was a point that only won the point and after which the players change ends: the
    // change of ends toast shows from it, for the toast's time.
    var endsToast as Boolean = false;

    private var _flash as Team? = null;
    private var _flashAt as Number = 0;
    private var _overlay as ScoreOverlay? = null;
    private var _overlayAt as Number = 0;
    // When the summary takes over, null when it doesn't.
    private var _summaryAt as Number? = null;

    function initialize() {
    }

    // An input that changes nothing: none, or a page swipe toward no page (swipe left on the stats page,
    // the last, unless the pages go round, swipe right on the score page, the first), or the score page
    // asked for on it.
    function isIdle(action as ScoreAction) as Boolean {
        return action == INPUT_NONE || (action == INPUT_NEXT_PAGE && page == PAGE_STATS && !wrap)
            || ((action == INPUT_PREVIOUS_PAGE || action == INPUT_SCORE_PAGE) && page == PAGE_SCORE);
    }

    // The match menu's Data page and Stats page: true when target, the data page or the stats page,
    // wasn't showing and now does, from any other page.
    function showPage(target as ScorePage) as Boolean {
        if (page == target) {
            return false;
        }
        page = target;
        return true;
    }

    // After an input on the score screen at now, with ScoreInput's action, team, what the point won
    // and whether the players change ends after it, and the state after it. Returns the overlay it
    // ended, or null.
    function input(action as ScoreAction, team as Team?, won as PointWon, ends as Boolean, state as MatchState,
            now as Number) as ScoreOverlay? {
        endsToast = false;
        if (isIdle(action)) {
            return null;
        }
        if (action == INPUT_NEXT_PAGE) {
            page = page == PAGE_SCORE ? PAGE_DATA : page == PAGE_STATS ? PAGE_SCORE : PAGE_STATS;
        } else if (action == INPUT_PREVIOUS_PAGE) {
            page = page == PAGE_STATS ? PAGE_DATA : PAGE_SCORE;
        } else if (action == INPUT_POINT || action == INPUT_UNDO || action == INPUT_TOAST || action == INPUT_SCORE_PAGE) {
            page = PAGE_SCORE;
        }
        var ended = getOverlayAt(now);
        _overlay = null;
        // At the match end the summary takes over as soon as the score page shows: at once after UP
        // or DOWN (refused, "Match over") or a swipe right back to it. A menu (START, hold UP) holds it
        // until the screen shows again (shown()), and the data and stats pages until the player leaves
        // them. The match point sets it after its overlay, below.
        _summaryAt = state.matchOver && page == PAGE_SCORE && action != INPUT_PAUSE && action != INPUT_MATCH_MENU
            ? now : null;
        if (action == INPUT_POINT && team != null) {
            var change = ends && endsAlert;
            if (won == WON_POINT) {
                _flash = team;
                _flashAt = now;
                endsToast = change;
            } else {
                _flash = null;
                _overlay = new ScoreOverlay(team, won, state, change);
                _overlayAt = now;
                if (won == WON_MATCH) {
                    _summaryAt = now + OVERLAY;
                }
            }
        } else if (action == INPUT_UNDO) {
            _flash = null;
        }
        return ended;
    }

    // The team whose half flashes at now, or null.
    function getFlashAt(now as Number) as Team? {
        var age = now - _flashAt;
        return age >= 0 && age < FLASH ? _flash : null;
    }

    // The overlay showing at now, or null.
    function getOverlayAt(now as Number) as ScoreOverlay? {
        var age = now - _overlayAt;
        return age >= 0 && age < OVERLAY ? _overlay : null;
    }

    // Whether the flash or the overlay shown at then and at now differ: the screen drawn at then needs
    // a redraw.
    function changed(then as Number, now as Number) as Boolean {
        return getFlashAt(then) != getFlashAt(now) || getOverlayAt(then) != getOverlayAt(now);
    }

    // True once, at the first call from the time the summary takes over.
    function takeSummary(now as Number) as Boolean {
        var at = _summaryAt;
        if (at == null || now - at < 0) {
            return false;
        }
        _summaryAt = null;
        return true;
    }

    // The screen shows: the first tick a second from now.
    function startTicks(now as Number) as Void {
        tickAt = now + TICK;
    }

    // The screen shows again, a menu closed: with the match over (a menu opened at the match end, or
    // during its overlay) on the score page, the summary takes over at once. The overlay hidden by
    // something else keeps its hand-over at its end.
    function shown(state as MatchState, now as Number) as Void {
        if (state.matchOver && page == PAGE_SCORE && getOverlayAt(now) == null) {
            _summaryAt = now;
        }
    }

    // At a wake-up: true when the tick is due, and the next one is then set a second after it, or a
    // second from now if the wake-up came more than a second late.
    function tick(now as Number) as Boolean {
        if (now - tickAt < 0) {
            return false;
        }
        tickAt += TICK;
        if (now - tickAt >= 0) {
            tickAt = now + TICK;
        }
        return true;
    }

    // The wait in ms from now until the timer must wake up: the next tick, the end of the flash, the
    // overlay or the toast (toastEnd, null with no toast), or the summary's hand-over, whichever comes
    // first, and never less than MIN_WAIT.
    function nextWake(now as Number, toastEnd as Number?) as Number {
        var wait = tickAt - now;
        if (getFlashAt(now) != null) {
            wait = earlier(wait, _flashAt + FLASH - now);
        }
        if (getOverlayAt(now) != null) {
            wait = earlier(wait, _overlayAt + OVERLAY - now);
        }
        var summary = _summaryAt;
        if (summary != null) {
            wait = earlier(wait, summary - now);
        }
        if (toastEnd != null) {
            wait = earlier(wait, toastEnd - now);
        }
        return wait < MIN_WAIT ? MIN_WAIT : wait;
    }

    private static function earlier(a as Number, b as Number) as Number {
        return b < a ? b : a;
    }
}

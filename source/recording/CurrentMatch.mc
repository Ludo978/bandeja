import Toybox.Lang;

// The match being played: its engine (format and event log) and its start, tied to the recording.
// Created when the match starts, at the START that ends the warm-up or, with the Warm-up phase off,
// the one that begins recording (WarmUpFlow), or from the stored match at a resume (MatchRecovery),
// and held by the app for the screens that follow (getMatch()). It gives the session its match for
// the session fields (SessionManager.setMatch()), and every event added or undone through it
// reaches the lap commit and the record field (LapCommitter.update()), so score input calls nothing
// else.
//
// Every event added or undone also leaves it unsaved, until save() writes it to storage (MatchStore).
// The write takes about 35 ms on the watch, so the screens call save() once the change is
// on screen: the score screen at its next wake-up after the redraw, or when a menu covers it; the
// menus after each event; MatchFlow when the match starts.
class CurrentMatch {

    var engine as ScoringEngine;
    // When the match started, in seconds (Time.now().value()): the first game's duration runs from
    // it (MatchState.getStats()). Not an event: undo never takes the match back to the warm-up.
    // Stored with the log for a resume.
    var start as Number;
    // Indoor / Outdoor as picked for the match, stored for the resumed session's GPS.
    var outdoor as Boolean;
    // A timed match's court booking, null for an untimed match: picked at setup, before
    // the match (WarmUpFlow), stored with it. Its end time and the alerts given aren't events.
    var court as CourtBooking? = null;
    // The last change wrote a game's lap (LapCommitter.update()): the watch is playing its own lap
    // alert, so the app's feedback leaves that press to it.
    var lapWritten as Boolean = false;
    private var _laps as LapCommitter;
    private var _unsaved as Boolean = true;
    private var _released as Boolean = false;

    function initialize(engine as ScoringEngine, start as Number, outdoor as Boolean, session as SessionManager,
            laps as LapCommitter) {
        self.engine = engine;
        self.start = start;
        self.outdoor = outdoor;
        _laps = laps;
        session.setMatch(engine, start);
    }

    // Adds the event (MatchEvent.now() in the app); false, changing nothing, when it's refused.
    function add(event as MatchEvent) as Boolean {
        if (!engine.add(event)) {
            return false;
        }
        lapWritten = _laps.update(engine.getState());
        _unsaved = true;
        return true;
    }

    // Removes the last event, whatever its type, and returns it, or null when there's none.
    function undo() as MatchEvent? {
        var undone = engine.undo();
        if (undone != null) {
            lapWritten = _laps.update(engine.getState());
            _unsaved = true;
        }
        return undone;
    }

    // The current state; get it again after every change.
    function getState() as MatchState {
        return engine.getState();
    }

    // The court time alert due at now (CourtBooking.take()), given once, so the match is to be
    // written: a resume won't give it again. None for an untimed match, nor once the match is over
    // (the summary): undone back into the match, it comes then.
    function takeCourtAlert(now as Number) as CourtAlert {
        var booking = court;
        if (booking == null || getState().matchOver) {
            return COURT_NONE;
        }
        var alert = booking.take(now);
        if (alert != COURT_NONE) {
            _unsaved = true;
        }
        return alert;
    }

    // Keep playing, once the court time is up: no more alerts, no TIME banner (written too).
    function keepPlaying() as Void {
        var booking = court;
        if (booking != null) {
            booking.keepPlaying();
            _unsaved = true;
        }
    }

    // Debug builds only: the booking ends seconds from now, its alerts not given yet, to reach the
    // warnings and the TIME alert in the simulator without waiting.
    (:debug)
    function debugCourtEnd(now as Number, seconds as Number) as Void {
        var booking = court;
        if (booking != null) {
            booking.end = now + seconds;
            booking.alert = COURT_NONE;
            _unsaved = true;
        }
    }

    // A change isn't written to storage yet.
    function isUnsaved() as Boolean {
        return _unsaved;
    }

    // The match is saved and leaves (MatchFlow.saved(), the app stopped on a finished match): its log and
    // undo snapshots go (ScoringEngine.release()), so the history's write has their memory with a long
    // match, and nothing writes it to storage again.
    function release() as Void {
        engine.release();
        _released = true;
        _unsaved = false;
    }

    // Writes the match to storage if it changed since the last write (never once released).
    function save() as Void {
        if (_unsaved && !_released) {
            MatchStore.save(engine, start, outdoor, court);
            _unsaved = false;
        }
    }
}

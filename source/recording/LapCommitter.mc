import Toybox.Lang;

// One lap per game, written at the point that wins it, with its lap values (LapValues),
// tie-breaks and the super tie-break included. The match point writes none: the save closes the last
// lap, with that game's values, so no lap is left holding the time on the summary. Every lap makes the
// watch play its own lap alert, a beep and a buzz, which the app can't turn off: that is the game's
// signal, and the app adds no feedback of its own (update()'s result). Lap 1, the warm-up,
// is SessionManager.startMatch()'s.
//
// The FIT API can't change or remove a lap. It reads the state after every change to the match, an
// event added or undone, and only writes the laps of games beyond those already written: undoing a
// game-winning point leaves its lap, the game played again gets no second one, and the written lap
// keeps its first values. As it sees every change, it also keeps the record field,
// the point differential, up to date.
class LapCommitter {

    private var _session as SessionManager;
    // Game laps written. The lap of finished game i is written once this is above i. Undo never
    // lowers it: a written lap stays.
    private var _committed as Number = 0;

    function initialize(session as SessionManager) {
        _session = session;
    }

    // To call after every event added or undone. Writes the lap of each finished game not written yet,
    // but the match point's, then gives the session the values of the lap in progress, for the save,
    // and the point differential. True when it wrote a lap: the watch is playing its lap alert.
    function update(state as MatchState) as Boolean {
        var written = _committed;
        var closed = getClosedGames(state);
        while (_committed < closed) {
            if (!_session.addLap(LapValues.forGame(state, _committed))) {
                break;
            }
            _committed++;
        }
        _session.setLapValues(_committed < state.finishedGames.size()
            ? LapValues.forGame(state, _committed) : LapValues.forUnfinished(state));
        setPointDifferential(state);
        return _committed > written;
    }

    // Resume after a crash, once the new session has started: the games played so far had
    // their laps in the lost session, so the new session's laps start with the game in progress. Its
    // chart starts at the differential the match is at.
    function resume(state as MatchState) as Void {
        _committed = state.finishedGames.size();
        _session.setLapValues(LapValues.forUnfinished(state));
        setPointDifferential(state);
    }

    // The record field: our points minus theirs, every point of the match counted.
    private function setPointDifferential(state as MatchState) as Void {
        _session.setPointDifferential(state.pointsWon[TEAM_US] - state.pointsWon[TEAM_THEM]);
    }

    // Game laps written so far, the warm-up not included.
    function getCommitted() as Number {
        return _committed;
    }

    // Finished games whose lap can be written: all of them, but the last once the match is over. When
    // the match point won it, the save closes its lap; after End match, or an End set now that ended
    // the match, its point already wrote it.
    static function getClosedGames(state as MatchState) as Number {
        var finished = state.finishedGames.size();
        return state.matchOver ? finished - 1 : finished;
    }
}

import Toybox.Lang;

// Where the recording stands. IDLE moves to WARM_UP or MATCH (start) or to FAILED (the watch
// refused the session), WARM_UP to MATCH (startMatch), WARM_UP and MATCH to ENDED (save,
// discard). ENDED and FAILED are final: the app then returns to the watch face.
enum SessionPhase {
    SESSION_IDLE,
    SESSION_WARM_UP,  // recording, lap 1 is the warm-up
    SESSION_MATCH,    // recording, the match has started
    SESSION_ENDED,    // saved or discarded
    SESSION_FAILED    // the watch refused the Padel session: nothing records
}

// The only owner of the FIT session. The app holds one for its whole run, so
// no screen can drop the recording: screens ask it to start, pause, save or discard, and check
// isRecording() before letting BACK leave. Pure logic over a Recorder, so the tests use a fake.
class SessionManager {

    private var _recorder as Recorder;
    private var _phase as SessionPhase = SESSION_IDLE;
    private var _paused as Boolean = false;
    private var _sensorsOn as Boolean = false;
    private var _gps as Boolean = false;
    private var _error as String?;
    // The lap fields of the lap in progress (LapCommitter). Only match laps get them.
    private var _lapValues as LapValues?;
    // The match the session fields come from, and its start (setMatch()).
    private var _match as ScoringEngine?;
    private var _matchStart as Number = 0;
    // The record field as last set: FitFields starts it at 0.
    private var _pointDifferential as Number = 0;

    function initialize(recorder as Recorder) {
        _recorder = recorder;
    }

    // Sensor lock before START: heart rate, and GPS only outdoors (criterion 7).
    // start() turns them on anyway; a screen only calls this to lock them earlier.
    function enableSensors(outdoor as Boolean) as Void {
        if (_phase != SESSION_IDLE || (_sensorsOn && _gps == outdoor)) {
            return;
        }
        _recorder.enableSensors(outdoor);
        _sensorsOn = true;
        _gps = outdoor;
    }

    // Leaving the sensor lock without recording (BACK to the home screen): the sensors go off, GPS
    // included. While recording they stay on until save or discard.
    function disableSensors() as Void {
        if (_phase == SESSION_IDLE) {
            releaseSensors();
        }
    }

    // Creates the Padel session and starts recording: in the warm-up (lap 1) when warmUp is on,
    // else straight into the match. One session per app run. False when the watch refuses it:
    // the phase is then SESSION_FAILED for the error screen, with no fallback to another sport.
    function start(outdoor as Boolean, warmUp as Boolean) as Boolean {
        if (_phase != SESSION_IDLE) {
            return false;
        }
        try {
            _recorder.createSession();
        } catch (e) {
            fail(e.getErrorMessage());
            return false;
        }
        enableSensors(outdoor);
        if (!_recorder.start()) {
            _recorder.discard();
            fail(null);
            return false;
        }
        _phase = warmUp ? SESSION_WARM_UP : SESSION_MATCH;
        return true;
    }

    // The match starts: closes the warm-up lap, so lap 2 begins. False without a
    // warm-up, or once the match has started.
    function startMatch() as Boolean {
        if (_phase != SESSION_WARM_UP) {
            return false;
        }
        _recorder.addLap();
        _phase = SESSION_MATCH;
        return true;
    }

    // Closes the current lap during the match, paused or not, with values as its lap fields. Only
    // LapCommitter calls it: one lap per game, written at the point that wins it.
    function addLap(values as LapValues) as Boolean {
        if (_phase != SESSION_MATCH) {
            return false;
        }
        _recorder.setLapValues(values);
        _recorder.addLap();
        return true;
    }

    // The lap fields of the lap in progress, which LapCommitter keeps up to date after every change.
    // They reach the recorder where the timer stops, so the last lap, which the save closes, has them.
    function setLapValues(values as LapValues) as Void {
        _lapValues = values;
    }

    // The match whose session fields the session writes, worked out where the timer stops
    // and again at a save from the pause, with the stats its state keeps (no replay, so a pause
    // costs the same at any length of match). matchStart is when its first game began (the START
    // that ended the warm-up), which the app keeps with the match. The app gives it when the match
    // starts or is resumed; the warm-up writes none.
    function setMatch(engine as ScoringEngine, matchStart as Number) as Void {
        _match = engine;
        _matchStart = matchStart;
    }

    // The record field: our points minus theirs (LapCommitter, after every change). Set on the
    // recorder only while recording, and only when it changes (smart recording writes a record
    // when a value changes).
    function setPointDifferential(value as Number) as Void {
        if (isRecording() && value != _pointDifferential) {
            _recorder.setPointDifferential(value);
            _pointDifferential = value;
        }
    }

    // Stops the timer (pause menu). The session keeps recording until save or discard.
    function pause() as Boolean {
        if (!isRecording() || _paused) {
            return false;
        }
        stopTimer();
        return true;
    }

    function resume() as Boolean {
        if (!isRecording() || !_paused || !_recorder.start()) {
            return false;
        }
        _paused = false;
        return true;
    }

    // Writes the FIT file and ends the session. False when the watch can't: the session stays,
    // paused, so the player can save again or discard.
    function save() as Boolean {
        if (!isRecording()) {
            return false;
        }
        if (_paused) {
            // Set at the pause, but the menus may have changed them since (End match, End set now, and
            // Edit score, which the match menu offers while paused): the lap in progress's fields too.
            setLapFields();
            setSessionValues();
        }
        stopTimer();
        if (!_recorder.save()) {
            return false;
        }
        end();
        return true;
    }

    // Drops the recording and ends the session. Always ends it, so the player is never trapped.
    function discard() as Boolean {
        if (!isRecording()) {
            return false;
        }
        stopTimer();
        _recorder.discard();
        end();
        return true;
    }

    function getPhase() as SessionPhase {
        return _phase;
    }

    // A session exists and isn't saved or discarded, paused or not: BACK must not leave the app.
    function isRecording() as Boolean {
        return _phase == SESSION_WARM_UP || _phase == SESSION_MATCH;
    }

    function isPaused() as Boolean {
        return _paused;
    }

    // Why the watch refused the session, as it said (not translated), or null.
    function getError() as String? {
        return _error;
    }

    // The only place the timer stops, on a pause as before save or discard. The lap fields of the
    // lap in progress (the one save closes) and the session fields are set here, right before, in
    // the match only (the warm-up lap gets none): values must be set while recording,
    // and a save from the pause menu comes after it. An event logged while paused (End set now, Edit
    // score) can change both, so they are set again at that save.
    private function stopTimer() as Void {
        if (!_paused) {
            setLapFields();
            setSessionValues();
            _recorder.stop();
            _paused = true;
        }
    }

    // The lap in progress's fields, the ones the save closes the last lap with, in the match only.
    private function setLapFields() as Void {
        var values = _lapValues;
        if (values != null && _phase == SESSION_MATCH) {
            _recorder.setLapValues(values);
        }
    }

    private function setSessionValues() as Void {
        var match = _match;
        if (match != null && _phase == SESSION_MATCH) {
            _recorder.setSessionValues(SessionValues.compute(match, _matchStart));
        }
    }

    private function fail(message as String?) as Void {
        _phase = SESSION_FAILED;
        _error = message;
        releaseSensors();
    }

    private function end() as Void {
        _phase = SESSION_ENDED;
        _paused = false;
        releaseSensors();
    }

    private function releaseSensors() as Void {
        if (_sensorsOn) {
            _recorder.disableSensors();
            _sensorsOn = false;
            _gps = false;
        }
    }
}

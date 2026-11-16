import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.WatchUi;

// What SessionManager drives on the watch: one FIT session and the sensors it records. FitRecorder
// is the real one; unit tests use RecordingTests.FakeRecorder, since they can't record a session.
typedef Recorder as interface {
    // Creates the Padel session, not started yet. Throws when the watch refuses it.
    function createSession() as Void;
    // Starts or restarts the timer; false when the watch doesn't.
    function start() as Boolean;
    function stop() as Void;
    // The lap fields of the lap in progress, written when it closes (addLap(), or save() for the
    // last lap). On the watch they stay set for the laps after it until set again.
    function setLapValues(values as LapValues) as Void;
    // The session fields, written by save(). Values set before start() are dropped.
    function setSessionValues(values as SessionValues) as Void;
    // The record field (the Momentum chart), written with every record until set again.
    function setPointDifferential(value as Number) as Void;
    // Closes the current lap; the next one begins.
    function addLap() as Void;
    // Writes the FIT file; false when the watch can't, and the session is kept.
    function save() as Boolean;
    function discard() as Void;
    // Heart rate, plus GPS when gps is true (turned off when it's false).
    function enableSensors(gps as Boolean) as Void;
    function disableSensors() as Void;
};

class FitRecorder {

    private var _session as ActivityRecording.Session?;
    // The developer fields; null if the watch refused them.
    private var _fields as FitFields?;
    private var _gps as Boolean = false;

    function initialize() {
    }

    function createSession() as Void {
        var session = ActivityRecording.createSession({
            :name => WatchUi.loadResource(Rez.Strings.ActivityName) as String,
            :sport => Activity.SPORT_RACKET,
            :subSport => Activity.SUB_SPORT_PADEL
        });
        _session = session;
        // Without its developer fields the activity still records: only the score data is lost.
        try {
            _fields = new FitFields(session);
        } catch (e) {
            _fields = null;
        }
    }

    function start() as Boolean {
        var session = _session;
        return session != null && session.start();
    }

    function stop() as Void {
        var session = _session;
        if (session != null) {
            session.stop();
        }
    }

    function setLapValues(values as LapValues) as Void {
        var fields = _fields;
        if (fields != null) {
            fields.setLapValues(values);
        }
    }

    function setSessionValues(values as SessionValues) as Void {
        var fields = _fields;
        if (fields != null) {
            fields.setSessionValues(values);
        }
    }

    function setPointDifferential(value as Number) as Void {
        var fields = _fields;
        if (fields != null) {
            fields.setPointDifferential(value);
        }
    }

    function addLap() as Void {
        var session = _session;
        if (session != null) {
            session.addLap();
        }
    }

    function save() as Boolean {
        var session = _session;
        if (session == null || !session.save()) {
            return false;
        }
        _session = null;
        _fields = null;
        return true;
    }

    function discard() as Void {
        var session = _session;
        if (session != null) {
            session.discard();
        }
        _session = null;
        _fields = null;
    }

    function enableSensors(gps as Boolean) as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        setGps(gps);
    }

    function disableSensors() as Void {
        Sensor.setEnabledSensors([]);
        setGps(false);
    }

    // The session records the positions by itself; the app doesn't use them.
    function onPosition(info as Position.Info) as Void {
    }

    private function setGps(on as Boolean) as Void {
        if (on == _gps) {
            return;
        }
        if (on) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        } else {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        }
        _gps = on;
    }
}

// Debug builds only: a recorder the watch refuses, for the error screen (BandejaApp).
(:debug)
class RefusingRecorder extends FitRecorder {

    function initialize() {
        FitRecorder.initialize();
    }

    function createSession() as Void {
        throw new Lang.InvalidValueException("Simulated (debug build)");
    }
}

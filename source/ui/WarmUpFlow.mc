import Toybox.Lang;
import Toybox.WatchUi;

// What the screen does after a press on the sensor lock or the warm-up (WarmUpFlow).
enum WarmUpStep {
    STEP_NONE,     // nothing changed
    STEP_TOAST,    // "Press START to begin the match": nothing else happens
    STEP_WARM_UP,  // recording started, in the warm-up
    STEP_MATCH,    // the match started: getMatch() holds it
    STEP_FAILED,   // the watch refused the session: the error screen
    STEP_HOME,     // BACK before recording: back to the home screen
    STEP_MENU,     // the warm-up's menu (WarmUpFlow.swipe())
    STEP_LOCK_MENU // the sensor lock's menu: the debug menu in debug builds, none in release
}

// From PLAY to the match, the rules without the screen, so they're unit-tested.
// The sensor lock comes first: nothing records, START begins recording, BACK goes home and turns the
// sensors off. Then, with the Warm-up phase on, the warm-up: lap 1 records, UP, DOWN and BACK only
// bring the toast (they never score and never leave), and START, or Start match in its menu,
// starts the match. With the Warm-up phase off, the START that begins recording starts the match.
// The match starts at once: lap 2 begins (SessionManager.startMatch()) and the match holder
// (CurrentMatch) is created with that time as the match start; the serve questions come after,
// before the first point. On the watches without UP and DOWN (InputFlags), a swipe up opens the menu
// the menu key opens (swipeMenu).
class WarmUpFlow {

    // As MatchFlow read them at PLAY: the format, Indoor / Outdoor, the Warm-up phase setting.
    var config as MatchConfig;
    var outdoor as Boolean;
    var warmUp as Boolean;
    // A timed match's court booking, picked before the sensor lock (CourtMenu), so its
    // countdown and alerts run from the lock on; the match takes it. Null for an untimed match.
    var court as CourtBooking? = null;
    // A swipe up opens the screen's menu (InputFlags).
    var swipeMenu as Boolean = false;

    private var _session as SessionManager;
    private var _laps as LapCommitter;
    private var _match as CurrentMatch? = null;

    function initialize(config as MatchConfig, outdoor as Boolean, warmUp as Boolean, session as SessionManager,
            laps as LapCommitter) {
        self.config = config;
        self.outdoor = outdoor;
        self.warmUp = warmUp;
        _session = session;
        _laps = laps;
    }

    // The sensor lock, while the screen shows before recording: heart rate, GPS outdoors.
    function lock() as Void {
        if (_session.getPhase() == SESSION_IDLE) {
            _session.enableSensors(outdoor);
        }
    }

    // START, or Start match in the warm-up menu. now is the time (Time.now().value()) the match
    // starts at, if it does.
    function start(now as Number) as WarmUpStep {
        var phase = _session.getPhase();
        if (phase == SESSION_IDLE) {
            if (!_session.start(outdoor, warmUp)) {
                return STEP_FAILED;
            }
            if (warmUp) {
                return STEP_WARM_UP;
            }
        } else if (!_session.startMatch()) {
            return STEP_NONE;
        }
        var match = new CurrentMatch(new ScoringEngine(config), now, outdoor, _session, _laps);
        match.court = court;
        _match = match;
        return STEP_MATCH;
    }

    // UP or DOWN: never a point. The toast while recording, nothing at the lock.
    function press() as WarmUpStep {
        return _session.isRecording() ? STEP_TOAST : STEP_NONE;
    }

    // BACK (or a swipe right): the toast while recording, never an exit; at the lock, home, with
    // the sensors off.
    function back() as WarmUpStep {
        if (_session.isRecording()) {
            return STEP_TOAST;
        }
        _session.disableSensors();
        return STEP_HOME;
    }

    // A swipe, with swipeMenu: up opens what the menu key opens, the warm-up's menu while recording, the
    // lock's before. Nothing otherwise.
    function swipe(direction as WatchUi.SwipeDirection) as WarmUpStep {
        if (!swipeMenu || direction != WatchUi.SWIPE_UP) {
            return STEP_NONE;
        }
        return _session.isRecording() ? STEP_MENU : STEP_LOCK_MENU;
    }

    function isRecording() as Boolean {
        return _session.isRecording();
    }

    // The match, once started.
    function getMatch() as CurrentMatch? {
        return _match;
    }
}

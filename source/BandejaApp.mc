import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The app, and the glance's too: in the watch's glance loop this class runs with the glance
// code alone ((:glance): LastMatch, BandejaGlance), in 64 KB, and only getGlanceView() is asked for. So
// nothing here touches the rest of the app before getInitialView(): the session, its laps and the
// feedback are made when first asked for, and onStop() does nothing for the glance. The functions the
// glance never calls skip the compiler's glance scope check (typecheck(disableGlanceCheck)).
(:glance)
class BandejaApp extends Application.AppBase {

    // The one owner of the FIT session for the whole run: screens come and go, it stays.
    private var _session as SessionManager? = null;
    // Its game laps, fed after every event added or undone.
    private var _laps as LapCommitter? = null;
    // The match being played, from the START that starts it (MatchFlow.startMatch()).
    private var _match as CurrentMatch? = null;
    // Vibration and tones, kept for the run so a pattern outlives the screen it began on.
    private var _feedback as Feedback? = null;
    // getInitialView() ran: the app runs, not its glance.
    private var _foreground as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    // The system stops the app while it records (the watch turned off): the session is saved and the
    // match stays stored for the resume prompt (MatchRecovery.stop()), or, when it was over, goes
    // into the history. After Save or Discard, nothing records and nothing is stored.
    // Stopped during the launch replay, which didn't fail, its mark goes. The glance's stop does
    // nothing.
    (:typecheck(disableGlanceCheck))
    function onStop(state as Dictionary?) as Void {
        if (!_foreground) {
            return;
        }
        MatchStore.endLoad();
        // Taken before the session's save, which clears the activity's timer and calories.
        var match = _match;
        var session = getSessionManager();
        var record = match != null && session.isRecording() ? MatchFlow.historyRecord(match) : null;
        if (MatchRecovery.stop(session, match) && record != null) {
            // Saved, the stored match cleared: as after a Save (MatchFlow.saved()).
            (match as CurrentMatch).release();
            HistoryStore.add(record);
        }
    }

    // The resume prompt when a match is stored (an unfinished match left by a crash, a stop
    // or a flat battery), else the home screen. The stored match is replayed first, in try/catch and
    // a step at a time (ResumeMenu.launchView()): one that can't be read offers Discard only.
    // A history saved before the glance gives the glance its value first (HistoryStore.restoreLast()).
    (:typecheck(disableGlanceCheck))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _foreground = true;
        HistoryStore.restoreLast();
        if (MatchStore.isStored()) {
            return ResumeMenu.launchView();
        }
        var view = new HomeView();
        return [view, new HomeDelegate(view)];
    }

    // A change made in the Garmin Connect app, also during a match: it applies as one
    // made on the watch. The settings are read when needed (Settings), so what reads them at each press
    // or event already has it (touch scoring, the press delay, Vibration, Sounds); the menus showing
    // settings show it at once (SettingsMenu.refresh()), and the screen showing reads again what it
    // reads when it shows: the score screen its change of ends alert and theme, the summary its theme
    // and the match's own its team names. What is read at a moment (Serve tracking at the match start,
    // the Warm-up phase at PLAY) applies from the next one, as from the watch. The glance's does nothing.
    (:typecheck(disableGlanceCheck))
    function onSettingsChanged() as Void {
        if (!_foreground) {
            return;
        }
        SettingsMenu.refresh();
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ScoreView) {
            view.applySettings();
        } else if (view instanceof SummaryView) {
            view.applySettings();
        }
        WatchUi.requestUpdate();
    }

    // The glance: the last saved match in the glance loop. Selecting it opens the app
    // (getInitialView()).
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new BandejaGlance()];
    }

    (:typecheck(disableGlanceCheck))
    function getSessionManager() as SessionManager {
        var session = _session;
        if (session == null) {
            session = new SessionManager(new FitRecorder());
            _session = session;
            _laps = new LapCommitter(session);
        }
        return session;
    }

    (:typecheck(disableGlanceCheck))
    function getLapCommitter() as LapCommitter {
        getSessionManager();
        return _laps as LapCommitter;
    }

    function getMatch() as CurrentMatch? {
        return _match;
    }

    (:typecheck(disableGlanceCheck))
    function getFeedback() as Feedback {
        var feedback = _feedback;
        if (feedback == null) {
            feedback = new Feedback();
            _feedback = feedback;
        }
        return feedback;
    }

    function setMatch(match as CurrentMatch) as Void {
        _match = match;
    }

    // Debug builds only: the next START gets a session the watch refuses, to see the error screen
    // in the simulator, where createSession never fails.
    (:debug, :typecheck(disableGlanceCheck))
    function simulateRefusedSession() as Void {
        if (getSessionManager().getPhase() == SESSION_IDLE) {
            var session = new SessionManager(new RefusingRecorder());
            _session = session;
            _laps = new LapCommitter(session);
        }
    }
}

function getSessionManager() as SessionManager {
    return (Application.getApp() as BandejaApp).getSessionManager();
}

function getLapCommitter() as LapCommitter {
    return (Application.getApp() as BandejaApp).getLapCommitter();
}

// The match being played, null before it starts.
function getMatch() as CurrentMatch? {
    return (Application.getApp() as BandejaApp).getMatch();
}

function getFeedback() as Feedback {
    return (Application.getApp() as BandejaApp).getFeedback();
}

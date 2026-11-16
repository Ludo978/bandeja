import Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The one way into a match: PLAY on the home screen calls begin(), and nothing else
// starts one. It takes the format, Indoor / Outdoor and the Warm-up phase setting as stored at that
// moment, so a match never changes format under the player.
module MatchFlow {

    // The score screen of the match being played (showScore()), for the match menu's Data page and
    // Stats page; null while the summary shows.
    var _score as ScoreView? = null;
    // The low battery save was tried (checkBattery()): once per run.
    var _lowBatteryTried as Boolean = false;
    // The record the summary shows (showSummary()), which its Save puts into the history as it is;
    // null while no summary shows.
    var _record as HistoryRecord? = null;

    // The sensor lock, then the warm-up when the Warm-up phase setting is on (WarmUpView). A timed
    // match asks for the court booking's end time first (CourtMenu), so its countdown runs
    // from the lock on; BACK there returns home.
    function begin() as Void {
        if (Settings.isTimedMatch()) {
            CourtMenu.open();
        } else {
            openLock(null);
        }
    }

    // The sensor lock, with the court booking picked for a timed match (null for an untimed one).
    function openLock(court as CourtBooking?) as Void {
        var flow = new WarmUpFlow(FormatStore.load(), Settings.isOutdoor(), Settings.isWarmUp(),
            getSessionManager(), getLapCommitter());
        flow.court = court;
        var view = new WarmUpView(flow);
        WatchUi.pushView(view, new WarmUpDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // The match has started (WarmUpFlow.start(): the START that ends the warm-up, or the one that
    // begins recording without it). It's stored from now on, so a crash before the first point can
    // be resumed too: the warm-up has no score to keep. The serve questions open
    // over the score screen, before the first point, when serve tracking is on (read now, so a
    // change in the warm-up menu's Settings counts), and close on it.
    function startMatch(match as CurrentMatch) as Void {
        match.save();
        showScore(match);
        ServeMenu.open(new ServeQuestions(match, Settings.isServeTracking()));
    }

    // Resume at the launch prompt (ResumeMenu): the stored match on a new session with no warm-up
    // (MatchRecovery.resume()), in place of the prompt. The summary when the match was over; the
    // serve questions, as at the match start, when it had no event yet; else the score screen. The
    // error screen when the watch refuses the session.
    function resume(stored as StoredMatch) as Void {
        var session = getSessionManager();
        var match = MatchRecovery.resume(stored, session, getLapCommitter());
        if (match == null) {
            showSessionError(session);
            return;
        }
        var state = match.getState();
        if (state.matchOver) {
            (Application.getApp() as BandejaApp).setMatch(match);
            showSummary(match);
        } else if (state.eventCount == 0) {
            startMatch(match);
        } else {
            showScore(match);
        }
    }

    // Discard at the launch prompt (confirmed, the stored match cleared): the home screen in its
    // place.
    function home() as Void {
        var view = new HomeView();
        WatchUi.switchToView(view, new HomeDelegate(view), WatchUi.SLIDE_RIGHT);
    }

    // The app keeps the match for the screens that follow, and the score screen replaces the one
    // showing (the warm-up screen), so BACK never returns to it.
    function showScore(match as CurrentMatch) as ScoreView {
        return openScore(match, WatchUi.SLIDE_LEFT);
    }

    // showScore() with the caller's slide: BACK from the summary slides the score screen down.
    function openScore(match as CurrentMatch, transition as WatchUi.SlideType) as ScoreView {
        (Application.getApp() as BandejaApp).setMatch(match);
        _record = null;
        var view = new ScoreView(match);
        WatchUi.switchToView(view, new ScoreDelegate(view, match), transition);
        _score = view;
        return view;
    }

    // The screens the score screen opens (ScoreDelegate), each filled in by its task.

    // START, the session just paused: the pause menu (MatchMenus). BACK there leaves the
    // timer stopped.
    function openPauseMenu(match as CurrentMatch) as Void {
        MatchMenus.openPause(new MatchMenuRules(match, getSessionManager()));
    }

    // Hold UP: the match menu (MatchMenus), the timer running (or still stopped, paused).
    function openMatchMenu(match as CurrentMatch) as Void {
        MatchMenus.openMatch(new MatchMenuRules(match, getSessionManager()));
    }

    // Data page or Stats page in the match menu (closed first): page, the data page or the stats page,
    // the score screen's second and third pages, which the swipes also turn to
    // (ScoreView). Stays on it when the menu was opened there.
    function showPage(page as ScorePage) as Void {
        var view = _score;
        if (view != null) {
            view.showPage(page);
        }
    }

    // The match is over: a point won it, or End match or End set now in the pause menu (closed first,
    // the session paused, the last event END_MATCH or END_SET). After the point, the match's overlay
    // shows first and the score screen's timer calls this when it's over: 1.5 s after the point, or
    // at once when UP or DOWN ends it (refused, "Match over"); after a menu opened at the match end,
    // when the score screen shows again (ScoreMotion). The summary replaces the score
    // screen, its stats read once, here: the match's record (HistoryRecord.of()), with its stats
    // (MatchState.getStats(), no replay) and the activity's values as they stand now, which a Save
    // there puts into the history as it is (saved()), with the team names of that moment.
    function showSummary(match as CurrentMatch) as Void {
        var record = HistoryRecord.of(match, activityValues());
        record.names = Settings.getTeamNames();
        var model = new SummaryModel(record);
        var view = new SummaryView(model, true);
        var input = new SummaryInput(match, getSessionManager(), model.getPageCount());
        WatchUi.switchToView(view, new SummaryDelegate(view, input, match), WatchUi.SLIDE_UP);
        _score = null;
        _record = record;
    }

    // BACK on the summary, or its menu's Back to match: undone is the event SummaryInput took back.
    // The score screen replaces the summary with the match as it was before that event, and the
    // session as it is (running after a match point, paused after the pause menu's End match or End
    // set now: START resumes there). The undo's toast and pulse, as BACK on the score screen.
    function backToMatch(match as CurrentMatch, undone as MatchEvent) as Void {
        var view = openScore(match, WatchUi.SLIDE_DOWN);
        view.showToast(WatchUi.loadResource(ScoreInput.undoneString(undone.type)) as String);
        getFeedback().undo();
        // The new score screen writes the undo once it shows (ScoreView).
    }

    // The session is saved: the summary's START or Save, the pause menu's Save, the low battery save.
    // record, the match as it was saved (historyRecord(), taken before the session's save, which
    // clears the activity's timer and calories), goes into the history, then the app
    // exits (exit()). The match's log and undo snapshots go first: the history's write needs their
    // memory with a long match, and nothing is added or undone after a save.
    function saved(record as HistoryRecord?) as Void {
        var match = getMatch();
        if (match != null) {
            match.release();
        }
        if (record != null) {
            HistoryStore.add(record);
        }
        exit();
    }

    // The match's record for the history: the one the summary shows, with the values it opened with,
    // so the history keeps what it showed; else the match as it stands, with the activity's values now
    // (the pause menu's Save, the low battery save, the app stopped during the match's overlay), so
    // taken before the session is saved. Either way with the team names as they are at the save,
    // which the summary showing shows too (SummaryView.applySettings()): the record keeps
    // them, so a later rename in the Garmin Connect app leaves the saved match as it was.
    function historyRecord(match as CurrentMatch) as HistoryRecord {
        var record = _record;
        if (record == null) {
            record = HistoryRecord.of(match, activityValues());
        }
        record.names = Settings.getTeamNames();
        return record;
    }

    // The session is saved (saved()) or discarded (confirmed): nothing is left to resume, and the app
    // exits to the watch face.
    function exit() as Void {
        MatchStore.clear();
        System.exit();
    }

    // On the score screen's and the warm-up's 1 Hz tick, while recording: at 3 % battery the session
    // is saved (result unfinished, unless the match is over) and the app exits. True
    // then. Tried once per run: a save the watch refuses leaves the session paused, the match stored,
    // and the pause menu's Save and Discard.
    function checkBattery() as Boolean {
        var session = getSessionManager();
        if (_lowBatteryTried || !session.isRecording()) {
            return false;
        }
        var stats = System.getSystemStats();
        if (!MatchRecovery.isBatteryLow(stats.battery, stats.charging)) {
            return false;
        }
        _lowBatteryTried = true;
        var match = getMatch();
        var record = match != null ? historyRecord(match) : null;
        if (!session.save()) {
            return false;
        }
        saved(record);
        return true;
    }

    // [timer seconds, average heart rate, maximum heart rate, calories] as the activity has them now,
    // each null when the watch doesn't give it; a debug fixture's values when the score screen shows
    // one (ScoreView.getFixed()).
    function activityValues() as Array<Number?> {
        var score = _score;
        var fixed = score != null ? score.getFixed() : null;
        if (fixed != null) {
            return [fixed[0], fixed[1], fixed.size() > 4 ? fixed[4] : null, fixed[2]] as Array<Number?>;
        }
        var info = Activity.getActivityInfo();
        var timer = info != null ? info.timerTime : null;
        return [timer != null ? timer / 1000 : null, info != null ? info.averageHeartRate : null,
            info != null ? info.maxHeartRate : null, info != null ? info.calories : null] as Array<Number?>;
    }
}

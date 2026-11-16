import Toybox.Lang;

// What keeps a match through a crash, a stop and a flat battery, without the screens, so
// it's unit-tested over a fake recorder: the resume of a stored match on a new session, what the app
// does when the system stops it while recording, and the battery level that saves the session.
module MatchRecovery {

    // The battery level, in percent, at which the app saves the session by itself.
    const LOW_BATTERY = 3.0;

    // Resume at launch: the stored match on a new Padel session with no warm-up (the previous one
    // was lost with the crash). The match holder takes the restored engine and the stored start,
    // which gives the session its match (session fields); the lap commit counts the games already
    // played as written, so the new session's laps start with the game in progress and no burst of
    // laps comes at the next game won, and the record field starts at the match's point
    // differential (LapCommitter.resume()). A timed match keeps its court booking: the same end
    // time, and the alerts already given aren't given again. Null when the watch refuses the
    // session: the error screen, as at PLAY.
    function resume(stored as StoredMatch, session as SessionManager, laps as LapCommitter) as CurrentMatch? {
        if (!session.start(stored.outdoor, false)) {
            return null;
        }
        var match = new CurrentMatch(stored.engine, stored.start, stored.outdoor, session, laps);
        match.court = stored.court;
        laps.resume(match.getState());
        return match;
    }

    // The system stops the app while it records (AppBase.onStop(): the watch turned off, the app
    // terminated). The match is written if its last event isn't yet, and the session is saved, so
    // its heart rate, time and laps aren't lost (result unfinished mid-match). The stored match
    // stays, so the next launch offers to resume it, unless it's over: then nothing is left to play,
    // it's cleared, and true says the match goes into the history as after a Save. A
    // crash calls nothing: only the stored match is left.
    function stop(session as SessionManager, match as CurrentMatch?) as Boolean {
        if (!session.isRecording()) {
            return false;
        }
        if (match != null) {
            match.save();
        }
        if (session.save() && match != null && match.getState().matchOver) {
            MatchStore.clear();
            return true;
        }
        return false;
    }

    // The battery as System.Stats gives it: at LOW_BATTERY or less, and not charging.
    function isBatteryLow(battery as Float, charging as Boolean) as Boolean {
        return !charging && battery <= LOW_BATTERY;
    }
}

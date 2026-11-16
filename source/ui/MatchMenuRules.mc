import Toybox.Lang;

// An item of the pause menu or the match menu, also its menu item's ID.
enum MatchMenuItem {
    ITEM_RESUME,
    ITEM_END_MATCH,
    ITEM_SAVE,
    ITEM_DISCARD,
    ITEM_SWAP_SERVER,
    ITEM_FIX_SERVING_TEAM,
    ITEM_DEUCE_MODE,
    ITEM_END_SET,
    ITEM_SETTINGS,
    ITEM_DATA_PAGE,
    ITEM_VIBRATION,
    ITEM_SOUNDS,
    ITEM_FINISH,       // a timed match once the time is up: End match under another name
    ITEM_KEEP_PLAYING, // and Resume, the TIME alert done with
    ITEM_EDIT_SCORE,   // the match menu's Edit score (EditScoreRules)
    ITEM_TOUCH_SCORING, // the match menu's Touch scoring, a setting
    ITEM_STATS_PAGE    // the match menu's Stats page, after Data page
}

// The pause menu (START) and the match menu (hold UP) without the native menus
// (MatchMenus), so they're unit-tested: which items show for the match as it stands, the value shown
// under the items that set one, and what each item logs. Every event goes through the match holder,
// so the laps follow it and BACK on the score screen undoes it with its toast.
//
// An item that would only log a refused event isn't shown: Swap our server order in singles,
// and every event once the match is over (only undo reopens it); at the longest match kept
// (ScoringEngine.isFull()) every event but End match, and Edit score once the log has no room for an edit
// of the score as it stands. Fix serving team stays while the server is unknown: it starts serve
// tracking. Picking the team already serving or the deuce mode already chosen logs nothing.
//
// A timed match whose court time is up (CourtBooking.offersFinish()) offers Finish and Keep playing at
// the top of the pause menu, in place of Resume and End match: Finish ends the match
// early as End match does, Keep playing resumes and ends the TIME alert. Never a prompt during play.
class MatchMenuRules {

    var match as CurrentMatch;
    private var _session as SessionManager;

    function initialize(match as CurrentMatch, session as SessionManager) {
        self.match = match;
        _session = session;
    }

    // Resume / End match / Save / Discard / Swap our server order / Fix serving team / Deuce mode /
    // End set now / Settings; Resume / Save / Discard / Settings once the match is over. At now
    // (Time.now().value()) a timed match's time is up: Finish / Keep playing in place of Resume / End
    // match.
    function getPauseItems(now as Number) as Array<MatchMenuItem> {
        var open = !isMatchOver();
        var court = match.court;
        var items = [] as Array<MatchMenuItem>;
        if (open && court != null && court.offersFinish(now)) {
            items.add(ITEM_FINISH);
            items.add(ITEM_KEEP_PLAYING);
        } else {
            items.add(ITEM_RESUME);
            if (open) {
                items.add(ITEM_END_MATCH);
            }
        }
        items.add(ITEM_SAVE);
        items.add(ITEM_DISCARD);
        if (open && !match.engine.isFull()) {
            addCorrections(items);
            items.add(ITEM_END_SET);
        }
        items.add(ITEM_SETTINGS);
        return items;
    }

    // Data page / Stats page / Swap our server order / Fix serving team / Deuce mode / Edit score /
    // Vibration / Sounds / Touch scoring; Data page / Stats page / Vibration / Sounds / Touch scoring once
    // the match is over (the pages and the settings log nothing). Edit score is in this menu only, not
    // the pause menu.
    function getMatchItems() as Array<MatchMenuItem> {
        var items = [ITEM_DATA_PAGE, ITEM_STATS_PAGE] as Array<MatchMenuItem>;
        if (!isMatchOver() && !match.engine.isFull()) {
            addCorrections(items);
        }
        // Left out past the sets an edit holds (ScoreEdit.MAX, a long Free play), where every edit would
        // be refused.
        var sets = match.getState().setScores.size();
        if (!isMatchOver() && sets <= ScoreEdit.MAX && EditScoreRules.fits(match.engine, sets)) {
            items.add(ITEM_EDIT_SCORE);
        }
        items.add(ITEM_VIBRATION);
        items.add(ITEM_SOUNDS);
        items.add(ITEM_TOUCH_SCORING);
        return items;
    }

    function getLabel(item as MatchMenuItem) as ResourceId {
        return [Rez.Strings.Resume, Rez.Strings.MenuEndMatch, Rez.Strings.Save, Rez.Strings.Discard,
            Rez.Strings.MenuSwapServer, Rez.Strings.MenuFixServingTeam, Rez.Strings.MenuDeuceMode,
            Rez.Strings.MenuEndSet, Rez.Strings.MenuSettings, Rez.Strings.MenuDataPage,
            Rez.Strings.MenuVibration, Rez.Strings.MenuSounds, Rez.Strings.MenuFinish, Rez.Strings.MenuKeepPlaying,
            Rez.Strings.MenuEditScore, Rez.Strings.MenuTouchScoring, Rez.Strings.MenuStatsPage][item];
    }

    // The value under an item that sets one: our player for our current or next service game (Swap
    // our server order), the team serving now (Fix serving team, none while unknown), the deuce mode
    // chosen for the next games (Deuce mode). Null for the others; Vibration's is a setting, and
    // Sounds and Touch scoring are toggles.
    function getValue(item as MatchMenuItem) as ResourceId? {
        var state = match.getState();
        if (item == ITEM_SWAP_SERVER) {
            return state.ourServer == PLAYER_PARTNER ? Rez.Strings.ServePartner : Rez.Strings.ServeMe;
        } else if (item == ITEM_FIX_SERVING_TEAM) {
            var team = state.getServingTeam();
            return team != null ? teamName(team) : null;
        } else if (item == ITEM_DEUCE_MODE) {
            return FormatText.deuceModeName(state.deuceMode);
        }
        return null;
    }

    // Us or Them, as the menus' lists show the teams.
    static function teamName(team as Team) as ResourceId {
        return team == TEAM_US ? Rez.Strings.TeamUs : Rez.Strings.TeamThem;
    }

    // Swap our server order: our two players swap their order (a toggle). Refused in singles.
    function swapServer(time as Number) as Boolean {
        return add(EVENT_SWAP_OUR_SERVER, null, time);
    }

    // The team serving the point now, which Fix serving team opens on; null while unknown.
    function getServingTeam() as Team? {
        return match.getState().getServingTeam();
    }

    // Fix serving team: team serves the point now. Nothing is logged when it already does.
    function fixServingTeam(team as Team, time as Number) as Boolean {
        return add(EVENT_FIX_SERVING_TEAM, team, time);
    }

    // The deuce mode chosen for the next games, which Deuce mode opens on.
    function getDeuceMode() as DeuceMode {
        return match.getState().deuceMode;
    }

    // From the next game, or from this one while no point is played in it.
    // Nothing is logged for the mode already chosen.
    function setDeuceMode(mode as DeuceMode, time as Number) as Boolean {
        return add(EVENT_SET_DEUCE_MODE, mode, time);
    }

    // End set now must ask who gets the set: its games are level, or the super tie-break's points.
    function isSetLevel() as Boolean {
        return match.getState().getSetLeader() == null;
    }

    // End set now: the set goes to the team ahead (team null), or when it's level to team, the
    // player's answer. The game in progress is dropped. It may end the match (isMatchOver()).
    function endSet(team as Team?, time as Number) as Boolean {
        return add(EVENT_END_SET, team, time);
    }

    // End match, and Finish once a timed match's time is up: the early end result, by sets, then the
    // unfinished set's games, then the game's points, else a draw.
    function endMatch(time as Number) as Boolean {
        return add(EVENT_END_MATCH, null, time);
    }

    function isMatchOver() as Boolean {
        return match.getState().matchOver;
    }

    // Resume: the timer runs again.
    function resume() as Boolean {
        return _session.resume();
    }

    // Keep playing, once a timed match's time is up: the timer runs again, and the TIME alert is done
    // with (no more alerts, no TIME banner). Logs nothing.
    function keepPlaying() as Boolean {
        match.keepPlaying();
        return _session.resume();
    }

    // Save: the FIT file with the result as it stands (unfinished mid-match). False when the watch
    // can't, the session then kept, paused.
    function save() as Boolean {
        return _session.save();
    }

    // Swap our server order (doubles only), Fix serving team, Deuce mode.
    private function addCorrections(items as Array<MatchMenuItem>) as Void {
        if (match.getState().doubles) {
            items.add(ITEM_SWAP_SERVER);
        }
        items.add(ITEM_FIX_SERVING_TEAM);
        items.add(ITEM_DEUCE_MODE);
    }

    private function add(type as EventType, payload as Number?, time as Number) as Boolean {
        return match.add(new MatchEvent(type, time, payload));
    }
}

import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The pause menu (START, titled "Paused") and the match menu (hold UP, the timer
// running), native menus over the score screen. MatchMenuRules says which items
// show and what each logs. Once a timed match's time is up, the pause menu opens on Finish, then Keep
// playing.
//
// An item that sets a value stays in its menu and shows the new value under its label, as in the
// Settings menu: Swap our server order (our next server, Me / Partner), Fix serving team (Us / Them),
// Deuce mode (the four modes, opening on the current one), Vibration, Sounds and Touch scoring. The
// other items leave it: Resume, End match, End set now, Data page and Stats page close it, Save and
// Discard end the app, Settings opens its menu above it, and so does Edit score (EditScoreMenu), whose
// Apply closes both.
// The score screen shows the events once the menu closes, and BACK there undoes the last one with its
// toast (while paused, after START). BACK closes the menu, the pause menu leaving the
// timer stopped. A pick gives no feedback.
module MatchMenus {

    function openPause(rules as MatchMenuRules) as Void {
        var menu = build(Rez.Strings.ToastPaused, rules, rules.getPauseItems(Time.now().value()));
        WatchUi.pushView(menu, new MatchMenuDelegate(menu, rules), WatchUi.SLIDE_UP);
    }

    function openMatch(rules as MatchMenuRules) as Void {
        var menu = build(Rez.Strings.AppName, rules, rules.getMatchItems());
        addDebugItems(menu, rules.match);
        WatchUi.pushView(menu, new MatchMenuDelegate(menu, rules), WatchUi.SLIDE_UP);
    }

    // Its Vibration, Sounds and Touch scoring items follow a change made in the Garmin Connect app
    // (SettingsMenu.watch()).
    function build(title as ResourceId, rules as MatchMenuRules, items as Array<MatchMenuItem>) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => title});
        var settings = {} as Dictionary<Object, Symbol>;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (item == ITEM_VIBRATION) {
                menu.addItem(SettingsMenu.vibrationItem(item));
                settings[item] = :vibration;
            } else if (item == ITEM_SOUNDS) {
                menu.addItem(SettingsMenu.soundsItem(item));
                settings[item] = :sounds;
            } else if (item == ITEM_TOUCH_SCORING) {
                menu.addItem(SettingsMenu.touchScoringItem(item));
                settings[item] = :touchScoring;
            } else {
                menu.addItem(new WatchUi.MenuItem(rules.getLabel(item), rules.getValue(item), item, null));
            }
        }
        if (settings.size() > 0) {
            SettingsMenu.watch(menu, settings);
        }
        return menu;
    }

    // Debug builds only, last in the match menu: a deliberate crash, confirmed, to check the
    // resume after one in the simulator and on the watch (an unhandled exception: no onStop, only the
    // stored match is left), with the storage writes' last and longest times under it (MatchStore).
    // Real matches are played with the sideloaded debug build too (the store beta is a release build),
    // hence the confirmation and its place out of the pause menu. In a timed match, Court end
    // before it moves the booking's end close (DebugCourt).
    const DEBUG_CRASH = 100;
    const DEBUG_COURT = 101;
    const DEBUG_INPUT_LOG = 102;
    // A change made as the Garmin Connect app makes it, a few seconds after the menu closes
    // (DebugSettings).
    const DEBUG_SETTINGS = 103;

    (:debug)
    function addDebugItems(menu as WatchUi.Menu2, match as CurrentMatch) as Void {
        if (match.court != null) {
            menu.addItem(new WatchUi.MenuItem("Court end (debug)", null, DEBUG_COURT, null));
        }
        menu.addItem(new WatchUi.MenuItem("Input log (debug)", null, DEBUG_INPUT_LOG, null));
        menu.addItem(new WatchUi.MenuItem("Connect change (debug)", DebugSettings.nextName(), DEBUG_SETTINGS, null));
        menu.addItem(new WatchUi.MenuItem("Crash (debug)",
            "Write " + MatchStore.lastWrite + " ms, max " + MatchStore.longestWrite, DEBUG_CRASH, null));
    }

    (:release)
    function addDebugItems(menu as WatchUi.Menu2, match as CurrentMatch) as Void {
    }
}

class MatchMenuDelegate extends WatchUi.Menu2InputDelegate {

    // The level set question's Cancel (End set now).
    private const CANCEL = -1;

    private var _menu as WatchUi.Menu2;
    private var _rules as MatchMenuRules;

    function initialize(menu as WatchUi.Menu2, rules as MatchMenuRules) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _rules = rules;
    }

    // A toggle (Sounds, Touch scoring) has already switched when this is called.
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == MatchMenus.DEBUG_CRASH) {
            crash();
            return;
        } else if (item.getId() == MatchMenus.DEBUG_COURT) {
            debugCourt();
            return;
        } else if (item.getId() == MatchMenus.DEBUG_INPUT_LOG) {
            inputLog();
            return;
        } else if (item.getId() == MatchMenus.DEBUG_SETTINGS) {
            connectChange();
            close();
            return;
        }
        var id = item.getId() as Number as MatchMenuItem;
        if (id == ITEM_RESUME) {
            _rules.resume();
            close();
        } else if (id == ITEM_KEEP_PLAYING) {
            // Logs nothing, but the alert done with is written, so a resume doesn't bring it back.
            _rules.keepPlaying();
            _rules.match.save();
            close();
        } else if (id == ITEM_END_MATCH || id == ITEM_FINISH) {
            if (_rules.endMatch(now())) {
                matchEnded();
            }
        } else if (id == ITEM_SAVE) {
            // After Save the app returns to the watch face. A refused save keeps the session,
            // paused, and the menu, to save again or discard. The history's record is taken
            // first: the save clears the activity's timer and calories.
            var record = MatchFlow.historyRecord(_rules.match);
            if (_rules.save()) {
                MatchFlow.saved(record);
            } else {
                ChoiceMenu.setSubLabel(_menu, ITEM_SAVE, Rez.Strings.SaveFailed);
            }
        } else if (id == ITEM_DISCARD) {
            DiscardConfirm.push();
        } else if (id == ITEM_SWAP_SERVER) {
            if (_rules.swapServer(now())) {
                logged();
            }
        } else if (id == ITEM_FIX_SERVING_TEAM) {
            // On the team serving now, or on Us while unknown.
            var team = _rules.getServingTeam();
            ChoiceMenu.push(Rez.Strings.MenuFixServingTeam, [Rez.Strings.TeamUs, Rez.Strings.TeamThem],
                [TEAM_US as Number, TEAM_THEM as Number], (team != null ? team : TEAM_US) as Number,
                method(:onServingTeam));
        } else if (id == ITEM_DEUCE_MODE) {
            var modes = FormatChoices.deuceModeChoices();
            var labels = [] as Array<String or ResourceId>;
            var values = [] as Array<Number>;
            for (var i = 0; i < modes.size(); i++) {
                labels.add(FormatText.deuceModeName(modes[i]));
                values.add(modes[i] as Number);
            }
            ChoiceMenu.push(Rez.Strings.MenuDeuceMode, labels, values, _rules.getDeuceMode() as Number,
                method(:onDeuceMode));
        } else if (id == ITEM_END_SET) {
            if (_rules.isSetLevel()) {
                // Level: who gets the set, Us / Them / Cancel.
                ChoiceMenu.push(Rez.Strings.SetWinner, [Rez.Strings.TeamUs, Rez.Strings.TeamThem, Rez.Strings.Cancel],
                    [TEAM_US as Number, TEAM_THEM as Number, CANCEL], TEAM_US as Number, method(:onSetWinner));
            } else {
                endSet(null);
            }
        } else if (id == ITEM_SETTINGS) {
            SettingsMenu.open();
        } else if (id == ITEM_EDIT_SCORE) {
            EditScoreMenu.open(new EditScoreRules(_rules.match));
        } else if (id == ITEM_DATA_PAGE) {
            close();
            MatchFlow.showPage(PAGE_DATA);
        } else if (id == ITEM_STATS_PAGE) {
            close();
            MatchFlow.showPage(PAGE_STATS);
        } else if (id == ITEM_VIBRATION) {
            SettingsMenu.pushVibration(_menu, ITEM_VIBRATION);
        } else if (id == ITEM_SOUNDS) {
            Settings.setSounds((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == ITEM_TOUCH_SCORING) {
            Settings.setTouchScoring((item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }

    // The menu closes; from the pause menu the timer stays stopped.
    function onBack() as Void {
        close();
    }

    // The lists pop themselves before these (ChoiceMenu), back on this menu.

    function onServingTeam(value as Number) as Void {
        if (_rules.fixServingTeam(value as Team, now())) {
            logged();
        }
    }

    function onDeuceMode(value as Number) as Void {
        if (_rules.setDeuceMode(value as DeuceMode, now())) {
            logged();
        }
    }

    function onSetWinner(value as Number) as Void {
        if (value != CANCEL) {
            endSet(value as Team);
        }
    }

    // The set ends; the score screen shows the next one, or the match is over.
    private function endSet(team as Team?) as Void {
        if (!_rules.endSet(team, now())) {
            return;
        }
        if (_rules.isMatchOver()) {
            matchEnded();
        } else {
            logged();
            close();
        }
    }

    // End match, or End set now that ended it: the summary, in place of the score screen.
    private function matchEnded() as Void {
        logged();
        close();
        MatchFlow.showSummary(_rules.match);
    }

    // After every event logged: the match is written (no score shows under the menu to hold
    // back), and the values under the items follow it.
    private function logged() as Void {
        _rules.match.save();
        var items = [ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE] as Array<MatchMenuItem>;
        for (var i = 0; i < items.size(); i++) {
            ChoiceMenu.setSubLabel(_menu, items[i], _rules.getValue(items[i]));
        }
    }

    private function close() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    // Debug builds only: confirmed, an exception nothing catches ends the app as a crash does.
    (:debug)
    private function crash() as Void {
        WatchUi.pushView(new WatchUi.Confirmation("Crash the app?"), new DebugCrashDelegate(), WatchUi.SLIDE_LEFT);
    }

    (:release)
    private function crash() as Void {
    }

    // Debug builds only: the court booking ends in a few minutes from now (DebugCourt).
    (:debug)
    private function debugCourt() as Void {
        DebugCourt.push(new DebugCourt(_rules.match, null).method(:onChoice));
    }

    (:release)
    private function debugCourt() as Void {
    }

    // Debug builds only: the score screen's last input events (InputLog).
    (:debug)
    private function inputLog() as Void {
        InputLog.show();
    }

    (:release)
    private function inputLog() as Void {
    }

    // Debug builds only: a Garmin Connect change, applied once the menu is closed (DebugSettings).
    (:debug)
    private function connectChange() as Void {
        DebugSettings.schedule();
    }

    (:release)
    private function connectChange() as Void {
    }

    private function now() as Number {
        return Time.now().value();
    }
}

(:debug)
class DebugCrashDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            throw new Lang.InvalidValueException("debug crash");
        }
        return true;
    }
}

// Debug builds only: a timed match's court booking made to end a set time from now, its alerts
// not given yet, from the match menu (the match's) or the warm-up menu (the flow's, before the match):
// the mockups' 85:28 and 47:43, then 10 s before the T-10 and T-5 warnings and the end, so they come
// at once in the simulator.
(:debug)
class DebugCourt {

    static const SECONDS = [5128, 2863, 610, 310, 10] as Array<Number>;

    private var _match as CurrentMatch?;
    private var _flow as WarmUpFlow?;

    function initialize(match as CurrentMatch?, flow as WarmUpFlow?) {
        _match = match;
        _flow = flow;
    }

    static function push(onChoice as Method(value as Number) as Void) as Void {
        var labels = [] as Array<String or ResourceId>;
        for (var i = 0; i < SECONDS.size(); i++) {
            labels.add(TimeText.countdown(SECONDS[i]));
        }
        ChoiceMenu.push(Rez.Strings.AppName, labels, SECONDS, SECONDS[0], onChoice);
    }

    function onChoice(value as Number) as Void {
        var now = Time.now().value();
        var match = _match;
        var flow = _flow;
        if (match != null) {
            match.debugCourtEnd(now, value);
            match.save();
        } else if (flow != null && flow.court != null) {
            var court = flow.court as CourtBooking;
            court.end = now + value;
            court.alert = COURT_NONE;
        }
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Debug builds only: a change made as the Garmin Connect app makes it, for the simulator, whose
// own app settings editor (File > Edit Persistent Storage > Edit Application.Properties data) waits on
// a keychain prompt on this machine. The properties are written as Connect writes them (a list's value
// as a Number, a toggle's as a Boolean, a name as a String), then the app's onSettingsChanged() runs, as
// the system calls it, DELAY ms after the pick, so the screen under the menu is the one showing by then
// (the score screen, the summary after a match point, a Settings menu opened meanwhile). Each pick
// applies the next of PRESETS, the last one the defaults. From the sensor lock's debug menu and the
// match menu's debug items.
(:debug)
module DebugSettings {

    const DELAY = 10000;
    // Each: its name, then serve tracking, warm-up, vibration, sounds, change of ends alert, touch scoring,
    // press delay, theme, our team's name, theirs.
    const PRESETS = [
        ["Grass, names", false, false, 2, true, false, true, 1200, 2, "Hugo & Lena", "Las Panteras"],
        ["Clay, long names", true, true, 1, false, true, false, 500, 1, "Łukasz & Zoë", "MMMMMMMMMMMMMMM"],
        ["Defaults", true, true, 0, false, true, false, 800, 0, "", ""]
    ];
    const KEYS = [Settings.SERVE_TRACKING, Settings.WARM_UP, Settings.VIBRATION, Settings.SOUNDS, Settings.CHANGE_OF_ENDS,
        Settings.TOUCH_SCORING, Settings.DEBOUNCE, Settings.THEME, Settings.TEAM_NAME_US, Settings.TEAM_NAME_THEM];

    var _next as Number = 0;
    var _change as DebugSettingsChange? = null;

    // The menu item's line under it: what the next pick applies.
    function nextName() as String {
        return "next: " + ((PRESETS[_next] as Array)[0] as String) + ", in " + DELAY / 1000 + " s";
    }

    // The next preset, DELAY ms from now.
    function schedule() as Void {
        var change = new DebugSettingsChange(PRESETS[_next] as Array);
        _next = (_next + 1) % PRESETS.size();
        _change = change;
        change.start();
    }
}

(:debug)
class DebugSettingsChange {

    private var _preset as Array;
    private var _timer as Timer.Timer = new Timer.Timer();

    function initialize(preset as Array) {
        _preset = preset;
    }

    function start() as Void {
        _timer.start(method(:apply), DebugSettings.DELAY, false);
    }

    function apply() as Void {
        for (var i = 0; i < DebugSettings.KEYS.size(); i++) {
            Settings.write(DebugSettings.KEYS[i], _preset[i + 1] as Application.Properties.ValueType);
        }
        System.println("debug: Connect change " + (_preset[0] as String));
        (Application.getApp() as BandejaApp).onSettingsChanged();
    }
}

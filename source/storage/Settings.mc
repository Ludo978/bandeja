import Toybox.Application;
import Toybox.Lang;

// The Vibration setting. The values are stored: never renumber.
enum VibrationSetting {
    VIBRATION_EVERY_POINT = 0,
    VIBRATION_IMPORTANT = 1,  // game, set, match, change of ends and court time only
    VIBRATION_OFF = 2
}

// The Theme setting: the team colors (Palette). The values are stored: never
// renumber.
enum ThemeSetting {
    THEME_COURT = 0,  // cyan / orange
    THEME_CLAY = 1,   // sand / terracotta
    THEME_GRASS = 2   // green / violet
}

// The settings, and Indoor / Outdoor and the timed match (picked in the Format menu), kept in
// Application.Properties as declared in resources/settings/properties.xml. They are read when
// needed, not cached, so a change in a menu applies at once. A value that is missing, of another
// type or out of range (left by another version) reads as its default. Every
// setting but Indoor / Outdoor and the timed match can be changed in the Garmin
// Connect app too (resources/settings/settings.xml), which sends a list's value as a Number, a toggle's
// as a Boolean and a name as a String: read through the same checks, so a value from the phone that
// can't be used reads as the default too. The names are typed there only.
module Settings {

    // Property IDs, as in properties.xml: never rename.
    const SERVE_TRACKING = "serveTracking";
    const WARM_UP = "warmUp";
    const VIBRATION = "vibration";
    const SOUNDS = "sounds";
    const OUTDOOR = "outdoor";
    const TIMED_MATCH = "timedMatch";
    const CHANGE_OF_ENDS = "changeOfEnds";
    const TOUCH_SCORING = "touchScoring";
    const THEME = "theme";
    const DEBOUNCE = "debounce";
    const TEAM_NAME_US = "teamNameUs";
    const TEAM_NAME_THEM = "teamNameThem";

    // The defaults, the same as properties.xml.
    const DEFAULT_SERVE_TRACKING = true;
    const DEFAULT_WARM_UP = true;
    const DEFAULT_VIBRATION = VIBRATION_EVERY_POINT;
    const DEFAULT_SOUNDS = false;
    const DEFAULT_OUTDOOR = false;
    const DEFAULT_TIMED_MATCH = false;
    const DEFAULT_CHANGE_OF_ENDS = true;
    const DEFAULT_TOUCH_SCORING = false;
    const DEFAULT_THEME = THEME_COURT;
    // Milliseconds, as stored.
    const DEFAULT_DEBOUNCE = 800;
    // A team name's most characters: a longer one is cut.
    const NAME_MAX = 12;
    // The characters a team name keeps (readTeamName()), as [first, last] code point pairs: the letters,
    // digits and signs of the watch's RobotoCondensed fonts (Basic Latin, Latin-1, Latin Extended-A,
    // the Vietnamese and Romanian letters, Greek, Cyrillic, quotes and dashes, the euro sign). Others
    // (emoji, CJK, symbols) would draw as an empty box.
    const NAME_CHARS = [0x21, 0x7E, 0xA1, 0xAC, 0xAE, 0x17F, 0x1A0, 0x1A1, 0x1AF, 0x1B0, 0x218, 0x21B, 0x386, 0x386,
        0x388, 0x38A, 0x38C, 0x38C, 0x38E, 0x3A1, 0x3A3, 0x3CE, 0x400, 0x481, 0x48A, 0x4FF, 0x1EA0, 0x1EF9, 0x2013, 0x2014,
        0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2026, 0x20AC, 0x20AC] as Array<Number>;

    // Asks who serves first and keeps the serve stats.
    function isServeTracking() as Boolean {
        return readBoolean(read(SERVE_TRACKING), DEFAULT_SERVE_TRACKING);
    }

    function setServeTracking(on as Boolean) as Void {
        write(SERVE_TRACKING, on);
    }

    // Recording starts in the warm-up.
    function isWarmUp() as Boolean {
        return readBoolean(read(WARM_UP), DEFAULT_WARM_UP);
    }

    function setWarmUp(on as Boolean) as Void {
        write(WARM_UP, on);
    }

    function getVibration() as VibrationSetting {
        return readVibration(read(VIBRATION));
    }

    function setVibration(vibration as VibrationSetting) as Void {
        write(VIBRATION, vibration as Number);
    }

    // Beeps for the important events.
    function isSoundsOn() as Boolean {
        return readBoolean(read(SOUNDS), DEFAULT_SOUNDS);
    }

    function setSounds(on as Boolean) as Void {
        write(SOUNDS, on);
    }

    // Outdoor turns GPS on.
    function isOutdoor() as Boolean {
        return readBoolean(read(OUTDOOR), DEFAULT_OUTDOOR);
    }

    function setOutdoor(outdoor as Boolean) as Void {
        write(OUTDOOR, outdoor);
    }

    // The timed match: PLAY asks for the court booking's end time first.
    function isTimedMatch() as Boolean {
        return readBoolean(read(TIMED_MATCH), DEFAULT_TIMED_MATCH);
    }

    function setTimedMatch(timed as Boolean) as Void {
        write(TIMED_MATCH, timed);
    }

    // The change of ends alert: its pulses and tones. Off, a change of ends adds nothing
    // to a point's feedback.
    function isChangeOfEndsAlert() as Boolean {
        return readBoolean(read(CHANGE_OF_ENDS), DEFAULT_CHANGE_OF_ENDS);
    }

    function setChangeOfEndsAlert(on as Boolean) as Void {
        write(CHANGE_OF_ENDS, on);
    }

    // Touch scoring: a tap on the score page scores, the upper half for THEM, the lower half for
    // US. Off by default: sweat, a racket or a sleeve would score.
    function isTouchScoring() as Boolean {
        return readBoolean(read(TOUCH_SCORING), DEFAULT_TOUCH_SCORING);
    }

    function setTouchScoring(on as Boolean) as Void {
        write(TOUCH_SCORING, on);
    }

    // Whether the watch has a touchscreen, which Touch scoring needs: the menus leave it out on
    // the watches without one (the Instinct 3 AMOLED and Instinct Crossover AMOLED). Known per watch
    // when it's built, monkey.jungle excluding one of the two below, rather than from
    // DeviceSettings.isTouchScreen, which is also false on a touch watch whose touch is turned off in
    // its settings: there the item stays, as harmless as a tap that never comes.
    (:touchScreen)
    function hasTouchScreen() as Boolean {
        return true;
    }

    (:noTouchScreen)
    function hasTouchScreen() as Boolean {
        return false;
    }

    // The team colors (Palette). Each screen reads it when it shows, so a change in the Settings menu
    // applies when the screen comes back.
    function getTheme() as ThemeSetting {
        return readTheme(read(THEME));
    }

    function setTheme(theme as ThemeSetting) as Void {
        write(THEME, theme as Number);
    }

    // The press delay: a point press, button or tap, less than this many milliseconds after the
    // last point that counted is ignored. ScoreDelegate reads it at each press.
    function getDebounce() as Number {
        return readDebounce(read(DEBOUNCE));
    }

    function setDebounce(ms as Number) as Void {
        write(DEBOUNCE, ms);
    }

    // The team names typed in the Garmin Connect app, indexed by Team (readTeamName()): null for a team
    // with none, which the summary shows as US / THEM.
    function getTeamNames() as Array<String?> {
        return [readTeamName(read(TEAM_NAME_US)), readTeamName(read(TEAM_NAME_THEM))];
    }

    // A team name as the summary can draw it: the characters of NAME_CHARS, the spaces at its ends
    // dropped and the others kept one at a time (a tab, a line break or a no-break space counting as
    // one), cut at NAME_MAX characters. Null when nothing is left, and for a value that isn't a String.
    function readTeamName(value as Object?) as String? {
        if (!(value instanceof String)) {
            return null;
        }
        var chars = value.toCharArray();
        var name = "";
        var count = 0;
        var space = false;
        for (var i = 0; i < chars.size() && count < NAME_MAX; i++) {
            var code = chars[i].toNumber();
            if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0xA0) {
                space = count > 0;
            } else if (isNameChar(code)) {
                if (space) {
                    // A space goes in only with a character after it.
                    if (count + 2 > NAME_MAX) {
                        break;
                    }
                    name += " ";
                    count++;
                    space = false;
                }
                name += chars[i].toString();
                count++;
            }
        }
        return count > 0 ? name : null;
    }

    // A character a team name keeps (NAME_CHARS), by its code point.
    function isNameChar(code as Number) as Boolean {
        for (var i = 0; i < NAME_CHARS.size(); i += 2) {
            if (code >= NAME_CHARS[i] && code <= NAME_CHARS[i + 1]) {
                return true;
            }
        }
        return false;
    }

    // The press delay's values in milliseconds, in the Settings menu's order: 0.5 s, 0.8 s, 1.2 s. Never
    // 0: the debounce is never off.
    function debounceChoices() as Array<Number> {
        return [500, DEFAULT_DEBOUNCE, 1200];
    }

    // A stored value, if it's one of debounceChoices().
    function readDebounce(value as Object?) as Number {
        if (value instanceof Number && debounceChoices().indexOf(value) >= 0) {
            return value as Number;
        }
        return DEFAULT_DEBOUNCE;
    }

    // A stored value, if it's a Boolean.
    function readBoolean(value as Object?, fallback as Boolean) as Boolean {
        return value instanceof Boolean ? value as Boolean : fallback;
    }

    // A stored value, if it's a VibrationSetting.
    function readVibration(value as Object?) as VibrationSetting {
        if (value instanceof Number && value >= VIBRATION_EVERY_POINT && value <= VIBRATION_OFF) {
            return value as VibrationSetting;
        }
        return DEFAULT_VIBRATION;
    }

    // A stored value, if it's a ThemeSetting.
    function readTheme(value as Object?) as ThemeSetting {
        if (value instanceof Number && value >= THEME_COURT && value <= THEME_GRASS) {
            return value as ThemeSetting;
        }
        return DEFAULT_THEME;
    }

    // The stored value, or null for a key properties.xml doesn't declare.
    function read(key as String) as Object? {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }

    // A value that can't be stored is dropped: the setting keeps its previous value.
    function write(key as String, value as Application.Properties.ValueType) as Void {
        try {
            Application.Properties.setValue(key, value);
        } catch (e) {
        }
    }
}

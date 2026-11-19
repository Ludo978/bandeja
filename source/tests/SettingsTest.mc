import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// The v1 settings in Application.Properties and the remembered format in
// Application.Storage: defaults, values that can't be used, and the round trips. The
// tests put the simulator's values back when they're done.

(:test)
function settingsValuesTest(logger as Logger) as Boolean {
    // The defaults: serve tracking on, warm-up phase on, vibration on every point, sounds off, indoor; the timed
    // match off until picked in the Format menu; the change of ends alert on, touch
    // scoring off, the Court theme and a press delay of 800 ms, also for a
    // version that didn't store them (properties.xml gives the defaults). The stored vibration and theme
    // numbers are never renumbered. A value missing (null: undeclared key), of another type or out of
    // range reads as the default; the press delay is one of its three values in milliseconds, anything
    // else reads as 800, never as off. Every key is declared in properties.xml with a value of its type.
    Test.assert(Settings.DEFAULT_SERVE_TRACKING && Settings.DEFAULT_WARM_UP && Settings.DEFAULT_VIBRATION == VIBRATION_EVERY_POINT);
    Test.assert(!Settings.DEFAULT_SOUNDS && !Settings.DEFAULT_OUTDOOR && !Settings.DEFAULT_TIMED_MATCH);
    Test.assert(Settings.DEFAULT_CHANGE_OF_ENDS && !Settings.DEFAULT_TOUCH_SCORING && Settings.DEFAULT_THEME == THEME_COURT);
    Test.assert((VIBRATION_EVERY_POINT as Number) == 0 && (VIBRATION_IMPORTANT as Number) == 1 && (VIBRATION_OFF as Number) == 2);
    Test.assert((THEME_COURT as Number) == 0 && (THEME_CLAY as Number) == 1 && (THEME_GRASS as Number) == 2);
    Test.assert(Settings.readBoolean(true, false) && !Settings.readBoolean(false, true));
    var badBooleans = [null, 0, 1, "true", 1.0];
    for (var i = 0; i < badBooleans.size(); i++) {
        Test.assert(Settings.readBoolean(badBooleans[i], true) && !Settings.readBoolean(badBooleans[i], false));
    }
    Test.assert(Settings.readVibration(1) == VIBRATION_IMPORTANT && Settings.readVibration(2) == VIBRATION_OFF);
    var badVibrations = [null, -1, 3, "1", 1.0, 1l, true];
    for (var i = 0; i < badVibrations.size(); i++) {
        Test.assertEqual(Settings.readVibration(badVibrations[i]), VIBRATION_EVERY_POINT);
        Test.assertEqual(Settings.readTheme(badVibrations[i]), THEME_COURT);
    }
    Test.assert(Settings.readTheme(0) == THEME_COURT && Settings.readTheme(1) == THEME_CLAY && Settings.readTheme(2) == THEME_GRASS);
    Test.assertEqual(Settings.DEFAULT_DEBOUNCE, 800);
    var debounces = Settings.debounceChoices();
    for (var i = 0; i < debounces.size(); i++) {
        Test.assertEqual(Settings.readDebounce(debounces[i]), debounces[i]);
    }
    var badDebounces = [null, 0, -800, 499, 501, 799, 801, 1000, 1199, 1201, 2000, "800", "500", 500.0, 500l, true, 0.5];
    for (var i = 0; i < badDebounces.size(); i++) {
        Test.assertEqualMessage(Settings.readDebounce(badDebounces[i]), 800, "bad debounce " + i);
    }
    Test.assert(SettingsMenu.debounceName(500) == Rez.Strings.Debounce500 && SettingsMenu.debounceName(800) == Rez.Strings.Debounce800
        && SettingsMenu.debounceName(1200) == Rez.Strings.Debounce1200);
    var booleans = [Settings.SERVE_TRACKING, Settings.WARM_UP, Settings.SOUNDS, Settings.OUTDOOR, Settings.TIMED_MATCH,
        Settings.CHANGE_OF_ENDS, Settings.TOUCH_SCORING];
    for (var i = 0; i < booleans.size(); i++) {
        Test.assertMessage(Settings.read(booleans[i]) instanceof Boolean, booleans[i]);
    }
    Test.assert(Settings.read(Settings.VIBRATION) instanceof Number && Settings.read(Settings.THEME) instanceof Number);
    Test.assert(Settings.read(Settings.DEBOUNCE) instanceof Number);
    // The team names are Strings, empty until typed in the Garmin Connect app.
    Test.assert(Settings.read(Settings.TEAM_NAME_US) instanceof String && Settings.read(Settings.TEAM_NAME_THEM) instanceof String);
    Test.assert(Settings.read("notASetting") == null);
    return true;
}

(:test)
function settingsTeamNameTest(logger as Logger) as Boolean {
    // A team name typed in the Garmin Connect app keeps NAME_MAX (12) characters at
    // most, a longer one cut; the spaces at its ends go and the others are kept one at a time (a tab, a
    // line break, a no-break space counting as one); a character the watch's fonts lack (emoji, CJK, a
    // symbol, a control character, the invisible soft hyphen) goes. Nothing left, or a value that isn't
    // a String (another type from the phone, a key missing): none, which shows US / THEM.
    Test.assertEqual(Settings.NAME_MAX, 12);
    var none = [null, "", "   ", " \t\n ", 12, true, 1.5, ["Ana"], "😀😀", "中文", "\u2603\u24D0", "\u0001\u00AD"];
    for (var i = 0; i < none.size(); i++) {
        Test.assertMessage(Settings.readTeamName(none[i]) == null, "none " + i);
    }
    var names = [
        ["Hugo & Lena", "Hugo & Lena"],
        ["  Las   Panteras  ", "Las Panteras"],
        ["Ana\tBea\nCris\r\nDani", "Ana Bea Cris"],
        ["Ana\u00A0Bea", "Ana Bea"],
        ["ABCDEFGHIJKLMNOP", "ABCDEFGHIJKL"],
        ["ABCDEFGHIJK LMN", "ABCDEFGHIJK"],
        ["ABCDEFGHIJ KLMN", "ABCDEFGHIJ K"],
        ["Zoë 😀 Léa", "Zoë Léa"],
        ["😀Zoé", "Zoé"],
        ["Ana\u00ADBea", "AnaBea"],
        ["Łukasz & Žofie", "Łukasz & Žof"],
        ["O’Brien", "O’Brien"],
        ["Αθηνά", "Αθηνά"],
        ["Жора и Миша", "Жора и Миша"],
        ["Nguyễn Ơn", "Nguyễn Ơn"],
        ["Ștefan", "Ștefan"],
        ["Straße", "Straße"],
        ["12345", "12345"],
        ["!#$%&*+-./:", "!#$%&*+-./:"],
        ["€10 €", "€10 €"]
    ];
    for (var i = 0; i < names.size(); i++) {
        Test.assertMessage(names[i][1].equals(Settings.readTeamName(names[i][0])), "name " + i + ": " + Settings.readTeamName(names[i][0]));
        Test.assert((Settings.readTeamName(names[i][0]) as String).length() <= Settings.NAME_MAX);
    }
    // The fonts' characters: kept, by code point, at the ends of each range, and their neighbors gone.
    var kept = [0x21, 0x7E, 0xA1, 0xAC, 0xAE, 0x17F, 0x3A3, 0x3CE, 0x400, 0x4FF, 0x1EA0, 0x1EF9, 0x20AC];
    var gone = [0x20, 0x7F, 0x80, 0x9F, 0xA0, 0xAD, 0x180, 0x37F, 0x3A2, 0x482, 0x500, 0x1E9E, 0x1EFA, 0x2603, 0x1F600];
    for (var i = 0; i < kept.size(); i++) {
        Test.assertMessage(Settings.isNameChar(kept[i]), "kept " + kept[i]);
    }
    for (var i = 0; i < gone.size(); i++) {
        Test.assertMessage(!Settings.isNameChar(gone[i]), "gone " + gone[i]);
    }

    // From the properties, as the Garmin Connect app leaves them: indexed by Team.
    var keys = [Settings.TEAM_NAME_US, Settings.TEAM_NAME_THEM];
    var saved = [Settings.read(keys[0]), Settings.read(keys[1])];
    try {
        Settings.write(Settings.TEAM_NAME_US, "  Hugo & Lena ");
        Settings.write(Settings.TEAM_NAME_THEM, "");
        var read = Settings.getTeamNames();
        Test.assert("Hugo & Lena".equals(read[TEAM_US]) && read[TEAM_THEM] == null);
        Settings.write(Settings.TEAM_NAME_US, "");
        Settings.write(Settings.TEAM_NAME_THEM, "Las Panteras de Madrid");
        read = Settings.getTeamNames();
        Test.assert(read[TEAM_US] == null && "Las Panteras".equals(read[TEAM_THEM]));
    } finally {
        for (var i = 0; i < keys.size(); i++) {
            Settings.write(keys[i], saved[i] instanceof String ? saved[i] as String : "");
        }
    }
    return true;
}

(:test)
function settingsRoundTripTest(logger as Logger) as Boolean {
    var keys = [Settings.SERVE_TRACKING, Settings.WARM_UP, Settings.VIBRATION, Settings.SOUNDS, Settings.OUTDOOR,
        Settings.TIMED_MATCH, Settings.CHANGE_OF_ENDS, Settings.TOUCH_SCORING, Settings.THEME, Settings.DEBOUNCE];
    var saved = new Array<Object?>[keys.size()];
    for (var i = 0; i < keys.size(); i++) {
        saved[i] = Settings.read(keys[i]);
    }
    try {
        for (var on = 0; on < 2; on++) {
            Settings.setServeTracking(on == 1);
            Settings.setWarmUp(on == 1);
            Settings.setVibration(on == 1 ? VIBRATION_IMPORTANT : VIBRATION_OFF);
            Settings.setSounds(on == 0);
            Settings.setOutdoor(on == 0);
            Settings.setTimedMatch(on == 0);
            Settings.setChangeOfEndsAlert(on == 1);
            Settings.setTouchScoring(on == 0);
            Test.assert(Settings.isChangeOfEndsAlert() == (on == 1) && Settings.isTouchScoring() == (on == 0));
            Test.assert(Settings.isServeTracking() == (on == 1) && Settings.isWarmUp() == (on == 1));
            Test.assert(Settings.getVibration() == (on == 1 ? VIBRATION_IMPORTANT : VIBRATION_OFF));
            Test.assert(Settings.isSoundsOn() == (on == 0) && Settings.isOutdoor() == (on == 0) && Settings.isTimedMatch() == (on == 0));
        }
        var themes = [THEME_CLAY, THEME_GRASS, THEME_COURT] as Array<ThemeSetting>;
        for (var i = 0; i < themes.size(); i++) {
            Settings.setTheme(themes[i]);
            Test.assertEqual(Settings.getTheme(), themes[i]);
        }
        var debounces = [1200, 500, 800];
        for (var i = 0; i < debounces.size(); i++) {
            Settings.setDebounce(debounces[i]);
            Test.assertEqual(Settings.getDebounce(), debounces[i]);
        }
        Settings.write(Settings.DEBOUNCE, 300);
        Test.assertEqual(Settings.getDebounce(), 800);
    } finally {
        for (var i = 0; i < keys.size(); i++) {
            var value = saved[i];
            if (value != null) {
                Settings.write(keys[i], value as Application.Properties.ValueType);
            }
        }
    }
    return true;
}

(:test)
function settingsTouchGestureTest(logger as Logger) as Boolean {
    // The Touch scoring setting's gesture on the watches without UP and DOWN: Tap (0, the default) or Hold
    // (1), stored as a Number and never renumbered, declared in properties.xml. A value missing, of another
    // type or out of range reads as Tap. The watches with UP and DOWN store it too (one settings.xml for
    // every watch) and never read it.
    Test.assert(Settings.TOUCH_GESTURE.equals("touchGesture") && Settings.DEFAULT_TOUCH_GESTURE == GESTURE_TAP);
    Test.assert((GESTURE_TAP as Number) == 0 && (GESTURE_HOLD as Number) == 1);
    Test.assert(Settings.readTouchGesture(0) == GESTURE_TAP && Settings.readTouchGesture(1) == GESTURE_HOLD);
    var bad = [null, -1, 2, "1", 1.0, 1l, true];
    for (var i = 0; i < bad.size(); i++) {
        Test.assertEqualMessage(Settings.readTouchGesture(bad[i]), GESTURE_TAP, "bad gesture " + i);
    }
    var saved = Settings.read(Settings.TOUCH_GESTURE);
    Test.assert(saved instanceof Number);
    try {
        Settings.setTouchGesture(GESTURE_HOLD);
        Test.assertEqual(Settings.getTouchGesture(), GESTURE_HOLD);
        Settings.setTouchGesture(GESTURE_TAP);
        Test.assertEqual(Settings.getTouchGesture(), GESTURE_TAP);
        Settings.write(Settings.TOUCH_GESTURE, 7);
        Test.assertEqual(Settings.getTouchGesture(), GESTURE_TAP);
    } finally {
        Settings.write(Settings.TOUCH_GESTURE, saved as Number);
    }
    return true;
}

(:test)
function formatStoreTest(logger as Logger) as Boolean {
    // The last format picked comes back as it was. First launch, or data that can't be used: Best of 3,
    // Star point, doubles, not mixed. The last Custom structure is kept apart from the format, so
    // picking a preset doesn't lose it.
    var keys = [FormatStore.FORMAT_KEY, FormatStore.CUSTOM_KEY];
    var saved = TestKit.backup(keys);
    try {
        var silver = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
        silver.deuceMode = DEUCE_SILVER;
        var formats = [TestKit.custom(), silver];
        for (var i = 0; i < formats.size(); i++) {
            FormatStore.save(formats[i]);
            Test.assert(FormatStore.load().equals(formats[i]));
        }
        Application.Storage.deleteValue(FormatStore.FORMAT_KEY);
        Test.assert(FormatStore.load().equals(new MatchConfig()));
        var invalid = TestKit.storedBestOf3();
        invalid.put("tieBreakAt", 4);
        var stale = [42, "Best of 3", [2, 6, 6], {"setsToWin" => 2}, invalid];
        for (var i = 0; i < stale.size(); i++) {
            Application.Storage.setValue(FormatStore.FORMAT_KEY, stale[i] as Application.Storage.ValueType);
            Test.assertMessage(FormatStore.load().equals(new MatchConfig()), "loaded " + stale[i]);
        }
        Application.Storage.deleteValue(FormatStore.CUSTOM_KEY);
        Test.assert(FormatStore.loadCustom() == null);
        FormatStore.saveCustom(TestKit.custom());
        FormatStore.save(new MatchConfig());
        Test.assert(TestKit.custom().equals(FormatStore.loadCustom()) && FormatStore.load().equals(new MatchConfig()));
        Application.Storage.setValue(FormatStore.CUSTOM_KEY, "Fast4");
        Test.assert(FormatStore.loadCustom() == null);
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

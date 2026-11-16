import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The team names, typed in the Garmin Connect app: on the summary, the
// match's and the history's, in capitals over the set table's columns, US / THEM for a team with none;
// kept in the match's history record at its save, so a later rename leaves it as it was; never on the
// score screen. And a change made in Connect showing at once in the menus that show settings. Reading
// a name from the properties is in SettingsTest.mc.

(:test)
function teamNamesTextTest(logger as Logger) as Boolean {
    // In capitals, as US and THEM: accented, Greek, Cyrillic and Vietnamese letters too; a letter whose
    // capital the fonts lack stays as typed (ß, its capital ẞ missing); signs and digits as they are.
    var cases = [["Hugo & Lena", "HUGO & LENA"], ["Léa & Zoë", "LÉA & ZOË"], ["Straße", "STRAßE"], ["ÿ ñ ç æ œ ł", "Ÿ Ñ Ç Æ Œ Ł"],
        ["Αθηνά", "ΑΘΗΝΆ"], ["Жора", "ЖОРА"], ["Nguyễn ơn", "NGUYỄN ƠN"], ["O’Brien 2", "O’BRIEN 2"], ["LAS PANTERAS", "LAS PANTERAS"]];
    for (var i = 0; i < cases.size(); i++) {
        Test.assertEqualMessage(SummaryModel.nameText(cases[i][0]), cases[i][1], "case " + i);
    }
    return true;
}

(:test)
function teamNamesPlaceTest(logger as Logger) as Boolean {
    // Each name centered on its column (262, 322), as the mockup's US / THEM; one that would come within
    // NAMES_GAP / 2 (8) of the middle between them (292) moves out, ours to the left, theirs to the
    // right, so two long names keep 16 apart. The defaults (15 and 35 wide) stay on the columns.
    Test.assertEqual(SummaryModel.COLUMNS[TEAM_US], 262);
    Test.assertEqual(SummaryModel.COLUMNS[TEAM_THEM], 322);
    var cases = [[15.0, 35.0, 262.0, 322.0], [44.0, 44.0, 262.0, 322.0], [46.0, 46.0, 261.0, 323.0], [86.0, 72.0, 241.0, 336.0],
        [10.0, 130.0, 262.0, 365.0], [130.0, 10.0, 219.0, 322.0]];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var centers = SummaryModel.nameCenters([c[0], c[1]]);
        TestKit.assertNear(centers[TEAM_US], c[2], 0.01);
        TestKit.assertNear(centers[TEAM_THEM], c[3], 0.01);
        Test.assertMessage(centers[TEAM_THEM] - c[1] / 2 - (centers[TEAM_US] + c[0] / 2) >= SummaryModel.NAMES_GAP - 0.01, "gap " + i);
    }
    return true;
}

(:test)
function teamNamesFitTest(logger as Logger) as Boolean {
    // On this screen (the suite runs on the FR265 and the FR265S), with the app's fonts: US / THEM and
    // NOUS / EUX at the mockup's size on their columns; two names of 12 characters, the widest letters
    // too, at the label size or shrunk to no less than three quarters of it, both inside the circle with
    // the margin, their gap kept. The run logs each pair's size and edges (mockup pixels).
    var dc = (Graphics.createBufferedBitmap({:width => 4, :height => 4}).get() as Graphics.BufferedBitmap).getDc();
    var l = new Layout(System.getDeviceSettings().screenWidth);
    var pairs = [["US", "THEM"], ["NOUS", "EUX"], ["HUGO & LENA", "LAS PANTERAS"], ["ABCDEFGHIJKL", "MNOPQRSTUVWX"],
        ["ŁUKASZ & ZOË", "LOS GALÁCTIC"], ["WWWWWWWWWWWW", "WWWWWWWWWWWW"], ["MMMMMMMMMMMM", "MMMMMMMMMMMM"], ["A", "B"]];
    for (var i = 0; i < pairs.size(); i++) {
        var names = pairs[i];
        var fit = SummaryView.fitNames(dc, l, names);
        var size = fit[0] as Number;
        var widths = [l.textWidth(dc, STYLE_BOLD, size, names[TEAM_US], SummaryView.LABEL_SPACING),
            l.textWidth(dc, STYLE_BOLD, size, names[TEAM_THEM], SummaryView.LABEL_SPACING)];
        var left = (fit[1] as Float) - widths[TEAM_US] / 2;
        var right = (fit[2] as Float) + widths[TEAM_THEM] / 2;
        var half = Layout.chord(SummaryView.TEAMS_Y - 2 * Fonts.CAP_MIDDLE * size) / 2 - SummaryView.MARGIN;
        logger.debug(l.width + " px: " + names[0] + " / " + names[1] + ": size " + size + ", " + left.format("%.1f") + " to "
            + right.format("%.1f") + " of " + (240 - half).format("%.1f") + " to " + (240 + half).format("%.1f"));
        Test.assertMessage(size >= SummaryView.LABEL_SIZE * 3 / 4 && left >= 240 - half && right <= 240 + half, "pair " + i);
        if (i < 2) {
            Test.assert(size == SummaryView.LABEL_SIZE && fit[1] == 262.0 && fit[2] == 322.0);
        }
    }
    return true;
}

(:test)
function teamNamesRecordTest(logger as Logger) as Boolean {
    // A record keeps the names as [ours, theirs], each a String or null for none, under the
    // optional key "names", left out when neither team has one (a record from before team names); the summary
    // shows them, a record without them US / THEM. A stored name is read as a typed one (cut, cleaned).
    // Names that aren't two Strings or nulls make the record one that can't be read, as any key of the
    // wrong type (skipped, never a crash).
    var record = HistoryTests.largest();
    Test.assert(record.names[TEAM_US] == null && record.names[TEAM_THEM] == null);
    var value = record.toValue() as Dictionary<String, Object?>;
    Test.assert(!value.hasKey("names"));
    var back = HistoryRecord.fromValue(value) as HistoryRecord;
    Test.assert(back.names[TEAM_US] == null && back.names[TEAM_THEM] == null);
    var model = new SummaryModel(back);
    Test.assert(model.names[TEAM_US] == null && model.names[TEAM_THEM] == null);

    var cases = [[["Hugo & Lena", null], ["Hugo & Lena", null]], [[null, "Las Panteras"], [null, "Las Panteras"]],
        [["Ana", "Bea"], ["Ana", "Bea"]]];
    for (var i = 0; i < cases.size(); i++) {
        record.names = cases[i][0] as Array<String?>;
        value = record.toValue() as Dictionary<String, Object?>;
        var stored = value["names"] as Array;
        var expected = cases[i][1] as Array<String?>;
        Test.assert(stored.size() == 2);
        back = HistoryRecord.fromValue(value) as HistoryRecord;
        model = new SummaryModel(back);
        for (var team = 0; team < 2; team++) {
            var name = expected[team];
            Test.assertMessage(name == null ? back.names[team] == null && model.names[team] == null
                : name.equals(back.names[team]) && name.equals(model.names[team]), "case " + i);
        }
        Test.assertEqual(SummaryTests.text(model), SummaryTests.text(new SummaryModel(HistoryTests.largest())));
    }

    var cleaned = HistoryTests.with(value, "names", ["  Las Panteras de Madrid", "😀"]);
    back = HistoryRecord.fromValue(cleaned) as HistoryRecord;
    Test.assert("Las Panteras".equals(back.names[TEAM_US]) && back.names[TEAM_THEM] == null);
    // A later version's third value is ignored.
    back = HistoryRecord.fromValue(HistoryTests.with(value, "names", ["Ana", "Bea", 3])) as HistoryRecord;
    Test.assert("Ana".equals(back.names[TEAM_US]) && "Bea".equals(back.names[TEAM_THEM]));
    var bad = ["Ana", 12, [], ["Ana"], [1, 2], ["Ana", true], [null, 1.5], {"us" => "Ana"}];
    for (var i = 0; i < bad.size(); i++) {
        Test.assertMessage(HistoryRecord.fromValue(HistoryTests.with(value, "names", bad[i])) == null, "bad " + i);
    }
    return true;
}

(:test)
function teamNamesSaveTest(logger as Logger) as Boolean {
    // The match's record takes the names typed in Connect when it's saved (MatchFlow.historyRecord():
    // the pause menu's Save, the summary's, the low battery save, the app stopped), so a rename after
    // the save leaves the stored match as it was, and one before it is in. Through the history too.
    var keys = [Settings.TEAM_NAME_US, Settings.TEAM_NAME_THEM];
    var saved = [Settings.read(keys[0]), Settings.read(keys[1])];
    var storage = GlanceTests.keys();
    var stored = TestKit.backup(storage);
    try {
        HistoryStore.clear();
        var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
        rig.play("UUUU");
        Settings.write(Settings.TEAM_NAME_US, "Hugo & Lena");
        Settings.write(Settings.TEAM_NAME_THEM, "");
        var record = MatchFlow.historyRecord(rig.match);
        Test.assert("Hugo & Lena".equals(record.names[TEAM_US]) && record.names[TEAM_THEM] == null);
        Settings.write(Settings.TEAM_NAME_THEM, "Las Panteras");
        record = MatchFlow.historyRecord(rig.match);
        Test.assert("Hugo & Lena".equals(record.names[TEAM_US]) && "Las Panteras".equals(record.names[TEAM_THEM]));
        HistoryStore.add(record);
        Settings.write(Settings.TEAM_NAME_US, "Someone else");
        Settings.write(Settings.TEAM_NAME_THEM, "");
        var loaded = HistoryStore.load();
        Test.assertEqual(loaded.size(), 1);
        Test.assert("Hugo & Lena".equals(loaded[0].names[TEAM_US]) && "Las Panteras".equals(loaded[0].names[TEAM_THEM]));
    } finally {
        TestKit.restore(storage, stored);
        for (var i = 0; i < keys.size(); i++) {
            Settings.write(keys[i], saved[i] instanceof String ? saved[i] as String : "");
        }
    }
    return true;
}

(:test)
function teamNamesMenuRefreshTest(logger as Logger) as Boolean {
    // A change made in Connect while a menu shows settings (the Settings menu, the pause and match
    // menus): refresh() gives every watched menu's items the stored values, a toggle's state and the
    // value under a list's item; ids the menu doesn't have, and menus closed since, are left alone.
    var keys = [Settings.SOUNDS, Settings.TOUCH_SCORING, Settings.VIBRATION, Settings.THEME, Settings.DEBOUNCE];
    var saved = new Array<Object?>[keys.size()];
    for (var i = 0; i < keys.size(); i++) {
        saved[i] = Settings.read(keys[i]);
    }
    try {
        Settings.setSounds(false);
        Settings.setTouchScoring(false);
        Settings.setVibration(VIBRATION_EVERY_POINT);
        Settings.setTheme(THEME_COURT);
        Settings.setDebounce(800);
        var menu = new WatchUi.Menu2({:title => "Settings"});
        menu.addItem(SettingsMenu.soundsItem(:sounds));
        menu.addItem(SettingsMenu.touchScoringItem(7));
        menu.addItem(SettingsMenu.vibrationItem(:vibration));
        menu.addItem(new WatchUi.MenuItem("Theme", SettingsMenu.themeName(Settings.getTheme()), :theme, null));
        menu.addItem(new WatchUi.MenuItem("Press delay", SettingsMenu.debounceName(Settings.getDebounce()), :debounce, null));
        SettingsMenu.watch(menu, {:sounds => :sounds, 7 => :touchScoring, :vibration => :vibration, :theme => :theme,
            :debounce => :debounce, :warmUp => :warmUp} as Dictionary<Object, Symbol>);
        var watched = SettingsMenu._menus.size();
        Settings.setSounds(true);
        Settings.setTouchScoring(true);
        Settings.setVibration(VIBRATION_OFF);
        Settings.setTheme(THEME_GRASS);
        Settings.setDebounce(1200);
        SettingsMenu.refresh();
        Test.assert((menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled() && (menu.getItem(1) as WatchUi.ToggleMenuItem).isEnabled());
        var vibration = WatchUi.loadResource(Rez.Strings.VibrationOff) as String;
        var theme = WatchUi.loadResource(Rez.Strings.ThemeGrass) as String;
        var debounce = WatchUi.loadResource(Rez.Strings.Debounce1200) as String;
        Test.assert(vibration.equals((menu.getItem(2) as WatchUi.MenuItem).getSubLabel()));
        Test.assert(theme.equals((menu.getItem(3) as WatchUi.MenuItem).getSubLabel()));
        Test.assert(debounce.equals((menu.getItem(4) as WatchUi.MenuItem).getSubLabel()));
        Settings.setSounds(false);
        SettingsMenu.refresh();
        Test.assert(!(menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
        // Closed: nothing holds it but the watch list, which lets it go.
        menu = new WatchUi.Menu2({:title => "Other"});
        SettingsMenu.refresh();
        Test.assertEqual(SettingsMenu._menus.size(), watched - 1);
        Test.assertEqual(SettingsMenu._items.size(), watched - 1);
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

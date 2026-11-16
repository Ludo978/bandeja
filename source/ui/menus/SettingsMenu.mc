import Toybox.Lang;
import Toybox.WatchUi;

// The Settings menu: the v1 settings, the change of ends alert, touch scoring,
// the press delay and the theme, each stored at once (Settings). The warm-up
// and pause menus open it too, and the match menu has its Vibration, Sounds and
// Touch scoring items. The team names are typed in the Garmin Connect app only, where every
// item here can be changed too: a menu showing settings (this one, the pause and match menus) is
// watched (watch()), and shows such a change at once (refresh()).
module SettingsMenu {

    // The menus showing settings, weakly held (a menu closed goes), each with its setting items: the
    // item's id to the setting it shows, by the Settings menu's ids (:vibration, :sounds...).
    var _menus as Array<WeakReference> = [] as Array<WeakReference>;
    var _items as Array<Dictionary<Object, Symbol>> = [] as Array<Dictionary<Object, Symbol>>;

    // The Settings menu's items, each id the setting it shows.
    const ITEMS = [:serveTracking, :warmUp, :vibration, :sounds, :changeOfEnds, :touchScoring, :debounce, :theme]
        as Array<Symbol>;

    function open() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuSettings});
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuServeTracking, null, :serveTracking,
            Settings.isServeTracking(), null));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuWarmUp, null, :warmUp, Settings.isWarmUp(), null));
        menu.addItem(vibrationItem(:vibration));
        menu.addItem(soundsItem(:sounds));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuChangeOfEnds, null, :changeOfEnds,
            Settings.isChangeOfEndsAlert(), null));
        menu.addItem(touchScoringItem(:touchScoring));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDebounce, debounceName(Settings.getDebounce()), :debounce, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuTheme, themeName(Settings.getTheme()), :theme, null));
        var items = {} as Dictionary<Object, Symbol>;
        for (var i = 0; i < ITEMS.size(); i++) {
            items[ITEMS[i]] = ITEMS[i];
        }
        watch(menu, items);
        WatchUi.pushView(menu, new SettingsMenuDelegate(menu), WatchUi.SLIDE_LEFT);
    }

    // menu shows settings in items (id to setting) until it's closed: refresh() keeps them up to date.
    function watch(menu as WatchUi.Menu2, items as Dictionary<Object, Symbol>) as Void {
        prune();
        _menus.add(menu.weak());
        _items.add(items);
    }

    // A change made in the Garmin Connect app (BandejaApp.onSettingsChanged()): every open menu's
    // setting items show the stored values (a toggle's state, the value under a list's item).
    function refresh() as Void {
        prune();
        for (var i = 0; i < _menus.size(); i++) {
            var menu = _menus[i].get() as WatchUi.Menu2?;
            if (menu == null) {
                continue;
            }
            var ids = _items[i].keys();
            for (var j = 0; j < ids.size(); j++) {
                refreshItem(menu, ids[j], _items[i][ids[j]] as Symbol);
            }
        }
    }

    // The item id of menu, if it has it, shows the stored value of setting.
    function refreshItem(menu as WatchUi.Menu2, id as Object, setting as Symbol) as Void {
        var index = menu.findItemById(id);
        var item = index >= 0 ? menu.getItem(index) : null;
        if (item == null) {
            return;
        }
        if (setting == :vibration) {
            item.setSubLabel(vibrationName(Settings.getVibration()));
        } else if (setting == :debounce) {
            item.setSubLabel(debounceName(Settings.getDebounce()));
        } else if (setting == :theme) {
            item.setSubLabel(themeName(Settings.getTheme()));
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            item.setEnabled(isOn(setting));
        }
        menu.updateItem(item, index);
    }

    // A toggle's setting, by its id in the Settings menu.
    function isOn(setting as Symbol) as Boolean {
        if (setting == :serveTracking) {
            return Settings.isServeTracking();
        } else if (setting == :warmUp) {
            return Settings.isWarmUp();
        } else if (setting == :sounds) {
            return Settings.isSoundsOn();
        } else if (setting == :changeOfEnds) {
            return Settings.isChangeOfEndsAlert();
        }
        return Settings.isTouchScoring();
    }

    // The menus closed since go.
    function prune() as Void {
        var menus = [] as Array<WeakReference>;
        var items = [] as Array<Dictionary<Object, Symbol>>;
        for (var i = 0; i < _menus.size(); i++) {
            if (_menus[i].stillAlive()) {
                menus.add(_menus[i]);
                items.add(_items[i]);
            }
        }
        _menus = menus;
        _items = items;
    }

    // Vibration, its setting shown under it. pushVibration() opens its choices.
    function vibrationItem(id as Object) as WatchUi.MenuItem {
        return new WatchUi.MenuItem(Rez.Strings.MenuVibration, vibrationName(Settings.getVibration()), id, null);
    }

    // Sounds, a toggle: its delegate stores isEnabled() when it's picked (Settings.setSounds()).
    function soundsItem(id as Object) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(Rez.Strings.MenuSounds, {:enabled => Rez.Strings.SoundsOn}, id,
            Settings.isSoundsOn(), null);
    }

    // Touch scoring, a toggle: its delegate stores isEnabled() when it's picked (Settings.setTouchScoring()),
    // and the score screen reads it at each tap.
    function touchScoringItem(id as Object) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(Rez.Strings.MenuTouchScoring, null, id, Settings.isTouchScoring(), null);
    }

    // The Vibration choices over menu, on the current one. A choice is stored at once, so it applies
    // to the next event (Feedback reads it at each one), and shown under the item id.
    function pushVibration(menu as WatchUi.Menu2, id as Object) as Void {
        var choices = vibrationChoices();
        var labels = [] as Array<String or ResourceId>;
        var values = [] as Array<Number>;
        for (var i = 0; i < choices.size(); i++) {
            labels.add(vibrationName(choices[i]));
            values.add(choices[i] as Number);
        }
        ChoiceMenu.push(Rez.Strings.MenuVibration, labels, values, Settings.getVibration() as Number,
            new VibrationChoice(menu, id).method(:onChoice));
    }

    // The Press delay choices over menu, on the current one. A choice is stored at once and shown under
    // the item id; the score screen reads it at each press (Settings.getDebounce()).
    function pushDebounce(menu as WatchUi.Menu2, id as Object) as Void {
        var values = Settings.debounceChoices();
        var labels = [] as Array<String or ResourceId>;
        for (var i = 0; i < values.size(); i++) {
            labels.add(debounceName(values[i]));
        }
        ChoiceMenu.push(Rez.Strings.MenuDebounce, labels, values, Settings.getDebounce(),
            new DebounceChoice(menu, id).method(:onChoice));
    }

    // A press delay in milliseconds, as the menu shows it: "0.8 s" ("0,8 s" in French).
    function debounceName(ms as Number) as ResourceId {
        if (ms == 500) {
            return Rez.Strings.Debounce500;
        } else if (ms == 1200) {
            return Rez.Strings.Debounce1200;
        }
        return Rez.Strings.Debounce800;
    }

    // The Theme choices over menu, each with its two colors under it, ours first. A choice is stored at
    // once and shown under the item id; each screen reads it when it shows (Settings.getTheme()).
    function pushTheme(menu as WatchUi.Menu2, id as Object) as Void {
        var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
        var colors = [Rez.Strings.ThemeCourtColors, Rez.Strings.ThemeClayColors, Rez.Strings.ThemeGrassColors];
        var labels = [] as Array<String or ResourceId>;
        var values = [] as Array<Number>;
        for (var i = 0; i < themes.size(); i++) {
            labels.add(themeName(themes[i]));
            values.add(themes[i] as Number);
        }
        ChoiceMenu.pushWithSubLabels(Rez.Strings.MenuTheme, labels, colors as Array<String or ResourceId or Null>, values,
            Settings.getTheme() as Number, new ThemeChoice(menu, id).method(:onChoice));
    }

    function themeName(theme as ThemeSetting) as ResourceId {
        if (theme == THEME_CLAY) {
            return Rez.Strings.ThemeClay;
        } else if (theme == THEME_GRASS) {
            return Rez.Strings.ThemeGrass;
        }
        return Rez.Strings.ThemeCourt;
    }

    function vibrationChoices() as Array<VibrationSetting> {
        return [VIBRATION_EVERY_POINT, VIBRATION_IMPORTANT, VIBRATION_OFF];
    }

    function vibrationName(vibration as VibrationSetting) as ResourceId {
        if (vibration == VIBRATION_IMPORTANT) {
            return Rez.Strings.VibrationImportant;
        } else if (vibration == VIBRATION_OFF) {
            return Rez.Strings.VibrationOff;
        }
        return Rez.Strings.VibrationEveryPoint;
    }
}

// A Vibration choice (SettingsMenu.pushVibration()): stored, and shown under the menu's item.
class VibrationChoice {

    private var _menu as WatchUi.Menu2;
    private var _id as Object;

    function initialize(menu as WatchUi.Menu2, id as Object) {
        _menu = menu;
        _id = id;
    }

    function onChoice(value as Number) as Void {
        Settings.setVibration(value as VibrationSetting);
        ChoiceMenu.setSubLabel(_menu, _id, SettingsMenu.vibrationName(Settings.getVibration()));
    }
}

// A Press delay choice (SettingsMenu.pushDebounce()): stored, and shown under the menu's item.
class DebounceChoice {

    private var _menu as WatchUi.Menu2;
    private var _id as Object;

    function initialize(menu as WatchUi.Menu2, id as Object) {
        _menu = menu;
        _id = id;
    }

    function onChoice(value as Number) as Void {
        Settings.setDebounce(value);
        ChoiceMenu.setSubLabel(_menu, _id, SettingsMenu.debounceName(Settings.getDebounce()));
    }
}

// A Theme choice (SettingsMenu.pushTheme()): stored, and shown under the menu's item.
class ThemeChoice {

    private var _menu as WatchUi.Menu2;
    private var _id as Object;

    function initialize(menu as WatchUi.Menu2, id as Object) {
        _menu = menu;
        _id = id;
    }

    function onChoice(value as Number) as Void {
        Settings.setTheme(value as ThemeSetting);
        ChoiceMenu.setSubLabel(_menu, _id, SettingsMenu.themeName(Settings.getTheme()));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;

    function initialize(menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    // A toggle has already switched when this is called.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :vibration) {
            SettingsMenu.pushVibration(_menu, :vibration);
            return;
        } else if (id == :theme) {
            SettingsMenu.pushTheme(_menu, :theme);
            return;
        } else if (id == :debounce) {
            SettingsMenu.pushDebounce(_menu, :debounce);
            return;
        }
        var on = (item as WatchUi.ToggleMenuItem).isEnabled();
        if (id == :serveTracking) {
            Settings.setServeTracking(on);
        } else if (id == :warmUp) {
            Settings.setWarmUp(on);
        } else if (id == :sounds) {
            Settings.setSounds(on);
        } else if (id == :changeOfEnds) {
            Settings.setChangeOfEndsAlert(on);
        } else if (id == :touchScoring) {
            Settings.setTouchScoring(on);
        }
    }
}

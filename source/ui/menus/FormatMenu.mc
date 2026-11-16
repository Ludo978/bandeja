import Toybox.Lang;
import Toybox.WatchUi;

// The Format menu: Sets (a preset, or Custom with its own menu), Deuce mode, Players
// (doubles or singles), Mixed, Court (indoor or outdoor) and Timed match (the court booking's end
// asked at PLAY). Each item shows its value, and every change is stored at once, so the next
// match and the next launch get it.
module FormatMenu {

    function open() as Void {
        var config = FormatStore.load();
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuFormat});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSets, null, :sets, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuDeuceMode, null, :deuceMode, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuPlayers, null, :players, null));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.Mixed, null, :mixed, config.mixed, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuCourt, null, :court, null));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuTimed, null, :timed, Settings.isTimedMatch(), null));
        var delegate = new FormatMenuDelegate(menu, config);
        delegate.refresh();
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }

    // Custom's own menu: Sets, Games per set, Tie-break and Tie-break to, on config, which already
    // holds the last custom structure. Every change is stored as the format and as the last custom
    // one, and onChange shows it in the Format menu.
    function openCustom(config as MatchConfig, onChange as Method() as Void) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.PresetCustom});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSets, null, :sets, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuGames, null, :games, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuTieBreak, null, :tieBreak, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuTieBreakPoints, null, :tieBreakPoints, null));
        var delegate = new CustomFormatMenuDelegate(menu, config, onChange);
        delegate.refresh();
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class FormatMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;
    private var _config as MatchConfig;

    function initialize(menu as WatchUi.Menu2, config as MatchConfig) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _config = config;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :sets) {
            var presets = FormatChoices.presetChoices();
            var labels = [] as Array<String or ResourceId>;
            var values = [] as Array<Number>;
            for (var i = 0; i < presets.size(); i++) {
                labels.add(FormatText.presetName(presets[i]));
                values.add(presets[i] as Number);
            }
            ChoiceMenu.push(Rez.Strings.MenuSets, labels, values, _config.getPreset() as Number, method(:onSets));
        } else if (id == :deuceMode) {
            var modes = FormatChoices.deuceModeChoices();
            var labels = [] as Array<String or ResourceId>;
            var values = [] as Array<Number>;
            for (var i = 0; i < modes.size(); i++) {
                labels.add(FormatText.deuceModeName(modes[i]));
                values.add(modes[i] as Number);
            }
            ChoiceMenu.push(Rez.Strings.MenuDeuceMode, labels, values, _config.deuceMode as Number,
                method(:onDeuceMode));
        } else if (id == :players) {
            ChoiceMenu.push(Rez.Strings.MenuPlayers, [Rez.Strings.Doubles, Rez.Strings.Singles], [1, 0],
                _config.doubles ? 1 : 0, method(:onPlayers));
        } else if (id == :mixed) {
            _config.mixed = (item as WatchUi.ToggleMenuItem).isEnabled();
            changed();
        } else if (id == :timed) {
            // A setting of its own, like Indoor / Outdoor: it doesn't change the scoring.
            Settings.setTimedMatch((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :court) {
            ChoiceMenu.push(Rez.Strings.MenuCourt, [Rez.Strings.CourtIndoor, Rez.Strings.CourtOutdoor], [0, 1],
                Settings.isOutdoor() ? 1 : 0, method(:onCourt));
        }
    }

    // A preset replaces the sets and tie-breaks. Custom brings back the last custom ones (the
    // format's own, the first time, one set for Tie-break only) and opens their menu.
    function onSets(value as Number) as Void {
        if (value == PRESET_CUSTOM) {
            FormatChoices.startCustom(_config, FormatStore.loadCustom());
            FormatStore.saveCustom(_config);
            changed();
            FormatMenu.openCustom(_config, method(:refresh));
        } else {
            _config.applyPreset(value as Preset);
            changed();
        }
    }

    function onDeuceMode(value as Number) as Void {
        _config.deuceMode = value as DeuceMode;
        changed();
    }

    function onPlayers(value as Number) as Void {
        _config.doubles = value == 1;
        changed();
    }

    // Indoor / Outdoor is a setting of its own, not part of the format.
    function onCourt(value as Number) as Void {
        Settings.setOutdoor(value == 1);
        refresh();
    }

    function changed() as Void {
        FormatStore.save(_config);
        refresh();
    }

    // Shows each item's value.
    function refresh() as Void {
        ChoiceMenu.setSubLabel(_menu, :sets, FormatText.presetName(_config.getPreset()));
        ChoiceMenu.setSubLabel(_menu, :deuceMode, FormatText.deuceModeName(_config.deuceMode));
        ChoiceMenu.setSubLabel(_menu, :players, FormatText.playersName(_config.doubles));
        ChoiceMenu.setSubLabel(_menu, :court, FormatText.courtName(Settings.isOutdoor()));
    }
}

class CustomFormatMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;
    private var _config as MatchConfig;
    private var _onChange as Method() as Void;

    function initialize(menu as WatchUi.Menu2, config as MatchConfig, onChange as Method() as Void) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _config = config;
        _onChange = onChange;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var labels = [] as Array<String or ResourceId>;
        var values = [] as Array<Number>;
        if (id == :sets) {
            var sets = FormatChoices.setsChoices();
            for (var i = 0; i < sets.size(); i++) {
                labels.add(FormatText.setsName(sets[i]));
                values.add(sets[i] as Number);
            }
            ChoiceMenu.push(Rez.Strings.MenuSets, labels, values, FormatChoices.getSets(_config) as Number,
                method(:onSets));
        } else if (id == :games) {
            values = FormatChoices.gamesChoices();
            for (var i = 0; i < values.size(); i++) {
                labels.add(values[i].toString());
            }
            ChoiceMenu.push(Rez.Strings.MenuGames, labels, values, _config.gamesToWin, method(:onGames));
        } else if (id == :tieBreak) {
            var choices = [TIE_BREAK_AT_N, TIE_BREAK_AT_N_MINUS_1, TIE_BREAK_NONE];
            for (var i = 0; i < choices.size(); i++) {
                labels.add(FormatText.tieBreakName(_config, choices[i] as TieBreakChoice));
                values.add(choices[i] as Number);
            }
            ChoiceMenu.push(Rez.Strings.MenuTieBreak, labels, values, FormatChoices.getTieBreak(_config) as Number,
                method(:onTieBreak));
        } else if (id == :tieBreakPoints) {
            values = FormatChoices.tieBreakPointsChoices();
            for (var i = 0; i < values.size(); i++) {
                labels.add(FormatText.tieBreakPointsName(values[i]));
            }
            ChoiceMenu.push(Rez.Strings.MenuTieBreakPoints, labels, values, _config.tieBreakPoints,
                method(:onTieBreakPoints));
        }
    }

    function onSets(value as Number) as Void {
        FormatChoices.setSets(_config, value as SetsChoice);
        changed();
    }

    function onGames(value as Number) as Void {
        FormatChoices.setGames(_config, value);
        changed();
    }

    function onTieBreak(value as Number) as Void {
        FormatChoices.setTieBreak(_config, value as TieBreakChoice);
        changed();
    }

    function onTieBreakPoints(value as Number) as Void {
        _config.tieBreakPoints = value;
        changed();
    }

    function changed() as Void {
        FormatStore.save(_config);
        FormatStore.saveCustom(_config);
        refresh();
        _onChange.invoke();
    }

    function refresh() as Void {
        ChoiceMenu.setSubLabel(_menu, :sets, FormatText.setsName(FormatChoices.getSets(_config)));
        ChoiceMenu.setSubLabel(_menu, :games, _config.gamesToWin.toString());
        ChoiceMenu.setSubLabel(_menu, :tieBreak, FormatText.tieBreakName(_config, FormatChoices.getTieBreak(_config)));
        ChoiceMenu.setSubLabel(_menu, :tieBreakPoints, FormatText.tieBreakPointsName(_config.tieBreakPoints));
    }
}

import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Edit score: from the match menu (hold UP), a native menu titled "Edit score" of
// the score as it stands, from EditScoreRules: a finished set's item each (its games under it), the
// current set's games, the game's points, Add set, Remove set n, Apply. START on a part opens its
// list, on the value it has: a finished set and a regular game's points are one list, the current
// set's games and a tie-break's points two, ours then theirs (each list showing the score it gives);
// START picks, and BACK leaves a list with nothing changed. The menu then shows the draft again, on
// the item picked (on the current set after Add set and Remove set). Apply logs the draft as one
// event and closes this menu and the match menu, back on the score screen, where BACK undoes it
// ("Undone: score edit"); on the match's own score it logs nothing and says "No change" under
// Apply. BACK leaves the menu with nothing logged, back on the match menu. Pickers give no feedback.
module EditScoreMenu {

    function open(rules as EditScoreRules) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuEditScore});
        var delegate = new EditScoreDelegate(menu, rules);
        delegate.fill(null);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class EditScoreDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;
    private var _rules as EditScoreRules;
    // The item whose list is open, the sets or the points that list offers, and our count, picked
    // before theirs.
    private var _item as Number = EditScoreRules.ITEM_APPLY;
    private var _sets as Array<SetScore> = [] as Array<SetScore>;
    private var _points as Array<Array<Number> > = [] as Array<Array<Number> >;
    private var _us as Number = 0;

    function initialize(menu as WatchUi.Menu2, rules as EditScoreRules) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _rules = rules;
    }

    // The menu shows the draft: its items, each with its part of the draft, focused on focus (an item
    // ID; null leaves the focus as it is).
    function fill(focus as Number?) as Void {
        while (_menu.getItem(0) != null) {
            _menu.deleteItem(0);
        }
        var items = _rules.getItems();
        for (var i = 0; i < items.size(); i++) {
            _menu.addItem(new WatchUi.MenuItem(EditScoreText.label(_rules, items[i]), EditScoreText.value(_rules, items[i]),
                items[i], null));
        }
        if (focus != null) {
            var index = _menu.findItemById(focus);
            _menu.setFocus(index < 0 ? 0 : index);
        }
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Number;
        _item = id;
        if (id == EditScoreRules.ITEM_APPLY) {
            apply();
        } else if (id == EditScoreRules.ITEM_REMOVE_SET) {
            _rules.removeSet();
            fill(currentItem());
        } else if (id == EditScoreRules.ITEM_ADD_SET) {
            pushSet(_rules.sets.size());
        } else if (id >= EditScoreRules.ITEM_SET) {
            pushSet(id - EditScoreRules.ITEM_SET);
        } else if (_rules.isByTeam(id)) {
            pushOurs();
        } else {
            pushPoints();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // The lists pop themselves before these (ChoiceMenu), back on this menu.

    function onSet(value as Number) as Void {
        var adding = _item == EditScoreRules.ITEM_ADD_SET;
        _rules.setSet(adding ? _rules.sets.size() : _item - EditScoreRules.ITEM_SET, _sets[value]);
        fill(adding ? currentItem() : _item);
    }

    // Our count picked: their counts that go with it, on theirs in the draft or the nearest.
    function onOurs(value as Number) as Void {
        _us = value;
        var games = _item == EditScoreRules.ITEM_GAMES;
        var values = _rules.getTheirChoices(_item, value);
        var labels = [] as Array<String or ResourceId>;
        var theirs = (games ? _rules.games : _rules.points)[TEAM_THEM];
        var nearest = values[0];
        for (var i = 0; i < values.size(); i++) {
            labels.add(EditScoreText.pair([value, values[i]]));
            if ((values[i] - theirs).abs() < (nearest - theirs).abs()) {
                nearest = values[i];
            }
        }
        ChoiceMenu.pushWithSubLabels(games ? Rez.Strings.EditTheirGames : Rez.Strings.EditTheirPoints, labels, null, values,
            nearest, method(:onTheirs));
    }

    function onTheirs(value as Number) as Void {
        _rules.setPair(_item, _us, value);
        fill(_item);
    }

    function onPoints(value as Number) as Void {
        _rules.setPair(EditScoreRules.ITEM_POINTS, _points[value][TEAM_US], _points[value][TEAM_THEM]);
        fill(_item);
    }

    // Finished set index's list (index sets.size(): the one Add set adds), titled "Set n", on its score.
    private function pushSet(index as Number) as Void {
        _sets = _rules.getSetChoices(index);
        var labels = [] as Array<String or ResourceId>;
        var subLabels = [] as Array<String or ResourceId or Null>;
        var values = [] as Array<Number>;
        for (var i = 0; i < _sets.size(); i++) {
            labels.add(EditScoreText.pair(_sets[i].games));
            subLabels.add(_sets[i].endedEarly ? Rez.Strings.EditEndedEarly : null);
            values.add(i);
        }
        var current = index < _rules.sets.size() ? EditScoreRules.indexOf(_sets, _rules.sets[index]) : 0;
        ChoiceMenu.pushWithSubLabels(EditScoreText.setLabel(index + 1), labels, subLabels, values, current, method(:onSet));
    }

    // Our games or our tie-break points, on ours in the draft.
    private function pushOurs() as Void {
        var games = _item == EditScoreRules.ITEM_GAMES;
        var values = _rules.getOurChoices(_item);
        var labels = [] as Array<String or ResourceId>;
        for (var i = 0; i < values.size(); i++) {
            labels.add(values[i].toString());
        }
        ChoiceMenu.pushWithSubLabels(games ? Rez.Strings.EditOurGames : Rez.Strings.EditOurPoints, labels, null, values,
            (games ? _rules.games : _rules.points)[TEAM_US], method(:onOurs));
    }

    // A regular game's points, each with the deuce its banner names, on the draft's.
    private function pushPoints() as Void {
        _points = _rules.getPointsChoices();
        var mode = _rules.match.getState().gameDeuceMode;
        var labels = [] as Array<String or ResourceId>;
        var subLabels = [] as Array<String or ResourceId or Null>;
        var values = [] as Array<Number>;
        var current = 0;
        for (var i = 0; i < _points.size(); i++) {
            var points = _points[i];
            labels.add(EditScoreText.points(points, GAME_REGULAR));
            subLabels.add(EditScoreText.deuceName(points, mode));
            values.add(i);
            if (points[TEAM_US] == _rules.points[TEAM_US] && points[TEAM_THEM] == _rules.points[TEAM_THEM]) {
                current = i;
            }
        }
        ChoiceMenu.pushWithSubLabels(Rez.Strings.EditGame, labels, subLabels, values, current, method(:onPoints));
    }

    // Logged: the match is written, and the score screen shows the edit. Refused (the match's
    // own score): "No change" under Apply.
    private function apply() as Void {
        if (_rules.apply(Time.now().value())) {
            _rules.match.save();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            ChoiceMenu.setSubLabel(_menu, EditScoreRules.ITEM_APPLY, Rez.Strings.EditNoChange);
        }
    }

    // The set in progress's item: its games, or the super tie-break's points.
    private function currentItem() as Number {
        return _rules.getGameType() == GAME_SUPER_TIE_BREAK ? EditScoreRules.ITEM_POINTS : EditScoreRules.ITEM_GAMES;
    }
}

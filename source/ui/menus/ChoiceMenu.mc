import Toybox.Lang;
import Toybox.WatchUi;

// Helpers for the native menus (principle 5).
module ChoiceMenu {

    // Pushes a list of choices for one menu item, like the watch's own settings: it opens on the
    // current choice, START picks one and goes back to the menu, which then gets onChoice with the
    // choice's value, and BACK goes back with no change. labels[i] picks values[i].
    function push(title as ResourceId, labels as Array<String or ResourceId>, values as Array<Number>,
            current as Number, onChoice as Method(value as Number) as Void) as Void {
        pushWithSubLabels(title, labels, null, values, current, onChoice);
    }

    // The same, with a line under some choices (subLabels[i] under labels[i], none for null), and a
    // title that may be a String.
    function pushWithSubLabels(title as String or ResourceId, labels as Array<String or ResourceId>,
            subLabels as Array<String or ResourceId or Null>?, values as Array<Number>, current as Number,
            onChoice as Method(value as Number) as Void) as Void {
        var focus = values.indexOf(current);
        var menu = new WatchUi.Menu2({:title => title, :focus => focus < 0 ? 0 : focus});
        for (var i = 0; i < values.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(labels[i], subLabels != null ? subLabels[i] : null, values[i], null));
        }
        WatchUi.pushView(menu, new ChoiceMenuDelegate(onChoice), WatchUi.SLIDE_LEFT);
    }

    // Shows a menu item's current value under its label (none for null), if the menu has the item.
    function setSubLabel(menu as WatchUi.Menu2, id as Object, subLabel as String or ResourceId or Null) as Void {
        var index = menu.findItemById(id);
        var item = index >= 0 ? menu.getItem(index) : null;
        if (item != null) {
            item.setSubLabel(subLabel);
            menu.updateItem(item, index);
        }
    }
}

class ChoiceMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChoice as Method(value as Number) as Void;

    function initialize(onChoice as Method(value as Number) as Void) {
        Menu2InputDelegate.initialize();
        _onChoice = onChoice;
    }

    // Pops first, so onChoice can open another menu in this list's place (Custom).
    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        _onChoice.invoke(item.getId() as Number);
    }
}

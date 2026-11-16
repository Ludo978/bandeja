import Toybox.Lang;
import Toybox.WatchUi;

// The history list, from the home screen's list: a native menu of the stored matches,
// newest first, each its result and score over its date, duration and format (HistoryText); one line
// saying so when there's none, which does nothing. Read from storage each time it opens, so it shows
// the matches saved before the app last started. START on a match opens its summary, read only
// (HistoryInput); BACK there comes back here, and BACK here goes back to the home screen's list.
module HistoryMenu {

    function open() as Void {
        var records = HistoryStore.load();
        var lines = HistoryText.lines(records);
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuHistory});
        for (var i = 0; i < lines.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(lines[i][0], lines[i][1], records.size() > 0 ? i : :empty, null));
        }
        WatchUi.pushView(menu, new HistoryMenuDelegate(records), WatchUi.SLIDE_LEFT);
    }

    // The match's summary as its own summary showed it (SummaryModel from its record), without the
    // START hint: nothing saves here.
    function openSummary(record as HistoryRecord) as Void {
        var model = new SummaryModel(record);
        var view = new SummaryView(model, false);
        WatchUi.pushView(view, new HistoryDelegate(view, new HistoryInput(model.getPageCount())), WatchUi.SLIDE_LEFT);
    }
}

class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {

    // The records listed, in the menu's order: an item's id is its index (none for the empty line).
    private var _records as Array<HistoryRecord>;

    function initialize(records as Array<HistoryRecord>) {
        Menu2InputDelegate.initialize();
        _records = records;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number && id < _records.size()) {
            HistoryMenu.openSummary(_records[id]);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

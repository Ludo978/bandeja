import Toybox.Lang;
import Toybox.WatchUi;

// The summary's menu (hold UP): Save, Discard (confirmed), Back to match, a native menu
// titled with the app's name. Save and Back to match do what START and BACK do on the summary
// (SummaryInput); a save the watch refuses keeps the menu with "Not saved" under Save, as the pause
// menu does. BACK closes the menu, back on the summary.
module SummaryMenu {

    function open(input as SummaryInput, match as CurrentMatch) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Save, null, :save, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuBackToMatch, null, :backToMatch, null));
        WatchUi.pushView(menu, new SummaryMenuDelegate(menu, input, match), WatchUi.SLIDE_UP);
    }
}

class SummaryMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as WatchUi.Menu2;
    private var _input as SummaryInput;
    private var _match as CurrentMatch;

    function initialize(menu as WatchUi.Menu2, input as SummaryInput, match as CurrentMatch) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _input = input;
        _match = match;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :save) {
            if (_input.save() == SUMMARY_SAVED) {
                MatchFlow.saved(MatchFlow.historyRecord(_match));
            } else {
                ChoiceMenu.setSubLabel(_menu, :save, Rez.Strings.SaveFailed);
            }
        } else if (id == :discard) {
            DiscardConfirm.push();
        } else if (id == :backToMatch) {
            // Back on the summary first, which the score screen then replaces.
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (_input.backToMatch() == SUMMARY_UNDO) {
                MatchFlow.backToMatch(_match, _input.undone as MatchEvent);
            }
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

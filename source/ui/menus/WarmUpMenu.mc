import Toybox.Lang;
import Toybox.WatchUi;

// The warm-up's menu (hold UP): Start match, Discard (confirmed), Settings. The
// recording goes on while it shows; BACK returns to the warm-up.
module WarmUpMenu {

    function open(warmUp as WarmUpDelegate) as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuStartMatch, null, :startMatch, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, :discard, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSettings, null, :settings, null));
        addDebugItems(menu, warmUp.getFlow());
        WatchUi.pushView(menu, new WarmUpMenuDelegate(warmUp), WatchUi.SLIDE_UP);
    }

    // Debug builds only, in a timed match: the court booking ends a set time from now (DebugCourt).
    (:debug)
    function addDebugItems(menu as WatchUi.Menu2, flow as WarmUpFlow) as Void {
        if (flow.court != null) {
            menu.addItem(new WatchUi.MenuItem("Court end (debug)", null, :debugCourt, null));
        }
    }

    (:release)
    function addDebugItems(menu as WatchUi.Menu2, flow as WarmUpFlow) as Void {
    }
}

class WarmUpMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _warmUp as WarmUpDelegate;

    function initialize(warmUp as WarmUpDelegate) {
        Menu2InputDelegate.initialize();
        _warmUp = warmUp;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :startMatch) {
            // Back on the warm-up screen first, which the match screens then replace.
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _warmUp.start();
        } else if (id == :discard) {
            DiscardConfirm.push();
        } else if (id == :settings) {
            SettingsMenu.open();
        } else {
            debugCourt();
        }
    }

    (:debug)
    private function debugCourt() as Void {
        DebugCourt.push(new DebugCourt(null, _warmUp.getFlow()).method(:onChoice));
    }

    (:release)
    private function debugCourt() as Void {
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

import Toybox.Lang;
import Toybox.WatchUi;

// The list below the home screen: Format, History and Settings. No values
// under the labels: the home screen shows the format, and a format line doesn't fit a menu line on
// the 360 px screen.
module HomeMenu {

    function open() as Void {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuFormat, null, :format, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuHistory, null, :history, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSettings, null, :settings, null));
        WatchUi.pushView(menu, new HomeMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class HomeMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :format) {
            FormatMenu.open();
        } else if (id == :history) {
            HistoryMenu.open();
        } else if (id == :settings) {
            SettingsMenu.open();
        }
    }

    // Back down to the home screen, the way the list came up.
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

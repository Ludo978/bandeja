import Toybox.Lang;
import Toybox.WatchUi;

// The home screen's input. START plays (MatchFlow). DOWN or a swipe up opens
// the list below, Format, History and Settings, as the chevron shows; hold UP, the menu gesture,
// opens it too. BACK and swipe right exit to the watch face: nothing records here. A tap on the
// ball plays, a tap on the lines below it opens the list.
class HomeDelegate extends WatchUi.BehaviorDelegate {

    private var _view as HomeView;

    function initialize(view as HomeView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // The behaviors come first: START and a tap both give onSelect, which passes them on to onKey
    // and onTap.
    function onSelect() as Boolean {
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            MatchFlow.begin();
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var point = clickEvent.getCoordinates();
        if (_view.isOnBall(point[0], point[1])) {
            MatchFlow.begin();
        } else if (_view.isBelowBall(point[1])) {
            HomeMenu.open();
        }
        return true;
    }

    // DOWN or a swipe up.
    function onNextPage() as Boolean {
        HomeMenu.open();
        return true;
    }

    // UP or a swipe down: nothing.
    function onPreviousPage() as Boolean {
        return true;
    }

    function onMenu() as Boolean {
        HomeMenu.open();
        return true;
    }

    function onBack() as Boolean {
        return getSessionManager().isRecording();
    }
}

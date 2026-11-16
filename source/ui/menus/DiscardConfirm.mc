import Toybox.Lang;
import Toybox.WatchUi;

// Discard, always confirmed, with the watch's own confirmation. Yes drops
// the recording and returns to the watch face; no goes back to the menu, still recording.
module DiscardConfirm {

    function push() as Void {
        WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.DiscardConfirm) as String),
            new DiscardConfirmDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class DiscardConfirmDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getSessionManager().discard();
            MatchFlow.exit();
        }
        return true;
    }
}

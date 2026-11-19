import Toybox.Lang;
import Toybox.WatchUi;

// What the summary does after an input (SummaryInput). Every input is consumed, whatever it gives.
enum SummaryAction {
    SUMMARY_NONE,       // nothing happens (a touch, a page past the first or the last)
    SUMMARY_PAGE,       // another page shows (SummaryInput.page)
    SUMMARY_SAVED,      // the session is saved: the app exits to the watch face
    SUMMARY_NOT_SAVED,  // the watch refused the save: the session is kept, paused, "Not saved"
    SUMMARY_UNDO,       // the last event is undone (SummaryInput.undone): back to the match
    SUMMARY_MENU        // hold UP: Save / Discard / Back to match
}

// The summary's input rules, without the screen, so they're unit-tested:
// SummaryDelegate passes every input here and shows what comes back.
//
// START saves (Save in the hold UP menu too). BACK undoes the last event, whatever its type (the
// match point, or End match or End set now from the pause menu), and the score screen comes back
// with the match as it was before it (Back to match in the menu does the same). The session is left
// as it is: running after a match point, paused after the pause menu's End match or End set now, as
// it was when they were picked; START resumes on the score screen. UP and DOWN never score
// here: they turn the pages, as swipes down and up do. Hold UP opens the menu; touches and other
// swipes do nothing. Nothing leaves the summary but Save, Discard and BACK. On the watches without UP
// and DOWN (InputFlags), a swipe up on the last page opens the menu (swipeMenu).
class SummaryInput {

    // The page showing, from 0.
    var page as Number = 0;
    // A swipe up on the last page opens the menu (InputFlags).
    var swipeMenu as Boolean = false;
    // The event the last SUMMARY_UNDO took back.
    var undone as MatchEvent? = null;

    private var _match as CurrentMatch;
    private var _session as SessionManager;
    private var _pages as Number;

    function initialize(match as CurrentMatch, session as SessionManager, pages as Number) {
        _match = match;
        _session = session;
        _pages = pages;
    }

    // A button, as onKey gets it.
    function key(key as WatchUi.Key) as SummaryAction {
        if (key == WatchUi.KEY_DOWN) {
            return turn(1);
        } else if (key == WatchUi.KEY_UP) {
            return turn(-1);
        } else if (key == WatchUi.KEY_ENTER) {
            return save();
        } else if (key == WatchUi.KEY_ESC) {
            return backToMatch();
        } else if (key == WatchUi.KEY_MENU) {
            return SUMMARY_MENU;
        }
        return SUMMARY_NONE;
    }

    // A swipe up shows the page below, a swipe down the one above. With swipeMenu, a swipe up on the
    // last page opens the menu.
    function swipe(direction as WatchUi.SwipeDirection) as SummaryAction {
        if (direction == WatchUi.SWIPE_UP) {
            return swipeMenu && page == _pages - 1 ? SUMMARY_MENU : turn(1);
        } else if (direction == WatchUi.SWIPE_DOWN) {
            return turn(-1);
        }
        return SUMMARY_NONE;
    }

    // A tap, a touch hold or its release, a drag, a flick.
    function touch() as SummaryAction {
        return SUMMARY_NONE;
    }

    // START, and Save in the menu: the FIT file with the match's fields. A save the watch
    // refuses keeps the session, paused.
    function save() as SummaryAction {
        return _session.save() ? SUMMARY_SAVED : SUMMARY_NOT_SAVED;
    }

    // BACK, and Back to match in the menu: the last event undone, the match open again.
    function backToMatch() as SummaryAction {
        var event = _match.undo();
        if (event == null) {
            return SUMMARY_NONE;
        }
        undone = event;
        return SUMMARY_UNDO;
    }

    private function turn(step as Number) as SummaryAction {
        var next = page + step;
        if (next < 0 || next >= _pages) {
            return SUMMARY_NONE;
        }
        page = next;
        return SUMMARY_PAGE;
    }
}

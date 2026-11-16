import Toybox.Lang;
import Toybox.WatchUi;

// What a stored match's summary does after an input (HistoryInput). Every input is consumed.
enum HistoryAction {
    HISTORY_NONE,   // nothing happens (START, hold UP, a touch, a page past the first or the last)
    HISTORY_PAGE,   // another page shows (HistoryInput.page)
    HISTORY_BACK    // back to the history list
}

// The input rules of a stored match's summary, opened from the history list, without the
// screen, so they're unit-tested: HistoryDelegate passes every input here and shows what comes back.
//
// Read only: the match is saved and its session long gone, so nothing saves, undoes or discards, and
// the input holds neither. UP and DOWN turn the pages as on the match's own summary (swipes down and up
// too), with no wrap; BACK goes back to the list, and so does a swipe right, as on the watch's own
// screens. START and hold UP do nothing: there's no START hint on this summary and no menu, since a
// menu could only hold Back.
class HistoryInput {

    // The page showing, from 0.
    var page as Number = 0;

    private var _pages as Number;

    function initialize(pages as Number) {
        _pages = pages;
    }

    // A button, as onKey gets it.
    function key(key as WatchUi.Key) as HistoryAction {
        if (key == WatchUi.KEY_DOWN) {
            return turn(1);
        } else if (key == WatchUi.KEY_UP) {
            return turn(-1);
        } else if (key == WatchUi.KEY_ESC) {
            return HISTORY_BACK;
        }
        return HISTORY_NONE;
    }

    // A swipe up shows the page below, a swipe down the one above, a swipe right goes back.
    function swipe(direction as WatchUi.SwipeDirection) as HistoryAction {
        if (direction == WatchUi.SWIPE_UP) {
            return turn(1);
        } else if (direction == WatchUi.SWIPE_DOWN) {
            return turn(-1);
        } else if (direction == WatchUi.SWIPE_RIGHT) {
            return HISTORY_BACK;
        }
        return HISTORY_NONE;
    }

    // A tap, a touch hold or its release, a drag, a flick.
    function touch() as HistoryAction {
        return HISTORY_NONE;
    }

    private function turn(step as Number) as HistoryAction {
        var next = page + step;
        if (next < 0 || next >= _pages) {
            return HISTORY_NONE;
        }
        page = next;
        return HISTORY_PAGE;
    }
}

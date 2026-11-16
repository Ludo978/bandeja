import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Debug builds only: the score screen's last input events, to see on the watch what a gesture sends
// (the edge swipe right, found undoing points on 2026-10-31). The match menu's "Input log (debug)"
// lists them, newest first. Release builds keep an empty add().
(:debug)
module InputLog {

    const SIZE = 40;

    var lines as Array<String> = [];
    // Consecutive drag moves are one line, "drag 1 xN" (a swipe sends dozens).
    var _moves as Number = 0;

    // kind: "press", "key", "release", "swipe", "drag", "tap", "hold", "up", "flick"; a and b: the
    // key or direction and the event's type, or null; note: e.g. "ok" / "blocked".
    function add(kind as String, a as Number?, b as Number?, note as String?) as Void {
        var stamp = (System.getTimer() % 100000).format("%05d");
        if (kind.equals("drag") && a != null && a == 1) {
            _moves += 1;
            var line = stamp + " drag 1 x" + _moves;
            if (_moves > 1 && lines.size() > 0) {
                lines[lines.size() - 1] = line;
            } else {
                lines.add(line);
            }
            return;
        }
        _moves = 0;
        var text = stamp + " " + kind;
        if (a != null) {
            text += " " + (kind.equals("key") || kind.equals("press") || kind.equals("release") ? keyName(a) : a.toString());
        }
        if (b != null) {
            text += " t" + b;
        }
        if (note != null) {
            text += " " + note;
        }
        lines.add(text);
        if (lines.size() > SIZE) {
            lines = lines.slice(lines.size() - SIZE, null);
        }
    }

    function keyName(key as Number) as String {
        if (key == WatchUi.KEY_ESC) {
            return "BACK";
        } else if (key == WatchUi.KEY_UP) {
            return "UP";
        } else if (key == WatchUi.KEY_DOWN) {
            return "DOWN";
        } else if (key == WatchUi.KEY_ENTER) {
            return "START";
        } else if (key == WatchUi.KEY_MENU) {
            return "MENU";
        }
        return key.toString();
    }

    // The log as a native list, newest first; BACK closes it.
    function show() as Void {
        var menu = new WatchUi.Menu2({:title => "Input log"});
        if (lines.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("(empty)", null, 0, null));
        }
        for (var i = lines.size() - 1; i >= 0; i--) {
            menu.addItem(new WatchUi.MenuItem(lines[i], null, i, null));
        }
        WatchUi.pushView(menu, new WatchUi.Menu2InputDelegate(), WatchUi.SLIDE_LEFT);
    }
}

(:release)
module InputLog {
    function add(kind as String, a as Number?, b as Number?, note as String?) as Void {
    }
}

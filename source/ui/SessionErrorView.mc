import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Replaces the current screen with the error screen after SessionManager.start() failed.
function showSessionError(session as SessionManager) as Void {
    WatchUi.switchToView(new SessionErrorView(session.getError()), new SessionErrorDelegate(),
        WatchUi.SLIDE_IMMEDIATE);
}

// Shown when the watch refuses the Padel session: the app never falls back to a
// generic activity (G3). Nothing records, so START or BACK returns to the watch face. The watch's
// own message, untranslated, is shown small for bug reports.
class SessionErrorView extends WatchUi.View {

    // The app's palette (Palette.mc).
    private const COLOR_TEXT = 0xF5F7FA;
    private const COLOR_MUTED = 0x8B9099;
    private const COLOR_BALL = 0xD7F34A;
    // Top of the "START · EXIT" hint, as a fraction of the height.
    private const HINT_Y = 0.84;

    private var _detail as String?;

    function initialize(detail as String?) {
        View.initialize();
        _detail = detail;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(COLOR_TEXT, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);

        // Warning mark: a yellow ring with "!".
        var markY = h * 0.17;
        dc.setColor(COLOR_BALL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w / 104);
        dc.drawCircle(cx, markY, w * 0.055);
        dc.drawText(cx, markY, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Top down; the watch's message is left out when it would reach the hint.
        var hintY = h * HINT_Y;
        var y = h * 0.25;
        y = drawWrapped(dc, WatchUi.loadResource(Rez.Strings.SessionErrorTitle) as String,
            Graphics.FONT_SMALL, COLOR_TEXT, y, w * 0.76, 2, hintY);
        y = drawWrapped(dc, WatchUi.loadResource(Rez.Strings.SessionErrorBody) as String,
            Graphics.FONT_XTINY, COLOR_TEXT, y + h * 0.02, w * 0.84, 3, hintY);
        var detail = _detail;
        if (detail != null) {
            drawWrapped(dc, detail, Graphics.FONT_XTINY, COLOR_MUTED, y + h * 0.02, w * 0.8, 1, hintY);
        }

        drawStartHint(dc, WatchUi.loadResource(Rez.Strings.HintExit) as String);
    }

    // Draws text centered, wrapped to width and at most maxLines lines, if it ends above maxY.
    // Returns the y below it.
    private function drawWrapped(dc as Dc, text as String, font as Graphics.FontType, color as Number,
            y as Numeric, width as Numeric, maxLines as Number, maxY as Numeric) as Numeric {
        // fitTextToArea spaces lines a little more than the font height: leave room for that, short
        // of one more line.
        var fitted = Graphics.fitTextToArea(text, font, width, dc.getFontHeight(font) * (maxLines + 1) - 1, true);
        if (fitted == null) {
            return y;
        }
        var bottom = y + dc.getTextDimensions(fitted, font)[1];
        if (bottom > maxY) {
            return y;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, fitted, Graphics.TEXT_JUSTIFY_CENTER);
        return bottom;
    }

    // "START · EXIT" at the bottom and the yellow arc by the START button (principle 6),
    // placed as in the mockups: radius 202 of 208, from 22° to 38°.
    private function drawStartHint(dc as Dc, action as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COLOR_BALL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(w * 6 / 416);
        dc.drawArc(w / 2, h / 2, w * 202 / 416, Graphics.ARC_COUNTER_CLOCKWISE, 22, 38);

        var font = Graphics.FONT_XTINY;
        var start = WatchUi.loadResource(Rez.Strings.ButtonStart) as String;
        var rest = " · " + action;
        var startWidth = dc.getTextWidthInPixels(start, font);
        var x = (w - startWidth - dc.getTextWidthInPixels(rest, font)) / 2;
        var y = h * HINT_Y;
        dc.drawText(x, y, font, start, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + startWidth, y, font, rest, Graphics.TEXT_JUSTIFY_LEFT);
    }
}

class SessionErrorDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        System.exit();
    }

    function onBack() as Boolean {
        System.exit();
    }
}

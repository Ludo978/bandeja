import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// A short message the app draws inside its own view ("Press START to begin the match", "Undone:
// point US"), never WatchUi.showToast: a press on a system toast only dismisses it, so a point would
// be lost. It takes no input: the view's delegate keeps getting every press while it
// shows, and a press that shows it again restarts it. The view draws it last, over its content,
// where it wants it (draw()), and calls hide() from onHide(). With show(), a one-shot timer of its
// own redraws the view when it's over; the score screen times it with its one timer instead
// (showAt(), getEndAt()).
class Toast {

    // How long it shows, in milliseconds.
    static const DURATION = 2000;

    // The pill, in mockup pixels: height, text size, the space on each side of the text, and the
    // space kept from the edge of the round screen.
    private const HEIGHT = 40;
    private const TEXT_SIZE = 17;
    private const PADDING = 18;
    private const MARGIN = 10;
    // The pill's fill: the divider grey, so it reads as an overlay on the black ground.
    private const FILL = Palette.LINE;

    private var _text as String? = null;
    // System.getTimer() when it was shown.
    private var _shownAt as Number = 0;
    // The text's size where it was last drawn, smaller if a translation doesn't fit.
    private var _size as Number? = null;
    private var _timer as Timer.Timer? = null;

    function initialize() {
    }

    // Shows text now for DURATION, replacing what shows, and redraws the view.
    function show(text as String) as Void {
        showAt(text, System.getTimer());
        var timer = _timer;
        if (timer == null) {
            timer = new Timer.Timer();
            _timer = timer;
        }
        timer.stop();
        timer.start(method(:onExpire), DURATION, false);
        WatchUi.requestUpdate();
    }

    // show() at a given System.getTimer() time, without the timer.
    function showAt(text as String, now as Number) as Void {
        if (!text.equals(_text)) {
            _size = null;
        }
        _text = text;
        _shownAt = now;
    }

    // The text showing at a System.getTimer() time, or null. The difference keeps it right when
    // the timer wraps around.
    function getTextAt(now as Number) as String? {
        var age = now - _shownAt;
        return age >= 0 && age < DURATION ? _text : null;
    }

    function isShowing() as Boolean {
        return getTextAt(System.getTimer()) != null;
    }

    // When the text showing at now goes, or null with none: for a view that times the toast with its
    // own timer (the score screen's, ScoreMotion), showing it with showAt().
    function getEndAt(now as Number) as Number? {
        return getTextAt(now) != null ? _shownAt + DURATION : null;
    }

    function onExpire() as Void {
        _text = null;
        WatchUi.requestUpdate();
    }

    // Gone at once, for the view's onHide(): it doesn't come back when the view shows again.
    function hide() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _text = null;
    }

    // Draws it, if it shows, as a pill centered on the mockup's (240, mockupY), its text centered on
    // that line. The text gets smaller, down to three quarters, if the pill wouldn't fit the round
    // screen there.
    function draw(dc as Graphics.Dc, l as Layout, mockupY as Numeric) as Void {
        var text = getTextAt(System.getTimer());
        if (text == null) {
            return;
        }
        var size = _size;
        if (size == null) {
            size = l.fitSize(dc, STYLE_BOLD, TEXT_SIZE, text, 0, maxTextWidth(mockupY));
            _size = size;
        }
        drawPill(dc, l, mockupY, text, size);
    }

    // The same pill with any text, for as long as the caller draws it (the score screen's pause).
    function drawText(dc as Graphics.Dc, l as Layout, mockupY as Numeric, text as String) as Void {
        drawPill(dc, l, mockupY, text, l.fitSize(dc, STYLE_BOLD, TEXT_SIZE, text, 0, maxTextWidth(mockupY)));
    }

    private function drawPill(dc as Graphics.Dc, l as Layout, mockupY as Numeric, text as String,
            size as Numeric) as Void {
        var width = l.textWidth(dc, STYLE_BOLD, size, text, 0) + 2 * PADDING;
        dc.setColor(FILL, Graphics.COLOR_TRANSPARENT);
        l.fillRoundedRect(dc, 240 - width / 2, mockupY - HEIGHT / 2, width, HEIGHT, HEIGHT / 2);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, mockupY + Fonts.CAP_MIDDLE * size, STYLE_BOLD, size, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The widest text whose pill stays inside the round screen at mockupY, less the margin: the
    // circle is narrowest at the pill's edge farther from the center.
    private function maxTextWidth(mockupY as Numeric) as Float {
        var edge = mockupY < 240 ? mockupY - HEIGHT / 2 : mockupY + HEIGHT / 2;
        return Layout.chord(edge) - 2 * MARGIN - 2 * PADDING;
    }
}

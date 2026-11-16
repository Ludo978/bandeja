import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The home screen (mockup "Home"): the wordmark, the yellow PLAY ball, the format of
// the next match, and the hint to the list below it (Format, History, Settings: HISTORY · SETTINGS,
// the format showing right above), with the START hint arc.
// Drawn from the mockup's numbers through Layout. Nothing records here.
class HomeView extends WatchUi.View {

    // The PLAY ball, in mockup pixels, and the margin around it a tap still counts in.
    private const BALL_X = 240;
    private const BALL_Y = 234;
    private const BALL_RADIUS = 80;
    private const TAP_MARGIN = 12;

    private var _layout as Layout = new Layout(416);
    private var _wordmark as String = "";
    private var _play as String = "";
    private var _hint as String = "";
    // "Best of 3 · Star point", "Indoor · no GPS" ("Timed · Indoor · no GPS" for a timed match):
    // read again each time the screen shows, after the menus.
    private var _formatLine as String = "";
    private var _detailLine as String = "";
    // The font sizes of the two lines and the hint, made smaller if a translation doesn't fit the
    // round screen. Worked out at the first draw after the lines change.
    private var _sizes as Array<Number>?;
    // The seams: black at 18 % over the ball.
    private var _seamColor as Number = Palette.onBlack(Palette.BALL, 82);

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new Layout(dc.getWidth());
        _wordmark = (WatchUi.loadResource(Rez.Strings.AppName) as String).toUpper();
        _play = WatchUi.loadResource(Rez.Strings.Play) as String;
        _hint = WatchUi.loadResource(Rez.Strings.HomeHint) as String;
    }

    function onShow() as Void {
        var config = FormatStore.load();
        _formatLine = FormatText.line(config);
        _detailLine = FormatText.detailLine(config, Settings.isOutdoor(), Settings.isTimedMatch());
        _sizes = null;
    }

    function onUpdate(dc as Dc) as Void {
        var l = _layout;
        dc.setAntiAlias(true);
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var sizes = _sizes;
        if (sizes == null) {
            // Widths that stay inside the circle at each line's baseline, less a margin.
            sizes = [
                l.fitSize(dc, STYLE_BOLD, 21, _formatLine, 0, 332),
                l.fitSize(dc, STYLE_REGULAR, 16, _detailLine, 0, 290),
                l.fitSize(dc, STYLE_BOLD, 14, _hint, 1.5, 206)
            ];
            _sizes = sizes;
        }

        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.drawStartArc(dc);
        l.drawSpacedText(dc, 240, 116, STYLE_BOLD, 20, 6, _wordmark, Graphics.TEXT_JUSTIFY_CENTER);
        drawBall(dc, l);

        // The mockup's weight 500 is Bold (no Medium face).
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 350, STYLE_BOLD, sizes[0], _formatLine, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 377, STYLE_REGULAR, sizes[1], _detailLine, Graphics.TEXT_JUSTIFY_CENTER);
        l.drawSpacedText(dc, 240, 417, STYLE_BOLD, sizes[2], 1.5, _hint, Graphics.TEXT_JUSTIFY_CENTER);

        // The chevron: there's more below.
        dc.setPenWidth(l.pen(2));
        dc.drawLine(l.x(232), l.y(428), l.x(240), l.y(435));
        dc.drawLine(l.x(240), l.y(435), l.x(248), l.y(428));
    }

    // Whether a tap at screen (x, y) is on the PLAY ball.
    function isOnBall(x as Number, y as Number) as Boolean {
        var dx = x - _layout.x(BALL_X);
        var dy = y - _layout.y(BALL_Y);
        var radius = _layout.len(BALL_RADIUS + TAP_MARGIN);
        return dx * dx + dy * dy <= radius * radius;
    }

    // Whether a tap at screen y is below the ball, on the format lines or the hint.
    function isBelowBall(y as Number) as Boolean {
        return y > _layout.y(BALL_Y + BALL_RADIUS + TAP_MARGIN);
    }

    // The ball with its two seams, and PLAY on it.
    private function drawBall(dc as Dc, l as Layout) as Void {
        l.fillCircle(dc, BALL_X, BALL_Y, BALL_RADIUS);
        dc.setColor(_seamColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(l.pen(3));
        drawCurve(dc, l, 176, 206, 240, 236, 304, 206);
        drawCurve(dc, l, 176, 262, 240, 232, 304, 262);
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, 250, STYLE_BOLD, 44, 2, _play, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A quadratic curve as SVG's "M x0 y0 Q x1 y1 x2 y2", in short lines, with the current pen.
    private function drawCurve(dc as Dc, l as Layout, x0 as Numeric, y0 as Numeric, x1 as Numeric, y1 as Numeric,
            x2 as Numeric, y2 as Numeric) as Void {
        // Unrounded screen positions: the antialiased lines then follow the curve without steps.
        var steps = 16;
        var offset = Layout.MOCKUP_OFFSET;
        var fromX = (x0 - offset) * l.scale;
        var fromY = (y0 - offset) * l.scale;
        for (var i = 1; i <= steps; i++) {
            var t = i.toFloat() / steps;
            var u = 1 - t;
            var toX = (u * u * x0 + 2 * u * t * x1 + t * t * x2 - offset) * l.scale;
            var toY = (u * u * y0 + 2 * u * t * y1 + t * t * y2 - offset) * l.scale;
            dc.drawLine(fromX, fromY, toX, toY);
            fromX = toX;
            fromY = toY;
        }
    }
}

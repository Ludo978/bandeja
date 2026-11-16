import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// The glance (mockup "Glance"), in the watch's glance loop: Bandeja in yellow, at the size of
// the native glances' titles, then the last saved match, "Last: W 6-4 6-3 · 1h12", or a line in grey
// saying no match was played yet. The watch gives it its own area, right of the launcher icon it draws
// (275 x 120 on the FR265, 240 x 104 on the FR265S), and draws the background: the mockup's numbers are
// the area's, scaled to its height. A line too wide for the area shrinks, down to three quarters of its
// size, then shows the sets won in place of the score (LastMatch.lines()). It reads the one small value
// LastMatch keeps, never the history.
// Glance code: loaded with the app class alone, in 64 KB, so it keeps to Toybox and LastMatch. It takes
// no input: selecting it opens the app (BandejaApp.getInitialView()).
(:glance)
class BandejaGlance extends WatchUi.GlanceView {

    // The mockup's area height, and its title's and line's baselines and em sizes (its glance area
    // spans y 180 to 300). The title is as high as the system glance font, which the native
    // glances write their titles in (FONT_GLANCE: 39 px on the FR265, 34 on the FR265S), and written
    // like theirs, capital first, no letter spacing. The line grows as far as a two-set match still
    // fits whole at full size in French on both screens, with a few pixels to spare (`Dernier : D 0-6
    // 4-6 · 58 min`: 266 of the FR265's 275 px).
    static const HEIGHT = 120.0;
    static const TITLE_BASELINE = 57;
    static const TITLE_SIZE = 33;
    static const LINE_BASELINE = 88;
    static const LINE_SIZE = 24;
    // As Fonts': Roboto's line height per pixel of em size, getVectorFont's :size.
    static const LINE_HEIGHT = 1.1719;
    // Palette's ball, text and muted.
    private static const BALL = 0xD7F34A;
    private static const TEXT = 0xF5F7FA;
    private static const MUTED = 0x8B9099;

    // The line shown and its font, kept while the stored value gives the same lines (fitting it loads
    // a font per size tried), and the title's font, loaded once.
    private var _lines as Array<String>? = null;
    private var _line as String = "";
    private var _font as Graphics.FontType = Graphics.FONT_GLANCE;
    private var _titleFont as Graphics.FontType? = null;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var scale = dc.getHeight() / HEIGHT;
        var lines = LastMatch.lines(LastMatch.read());
        var kept = _lines;
        if (kept == null || !kept[0].equals(lines[0])) {
            var fitted = fit(dc, lines, LINE_SIZE * scale);
            _line = lines[fitted[0]];
            _font = fitted[2];
            _lines = lines;
        }
        dc.setColor(BALL, Graphics.COLOR_TRANSPARENT);
        drawTitle(dc, scale);
        // One line only when no match was saved yet: in grey.
        dc.setColor(lines.size() > 1 ? TEXT : MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, Math.round(LINE_BASELINE * scale).toNumber() - Graphics.getFontAscent(_font), _font, _line,
            Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Bandeja, the app's name as written (capital first), as the native glances write their titles.
    private function drawTitle(dc as Graphics.Dc, scale as Float) as Void {
        var font = _titleFont;
        if (font == null) {
            font = font(TITLE_SIZE * scale);
            _titleFont = font;
        }
        var top = Math.round(TITLE_BASELINE * scale).toNumber() - Graphics.getFontAscent(font);
        dc.drawText(0, top, font, WatchUi.loadResource(Rez.Strings.AppName) as String, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The first of lines that fits the area's width at size or smaller, down to three quarters of it;
    // the last one at three quarters when none does: its index in lines, its em size and its font.
    static function fit(dc as Graphics.Dc, lines as Array<String>, size as Float) as [Number, Float, Graphics.FontType] {
        var smallest = size * 3 / 4;
        for (var i = 0; i < lines.size(); i++) {
            for (var em = size; em >= smallest; em -= 1) {
                var font = font(em);
                if (dc.getTextWidthInPixels(lines[i], font) <= dc.getWidth()) {
                    return [i, em, font];
                }
                if (!isVector()) {
                    break;
                }
            }
        }
        return [lines.size() - 1, smallest, font(smallest)];
    }

    // RobotoCondensedBold at an em size in pixels; the glance's system font without vector fonts (the
    // FR265's first firmware, API 4.2.0).
    static function font(em as Float) as Graphics.FontType {
        if (isVector()) {
            var font = Graphics.getVectorFont({:face => "RobotoCondensedBold",
                :size => Math.round(em * LINE_HEIGHT).toNumber()});
            if (font != null) {
                return font;
            }
        }
        return Graphics.FONT_GLANCE;
    }

    static function isVector() as Boolean {
        return Graphics has :getVectorFont;
    }
}

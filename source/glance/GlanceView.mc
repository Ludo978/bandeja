import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// The glance (mockup "Glance"), in the watch's glance loop: Bandeja in yellow, at the size of
// the native glances' titles, then the last saved match, "Last: W 6-4 6-3 · 1h12", or a line in grey
// saying no match was played yet. The watch gives it its own area, right of the launcher icon it draws
// (275 x 120 on the FR265, 240 x 104 on the FR265S), and draws the background (on the Instinct 3 AMOLED a
// round window at its right, which the line keeps clear of, lineWidth(), as it does of the round
// screen's edge on the watches without UP and DOWN, roundLimit()): the mockup's numbers are
// the area's, scaled to its height, or less where the system glance font is smaller than the mockup's
// title would be (scale()), and centered in the area's height. A line too wide for the area shrinks,
// down to three quarters of its size, then shows the sets won in place of the score
// (LastMatch.lines()). It reads the one small value LastMatch keeps, never the history.
// Glance code: loaded with the app class alone, in 64 KB, so it keeps to Toybox and LastMatch. It takes
// no input: selecting it opens the app (BandejaApp.getInitialView()).
(:glance)
class BandejaGlance extends WatchUi.GlanceView {

    // The mockup's area height, and its title's and line's baselines and em sizes (its glance area
    // spans y 180 to 300). The title is as high as the system glance font, which the native
    // glances write their titles in (FONT_GLANCE: 39 px on the FR265, 34 on the FR265S, the title's
    // size scaled to each), and written like theirs, capital first, no letter spacing. The line grows
    // as far as a two-set match still fits whole at full size in French on both screens, with a few
    // pixels to spare (`Dernier : D 0-6 4-6 · 58 min`: 266 of the FR265's 275 px).
    static const HEIGHT = 120.0;
    static const TITLE_BASELINE = 57;
    static const TITLE_SIZE = 33;
    static const LINE_BASELINE = 88;
    static const LINE_SIZE = 24;
    // The height of Roboto's capitals and digits per pixel of em size, 1456 / 2048.
    static const CAP_HEIGHT = 0.711;
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
        var scale = scale(dc.getHeight());
        var top = top(dc.getHeight());
        var lines = LastMatch.lines(LastMatch.read());
        var kept = _lines;
        if (kept == null || !kept[0].equals(lines[0])) {
            var fitted = fit(dc, lines, LINE_SIZE * scale);
            _line = lines[fitted[0]];
            _font = fitted[2];
            _lines = lines;
        }
        dc.setColor(BALL, Graphics.COLOR_TRANSPARENT);
        drawTitle(dc, top + TITLE_BASELINE * scale);
        // One line only when no match was saved yet: in grey.
        dc.setColor(lines.size() > 1 ? TEXT : MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lineLeft(dc), Math.round(top + LINE_BASELINE * scale).toNumber() - Graphics.getFontAscent(_font),
            _font, _line, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Bandeja, the app's name as written (capital first), as the native glances write their titles, its
    // baseline at baseline.
    private function drawTitle(dc as Graphics.Dc, baseline as Float) as Void {
        var font = _titleFont;
        if (font == null) {
            font = titleFont();
            _titleFont = font;
        }
        var top = Math.round(baseline).toNumber() - Graphics.getFontAscent(font);
        dc.drawText(inset(top), top, font, WatchUi.loadResource(Rez.Strings.AppName) as String,
            Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Area pixels per mockup pixel in an area this high: its height's share of the mockup's, or the
    // system glance font's share of the mockup's title where that is smaller (the FR965's 148 px high
    // area has a 42 px glance font, a 120 px one would be 48), so the line keeps its size against the
    // title and the native titles. The same on the FR265 and FR265S, where both shares are about equal.
    static function scale(height as Number) as Float {
        var byHeight = height / HEIGHT;
        var byTitle = Graphics.getFontHeight(Graphics.FONT_GLANCE) / (TITLE_SIZE * LINE_HEIGHT);
        return byTitle < byHeight ? byTitle.toFloat() : byHeight.toFloat();
    }

    // The mockup's top in an area this high: the mockup centered in the area's height (0 when it's
    // scaled to the height).
    static function top(height as Number) as Float {
        return ((height - HEIGHT * scale(height)) / 2).toFloat();
    }

    // The title's font: RobotoCondensedBold as high as the system glance font, which the native glances
    // write their titles in (bundled on the watches built with bundled fonts, BundledGlanceFonts); the
    // system glance font itself without either.
    static function titleFont() as Graphics.FontType {
        if (isVector()) {
            var font = Graphics.getVectorFont({:face => "RobotoCondensedBold",
                :size => Graphics.getFontHeight(Graphics.FONT_GLANCE)});
            if (font != null) {
                return font;
            }
        }
        var bundled = bundledTitle();
        return bundled != null ? bundled : Graphics.FONT_GLANCE;
    }

    // The first of lines that fits the line's width (lineWidth()) at size or smaller, down to three
    // quarters of it; the last one at three quarters when none does: its index in lines, its em size and
    // its font.
    static function fit(dc as Graphics.Dc, lines as Array<String>, size as Float) as [Number, Float, Graphics.FontType] {
        var smallest = size * 3 / 4;
        var width = lineWidth(dc);
        for (var i = 0; i < lines.size(); i++) {
            for (var em = size; em >= smallest; em -= 1) {
                var font = font(em);
                if (dc.getTextWidthInPixels(lines[i], font) <= width) {
                    return [i, em, font];
                }
                if (!isVector() && !hasBundled()) {
                    break;
                }
            }
        }
        return [lines.size() - 1, smallest, font(smallest)];
    }

    // RobotoCondensedBold at an em size in pixels (bundled on the watches built with bundled fonts); the
    // glance's system font without either (the FR265's first firmware, API 4.2.0).
    static function font(em as Float) as Graphics.FontType {
        if (isVector()) {
            var font = Graphics.getVectorFont({:face => "RobotoCondensedBold",
                :size => Math.round(em * LINE_HEIGHT).toNumber()});
            if (font != null) {
                return font;
            }
        }
        var bundled = bundledBold(em);
        return bundled != null ? bundled : Graphics.FONT_GLANCE;
    }

    // Whether the glance draws with vector fonts: never on the watches built with bundled fonts, the
    // Venu 3 and 3S included, whose vector API has no Roboto Condensed (Fonts.isVector()).
    (:noBundledFonts)
    static function isVector() as Boolean {
        return Graphics has :getVectorFont;
    }

    (:bundledFonts)
    static function isVector() as Boolean {
        return false;
    }

    // The bundled fonts, on the watches built with them (monkey.jungle); none on the others.
    (:bundledFonts)
    static function hasBundled() as Boolean {
        return true;
    }

    (:bundledFonts)
    static function bundledBold(em as Float) as Graphics.FontType? {
        return BundledGlanceFonts.bold(Math.round(em).toNumber());
    }

    (:bundledFonts)
    static function bundledTitle() as Graphics.FontType? {
        return BundledGlanceFonts.title(Graphics.getFontHeight(Graphics.FONT_GLANCE));
    }

    (:noBundledFonts)
    static function hasBundled() as Boolean {
        return false;
    }

    (:noBundledFonts)
    static function bundledBold(em as Float) as Graphics.FontType? {
        return null;
    }

    (:noBundledFonts)
    static function bundledTitle() as Graphics.FontType? {
        return null;
    }

    // The width the line may take from its left (lineLeft()): the area's, but on the Instinct 3 AMOLED,
    // whose glances keep a round window at the right of their strip, from x 251 of the 45 mm's 390 px
    // (268 of the 50 mm's 416), where the line is drawn: the line ends 6 px before it, at 64 % of the
    // area's width on both (205 of the 45 mm's 320 px, area from x 40; 222 of the 50 mm's 346).
    (:glanceWindow)
    static function lineWidth(dc as Graphics.Dc) as Number {
        return (dc.getWidth() * 0.64).toNumber() - lineLeft(dc);
    }

    (:noGlanceWindow)
    static function lineWidth(dc as Graphics.Dc) as Number {
        var limit = roundLimit(dc.getWidth(), dc.getHeight());
        return limit < dc.getWidth() ? limit : dc.getWidth();
    }

    // Where the line must end in an area this size: the area's width, but on the watches without UP and
    // DOWN (the Venu, vivoactive 5 and 6, D2 Air X10, Approach S50, S70 and S72). Their glance is drawn
    // at the top of the round screen and their areas reach its right edge or nearly, so the circle cuts
    // the area's right end at the line's height (a two-set line in French lost its last digit on the
    // Venu 2): there the line ends inside the circle at the top of its capitals (roundEnd()).
    (:scoreButtons)
    static function roundLimit(width as Number, height as Number) as Number {
        return width;
    }

    (:noScoreButtons)
    static function roundLimit(width as Number, height as Number) as Number {
        var origin = areaOrigin(width, height);
        if (origin == null) {
            return width;
        }
        var row = top(height) + (LINE_BASELINE - CAP_HEIGHT * LINE_SIZE) * scale(height);
        return roundEnd(System.getDeviceSettings().screenWidth, origin[0], origin[1], row);
    }

    // Where each of those watches' glance areas starts on its screen, x then y, by the area's size (their
    // device files' glance areas): the Venu 2, 2 Plus and D2 Air X10; the Venu 2S; the Venu 3; the Venu 3S,
    // vivoactive 5 and Approach S50; the Venu 4 41 mm; the Venu 4 45 mm and Approach S72 47 mm; the
    // vivoactive 6; the Approach S70 42 mm; the S70 47 mm; the S72 43 mm. Where two watches share a size,
    // the place higher and further right, where the circle cuts sooner. Null for another area.
    (:noScoreButtons)
    static function areaOrigin(width as Number, height as Number) as [Number, Number]? {
        var areas = [[288, 133, 128, 8], [249, 115, 111, 7], [303, 164, 140, 0], [260, 141, 120, 1], [274, 128, 97, 9],
            [318, 150, 114, 0], [274, 146, 97, 4], [248, 103, 112, 13], [274, 103, 112, 13], [292, 130, 104, 0]]
            as Array<Array<Number> >;
        for (var i = 0; i < areas.size(); i++) {
            if (areas[i][0] == width && areas[i][1] == height) {
                return [areas[i][2], areas[i][3]];
            }
        }
        return null;
    }

    // Where the round screen ends at the right of a row y pixels below an area's top, in the area's
    // pixels, 4 px inside the circle: the area's left at x0 and its top at y0 on a screen screenWidth
    // wide. From the screen's middle down, the circle's own right end.
    (:noScoreButtons)
    static function roundEnd(screenWidth as Number, x0 as Number, y0 as Number, y as Float) as Number {
        var radius = screenWidth / 2.0;
        var dy = radius - (y0 + y);
        var half = dy > 0 ? Math.sqrt(radius * radius - dy * dy) : radius;
        return Math.floor(radius + half - x0 - 4).toNumber();
    }

    // Where the line starts: past the round screen's edge at the top of its capitals (inset()).
    static function lineLeft(dc as Graphics.Dc) as Number {
        var height = dc.getHeight();
        return inset((top(height) + (LINE_BASELINE - LINE_SIZE) * scale(height)).toNumber());
    }

    // The Instinct 3 AMOLED's glance strip runs along the top of its round screen, from x 40 and y 16
    // (its device files' glance area, y 17 on the 50 mm): there the circle cuts the strip's left end, at
    // x 84 of the 45 mm's screen at the title's top. A text whose top is at y in the area starts 4 px
    // inside the circle; 0 elsewhere.
    (:glanceWindow)
    static function inset(y as Number) as Number {
        var radius = System.getDeviceSettings().screenWidth / 2.0;
        var dy = radius - (16 + y);
        var edge = dy > 0 ? radius - Math.sqrt(radius * radius - dy * dy) : 0.0;
        var inset = Math.ceil(edge - 40 + 4).toNumber();
        return inset > 0 ? inset : 0;
    }

    (:noGlanceWindow)
    static function inset(y as Number) as Number {
        return 0;
    }
}

import Toybox.Graphics;
import Toybox.Lang;

// What a text is, which picks its font.
enum FontStyle {
    // Digits and ": - . %" only (points, games, times, HR): the system number fonts are among
    // its fallbacks, and they have no letters. A score with letters ("AD") is STYLE_BOLD.
    STYLE_NUMBER = 0,
    // Caps labels, banners, captions, any text with letters.
    STYLE_BOLD = 1,
    // Secondary text.
    STYLE_REGULAR = 2
}

// Fonts by style and em size, loaded once and kept: a vector font is expensive to load, so never
// per frame. The FR265 and FR265S have RobotoCondensedBold (STYLE_NUMBER, STYLE_BOLD) and
// RobotoCondensedRegular (STYLE_REGULAR) as scalable fonts from API 4.2.1. Without them (the FR265
// launched with 4.2.0), each size falls back to the system font closest in height.
module Fonts {

    const FACE_BOLD = "RobotoCondensedBold";
    const FACE_REGULAR = "RobotoCondensedRegular";
    // Roboto's line height (ascent plus descent) per pixel of em size, 2400 / 2048 font units. Sizes
    // here are em sizes, like the mockups' SVG font-size; getVectorFont's :size is the line height
    // (measured in the simulator: :size 400 gives ascent 317, descent 83, and "0" 173 px wide).
    const LINE_HEIGHT = 1.1719;
    // Half the height of the capitals and digits per pixel of em size, 1456 / 2 / 2048.
    const CAP_MIDDLE = 0.3555;

    // Keyed by size * 3 + style.
    var _cache as Dictionary<Number, Graphics.FontType> = {};
    // false only in debug builds, to show the fallback (setVectorEnabled).
    var _vector as Boolean = true;

    // The font for a style at an em size in screen pixels (Layout.font() scales a mockup size).
    function get(style as FontStyle, size as Number) as Graphics.FontType {
        var key = size * 3 + style;
        var font = _cache[key];
        if (font == null) {
            font = load(style, size);
            _cache[key] = font;
        }
        return font;
    }

    // Whether get() loads vector fonts.
    function isVector() as Boolean {
        return _vector && (Graphics has :getVectorFont);
    }

    // Debug builds: false makes get() return the fallback fonts (design test screen, tests).
    (:debug)
    function setVectorEnabled(enabled as Boolean) as Void {
        _vector = enabled;
        _cache = {};
    }

    function load(style as FontStyle, size as Number) as Graphics.FontType {
        var height = lineHeight(size);
        if (isVector()) {
            var font = Graphics.getVectorFont({:face => style == STYLE_REGULAR ? FACE_REGULAR : FACE_BOLD,
                :size => height});
            if (font != null) {
                return font;
            }
        }
        var fonts = fallbacks(style);
        var heights = new Array<Number>[fonts.size()];
        for (var i = 0; i < fonts.size(); i++) {
            heights[i] = Graphics.getFontHeight(fonts[i]);
        }
        return fonts[nearest(height, heights)];
    }

    // The line height of an em size, getVectorFont's :size.
    function lineHeight(size as Number) as Number {
        return Layout.round(size * LINE_HEIGHT);
    }

    // The system fonts a style can fall back to, smallest first. The number fonts only have digits
    // and a few signs.
    function fallbacks(style as FontStyle) as Array<Graphics.FontDefinition> {
        var fonts = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM,
            Graphics.FONT_LARGE] as Array<Graphics.FontDefinition>;
        if (style == STYLE_NUMBER) {
            fonts.addAll([Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT,
                Graphics.FONT_NUMBER_THAI_HOT]);
        }
        return fonts;
    }

    // The index of the height closest to target, the smaller one on a tie.
    function nearest(target as Numeric, heights as Array<Number>) as Number {
        var best = 0;
        for (var i = 1; i < heights.size(); i++) {
            var gap = (heights[i] - target).abs();
            var bestGap = (heights[best] - target).abs();
            if (gap < bestGap || (gap == bestGap && heights[i] < heights[best])) {
                best = i;
            }
        }
        return best;
    }
}

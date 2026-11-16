import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Draws the design mockups on any screen straight from their numbers. The mockups are 480 px
// frames with the 416 px screen centered at (240, 240): a screen coordinate is the mockup's minus
// 32 on the FR265, scaled by width / 416 on other screens (360 / 416 on the FR265S). Every
// function takes the mockup's numbers: x() and y() convert positions, len(), pen() and font()
// convert sizes, and the drawing functions take positions and sizes as the SVG writes them, text
// placed by its baseline. Colors are set by the caller, except for the stroked shapes.
class Layout {

    static const MOCKUP_SIZE = 416;
    static const MOCKUP_OFFSET = 32;
    // What fillCircle() takes off a radius.
    static const CIRCLE_BIAS = 1.0;

    // The screen's width in pixels.
    var width as Number;
    // Screen pixels per mockup pixel.
    var scale as Float;

    function initialize(width as Number) {
        self.width = width;
        scale = width.toFloat() / MOCKUP_SIZE;
    }

    // The screen x of a mockup x.
    function x(mockupX as Numeric) as Number {
        return round((mockupX - MOCKUP_OFFSET) * scale);
    }

    // The screen y of a mockup y.
    function y(mockupY as Numeric) as Number {
        return round((mockupY - MOCKUP_OFFSET) * scale);
    }

    // A mockup length (size, radius, gap) on this screen.
    function len(mockupLength as Numeric) as Number {
        return round(mockupLength * scale);
    }

    // A mockup stroke width on this screen, at least 1 pixel.
    function pen(mockupWidth as Numeric) as Number {
        var width = len(mockupWidth);
        return width < 1 ? 1 : width;
    }

    // The font for a mockup font size (cached by Fonts).
    function font(style as FontStyle, mockupSize as Numeric) as Graphics.FontType {
        return Fonts.get(style, fontSize(mockupSize));
    }

    // A mockup font size in screen pixels, at least 1.
    function fontSize(mockupSize as Numeric) as Number {
        var size = len(mockupSize);
        return size < 1 ? 1 : size;
    }

    // Text as an SVG <text>: at the mockup's x, anchored by justify (TEXT_JUSTIFY_LEFT, CENTER or
    // RIGHT for text-anchor start, middle or end), with its baseline at the mockup's y.
    function drawText(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, style as FontStyle,
            mockupSize as Numeric, text as String, justify as Graphics.TextJustification) as Void {
        var textFont = font(style, mockupSize);
        dc.drawText(x(mockupX), textTop(textFont, mockupY, mockupSize), textFont, text, justify);
    }

    // The same with letter spacing, as the mockups' caps labels. Drawn one character at a time,
    // each placed by the width of the text before it so rounding doesn't add up: keep it to short
    // labels.
    function drawSpacedText(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, style as FontStyle,
            mockupSize as Numeric, mockupSpacing as Numeric, text as String,
            justify as Graphics.TextJustification) as Void {
        var textFont = font(style, mockupSize);
        var spacing = mockupSpacing * scale;
        var left = (mockupX - MOCKUP_OFFSET) * scale;
        if (justify != Graphics.TEXT_JUSTIFY_LEFT) {
            var width = spacedWidth(dc, textFont, text, spacing);
            left -= justify == Graphics.TEXT_JUSTIFY_CENTER ? width / 2.0 : width;
        }
        var top = textTop(textFont, mockupY, mockupSize);
        var chars = text.toCharArray();
        var before = "";
        for (var i = 0; i < chars.size(); i++) {
            var char = chars[i].toString();
            dc.drawText(round(left + dc.getTextWidthInPixels(before, textFont) + spacing * i), top, textFont, char,
                Graphics.TEXT_JUSTIFY_LEFT);
            before += char;
        }
    }

    // The width of text in mockup pixels with the font it gets on this screen, letter spacing
    // included but none after the last character (where SVG adds one).
    function textWidth(dc as Graphics.Dc, style as FontStyle, mockupSize as Numeric, text as String,
            mockupSpacing as Numeric) as Float {
        return spacedWidth(dc, font(style, mockupSize), text, mockupSpacing * scale) / scale;
    }

    // The mockup font size, or a smaller one down to three quarters of it, so text fits in maxWidth
    // (mockup pixels): for translations longer than the mockup's text.
    function fitSize(dc as Graphics.Dc, style as FontStyle, mockupSize as Number, text as String,
            mockupSpacing as Numeric, maxWidth as Numeric) as Number {
        var fitted = mockupSize;
        while (fitted > mockupSize * 3 / 4 && textWidth(dc, style, fitted, text, mockupSpacing) > maxWidth) {
            fitted--;
        }
        return fitted;
    }

    // In screen pixels.
    private function spacedWidth(dc as Graphics.Dc, font as Graphics.FontType, text as String,
            spacing as Numeric) as Float {
        var count = text.length();
        var width = dc.getTextWidthInPixels(text, font).toFloat();
        return count > 1 ? width + spacing.toFloat() * (count - 1) : width;
    }

    // The top of a text box with its baseline at the mockup's y. A fallback font bigger or smaller
    // than the mockup size keeps the middle of the caps where the mockup has it, so it grows both
    // ways instead of up from the baseline (the system fonts are Roboto too).
    private function textTop(font as Graphics.FontType, mockupY as Numeric, mockupSize as Numeric) as Number {
        var gap = Graphics.getFontHeight(font) / Fonts.LINE_HEIGHT - mockupSize * scale;
        return round((mockupY - MOCKUP_OFFSET) * scale - Graphics.getFontAscent(font) + Fonts.CAP_MIDDLE * gap);
    }

    // Shapes at mockup positions and sizes, in the current color. Rectangles take both edges from
    // x() and y(), so shapes that touch in the mockup still touch after rounding.

    function fillRect(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, mockupWidth as Numeric,
            mockupHeight as Numeric) as Void {
        var left = x(mockupX);
        var top = y(mockupY);
        dc.fillRectangle(left, top, x(mockupX + mockupWidth) - left, y(mockupY + mockupHeight) - top);
    }

    function fillRoundedRect(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, mockupWidth as Numeric,
            mockupHeight as Numeric, mockupRadius as Numeric) as Void {
        var left = x(mockupX);
        var top = y(mockupY);
        dc.fillRoundedRectangle(left, top, x(mockupX + mockupWidth) - left, y(mockupY + mockupHeight) - top,
            len(mockupRadius));
    }

    // A rounded rectangle filled with fill and outlined with stroke, the outline centered on the
    // edge like an SVG stroke. Two fills: they antialias more evenly than a wide pen.
    function fillStrokedRoundedRect(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric,
            mockupWidth as Numeric, mockupHeight as Numeric, mockupRadius as Numeric, fill as Number,
            stroke as Number, mockupStroke as Numeric) as Void {
        var half = mockupStroke / 2.0;
        dc.setColor(stroke, Graphics.COLOR_TRANSPARENT);
        fillRoundedRect(dc, mockupX - half, mockupY - half, mockupWidth + mockupStroke, mockupHeight + mockupStroke,
            mockupRadius + half);
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        fillRoundedRect(dc, mockupX + half, mockupY + half, mockupWidth - mockupStroke, mockupHeight - mockupStroke,
            mockupRadius - half);
    }

    // Connect IQ draws a circle of radius r about 2r + 2 pixels wide and ignores fractions of a
    // pixel (measured in the simulator), so the radius is one pixel less, rounded.
    function fillCircle(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, mockupRadius as Numeric) as Void {
        var radius = round(mockupRadius * scale - CIRCLE_BIAS);
        dc.fillCircle(x(mockupX), y(mockupY), radius < 1 ? 1 : radius);
    }

    // A circle filled with fill and outlined with stroke, centered on the edge like an SVG stroke.
    function fillStrokedCircle(dc as Graphics.Dc, mockupX as Numeric, mockupY as Numeric, mockupRadius as Numeric,
            fill as Number, stroke as Number, mockupStroke as Numeric) as Void {
        var half = mockupStroke / 2.0;
        dc.setColor(stroke, Graphics.COLOR_TRANSPARENT);
        fillCircle(dc, mockupX, mockupY, mockupRadius + half);
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        fillCircle(dc, mockupX, mockupY, mockupRadius - half);
    }

    // An arc around the screen center (240, 240 in the mockup), counterclockwise from degreeStart
    // to degreeEnd in Connect IQ degrees: 0 at 3 o'clock, 90 at 12. An SVG arc point (px, py) is at
    // atan2(240 - py, px - 240). Connect IQ truncates the angles, so they're rounded here.
    function drawArc(dc as Graphics.Dc, mockupRadius as Numeric, mockupStroke as Numeric, degreeStart as Numeric,
            degreeEnd as Numeric) as Void {
        dc.setPenWidth(pen(mockupStroke));
        dc.drawArc(width / 2, width / 2, len(mockupRadius), Graphics.ARC_COUNTER_CLOCKWISE, round(degreeStart),
            round(degreeEnd));
    }

    // The yellow hint by the START button (principle 6) as the mockups draw it: an arc of
    // radius 202, 6 wide, from 22° to 38°, with round ends. In the current color.
    function drawStartArc(dc as Graphics.Dc) as Void {
        drawArc(dc, 202, 6, 22, 38);
        var ends = [22, 38];
        for (var i = 0; i < ends.size(); i++) {
            var angle = Math.toRadians(ends[i]);
            fillCircle(dc, 240 + 202 * Math.cos(angle), 240 - 202 * Math.sin(angle), 3);
        }
    }

    // The width of the round screen (radius 208 around 240, 240) at a mockup y, in mockup pixels: 0
    // at and past the edge. For text that must stay inside the circle.
    static function chord(mockupY as Numeric) as Float {
        var radius = MOCKUP_SIZE / 2;
        var dy = (mockupY - MOCKUP_SIZE / 2 - MOCKUP_OFFSET).abs();
        return dy < radius ? (2 * Math.sqrt(radius * radius - dy * dy)).toFloat() : 0.0;
    }

    // Rounds to the nearest pixel, halves up.
    static function round(value as Numeric) as Number {
        return Math.floor(value + 0.5).toNumber();
    }
}

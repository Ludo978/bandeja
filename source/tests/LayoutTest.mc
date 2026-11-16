import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Layout: mockup numbers to screen pixels on the FR265 (416 px) and FR265S (360 px);
// fonts: vector fonts by em size, cached, and the system font fallback. The palette's
// tests are in PaletteTest.mc.

(:test)
function layoutScaleTest(logger as Logger) as Boolean {
    // The 416 px screen sits at 32..448 in the 480 px mockup frame: positions move by 32, sizes don't. The
    // 360 px one is scaled by 360 / 416 = 0.8654 around the same center: font sizes scale like lengths,
    // and pens never vanish. Halves round away from zero.
    var l = new Layout(416);
    Test.assert(l.x(32) == 0 && l.x(448) == 416 && l.y(240) == 208 && l.y(20) == -12);
    Test.assert(l.len(60) == 60 && l.pen(1.5) == 2 && l.fontSize(120) == 120);
    l = new Layout(360);
    Test.assert(l.x(32) == 0 && l.x(240) == 180 && l.y(448) == 360 && l.x(80) == 42 && l.y(210) == 154 && l.x(20) == -10);
    Test.assert(l.len(60) == 52 && l.len(14) == 12 && l.pen(8) == 7 && l.pen(1.5) == 1 && l.pen(0.5) == 1);
    Test.assert(l.fontSize(120) == 104 && l.fontSize(46) == 40 && l.fontSize(15) == 13 && l.fontSize(13) == 11 && l.fontSize(0.1) == 1);
    Test.assert(Layout.round(2.5) == 3 && Layout.round(2.49) == 2 && Layout.round(-0.5) == 0 && Layout.round(-10.6) == -11);
    return true;
}

(:test)
function layoutChordTest(logger as Logger) as Boolean {
    // The round screen's width at a mockup y: 416 through the center, 0 at and past the edge; the
    // bottom caption's baseline (427): 182 wide.
    TestKit.assertNear(Layout.chord(240), 416, 0.01);
    TestKit.assertNear(Layout.chord(32), 0, 0.01);
    TestKit.assertNear(Layout.chord(0), 0, 0.01);
    TestKit.assertNear(Layout.chord(427), 182.2, 0.1);
    TestKit.assertNear(Layout.chord(53), 182.2, 0.1);
    return true;
}

(:test)
function layoutTextWidthTest(logger as Logger) as Boolean {
    // In mockup pixels, with the font the screen gets, the width doesn't depend on the screen. The
    // mockups' widths from Roboto Condensed Bold's advances: "30" at 120 is 121.4, "BREAK POINT" at 16
    // is 89.4 plus 10 letter spacings of 2. No spacing after the last character, nor for one character.
    var dc = (Graphics.createBufferedBitmap({:width => 4, :height => 4}).get() as Graphics.BufferedBitmap).getDc();
    var l416 = new Layout(416);
    var l360 = new Layout(360);
    TestKit.assertNear(l416.textWidth(dc, STYLE_NUMBER, 120, "30", 0), 121.4, 2);
    TestKit.assertNear(l360.textWidth(dc, STYLE_NUMBER, 120, "30", 0), 121.4, 3);
    TestKit.assertNear(l416.textWidth(dc, STYLE_BOLD, 16, "BREAK POINT", 2), 109.4, 2);
    TestKit.assertNear(l360.textWidth(dc, STYLE_BOLD, 16, "BREAK POINT", 2), 109.4, 3);
    Test.assertEqual(l416.textWidth(dc, STYLE_BOLD, 16, "B", 2), l416.textWidth(dc, STYLE_BOLD, 16, "B", 0));
    Test.assertEqual(l416.textWidth(dc, STYLE_BOLD, 16, "", 2), 0.0);
    return true;
}

(:test)
function fontsTest(logger as Logger) as Boolean {
    // getVectorFont's :size is the line height, 2400 / 2048 of the em size. The fallback is the system
    // font nearest in line height (the FR265's, FONT_XTINY to FONT_NUMBER_THAI_HOT), a tie going to the
    // smaller font. Only numbers may use the number fonts, which have no letters.
    Test.assert(Fonts.lineHeight(120) == 141 && Fonts.lineHeight(104) == 122 && Fonts.lineHeight(16) == 19 && Fonts.lineHeight(1) == 1);
    var heights = [34, 43, 50, 58, 67, 95, 117, 140, 162] as Array<Number>;
    Test.assert(Fonts.nearest(141, heights) == 7 && Fonts.nearest(75, heights) == 4 && Fonts.nearest(18, heights) == 0);
    Test.assert(Fonts.nearest(500, heights) == 8 && Fonts.nearest(54, heights) == 2 && Fonts.nearest(10, [15, 5] as Array<Number>) == 1);
    var text = Fonts.fallbacks(STYLE_BOLD);
    Test.assert(text.size() == 5 && text.indexOf(Graphics.FONT_NUMBER_HOT) == -1 && Fonts.fallbacks(STYLE_REGULAR).size() == 5);
    var numbers = Fonts.fallbacks(STYLE_NUMBER);
    Test.assert(numbers.size() == 9 && numbers.indexOf(Graphics.FONT_NUMBER_HOT) >= 0 && numbers.indexOf(Graphics.FONT_NUMBER_THAI_HOT) >= 0);
    return true;
}

(:test)
function fontsVectorTest(logger as Logger) as Boolean {
    // The FR265 and FR265S simulators have the vector fonts: the mockup size is the em size, loaded once
    // per style and size. Without them, on this device's screen: the points get FONT_NUMBER_HOT,
    // the labels the smallest text font, and big text the biggest text font, never a number font.
    var l = new Layout(System.getDeviceSettings().screenWidth);
    var points = l.font(STYLE_NUMBER, 120);
    Test.assert(Fonts.isVector() && points instanceof Graphics.VectorFont);
    Test.assertEqual(Graphics.getFontHeight(points), Fonts.lineHeight(l.fontSize(120)));
    Test.assert(l.font(STYLE_NUMBER, 120) == points && l.font(STYLE_BOLD, 120) != points);
    Test.assert(l.font(STYLE_REGULAR, 120) != l.font(STYLE_BOLD, 120));
    Fonts.setVectorEnabled(false);
    try {
        Test.assert(!Fonts.isVector() && l.font(STYLE_NUMBER, 120) == Graphics.FONT_NUMBER_HOT);
        Test.assert(l.font(STYLE_BOLD, 15) == Graphics.FONT_XTINY && l.font(STYLE_REGULAR, 13) == Graphics.FONT_XTINY);
        Test.assertEqual(l.font(STYLE_BOLD, 120), Graphics.FONT_LARGE);
    } finally {
        Fonts.setVectorEnabled(true);
    }
    return true;
}

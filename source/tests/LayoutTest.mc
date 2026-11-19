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
    // On the FR265's 416 px and the FR265S's 360 px; where the fonts are bundled, on this watch's own
    // screen twice (BundledFonts holds the sizes of its screen size only: 360, 390 and 416, or 454 px),
    // the text's width taken at the whole em size the screen draws (at 454 px the 16 is 17.46 px, drawn
    // at 17: 3 % narrower).
    var dc = (Graphics.createBufferedBitmap({:width => 4, :height => 4}).get() as Graphics.BufferedBitmap).getDc();
    var own = System.getDeviceSettings().screenWidth;
    var l416 = new Layout(Fonts.isVector() ? 416 : own);
    var small = new Layout(Fonts.isVector() ? 360 : own);
    var digits = Fonts.isVector() ? 121.4 : 121.4 * l416.fontSize(120) / (120 * l416.scale);
    var label = Fonts.isVector() ? 109.4 : 89.4 * l416.fontSize(16) / (16 * l416.scale) + 20;
    TestKit.assertNear(l416.textWidth(dc, STYLE_NUMBER, 120, "30", 0), digits, 2);
    TestKit.assertNear(small.textWidth(dc, STYLE_NUMBER, 120, "30", 0), digits, 3);
    TestKit.assertNear(l416.textWidth(dc, STYLE_BOLD, 16, "BREAK POINT", 2), label, 2);
    TestKit.assertNear(small.textWidth(dc, STYLE_BOLD, 16, "BREAK POINT", 2), label, 3);
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
    // per style and size. Without them, on this device's screen: the points get the number font nearest
    // their line height (FONT_NUMBER_HOT on the FR265 and FR265S, FONT_NUMBER_MEDIUM on the fenix 9 Pro
    // 51 mm, whose number fonts are larger), the labels the smallest text font, and big text the biggest
    // text font, never a number font.
    if (!Fonts.isVector()) {
        // The watches built with bundled fonts, the Venu 3 and 3S too, which have the vector API but
        // not its Roboto Condensed faces (fontsBundledTest).
        return true;
    }
    var l = new Layout(System.getDeviceSettings().screenWidth);
    var points = l.font(STYLE_NUMBER, 120);
    Test.assert(Fonts.isVector() && points instanceof Graphics.VectorFont);
    Test.assertEqual(Graphics.getFontHeight(points), Fonts.lineHeight(l.fontSize(120)));
    Test.assert(l.font(STYLE_NUMBER, 120) == points && l.font(STYLE_BOLD, 120) != points);
    Test.assert(l.font(STYLE_REGULAR, 120) != l.font(STYLE_BOLD, 120));
    Fonts.setVectorEnabled(false);
    try {
        var numbers = Fonts.fallbacks(STYLE_NUMBER);
        var heights = [] as Array<Number>;
        for (var i = 0; i < numbers.size(); i++) {
            heights.add(Graphics.getFontHeight(numbers[i]));
        }
        var index = Fonts.nearest(Fonts.lineHeight(l.fontSize(120)), heights);
        Test.assert(!Fonts.isVector() && l.font(STYLE_NUMBER, 120) == numbers[index]);
        Test.assert(index >= Fonts.fallbacks(STYLE_BOLD).size());
        // The FR265's and FR265S's system fonts (their part numbers): other watches of those sizes, the
        // Approach S72 43 mm, have others.
        var part = System.getDeviceSettings().partNumber;
        if (part.equals("006-B4257-00") || part.equals("006-B4258-00")) {
            Test.assertEqual(numbers[index], Graphics.FONT_NUMBER_HOT);
        }
        Test.assert(l.font(STYLE_BOLD, 15) == Graphics.FONT_XTINY && l.font(STYLE_REGULAR, 13) == Graphics.FONT_XTINY);
        Test.assertEqual(l.font(STYLE_BOLD, 120), Graphics.FONT_LARGE);
    } finally {
        Fonts.setVectorEnabled(true);
    }
    return true;
}

(:test :bundledFonts)
function fontsBundledTest(logger as Logger) as Boolean {
    // The watches without Roboto Condensed vector fonts (Descent G2, Instinct 3 AMOLED, Venu 2, 2 Plus, 2S,
    // 3 and 3S, vivoactive 5, D2 Air X10, Approach S50) draw with the bundled Roboto Condensed of their
    // screen size, and never ask for a vector font, not even the Venu 3 and 3S, whose vector API has no
    // such face (getVectorFont gives null there): every mockup size the screens use (and the labels' down
    // to three quarters) gets a bundled size within a pixel of its em size on this screen, with the vector
    // fonts' line height, and never a system font. The full character set's French and team name letters
    // have glyphs, and so do the lower case letters at the mixed-case lines' sizes: the home screen's
    // format line (bold 21) and its second line (regular 16), the toast (bold 17), the warm-up's format
    // line (bold 16), and the glance's line at its size in this watch's glance area.
    Test.assert(!Fonts.isVector() && !BandejaGlance.isVector());
    var l = new Layout(System.getDeviceSettings().screenWidth);
    var dc = (Graphics.createBufferedBitmap({:width => 4, :height => 4}).get() as Graphics.BufferedBitmap).getDc();
    var uses = [[STYLE_BOLD, [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 26, 44, 104, 120]],
        [STYLE_NUMBER, [18, 24, 26, 30, 32, 46, 48, 56, 64, 96, 120]], [STYLE_REGULAR, [12, 16, 26]]] as Array<Array>;
    for (var u = 0; u < uses.size(); u++) {
        var style = uses[u][0] as FontStyle;
        var sizes = uses[u][1] as Array<Number>;
        for (var i = 0; i < sizes.size(); i++) {
            var size = l.fontSize(sizes[i]);
            var font = Fonts.get(style, size);
            // The system fonts are FontDefinition values, Numbers.
            Test.assertMessage(!(font instanceof Lang.Number), "system font at " + size);
            var height = Graphics.getFontHeight(font);
            Test.assertMessage((height - Fonts.lineHeight(size)).abs() <= 2, "height " + height + " at " + size);
        }
    }
    var label = Fonts.get(STYLE_BOLD, l.fontSize(12));
    var letters = "ÀÉÈÊÔÇŁŒÜßéèàçôł·";
    for (var i = 0; i < letters.length(); i++) {
        Test.assertMessage(dc.getTextWidthInPixels(letters.substring(i, i + 1) as String, label) > 0, letters.substring(i, i + 1) as String);
    }
    var glanceSize = BandejaGlance.LINE_SIZE * BandejaGlance.scale(GlanceTests.area()[1]);
    var glanceLine = BandejaGlance.font(glanceSize);
    var height = Graphics.getFontHeight(glanceLine);
    Test.assertMessage((height - Fonts.lineHeight(Layout.round(glanceSize))).abs() <= 2, "glance line " + height + " at " + glanceSize);
    var mixed = [Fonts.get(STYLE_BOLD, l.fontSize(21)), Fonts.get(STYLE_REGULAR, l.fontSize(16)), Fonts.get(STYLE_BOLD, l.fontSize(17)),
        Fonts.get(STYLE_BOLD, l.fontSize(16)), glanceLine] as Array<Graphics.FontType>;
    var lower = "abcdefghijklmnopqrstuvwxyzéèàçôœ";
    for (var f = 0; f < mixed.size(); f++) {
        for (var i = 0; i < lower.length(); i++) {
            var letter = lower.substring(i, i + 1) as String;
            Test.assertMessage(dc.getTextWidthInPixels(letter, mixed[f]) > 0, "font " + f + ": " + letter);
        }
    }
    return true;
}

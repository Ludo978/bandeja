import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// The palette: the three themes' team colors, ours first, their tints and
// flashes precomputed on black, the two colors of a theme apart in lightness (colorblind-safe), and the
// overlay's black text readable on each of them.

(:test)
function paletteThemesTest(logger as Logger) as Boolean {
    // Court cyan / orange (v1's, the default), Clay sand / terracotta, Grass green / violet: the first
    // color of each pair is ours. Each half's tint at 12 % and the point flash at 35 % are
    // the team color on black, channels apart, halves rounded up: Court's as the design writes them. Every
    // tint stays at 31 or less per channel, so the mini court's 60 % black over it is plain black.
    var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
    var colors = [[0x33C3FF, 0xFF7A33], [0xF5C26B, 0xD9532B], [0x7EE07A, 0xC084FC]];
    for (var i = 0; i < themes.size(); i++) {
        for (var team = 0; team < 2; team++) {
            var color = Palette.teamColor(themes[i], team as Team);
            var tint = Palette.teamTint(themes[i], team as Team);
            Test.assertEqual(color, colors[i][team]);
            Test.assertEqual(tint, Palette.onBlack(color, Palette.TINT_PERCENT));
            Test.assertEqual(Palette.teamFlash(themes[i], team as Team), Palette.onBlack(color, Palette.FLASH_PERCENT));
            Test.assert((tint >> 16) <= 31 && ((tint >> 8) & 0xFF) <= 31 && (tint & 0xFF) <= 31);
        }
    }
    Test.assert(Palette.teamColor(THEME_COURT, TEAM_US) == Palette.US && Palette.teamColor(THEME_COURT, TEAM_THEM) == Palette.THEM);
    Test.assert(Palette.teamTint(THEME_COURT, TEAM_US) == 0x06171F && Palette.teamTint(THEME_COURT, TEAM_THEM) == 0x1F0F06);
    Test.assert(Palette.teamFlash(THEME_COURT, TEAM_US) == 0x124459 && Palette.teamFlash(THEME_COURT, TEAM_THEM) == 0x592B12);
    // The mockups' other opacities (the net line, TEXT at 55 %); below zone 1, or no zones: no zone color.
    Test.assert(Palette.onBlack(Palette.TEXT, 55) == 0x87888A && Palette.onBlack(0xFFFFFF, 50) == 0x808080 && Palette.onBlack(0x0000FF, 100) == 0x0000FF);
    Test.assert(Palette.hrZoneColor(0) == Palette.INACTIVE && Palette.hrZoneColor(6) == Palette.INACTIVE && Palette.hrZoneColor(5) != Palette.INACTIVE);
    return true;
}

(:test)
function paletteLightnessTest(logger as Logger) as Boolean {
    // A theme's two team colors differ in lightness, not only in hue, so they stay apart without
    // their hue (a red-green colorblind player, a grey view of the overlay in sunlight). CIELAB
    // lightness L* (0 black to 100 white, perceptually even): at least LIGHTNESS_APART between them,
    // over three times the just-noticeable difference (about 2.3), and Court's own gap, the v1 pair
    // (8.1): no theme is closer than it. Clay is 28.3 apart, Grass 15.8.
    var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
    var gaps = [8.1, 28.3, 15.8];
    for (var i = 0; i < themes.size(); i++) {
        var gap = (PaletteTests.lightness(Palette.teamColor(themes[i], TEAM_US))
            - PaletteTests.lightness(Palette.teamColor(themes[i], TEAM_THEM))).abs();
        Test.assertMessage(gap >= PaletteTests.LIGHTNESS_APART, "theme " + i + ": " + gap);
        Test.assertMessage((gap - gaps[i]).abs() < 0.1, "theme " + i + ": " + gap);
    }
    // The measure itself: black 0, white 100, mid grey about 53.6.
    Test.assert(PaletteTests.lightness(0x000000) < 0.01 && (PaletteTests.lightness(0xFFFFFF) - 100).abs() < 0.01);
    Test.assert((PaletteTests.lightness(0x808080) - 53.6).abs() < 0.1);
    return true;
}

(:test)
function paletteOverlayContrastTest(logger as Logger) as Boolean {
    // The game, set and match overlay and the games tiles write black on the full team
    // color: in every theme black reads at WCAG AA's 4.5:1 for text at least (terracotta, the darkest,
    // is 5.2:1) and better than white would (4.0:1 on terracotta), so no theme takes white text. The
    // overlay's context line, black at 60 % (the team color at 40 %), stays at 3:1 at least (3.2:1 on
    // terracotta, 4.0:1 on Court's orange).
    var themes = [THEME_COURT, THEME_CLAY, THEME_GRASS] as Array<ThemeSetting>;
    for (var i = 0; i < themes.size(); i++) {
        for (var team = 0; team < 2; team++) {
            var color = Palette.teamColor(themes[i], team as Team);
            var black = PaletteTests.contrast(color, Palette.BG);
            Test.assertMessage(black >= 4.5 && black > PaletteTests.contrast(color, 0xFFFFFF), "theme " + i + " team " + team);
            Test.assertMessage(PaletteTests.contrast(color, Palette.onBlack(color, Palette.OVERLAY_DIM_PERCENT)) >= 3.0,
                "theme " + i + " team " + team);
        }
    }
    // The measure itself: white on black 21:1, a color on itself 1:1.
    Test.assert((PaletteTests.contrast(0xFFFFFF, 0x000000) - 21).abs() < 0.01 && PaletteTests.contrast(0xD9532B, 0xD9532B) == 1.0);
    return true;
}

(:test)
module PaletteTests {

    // The least CIELAB lightness between a theme's two team colors (paletteLightnessTest).
    const LIGHTNESS_APART = 8;

    // A color's relative luminance (WCAG 2): its sRGB channels made linear, weighted.
    function luminance(color as Number) as Float {
        return 0.2126 * linear((color >> 16) & 0xFF) + 0.7152 * linear((color >> 8) & 0xFF) + 0.0722 * linear(color & 0xFF);
    }

    function linear(channel as Number) as Float {
        var c = channel / 255.0;
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4).toFloat();
    }

    // CIELAB L*, from 0 (black) to 100 (white).
    function lightness(color as Number) as Float {
        var y = luminance(color);
        return y > 0.008856 ? 116 * Math.pow(y, 1 / 3.0).toFloat() - 16 : 903.3 * y;
    }

    // The WCAG 2 contrast ratio of two colors, from 1 to 21.
    function contrast(a as Number, b as Number) as Float {
        var la = luminance(a);
        var lb = luminance(b);
        return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }
}

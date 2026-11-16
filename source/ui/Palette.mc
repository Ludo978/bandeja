import Toybox.Lang;

// The app's palette, as 0xRRGGBB. The ground is pure black, so a color at p % opacity is
// simply the color scaled by p: tints are precomputed opaque colors, never alpha blending. The team
// colors come from the Theme setting: Court (v1's), Clay or Grass, the first color of
// each pair ours; yellow, the greys and the HR zones are the same in every theme.
module Palette {

    const BG = 0x000000;
    const TEXT = 0xF5F7FA;      // points, values
    const MUTED = 0x8B9099;     // labels, secondary info
    const LINE = 0x2C2F35;      // dividers
    const US = 0x33C3FF;        // our team (Court theme): cyan
    const THEM = 0xFF7A33;      // the opponents (Court theme): orange
    const BALL = 0xD7F34A;      // serve ball, START hint, key banners, court time
    const INACTIVE = 0x3A3D44;  // HR zone segments that aren't the current zone

    // HR zones 1 to 5.
    const HR_ZONE_1 = 0x9AA0A6;
    const HR_ZONE_2 = 0x3B82F6;
    const HR_ZONE_3 = 0x22C55E;
    const HR_ZONE_4 = 0xF59E0B;
    const HR_ZONE_5 = 0xEF4444;

    // Each team's half during play, the point flash on the scoring team's half, and the
    // overlay's context line, black at 60 % over the team color.
    const TINT_PERCENT = 12;
    const FLASH_PERCENT = 35;
    const OVERLAY_DIM_PERCENT = 40;

    // Each theme's team colors, their tints (12 %) and their flashes (35 %), indexed by
    // theme * 2 + team (ThemeSetting, Team): Court cyan / orange, Clay sand / terracotta, Grass
    // green / violet. The Momentum chart in Garmin Connect keeps Court's cyan (fitcontributions.xml).
    const TEAM_COLORS = [US, THEM, 0xF5C26B, 0xD9532B, 0x7EE07A, 0xC084FC] as Array<Number>;
    const TEAM_TINTS = [0x06171F, 0x1F0F06, 0x1D170D, 0x1A0A05, 0x0F1B0F, 0x17101E] as Array<Number>;
    const TEAM_FLASHES = [0x124459, 0x592B12, 0x564425, 0x4C1D0F, 0x2C4E2B, 0x432E58] as Array<Number>;

    function teamColor(theme as ThemeSetting, team as Team) as Number {
        return TEAM_COLORS[(theme as Number) * 2 + (team as Number)];
    }

    function teamTint(theme as ThemeSetting, team as Team) as Number {
        return TEAM_TINTS[(theme as Number) * 2 + (team as Number)];
    }

    function teamFlash(theme as ThemeSetting, team as Team) as Number {
        return TEAM_FLASHES[(theme as Number) * 2 + (team as Number)];
    }

    // The color of HR zone 1 to 5; INACTIVE for anything else (below zone 1, or no zones).
    function hrZoneColor(zone as Number) as Number {
        if (zone == 1) {
            return HR_ZONE_1;
        } else if (zone == 2) {
            return HR_ZONE_2;
        } else if (zone == 3) {
            return HR_ZONE_3;
        } else if (zone == 4) {
            return HR_ZONE_4;
        } else if (zone == 5) {
            return HR_ZONE_5;
        }
        return INACTIVE;
    }

    // The opaque color of color at percent % opacity over black, each channel rounded. For the
    // mockups' other opacities (the net line is TEXT at 55 %), worked out once, not per frame.
    function onBlack(color as Number, percent as Number) as Number {
        var r = ((color >> 16) & 0xFF) * percent;
        var g = ((color >> 8) & 0xFF) * percent;
        var b = (color & 0xFF) * percent;
        return (((r + 50) / 100) << 16) | (((g + 50) / 100) << 8) | ((b + 50) / 100);
    }
}

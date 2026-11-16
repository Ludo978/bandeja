import Toybox.Lang;
import Toybox.WatchUi;

// The format in words, for the home screen (mockup "Home"), the menus and the warm-up
// screen: "Best of 3 · Star point", then "Indoor · no GPS".
module FormatText {

    const SEPARATOR = " · ";

    // The sets (a preset name, or Custom) and the deuce mode; Tie-break only alone, as it plays no game
    // for a deuce mode to apply to.
    function line(config as MatchConfig) as String {
        var sets = text(presetName(config.getPreset()));
        return config.isTieBreakOnly() ? sets : sets + SEPARATOR + text(deuceModeName(config.deuceMode));
    }

    // Indoor or outdoor, after Timed for a timed match, and before that Singles or Mixed when the
    // match isn't plain doubles (mixed means nothing in singles).
    function detailLine(config as MatchConfig, outdoor as Boolean, timed as Boolean) as String {
        var line = text(courtName(outdoor));
        if (timed) {
            line = text(Rez.Strings.Timed) + SEPARATOR + line;
        }
        if (!config.doubles) {
            return text(Rez.Strings.Singles) + SEPARATOR + line;
        } else if (config.mixed) {
            return text(Rez.Strings.Mixed) + SEPARATOR + line;
        }
        return line;
    }

    function presetName(preset as Preset) as ResourceId {
        if (preset == PRESET_BEST_OF_3) {
            return Rez.Strings.PresetBestOf3;
        } else if (preset == PRESET_BEST_OF_3_SUPER_TB) {
            return Rez.Strings.PresetBestOf3SuperTb;
        } else if (preset == PRESET_ONE_SET) {
            return Rez.Strings.PresetOneSet;
        } else if (preset == PRESET_PRO_SET) {
            return Rez.Strings.PresetProSet;
        } else if (preset == PRESET_SHORT_SETS) {
            return Rez.Strings.PresetShortSets;
        } else if (preset == PRESET_BEST_OF_5) {
            return Rez.Strings.PresetBestOf5;
        } else if (preset == PRESET_TIE_BREAK_7) {
            return Rez.Strings.PresetTieBreak7;
        } else if (preset == PRESET_TIE_BREAK_10) {
            return Rez.Strings.PresetTieBreak10;
        } else if (preset == PRESET_FREE_PLAY) {
            return Rez.Strings.PresetFreePlay;
        }
        return Rez.Strings.PresetCustom;
    }

    function deuceModeName(mode as DeuceMode) as ResourceId {
        if (mode == DEUCE_ADVANTAGE) {
            return Rez.Strings.DeuceAdvantage;
        } else if (mode == DEUCE_GOLDEN) {
            return Rez.Strings.DeuceGolden;
        } else if (mode == DEUCE_SILVER) {
            return Rez.Strings.DeuceSilver;
        }
        return Rez.Strings.DeuceStar;
    }

    // The Custom menu's Sets choices, with the preset names where they say the same.
    function setsName(choice as SetsChoice) as ResourceId {
        if (choice == SETS_ONE) {
            return Rez.Strings.PresetOneSet;
        } else if (choice == SETS_BEST_OF_3) {
            return Rez.Strings.PresetBestOf3;
        } else if (choice == SETS_BEST_OF_3_SUPER_TB) {
            return Rez.Strings.PresetBestOf3SuperTb;
        } else if (choice == SETS_BEST_OF_5) {
            return Rez.Strings.PresetBestOf5;
        }
        return Rez.Strings.SetsBestOf5SuperTb;
    }

    // "At 6-6", "At 5-5" or "None", from the format's N.
    function tieBreakName(config as MatchConfig, choice as TieBreakChoice) as String {
        if (choice == TIE_BREAK_NONE) {
            return text(Rez.Strings.TieBreakNone);
        }
        var games = choice == TIE_BREAK_AT_N ? config.gamesToWin : config.gamesToWin - 1;
        return Lang.format(text(Rez.Strings.TieBreakAt), [games]);
    }

    // "7 points".
    function tieBreakPointsName(points as Number) as String {
        return Lang.format(text(Rez.Strings.TieBreakPoints), [points]);
    }

    function playersName(doubles as Boolean) as ResourceId {
        return doubles ? Rez.Strings.Doubles : Rez.Strings.Singles;
    }

    function courtName(outdoor as Boolean) as ResourceId {
        return outdoor ? Rez.Strings.CourtOutdoor : Rez.Strings.CourtIndoor;
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

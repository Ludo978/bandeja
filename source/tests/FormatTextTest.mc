import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The Format menu: what Custom offers within its limits, what the other
// format items change, every choice leaving a valid format; and the format as the home screen and the
// menus write it (mockup "Home"): "Best of 3 · Star point", then "Indoor · no GPS",
// checked against the string resources, and word for word when the simulator is in English.

(:test)
function formatChoicesSetsTest(logger as Logger) as Boolean {
    // Sets to win and the final super tie-break go together, so no choice is invalid, and the rest of
    // the format stays. The Sets item lists the presets in menu order (short sets and best of 5 after
    // the pro set, then Tie-break only to 7 and to 10, then Free play), then Custom; the deuce modes in
    // menu order.
    var expected = [[SETS_ONE, 1, false], [SETS_BEST_OF_3, 2, false], [SETS_BEST_OF_3_SUPER_TB, 2, true], [SETS_BEST_OF_5, 3, false],
        [SETS_BEST_OF_5_SUPER_TB, 3, true]];
    var choices = FormatChoices.setsChoices();
    Test.assertEqual(choices.size(), expected.size());
    for (var i = 0; i < expected.size(); i++) {
        var choice = expected[i][0] as SetsChoice;
        var config = TestKit.custom();
        FormatChoices.setSets(config, choice);
        Test.assertMessage(choices[i] == choice && config.setsToWin == expected[i][1] && config.superTieBreak == expected[i][2]
            && FormatChoices.getSets(config) == choice && config.isValid(), "choice " + i);
        Test.assert(config.gamesToWin == 4 && config.tieBreakAt == 3 && config.deuceMode == DEUCE_GOLDEN);
    }
    Test.assertEqual(FormatChoices.presetChoices().toString(), [PRESET_BEST_OF_3, PRESET_BEST_OF_3_SUPER_TB, PRESET_ONE_SET,
        PRESET_PRO_SET, PRESET_SHORT_SETS, PRESET_BEST_OF_5, PRESET_TIE_BREAK_7, PRESET_TIE_BREAK_10, PRESET_FREE_PLAY,
        PRESET_CUSTOM].toString());
    Test.assertEqual(FormatChoices.deuceModeChoices().toString(), TestKit.MODES.toString());
    return true;
}

(:test)
function formatChoicesGamesAndTieBreakTest(logger as Logger) as Boolean {
    // N from 2 to 10 (the Custom limits). Changing N keeps the tie-break where it was: at N-N or at
    // (N-1)-(N-1); with no tie-break, its place is kept for when it comes back. Tie-break length:
    // 7 or 10.
    var games = FormatChoices.gamesChoices();
    Test.assert(games.size() == 9 && games[0] == MatchConfig.GAMES_TO_WIN_MIN && games[8] == MatchConfig.GAMES_TO_WIN_MAX);
    var config = new MatchConfig();
    Test.assertEqual(FormatChoices.getTieBreak(config), TIE_BREAK_AT_N);
    FormatChoices.setGames(config, 4);
    Test.assert(config.tieBreakAt == 4 && FormatChoices.getTieBreak(config) == TIE_BREAK_AT_N);
    FormatChoices.setTieBreak(config, TIE_BREAK_AT_N_MINUS_1);
    Test.assert(config.tieBreakAt == 3 && FormatChoices.getTieBreak(config) == TIE_BREAK_AT_N_MINUS_1);
    FormatChoices.setGames(config, 9);
    Test.assertEqual(config.tieBreakAt, 8);
    FormatChoices.setGames(config, 2);
    Test.assert(config.tieBreakAt == 1 && config.isValid());
    FormatChoices.setTieBreak(config, TIE_BREAK_NONE);
    FormatChoices.setGames(config, 6);
    Test.assert(!config.hasTieBreak && config.tieBreakAt == 5 && FormatChoices.getTieBreak(config) == TIE_BREAK_NONE);
    FormatChoices.setTieBreak(config, TIE_BREAK_AT_N);
    Test.assert(config.hasTieBreak && config.tieBreakAt == 6);
    Test.assertEqual(FormatChoices.tieBreakPointsChoices().toString(), [7, 10].toString());
    return true;
}

(:test)
function formatChoicesAlwaysValidTest(logger as Logger) as Boolean {
    // Every combination the Custom menu can reach is a valid format.
    var sets = FormatChoices.setsChoices();
    var games = FormatChoices.gamesChoices();
    var points = FormatChoices.tieBreakPointsChoices();
    var tieBreaks = [TIE_BREAK_AT_N, TIE_BREAK_AT_N_MINUS_1, TIE_BREAK_NONE];
    var config = new MatchConfig();
    for (var s = 0; s < sets.size(); s++) {
        FormatChoices.setSets(config, sets[s]);
        for (var g = 0; g < games.size(); g++) {
            FormatChoices.setGames(config, games[g]);
            for (var t = 0; t < tieBreaks.size(); t++) {
                FormatChoices.setTieBreak(config, tieBreaks[t] as TieBreakChoice);
                for (var p = 0; p < points.size(); p++) {
                    config.tieBreakPoints = points[p];
                    Test.assertMessage(config.isValid() && FormatChoices.getSets(config) == sets[s]
                        && FormatChoices.getTieBreak(config) == tieBreaks[t], config.toDictionary().toString());
                }
            }
        }
    }
    return true;
}

(:test)
function formatChoicesCopyStructureTest(logger as Logger) as Boolean {
    // Custom brings back its sets, games and tie-breaks; the deuce mode, singles or doubles and mixed
    // stay as picked, as with a preset, which then replaces the structure and keeps the rest too.
    var custom = TestKit.custom();
    var config = new MatchConfig();
    config.deuceMode = DEUCE_SILVER;
    FormatChoices.copyStructure(config, custom);
    var structure = config.copy();
    structure.deuceMode = custom.deuceMode;
    structure.doubles = custom.doubles;
    structure.mixed = custom.mixed;
    Test.assert(structure.equals(custom) && config.deuceMode == DEUCE_SILVER && config.doubles && !config.mixed);
    Test.assertEqual(config.getPreset(), PRESET_CUSTOM);
    config.applyPreset(PRESET_PRO_SET);
    Test.assert(config.getPreset() == PRESET_PRO_SET && config.deuceMode == DEUCE_SILVER);
    return true;
}

(:test)
function formatChoicesCustomEqualToPresetTest(logger as Logger) as Boolean {
    // A custom format the Custom menu makes equal to a preset takes the preset's name:
    // Best of 3 sets of 4 games, the tie-break at 4-4, is Short sets; Best of 5 sets of 6, at 6-6, is
    // Best of 5; the Format menu's Sets item and the home line then name the preset. The tie-break at
    // 3-3 (Fast4) or to 10 points keeps them Custom.
    var config = TestKit.custom();
    FormatChoices.setSets(config, SETS_BEST_OF_3);
    FormatChoices.setGames(config, 4);
    FormatChoices.setTieBreak(config, TIE_BREAK_AT_N_MINUS_1);
    config.tieBreakPoints = 7;
    Test.assertEqual(config.getPreset(), PRESET_CUSTOM);
    FormatChoices.setTieBreak(config, TIE_BREAK_AT_N);
    Test.assertEqual(config.getPreset(), PRESET_SHORT_SETS);
    Test.assertEqual(FormatText.line(config), FormatTextTests.text(Rez.Strings.PresetShortSets) + " · "
        + FormatTextTests.text(Rez.Strings.DeuceGolden));
    FormatChoices.setSets(config, SETS_BEST_OF_5);
    FormatChoices.setGames(config, 6);
    Test.assertEqual(config.getPreset(), PRESET_BEST_OF_5);
    Test.assertEqual(FormatText.presetName(config.getPreset()), FormatText.setsName(FormatChoices.getSets(config)));
    config.tieBreakPoints = 10;
    Test.assertEqual(config.getPreset(), PRESET_CUSTOM);
    // A preset picked in the Sets list is the Custom menu's choices too.
    config.applyPreset(PRESET_SHORT_SETS);
    Test.assert(FormatChoices.getSets(config) == SETS_BEST_OF_3 && config.gamesToWin == 4
        && FormatChoices.getTieBreak(config) == TIE_BREAK_AT_N && config.tieBreakPoints == 7);
    config.applyPreset(PRESET_BEST_OF_5);
    Test.assert(FormatChoices.getSets(config) == SETS_BEST_OF_5 && config.gamesToWin == 6
        && FormatChoices.getTieBreak(config) == TIE_BREAK_AT_N && config.tieBreakPoints == 7);
    return true;
}

(:test)
function formatChoicesCustomFromTieBreakOnlyTest(logger as Logger) as Boolean {
    // Custom brings back the last custom structure, or the format's own the first time, but
    // never Tie-break only, which the Custom menu has no choice for (its Sets are 1 set, best of 3 or 5,
    // the last two with or without a super tie-break): from Tie-break only, the first Custom is one set
    // (to 7: the 1 set preset's structure, so its name; to 10, one set with tie-breaks to 10, Custom).
    // The deuce mode, singles and mixed stay.
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    config.deuceMode = DEUCE_SILVER;
    FormatChoices.startCustom(config, null);
    Test.assert(!config.isTieBreakOnly() && FormatChoices.getSets(config) == SETS_ONE && config.getPreset() == PRESET_ONE_SET
        && config.deuceMode == DEUCE_SILVER && config.isValid());
    config = TestKit.preset(PRESET_TIE_BREAK_10);
    FormatChoices.startCustom(config, null);
    Test.assert(!config.isTieBreakOnly() && FormatChoices.getSets(config) == SETS_ONE && config.getPreset() == PRESET_CUSTOM
        && config.tieBreakPoints == 10);
    config = TestKit.preset(PRESET_TIE_BREAK_10);
    FormatChoices.startCustom(config, TestKit.custom());
    var structure = TestKit.custom();
    structure.deuceMode = config.deuceMode;
    structure.doubles = config.doubles;
    structure.mixed = config.mixed;
    Test.assert(config.equals(structure));
    // From Free play, which the Custom menu has no choice for either: a best of 3 of its sets of
    // 6, the Best of 3 preset's structure; a Custom kept comes back as it was.
    config = TestKit.preset(PRESET_FREE_PLAY);
    config.deuceMode = DEUCE_GOLDEN;
    FormatChoices.startCustom(config, null);
    Test.assert(!config.isFreePlay() && FormatChoices.getSets(config) == SETS_BEST_OF_3 && config.getPreset() == PRESET_BEST_OF_3
        && config.deuceMode == DEUCE_GOLDEN && config.isValid());
    config = TestKit.preset(PRESET_FREE_PLAY);
    FormatChoices.startCustom(config, TestKit.custom());
    Test.assert(FormatChoices.getSets(config) == SETS_BEST_OF_5_SUPER_TB && config.gamesToWin == 4);
    // Any other format starts Custom as it is.
    config = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    FormatChoices.startCustom(config, null);
    Test.assert(config.equals(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB)));
    return true;
}

(:test)
function formatTextNamesTest(logger as Logger) as Boolean {
    // The names of the presets, the deuce modes, the Custom menu's sets (the preset names where they say
    // the same), the players and the court.
    var presets = [PRESET_BEST_OF_3, PRESET_BEST_OF_3_SUPER_TB, PRESET_ONE_SET, PRESET_PRO_SET, PRESET_SHORT_SETS,
        PRESET_BEST_OF_5, PRESET_TIE_BREAK_7, PRESET_TIE_BREAK_10, PRESET_FREE_PLAY, PRESET_CUSTOM];
    var names = [Rez.Strings.PresetBestOf3, Rez.Strings.PresetBestOf3SuperTb, Rez.Strings.PresetOneSet, Rez.Strings.PresetProSet,
        Rez.Strings.PresetShortSets, Rez.Strings.PresetBestOf5, Rez.Strings.PresetTieBreak7, Rez.Strings.PresetTieBreak10,
        Rez.Strings.PresetFreePlay, Rez.Strings.PresetCustom];
    for (var i = 0; i < presets.size(); i++) {
        Test.assertEqual(FormatText.presetName(presets[i]), names[i]);
    }
    names = [Rez.Strings.DeuceAdvantage, Rez.Strings.DeuceGolden, Rez.Strings.DeuceStar, Rez.Strings.DeuceSilver];
    for (var i = 0; i < names.size(); i++) {
        Test.assertEqual(FormatText.deuceModeName(TestKit.MODES[i] as DeuceMode), names[i]);
    }
    var sets = [SETS_ONE, SETS_BEST_OF_3, SETS_BEST_OF_3_SUPER_TB, SETS_BEST_OF_5, SETS_BEST_OF_5_SUPER_TB];
    names = [Rez.Strings.PresetOneSet, Rez.Strings.PresetBestOf3, Rez.Strings.PresetBestOf3SuperTb, Rez.Strings.PresetBestOf5,
        Rez.Strings.SetsBestOf5SuperTb];
    for (var i = 0; i < sets.size(); i++) {
        Test.assertEqual(FormatText.setsName(sets[i]), names[i]);
    }
    Test.assert(FormatText.playersName(true) == Rez.Strings.Doubles && FormatText.playersName(false) == Rez.Strings.Singles);
    Test.assert(FormatText.courtName(false) == Rez.Strings.CourtIndoor && FormatText.courtName(true) == Rez.Strings.CourtOutdoor);
    return true;
}

(:test)
function formatTextLinesTest(logger as Logger) as Boolean {
    // The first line: the sets (preset name, or Custom) and the deuce mode; Tie-break only alone, with
    // no game for a deuce mode to apply to. The second: Indoor or outdoor, after Singles or
    // Mixed when the match isn't plain doubles, and Timed for a timed match, in that order;
    // Mixed means nothing in singles, so it isn't shown there.
    var config = TestKit.preset(PRESET_PRO_SET);
    config.deuceMode = DEUCE_GOLDEN;
    Test.assertEqual(FormatText.line(config), FormatTextTests.text(Rez.Strings.PresetProSet) + " · " + FormatTextTests.text(Rez.Strings.DeuceGolden));
    Test.assertEqual(FormatText.line(TestKit.custom()), FormatTextTests.text(Rez.Strings.PresetCustom) + " · "
        + FormatTextTests.text(Rez.Strings.DeuceGolden));
    config = TestKit.preset(PRESET_TIE_BREAK_7);
    config.deuceMode = DEUCE_GOLDEN;
    Test.assertEqual(FormatText.line(config), FormatTextTests.text(Rez.Strings.PresetTieBreak7));
    Test.assertEqual(FormatText.line(TestKit.preset(PRESET_TIE_BREAK_10)), FormatTextTests.text(Rez.Strings.PresetTieBreak10));
    var indoor = FormatTextTests.text(Rez.Strings.CourtIndoor);
    var outdoor = FormatTextTests.text(Rez.Strings.CourtOutdoor);
    var timed = FormatTextTests.text(Rez.Strings.Timed) + " · ";
    var mixed = FormatTextTests.text(Rez.Strings.Mixed) + " · ";
    var singles = FormatTextTests.text(Rez.Strings.Singles) + " · ";
    config = new MatchConfig();
    Test.assert(FormatText.detailLine(config, true, false).equals(outdoor) && FormatText.detailLine(config, false, true).equals(timed + indoor));
    config.mixed = true;
    Test.assert(FormatText.detailLine(config, false, false).equals(mixed + indoor) && FormatText.detailLine(config, false, true).equals(mixed + timed + indoor));
    config.doubles = false;
    Test.assert(FormatText.detailLine(config, true, false).equals(singles + outdoor) && FormatText.detailLine(config, true, true).equals(singles + timed + outdoor));
    if (System.getDeviceSettings().systemLanguage == System.LANGUAGE_ENG) {
        Test.assertEqual(FormatText.line(new MatchConfig()), "Best of 3 · Star point");
        Test.assertEqual(FormatText.line(TestKit.preset(PRESET_SHORT_SETS)), "Short sets · Star point");
        Test.assertEqual(FormatText.line(TestKit.preset(PRESET_BEST_OF_5)), "Best of 5 · Star point");
        Test.assertEqual(FormatText.line(TestKit.preset(PRESET_TIE_BREAK_7)), "Tie-break to 7");
        Test.assertEqual(FormatText.line(TestKit.preset(PRESET_TIE_BREAK_10)), "Tie-break to 10");
        Test.assertEqual(FormatText.line(TestKit.preset(PRESET_FREE_PLAY)), "Free play · Star point");
        Test.assertEqual(FormatText.detailLine(new MatchConfig(), false, false), "Indoor · no GPS");
        Test.assertEqual(FormatText.detailLine(new MatchConfig(), true, false), "Outdoor · GPS");
        Test.assertEqual(FormatText.detailLine(new MatchConfig(), false, true), "Timed · Indoor · no GPS");
        // The Custom menu's tie-break item: where it's played, or none.
        Test.assertEqual(FormatText.tieBreakName(new MatchConfig(), TIE_BREAK_AT_N), "At 6-6");
        Test.assertEqual(FormatText.tieBreakName(new MatchConfig(), TIE_BREAK_AT_N_MINUS_1), "At 5-5");
        Test.assertEqual(FormatText.tieBreakName(new MatchConfig(), TIE_BREAK_NONE), "None");
        Test.assertEqual(FormatText.tieBreakPointsName(10), "10 points");
    }
    return true;
}

(:test)
module FormatTextTests {

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

import Toybox.Lang;
import Toybox.Test;

// MatchConfig and presets: set model, presets and first-launch default,
// deuce modes and the mixed flag, singles/doubles, stored form.

(:test)
function matchConfigPresetsTest(logger as Logger) as Boolean {
    // The first-launch default is Best of 3, Star point, doubles, not mixed. The presets in menu order
    // (Custom isn't a structure, so it isn't listed), each applied over another structure: sets to
    // win, N, T, the final super tie-break and the sets played, tie-breaks to 7, recognized as that
    // preset; short sets are the FIP's best of 3 to 4 games, a tie-break at 4-4, best of 5 sets
    // of 6 with a tie-break at 6-6. A preset sets the sets and tie-breaks only: deuce mode,
    // singles/doubles and mixed are free. Tie-break only and Free play, the last three, have their own
    // tests (FreePlayTest.mc for Free play).
    var config = new MatchConfig();
    Test.assert(config.getPreset() == PRESET_BEST_OF_3 && config.deuceMode == DEUCE_STAR && config.doubles && !config.mixed);
    var presets = MatchConfig.presets();
    var expected = [[2, 6, 6, false, 3], [2, 6, 6, true, 3], [1, 6, 6, false, 1], [1, 9, 8, false, 1], [2, 4, 4, false, 3],
        [3, 6, 6, false, 5]];
    Test.assertEqual(presets.toString(), [PRESET_BEST_OF_3, PRESET_BEST_OF_3_SUPER_TB, PRESET_ONE_SET, PRESET_PRO_SET,
        PRESET_SHORT_SETS, PRESET_BEST_OF_5, PRESET_TIE_BREAK_7, PRESET_TIE_BREAK_10, PRESET_FREE_PLAY].toString());
    for (var i = 0; i < expected.size(); i++) {
        config = TestKit.custom();
        config.applyPreset(presets[i]);
        var e = expected[i];
        Test.assertMessage(config.setsToWin == e[0] && config.gamesToWin == e[1] && config.tieBreakAt == e[2]
            && config.hasTieBreak && config.tieBreakPoints == 7 && config.superTieBreak == e[3] && config.maxSets() == e[4]
            && config.isSuperTieBreakSet((e[4] as Number) - 1) == e[3] && !config.isSuperTieBreakSet(0), "preset " + i);
        Test.assert(config.isValid() && config.getPreset() == presets[i]);
        Test.assert(config.deuceMode == DEUCE_GOLDEN && !config.doubles && config.mixed);
        // A super tie-break with sets before it is to 10, whatever the tie-breaks' length.
        Test.assert(!config.isTieBreakOnly() && config.superTieBreakPoints() == 10);
        config.tieBreakPoints = 10;
        Test.assert(config.superTieBreakPoints() == 10 && !config.isGameWon(GAME_SUPER_TIE_BREAK, 7, 5)
            && config.isGameWon(GAME_SUPER_TIE_BREAK, 10, 8));
    }
    Test.assertEqual(MatchConfig.SUPER_TIE_BREAK_POINTS, 10);
    return true;
}

(:test)
function matchConfigTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only is stored as one set to win with the super tie-break flag, its
    // length the tie-break length: Tie-break to 7 and Tie-break to 10, the presets after Best of 5.
    // Applied over any structure, it sets those three and keeps the rest: the games and the tie-break at
    // T-T don't apply to it, so they don't change the preset either; the deuce mode, singles and
    // mixed are free, as with any preset. Its super tie-break is to 7 or 10, win by two, where a best of
    // 3's stays to 10. A one-set format with a super tie-break, invalid before, is this format.
    var presets = [PRESET_TIE_BREAK_7, PRESET_TIE_BREAK_10];
    var lengths = [7, 10];
    var bases = [new MatchConfig(), TestKit.custom(), TestKit.preset(PRESET_PRO_SET), TestKit.preset(PRESET_BEST_OF_3_SUPER_TB)];
    for (var i = 0; i < presets.size(); i++) {
        var length = lengths[i];
        for (var b = 0; b < bases.size(); b++) {
            var before = bases[b];
            var config = before.copy();
            config.applyPreset(presets[i]);
            var message = "preset " + i + ", base " + b;
            Test.assertMessage(config.setsToWin == 1 && config.superTieBreak && config.tieBreakPoints == length
                && config.gamesToWin == before.gamesToWin && config.tieBreakAt == before.tieBreakAt
                && config.hasTieBreak == before.hasTieBreak && config.deuceMode == before.deuceMode
                && config.doubles == before.doubles && config.mixed == before.mixed, message);
            Test.assertMessage(config.isValid() && config.isTieBreakOnly() && config.getPreset() == presets[i]
                && config.superTieBreakPoints() == length && config.maxSets() == 1 && config.isSuperTieBreakSet(0), message);
            Test.assertMessage(config.isGameWon(GAME_SUPER_TIE_BREAK, length, length - 2)
                && !config.isGameWon(GAME_SUPER_TIE_BREAK, length, length - 1)
                && !config.isGameWon(GAME_SUPER_TIE_BREAK, length - 1, 0)
                && config.isGameWon(GAME_SUPER_TIE_BREAK, length + 3, length + 1)
                && !config.isGameWon(GAME_SUPER_TIE_BREAK, length + 3, length + 2), message + ": length");
            // Stored and read back: the same format, the same preset.
            var loaded = MatchConfig.fromDictionary(config.toDictionary());
            Test.assertMessage(loaded != null && (loaded as MatchConfig).equals(config)
                && (loaded as MatchConfig).getPreset() == presets[i], message + ": stored");
            // The other length is the other preset; another preset brings its own structure back.
            config.tieBreakPoints = lengths[1 - i];
            Test.assertMessage(config.getPreset() == presets[1 - i], message + ": other length");
            config.applyPreset(PRESET_ONE_SET);
            Test.assertMessage(config.getPreset() == PRESET_ONE_SET && !config.isTieBreakOnly(), message + ": 1 set");
        }
    }
    // One set with the flag, made field by field as a format stored now: Tie-break only; one field away,
    // another format (the flag off: 1 set, or Custom with tie-breaks to 10; more sets: a super tie-break
    // to 10).
    var oneSet = TestKit.format(1, 4, 3, false);
    oneSet.superTieBreak = true;
    Test.assert(oneSet.isValid() && oneSet.getPreset() == PRESET_TIE_BREAK_7);
    oneSet.tieBreakPoints = 10;
    Test.assert(oneSet.getPreset() == PRESET_TIE_BREAK_10);
    var other = oneSet.copy();
    other.superTieBreak = false;
    Test.assert(other.getPreset() == PRESET_CUSTOM && !other.isTieBreakOnly());
    other = TestKit.preset(PRESET_TIE_BREAK_7);
    other.superTieBreak = false;
    Test.assert(other.getPreset() == PRESET_ONE_SET);
    other = oneSet.copy();
    other.setsToWin = 2;
    Test.assert(other.getPreset() == PRESET_CUSTOM && !other.isTieBreakOnly() && other.superTieBreakPoints() == 10);
    // As this version stores them: one set to win, the flag, the length; the fields that don't apply as
    // the format had them.
    var stored = [[7, 6, 6, true, PRESET_TIE_BREAK_7], [10, 6, 6, true, PRESET_TIE_BREAK_10], [10, 4, 3, false, PRESET_TIE_BREAK_10]];
    for (var i = 0; i < stored.size(); i++) {
        var data = TestKit.storedBestOf3();
        data.put("setsToWin", 1);
        data.put("superTieBreak", true);
        data.put("tieBreakPoints", stored[i][0]);
        data.put("gamesToWin", stored[i][1]);
        data.put("tieBreakAt", stored[i][2]);
        data.put("hasTieBreak", stored[i][3]);
        var loaded = MatchConfig.fromDictionary(data);
        Test.assertMessage(loaded != null && (loaded as MatchConfig).getPreset() == stored[i][4]
            && (loaded as MatchConfig).superTieBreakPoints() == stored[i][0] && (loaded as MatchConfig).deuceMode == DEUCE_STAR,
            "stored " + i);
    }
    // Formats stored by earlier versions load as before: Best of 3, and a best of 3 with a super tie-break
    // and tie-breaks to 10, whose super tie-break stays to 10.
    Test.assert(new MatchConfig().equals(MatchConfig.fromDictionary(TestKit.storedBestOf3())));
    var data = TestKit.storedBestOf3();
    data.put("superTieBreak", true);
    data.put("tieBreakPoints", 10);
    var loaded = MatchConfig.fromDictionary(data) as MatchConfig;
    Test.assert(loaded.getPreset() == PRESET_CUSTOM && !loaded.isTieBreakOnly() && loaded.superTieBreakPoints() == 10
        && loaded.maxSets() == 3 && loaded.isSuperTieBreakSet(2));
    return true;
}

(:test)
function matchConfigCustomTest(logger as Logger) as Boolean {
    // Any set structure that matches no preset is Custom, Fast4 included. Applying Custom keeps the
    // current values; applying a preset brings its structure back.
    var changes = [[6, 5, true, 7], [6, 6, false, 7], [6, 6, true, 10], [4, 3, true, 7]];
    for (var i = 0; i < changes.size(); i++) {
        var config = new MatchConfig();
        config.gamesToWin = changes[i][0] as Number;
        config.tieBreakAt = changes[i][1] as Number;
        config.hasTieBreak = changes[i][2] as Boolean;
        config.tieBreakPoints = changes[i][3] as Number;
        Test.assertMessage(config.isValid() && config.getPreset() == PRESET_CUSTOM, "change " + i);
        var before = config.copy();
        config.applyPreset(PRESET_CUSTOM);
        Test.assert(config.equals(before));
        config.applyPreset(PRESET_BEST_OF_3);
        Test.assertEqual(config.getPreset(), PRESET_BEST_OF_3);
    }
    var oneSet = TestKit.preset(PRESET_ONE_SET);
    oneSet.tieBreakAt = 5;
    Test.assertEqual(oneSet.getPreset(), PRESET_CUSTOM);
    return true;
}

(:test)
function matchConfigCustomTakesPresetNameTest(logger as Logger) as Boolean {
    // A preset is recognized from the set structure alone, so a custom format equal to
    // one takes its name: short sets and best of 5 made field by field, as the Custom menu and the
    // engine's earlier versions made them, with any deuce mode, singles or mixed. One field away and
    // they are Custom again: a tie-break at 3-3 (Fast4) or none, tie-breaks to 10, a final super
    // tie-break, another N or another number of sets. A format stored before these presets loads as
    // the preset its structure is.
    var shortSets = TestKit.format(2, 4, 4, true);
    var bestOf5 = TestKit.format(3, 6, 6, true);
    var configs = [shortSets, bestOf5];
    var presets = [PRESET_SHORT_SETS, PRESET_BEST_OF_5];
    for (var i = 0; i < configs.size(); i++) {
        var config = configs[i];
        for (var mode = DEUCE_ADVANTAGE; mode <= DEUCE_SILVER; mode++) {
            config.deuceMode = mode as DeuceMode;
            config.doubles = mode % 2 == 0;
            config.mixed = mode >= DEUCE_STAR;
            Test.assertMessage(config.getPreset() == presets[i], "preset " + i + ", mode " + mode);
            var loaded = MatchConfig.fromDictionary(config.toDictionary());
            Test.assertMessage(loaded != null && (loaded as MatchConfig).getPreset() == presets[i], "stored " + i);
        }
        var changes = [[0, config.gamesToWin - 1], [1, false], [2, 10], [3, true], [4, config.gamesToWin + 1]];
        for (var c = 0; c < changes.size(); c++) {
            var other = config.copy();
            var field = changes[c][0] as Number;
            var value = changes[c][1];
            if (field == 0) {
                other.tieBreakAt = value as Number;
            } else if (field == 1) {
                other.hasTieBreak = value as Boolean;
            } else if (field == 2) {
                other.tieBreakPoints = value as Number;
            } else if (field == 3) {
                other.superTieBreak = value as Boolean;
            } else {
                other.gamesToWin = value as Number;
                other.tieBreakAt = value as Number;
            }
            Test.assertMessage(other.isValid() && other.getPreset() == PRESET_CUSTOM, "preset " + i + ", change " + c);
        }
    }
    // Another number of sets: sets to 4 games in one set or a best of 5 are Custom; sets of 6 in one
    // set or a best of 3 are those presets.
    var sets = [[shortSets, 1, PRESET_CUSTOM], [shortSets, 3, PRESET_CUSTOM], [bestOf5, 1, PRESET_ONE_SET],
        [bestOf5, 2, PRESET_BEST_OF_3]];
    for (var i = 0; i < sets.size(); i++) {
        var other = (sets[i][0] as MatchConfig).copy();
        other.setsToWin = sets[i][1] as Number;
        Test.assertMessage(other.isValid() && other.getPreset() == sets[i][2], "sets " + i);
    }
    // As the first versions stored a custom best of 5 (Advantage, doubles).
    var stored = MatchConfig.fromDictionary({"setsToWin" => 3, "gamesToWin" => 6, "tieBreakAt" => 6, "hasTieBreak" => true,
        "tieBreakPoints" => 7, "superTieBreak" => false, "deuceMode" => 0, "doubles" => true, "mixed" => false});
    Test.assert(stored != null && (stored as MatchConfig).getPreset() == PRESET_BEST_OF_5);
    return true;
}

(:test)
function matchConfigValidityTest(logger as Logger) as Boolean {
    // T = N or T = N - 1, tie-break to 7 or 10, with or without a tie-break and a final
    // super tie-break; every deuce mode, singles and doubles, mixed or not. Beyond the Custom limits: 1
    // to 3 sets to win, N from 2 to 10. One set with a super tie-break is Tie-break only; no set
    // to win, Free play, only with its own structure.
    var valid = [TestKit.format(2, 6, 6, true), TestKit.format(1, 9, 8, true), TestKit.format(3, 4, 4, true),
        TestKit.format(2, 4, 3, false), TestKit.format(1, 2, 2, true), TestKit.format(2, 10, 9, true), TestKit.custom(),
        TestKit.preset(PRESET_TIE_BREAK_7), TestKit.preset(PRESET_TIE_BREAK_10), TestKit.preset(PRESET_FREE_PLAY)];
    for (var i = 0; i < valid.size(); i++) {
        for (var mode = DEUCE_ADVANTAGE; mode <= DEUCE_SILVER; mode++) {
            valid[i].deuceMode = mode as DeuceMode;
            valid[i].tieBreakPoints = valid[i].isFreePlay() ? 7 : 7 + 3 * (mode % 2);
            Test.assertMessage(valid[i].isValid(), "valid " + i + ", mode " + mode);
        }
    }
    var invalid = [[2, 6, 7], [2, 6, 4], [2, 6, 0], [2, 9, 7], [2, 4, 2], [2, 4, 5], [-1, 6, 6], [4, 6, 6], [2, 1, 1], [2, 11, 11],
        [0, 4, 4], [0, 6, 5]];
    for (var i = 0; i < invalid.size(); i++) {
        var config = new MatchConfig();
        config.setsToWin = invalid[i][0] as Number;
        config.gamesToWin = invalid[i][1] as Number;
        config.tieBreakAt = invalid[i][2] as Number;
        Test.assertMessage(!config.isValid(), "invalid " + invalid[i]);
        config.hasTieBreak = false;
        Test.assertMessage(!config.isValid(), "invalid with no tie-break " + invalid[i]);
    }
    var values = [[0, 0], [0, 5], [0, 8], [0, 11], [1, -1], [1, 4], [2, 0], [2, 4]];
    for (var i = 0; i < values.size(); i++) {
        var config = new MatchConfig();
        var value = values[i][1] as Number;
        if (values[i][0] == 0) {
            config.tieBreakPoints = value;
        } else if (values[i][0] == 1) {
            config.deuceMode = value as DeuceMode;
        } else {
            config.setsToWin = value;
            config.superTieBreak = true;
        }
        Test.assertMessage(!config.isValid(), "invalid " + values[i]);
    }
    return true;
}

(:test)
function matchConfigStoredFormTest(logger as Logger) as Boolean {
    // Every preset with every deuce mode, singles or doubles, mixed or not, and a custom format, go
    // through the stored form and back unchanged; equals() and copy() see every field. Formats stored
    // by earlier versions must keep loading: the keys and values are fixed, unknown keys (written by a
    // later version) are ignored.
    var presets = MatchConfig.presets();
    for (var i = 0; i < 4 * presets.size() + 1; i++) {
        var config = TestKit.custom();
        if (i < 4 * presets.size()) {
            config.applyPreset(presets[i / 4]);
            config.deuceMode = (i % 4) as DeuceMode;
            config.doubles = i % 3 != 0;
            config.mixed = i % 2 == 0;
        }
        var loaded = MatchConfig.fromDictionary(config.toDictionary());
        Test.assertMessage(loaded != null && (loaded as MatchConfig).equals(config), "format " + i);
    }
    var custom = TestKit.custom();
    var copy = custom.copy();
    copy.mixed = false;
    Test.assert(!copy.equals(custom) && custom.mixed && !custom.equals(null) && !custom.equals("config"));
    Test.assert(new MatchConfig().equals(MatchConfig.fromDictionary(TestKit.storedBestOf3())));
    var data = TestKit.storedBestOf3();
    data.put("courtEnd", 1290);
    Test.assert(MatchConfig.fromDictionary(data) != null);
    return true;
}

(:test)
function matchConfigRejectsInvalidStoredDataTest(logger as Logger) as Boolean {
    // Not a dictionary, a key missing, a value of the wrong type, or a format that fails validation:
    // null, so the first-launch default is used.
    var bad = [null, 2, "Best of 3", [2, 6, 6], {}] as Array<Object?>;
    var numbers = ["setsToWin", "gamesToWin", "tieBreakAt", "tieBreakPoints", "deuceMode"];
    var badNumbers = [null, true, "6", 6.0, 6l];
    var booleans = ["hasTieBreak", "superTieBreak", "doubles", "mixed"];
    var badBooleans = [null, 1, 0, "true"];
    var badValues = [["setsToWin", -1], ["setsToWin", 4], ["gamesToWin", 11], ["tieBreakAt", 4], ["tieBreakAt", 7],
        ["tieBreakPoints", 8], ["deuceMode", -1], ["deuceMode", 4]];
    for (var i = 0; i < numbers.size() + booleans.size(); i++) {
        var key = i < numbers.size() ? numbers[i] : booleans[i - numbers.size()];
        var values = i < numbers.size() ? badNumbers : badBooleans;
        var data = TestKit.storedBestOf3();
        data.remove(key);
        bad.add(data);
        for (var j = 0; j < values.size(); j++) {
            data = TestKit.storedBestOf3();
            data.put(key, values[j]);
            bad.add(data);
        }
    }
    for (var i = 0; i < badValues.size(); i++) {
        var data = TestKit.storedBestOf3();
        data.put(badValues[i][0] as String, badValues[i][1]);
        bad.add(data);
    }
    for (var i = 0; i < bad.size(); i++) {
        Test.assertMessage(MatchConfig.fromDictionary(bad[i]) == null, "loaded " + bad[i]);
    }
    return true;
}

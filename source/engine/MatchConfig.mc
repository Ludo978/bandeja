import Toybox.Application;
import Toybox.Lang;

// Rule at 40-40. The values are stored: never renumber.
enum DeuceMode {
    DEUCE_ADVANTAGE = 0, // unlimited deuces, win by two
    DEUCE_GOLDEN = 1,    // the next point at 40-40 wins the game
    DEUCE_STAR = 2,      // advantage at deuce 1 and 2, deciding point at deuce 3
    DEUCE_SILVER = 3     // advantage at deuce 1, deciding point at deuce 2
}

// Match format presets. PRESET_CUSTOM is any set structure no preset matches.
// A new preset gets the next number, a place in presets() and its structure in applyPreset().
enum Preset {
    PRESET_CUSTOM = 0,
    PRESET_BEST_OF_3 = 1,
    PRESET_BEST_OF_3_SUPER_TB = 2,
    PRESET_ONE_SET = 3,
    PRESET_PRO_SET = 4,
    PRESET_SHORT_SETS = 5,
    PRESET_BEST_OF_5 = 6,
    PRESET_TIE_BREAK_7 = 7,
    PRESET_TIE_BREAK_10 = 8,
    PRESET_FREE_PLAY = 9
}

// The match format. A preset sets the set structure (sets, games, tie-breaks); the deuce mode,
// singles/doubles and mixed go with any preset. Fields are public so menus can edit a copy,
// then check isValid().
class MatchConfig {

    // The final set's super tie-break, when the match has more sets (Tie-break only plays its one set
    // to the tie-break's length: superTieBreakPoints()).
    static const SUPER_TIE_BREAK_POINTS = 10;
    // Limits for a custom format.
    static const SETS_TO_WIN_MAX = 3;
    static const GAMES_TO_WIN_MIN = 2;
    static const GAMES_TO_WIN_MAX = 10;

    // Defaults: the first-launch format, Best of 3, Star Point, doubles, not mixed.
    // Sets needed to win the match: 1 (one set), 2 (best of 3), 3 (best of 5), or 0 for Free play, which
    // has no end: its sets go on until End match (isFreePlay()).
    var setsToWin as Number = 2;
    // N: a set is won with N or more games and a 2-game lead.
    var gamesToWin as Number = 6;
    // T: the tie-break is played at T-T. T = N or T = N - 1.
    var tieBreakAt as Number = 6;
    // False: no tie-break, sets are won by two games with no limit. tieBreakAt and
    // tieBreakPoints keep valid values and are ignored.
    var hasTieBreak as Boolean = true;
    // Tie-break length, 7 or 10, win by two; also Tie-break only's length.
    var tieBreakPoints as Number = 7;
    // The final set is a super tie-break: to SUPER_TIE_BREAK_POINTS with 2 sets to win or more; with
    // one set, the match is Tie-break only, that set played as one tie-break to tieBreakPoints
    // (superTieBreakPoints()).
    var superTieBreak as Boolean = false;
    // Mode the match starts with; a mid-match change is an event and applies from the next game.
    var deuceMode as DeuceMode = DEUCE_STAR;
    var doubles as Boolean = true;
    // Mixed doubles: the deciding point caption reads SAME SEX RECEIVES. Ignored in singles.
    var mixed as Boolean = false;

    // The presets in menu order, Custom excluded.
    static function presets() as Array<Preset> {
        return [PRESET_BEST_OF_3, PRESET_BEST_OF_3_SUPER_TB, PRESET_ONE_SET, PRESET_PRO_SET, PRESET_SHORT_SETS,
            PRESET_BEST_OF_5, PRESET_TIE_BREAK_7, PRESET_TIE_BREAK_10, PRESET_FREE_PLAY];
    }

    // Sets the preset's set structure and keeps the other fields. PRESET_CUSTOM changes nothing.
    // Tie-break only (to 7 or 10) is one set to win played as a super tie-break of the tie-break's
    // length: its games and tie-break at T-T don't apply, so they are kept as they are. Free play is
    // no set to win, sets of 6 with a tie-break at 6-6.
    function applyPreset(preset as Preset) as Void {
        if (preset == PRESET_BEST_OF_3) {
            setStructure(2, 6, 6, false);
        } else if (preset == PRESET_BEST_OF_3_SUPER_TB) {
            setStructure(2, 6, 6, true);
        } else if (preset == PRESET_ONE_SET) {
            setStructure(1, 6, 6, false);
        } else if (preset == PRESET_PRO_SET) {
            setStructure(1, 9, 8, false);
        } else if (preset == PRESET_SHORT_SETS) {
            // FIP short sets: best of 3 sets to 4 games, the tie-break at 4-4.
            setStructure(2, 4, 4, false);
        } else if (preset == PRESET_BEST_OF_5) {
            setStructure(3, 6, 6, false);
        } else if (preset == PRESET_TIE_BREAK_7 || preset == PRESET_TIE_BREAK_10) {
            setsToWin = 1;
            superTieBreak = true;
            tieBreakPoints = preset == PRESET_TIE_BREAK_7 ? 7 : 10;
        } else if (preset == PRESET_FREE_PLAY) {
            setStructure(0, 6, 6, false);
        }
    }

    // The preset whose set structure this is, or PRESET_CUSTOM.
    function getPreset() as Preset {
        var presets = MatchConfig.presets();
        for (var i = 0; i < presets.size(); i++) {
            var candidate = copy();
            candidate.applyPreset(presets[i]);
            if (candidate.equals(self)) {
                return presets[i];
            }
        }
        return PRESET_CUSTOM;
    }

    // Free play (no set to win) has one structure, its preset's: sets of 6, a tie-break at 6-6 to 7, no
    // super tie-break, so it is never Custom.
    function isValid() as Boolean {
        return setsToWin >= 0 && setsToWin <= SETS_TO_WIN_MAX
            && gamesToWin >= GAMES_TO_WIN_MIN && gamesToWin <= GAMES_TO_WIN_MAX
            && (tieBreakAt == gamesToWin || tieBreakAt == gamesToWin - 1)
            && (tieBreakPoints == 7 || tieBreakPoints == 10)
            && deuceMode >= DEUCE_ADVANTAGE && deuceMode <= DEUCE_SILVER
            && (setsToWin > 0 || (gamesToWin == 6 && tieBreakAt == 6 && hasTieBreak && tieBreakPoints == 7 && !superTieBreak));
    }

    // Most sets the match can last: 3 for best of 3. Free play has no limit: 0.
    function maxSets() as Number {
        return isFreePlay() ? 0 : 2 * setsToWin - 1;
    }

    // The match has no end: games and sets count, and only End match ends it, with no match
    // point.
    function isFreePlay() as Boolean {
        return setsToWin == 0;
    }

    // A team with this many sets has won the match; never in Free play.
    function winsMatch(sets as Number) as Boolean {
        return setsToWin > 0 && sets >= setsToWin;
    }

    // The match is one tie-break: one set to win, played as a super tie-break.
    function isTieBreakOnly() as Boolean {
        return setsToWin == 1 && superTieBreak;
    }

    // The super tie-break's length: 10, or the tie-break's (7 or 10) when the match is Tie-break only.
    function superTieBreakPoints() as Number {
        return isTieBreakOnly() ? tieBreakPoints : SUPER_TIE_BREAK_POINTS;
    }

    // Whether set setIndex (0 = first set) is played as a super tie-break.
    function isSuperTieBreakSet(setIndex as Number) as Boolean {
        return superTieBreak && setIndex == maxSets() - 1;
    }

    // Whether a game of this type is won with these points against the other team's: its length
    // (4, the tie-break's or the super tie-break's) and a 2-point lead. A deciding point aside.
    function isGameWon(type as GameType, points as Number, otherPoints as Number) as Boolean {
        var length = 4;
        if (type == GAME_TIE_BREAK) {
            length = tieBreakPoints;
        } else if (type == GAME_SUPER_TIE_BREAK) {
            length = superTieBreakPoints();
        }
        return points >= length && points - otherPoints >= 2;
    }

    // Whether a set is won with these games against the other team's: N or more and a 2-game lead.
    // A set won in its tie-break aside.
    function isSetWon(games as Number, otherGames as Number) as Boolean {
        return games >= gamesToWin && games - otherGames >= 2;
    }

    function copy() as MatchConfig {
        var other = new MatchConfig();
        other.setsToWin = setsToWin;
        other.gamesToWin = gamesToWin;
        other.tieBreakAt = tieBreakAt;
        other.hasTieBreak = hasTieBreak;
        other.tieBreakPoints = tieBreakPoints;
        other.superTieBreak = superTieBreak;
        other.deuceMode = deuceMode;
        other.doubles = doubles;
        other.mixed = mixed;
        return other;
    }

    function equals(other as Object?) as Boolean {
        if (other instanceof MatchConfig) {
            return setsToWin == other.setsToWin
                && gamesToWin == other.gamesToWin
                && tieBreakAt == other.tieBreakAt
                && hasTieBreak == other.hasTieBreak
                && tieBreakPoints == other.tieBreakPoints
                && superTieBreak == other.superTieBreak
                && deuceMode == other.deuceMode
                && doubles == other.doubles
                && mixed == other.mixed;
        }
        return false;
    }

    // Plain form for Application.Storage: the field names as keys, numbers and booleans as values.
    function toDictionary() as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType> {
        return {
            "setsToWin" => setsToWin,
            "gamesToWin" => gamesToWin,
            "tieBreakAt" => tieBreakAt,
            "hasTieBreak" => hasTieBreak,
            "tieBreakPoints" => tieBreakPoints,
            "superTieBreak" => superTieBreak,
            "deuceMode" => deuceMode as Number,
            "doubles" => doubles,
            "mixed" => mixed
        };
    }

    // Reads toDictionary()'s form; null when data is missing, mistyped or invalid. Unknown keys
    // are ignored. A key added later must be optional with a default, so stored formats still load.
    static function fromDictionary(data as Object?) as MatchConfig? {
        if (!(data instanceof Dictionary)) {
            return null;
        }
        var numberKeys = ["setsToWin", "gamesToWin", "tieBreakAt", "tieBreakPoints", "deuceMode"];
        for (var i = 0; i < numberKeys.size(); i++) {
            if (!(data.get(numberKeys[i]) instanceof Number)) {
                return null;
            }
        }
        var booleanKeys = ["hasTieBreak", "superTieBreak", "doubles", "mixed"];
        for (var i = 0; i < booleanKeys.size(); i++) {
            if (!(data.get(booleanKeys[i]) instanceof Boolean)) {
                return null;
            }
        }
        var config = new MatchConfig();
        config.setsToWin = data.get("setsToWin") as Number;
        config.gamesToWin = data.get("gamesToWin") as Number;
        config.tieBreakAt = data.get("tieBreakAt") as Number;
        config.hasTieBreak = data.get("hasTieBreak") as Boolean;
        config.tieBreakPoints = data.get("tieBreakPoints") as Number;
        config.superTieBreak = data.get("superTieBreak") as Boolean;
        config.deuceMode = data.get("deuceMode") as DeuceMode;
        config.doubles = data.get("doubles") as Boolean;
        config.mixed = data.get("mixed") as Boolean;
        return config.isValid() ? config : null;
    }

    // Every preset but Tie-break only plays tie-breaks to 7.
    private function setStructure(sets as Number, games as Number, tieBreakAtGames as Number,
            superTieBreakFinal as Boolean) as Void {
        setsToWin = sets;
        gamesToWin = games;
        tieBreakAt = tieBreakAtGames;
        hasTieBreak = true;
        tieBreakPoints = 7;
        superTieBreak = superTieBreakFinal;
    }
}

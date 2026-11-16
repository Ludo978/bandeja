import Toybox.Lang;

// The Custom menu's Sets item: sets to win and a final super tie-break together,
// so no choice is invalid (a super tie-break needs at least 2 sets to win).
enum SetsChoice {
    SETS_ONE,
    SETS_BEST_OF_3,
    SETS_BEST_OF_3_SUPER_TB,
    SETS_BEST_OF_5,
    SETS_BEST_OF_5_SUPER_TB
}

// The Custom menu's Tie-break item: at N-N, at (N-1)-(N-1), or none.
enum TieBreakChoice {
    TIE_BREAK_AT_N,
    TIE_BREAK_AT_N_MINUS_1,
    TIE_BREAK_NONE
}

// What the Format menu offers and what each choice changes in a MatchConfig. Every choice leaves
// a valid format: the menu needs no error message.
module FormatChoices {

    // The Sets item: the presets in menu order, then Custom.
    function presetChoices() as Array<Preset> {
        var choices = MatchConfig.presets();
        choices.add(PRESET_CUSTOM);
        return choices;
    }

    function deuceModeChoices() as Array<DeuceMode> {
        return [DEUCE_ADVANTAGE, DEUCE_GOLDEN, DEUCE_STAR, DEUCE_SILVER];
    }

    // Gives config the sets, games and tie-breaks of from, as picking Custom brings back the last
    // custom ones. The deuce mode, singles or doubles and mixed stay, as with a preset.
    function copyStructure(config as MatchConfig, from as MatchConfig) as Void {
        config.setsToWin = from.setsToWin;
        config.gamesToWin = from.gamesToWin;
        config.tieBreakAt = from.tieBreakAt;
        config.hasTieBreak = from.hasTieBreak;
        config.tieBreakPoints = from.tieBreakPoints;
        config.superTieBreak = from.superTieBreak;
    }

    // The structure Custom opens on: the last Custom one (custom), or the format's own the first time,
    // but never Tie-break only (one set to win with a super tie-break) nor Free play (no set to
    // win), which the Custom menu's Sets have no choice for: one set then, its "1 set", and a best
    // of 3 of Free play's sets of 6.
    function startCustom(config as MatchConfig, custom as MatchConfig?) as Void {
        if (custom != null) {
            copyStructure(config, custom);
        }
        if (config.isTieBreakOnly()) {
            config.superTieBreak = false;
        } else if (config.isFreePlay()) {
            config.setsToWin = 2;
        }
    }

    function setsChoices() as Array<SetsChoice> {
        return [SETS_ONE, SETS_BEST_OF_3, SETS_BEST_OF_3_SUPER_TB, SETS_BEST_OF_5, SETS_BEST_OF_5_SUPER_TB];
    }

    function getSets(config as MatchConfig) as SetsChoice {
        if (config.setsToWin == 1) {
            return SETS_ONE;
        } else if (config.setsToWin == 2) {
            return config.superTieBreak ? SETS_BEST_OF_3_SUPER_TB : SETS_BEST_OF_3;
        }
        return config.superTieBreak ? SETS_BEST_OF_5_SUPER_TB : SETS_BEST_OF_5;
    }

    function setSets(config as MatchConfig, choice as SetsChoice) as Void {
        if (choice == SETS_ONE) {
            config.setsToWin = 1;
        } else if (choice == SETS_BEST_OF_3 || choice == SETS_BEST_OF_3_SUPER_TB) {
            config.setsToWin = 2;
        } else {
            config.setsToWin = 3;
        }
        config.superTieBreak = choice == SETS_BEST_OF_3_SUPER_TB || choice == SETS_BEST_OF_5_SUPER_TB;
    }

    // Games to win a set, N: 2 to 10.
    function gamesChoices() as Array<Number> {
        var games = [] as Array<Number>;
        for (var n = MatchConfig.GAMES_TO_WIN_MIN; n <= MatchConfig.GAMES_TO_WIN_MAX; n++) {
            games.add(n);
        }
        return games;
    }

    // Sets N and keeps the tie-break at N-N or at (N-1)-(N-1), as it was.
    function setGames(config as MatchConfig, games as Number) as Void {
        var atN = config.tieBreakAt == config.gamesToWin;
        config.gamesToWin = games;
        config.tieBreakAt = atN ? games : games - 1;
    }

    function getTieBreak(config as MatchConfig) as TieBreakChoice {
        if (!config.hasTieBreak) {
            return TIE_BREAK_NONE;
        }
        return config.tieBreakAt == config.gamesToWin ? TIE_BREAK_AT_N : TIE_BREAK_AT_N_MINUS_1;
    }

    // No tie-break keeps where it was played, for when it comes back.
    function setTieBreak(config as MatchConfig, choice as TieBreakChoice) as Void {
        config.hasTieBreak = choice != TIE_BREAK_NONE;
        if (choice == TIE_BREAK_AT_N) {
            config.tieBreakAt = config.gamesToWin;
        } else if (choice == TIE_BREAK_AT_N_MINUS_1) {
            config.tieBreakAt = config.gamesToWin - 1;
        }
    }

    // Tie-break length.
    function tieBreakPointsChoices() as Array<Number> {
        return [7, 10];
    }
}

import Toybox.Lang;

// The game outcome lap field. The values are the FIT codes: never renumber.
enum LapOutcome {
    LAP_WE_HELD = 0,
    LAP_WE_BROKE = 1,
    LAP_THEY_HELD = 2,
    LAP_THEY_BROKE = 3,
    LAP_TIE_BREAK = 4,  // a tie-break or the super tie-break, with serve tracking off too
    LAP_NO_SERVE = 5    // a regular game whose serving team wasn't known (serve tracking off)
}

// The four lap fields of a lap, worked out from the match state alone. A lap
// holds one finished game; only the last lap, which the save closes, can hold none (a game left
// unfinished or dropped, or only the time since the last game), and it then has
// no outcome.
class LapValues {

    // 1 for the first set.
    var setNumber as Number;
    // Per Team, the set's score right after the game: its games (7-6 after a tie-break), or the
    // super tie-break's points (10-8), as the score text shows them.
    var games as Array<Number>;
    // Null when the lap holds no finished game: the FIT invalid value is written (getOutcomeCode()).
    var outcome as LapOutcome?;

    function initialize(setNumber as Number, games as Array<Number>, outcome as LapOutcome?) {
        self.setNumber = setNumber;
        self.games = games;
        self.outcome = outcome;
    }

    // The lap of finished game index (MatchState.finishedGames, 0 = the match's first game): the set
    // and its score right after the game, as the state kept them when the game ended, so an edited
    // score (EDIT_SCORE) counts in them.
    static function forGame(state as MatchState, index as Number) as LapValues {
        return new LapValues(state.getFinishedGameSet(index) + 1,
            [state.getFinishedGameScore(index, TEAM_US), state.getFinishedGameScore(index, TEAM_THEM)],
            gameOutcome(state, index));
    }

    // The last lap when it holds no finished game: the set the match stopped in and its score, as
    // the score text's last entry shows it (the set just ended when nothing is played in the next).
    static function forUnfinished(state as MatchState) as LapValues {
        var sets = state.setScores.size();
        var played = state.games[TEAM_US] + state.games[TEAM_THEM]
            + state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM];
        if (sets > 0 && played == 0) {
            var last = state.setScores[sets - 1];
            return new LapValues(capSet(sets), [last.getScore(TEAM_US), last.getScore(TEAM_THEM)], null);
        }
        return new LapValues(capSet(sets + 1),
            [state.getCurrentSetScore(TEAM_US), state.getCurrentSetScore(TEAM_THEM)], null);
    }

    // A set number as a game's lap has it (MatchState.finishedGameCode()): the 200th at most, so a
    // long Free play's last lap agrees with its game laps and fits the uint8 field.
    private static function capSet(number as Number) as Number {
        return number <= MatchState.SET_MAX + 1 ? number : MatchState.SET_MAX + 1;
    }

    // Held or broken from who served the game and who won it, both as the game ended, so a Fix
    // serving team during the game counts for all of it (as in the stats).
    private static function gameOutcome(state as MatchState, index as Number) as LapOutcome {
        if (state.getFinishedGameType(index) != GAME_REGULAR) {
            return LAP_TIE_BREAK;
        }
        var server = state.getFinishedGameServer(index);
        if (server == null) {
            return LAP_NO_SERVE;
        }
        var winner = state.getFinishedGameWinner(index);
        if (server == TEAM_US) {
            return winner == TEAM_US ? LAP_WE_HELD : LAP_THEY_BROKE;
        }
        return winner == TEAM_THEM ? LAP_THEY_HELD : LAP_WE_BROKE;
    }

    // The outcome field's value: its code, or the FIT invalid value when the lap holds no finished game.
    function getOutcomeCode() as Number {
        var code = outcome;
        return code == null ? FIT_INVALID_UINT8 : code as Number;
    }

    // "<set> <us>-<them> <outcome>", "-" for no outcome: "1 3-2 0". For tests.
    function toString() as String {
        var code = outcome;
        return setNumber + " " + games[TEAM_US] + "-" + games[TEAM_THEM] + " "
            + (code == null ? "-" : (code as Number).toString());
    }
}

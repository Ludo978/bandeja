import Toybox.Lang;

// The FIT invalid value of a uint8 field: Connect shows no value.
const FIT_INVALID_UINT8 = 0xFF;
// The largest count a uint8 field holds; a larger one (a long Free play's games) is written invalid.
const FIT_MAX_UINT8 = 0xFE;

// The 13 session fields of the activity, from our side, worked out from the match
// state and its stats. FitFields writes them in this order.
class SessionValues {

    // Bytes of the Score field, terminator included: MatchState.getScoreText() never fills it.
    static const SCORE_BYTES = MatchState.SCORE_TEXT_MAX + 1;

    // MatchState.getScoreText(): "6-4 3-6 10-8", "6-4 3-2*".
    var score as String;
    // Per Team: sets won (a super tie-break is a set), games won (a super tie-break counts none) and
    // points won, a dropped or unfinished game's included. A count of a uint8 field past FIT_MAX_UINT8
    // (a long Free play) is FIT_INVALID_UINT8, never wrapped round.
    var sets as Array<Number>;
    var games as Array<Number>;
    var points as Array<Number>;
    // Need serve tracking: FIT_INVALID_UINT8 without it. A percentage is also invalid while nothing
    // was played (we haven't served yet).
    var servePointsWonPercent as Number;
    var returnPointsWonPercent as Number;
    var breaksWon as Number;
    // The MatchResult, whose values are the FIT codes: 1 win, 0 loss, 2 unfinished, 3 draw.
    var result as Number;
    var decidingPointsWon as Number;
    var decidingPointsPlayed as Number;

    // From the state and its stats (null: the fields that need them are then invalid).
    function initialize(state as MatchState, stats as MatchStats?) {
        score = state.getScoreText();
        sets = [count(state.getSetsWon(TEAM_US)), count(state.getSetsWon(TEAM_THEM))];
        games = [count(state.getGamesWon(TEAM_US)), count(state.getGamesWon(TEAM_THEM))];
        points = [state.pointsWon[TEAM_US], state.pointsWon[TEAM_THEM]];
        result = state.getResult() as Number;
        if (stats == null) {
            servePointsWonPercent = FIT_INVALID_UINT8;
            returnPointsWonPercent = FIT_INVALID_UINT8;
            breaksWon = FIT_INVALID_UINT8;
            decidingPointsWon = FIT_INVALID_UINT8;
            decidingPointsPlayed = FIT_INVALID_UINT8;
        } else {
            servePointsWonPercent = orInvalid(stats.getServePointsWonPercent());
            returnPointsWonPercent = orInvalid(stats.getReturnPointsWonPercent());
            breaksWon = orInvalid(stats.breaksWon);
            decidingPointsWon = count(stats.decidingPointsWon);
            decidingPointsPlayed = count(stats.decidingPointsPlayed);
        }
    }

    // The values of the engine's match, whose first game began at matchStart. No replay: the state
    // keeps the stats (MatchState.getStats()).
    static function compute(engine as ScoringEngine, matchStart as Number) as SessionValues {
        var state = engine.getState();
        return new SessionValues(state, state.getStats(matchStart));
    }

    private static function orInvalid(value as Number?) as Number {
        return value == null ? FIT_INVALID_UINT8 : count(value);
    }

    // A count for a uint8 field: as it is, or FIT_INVALID_UINT8 past FIT_MAX_UINT8.
    private static function count(value as Number) as Number {
        return value > FIT_MAX_UINT8 ? FIT_INVALID_UINT8 : value;
    }

    // "<score> | sets 2-1 games 9-10 points 98-91 | serve 62 return 41 breaks 3 | result 1 |
    // deciding 4/7", 255 for an invalid value. For tests.
    function toString() as String {
        return score + " | sets " + pair(sets) + " games " + pair(games) + " points " + pair(points)
            + " | serve " + servePointsWonPercent + " return " + returnPointsWonPercent + " breaks " + breaksWon
            + " | result " + result + " | deciding " + decidingPointsWon + "/" + decidingPointsPlayed;
    }

    private static function pair(values as Array<Number>) as String {
        return values[TEAM_US] + "-" + values[TEAM_THEM];
    }
}

import Toybox.Lang;

// The stats of a match, from our side, for the summary and the FIT session
// fields; the average time per point and the longest streak show on the watch
// only. MatchState.getStats() fills them in from its tally; read-only after that.
//
// The stats that need serve tracking are null when no point has a known serving team (serve
// tracking off): the summary leaves them blank and the FIT fields write their invalid value. They
// count the games whose serving team is known when they end, with all of their points.
class MatchStats {

    // Every point played, those of a game dropped by End set now or left unfinished by End match
    // included.
    var pointsWon as Number = 0;
    var pointsLost as Number = 0;
    // MatchState.getGamesWon() and getSetsWon(): a super tie-break is a set and no game.
    var gamesWon as Number = 0;
    var gamesLost as Number = 0;
    var setsWon as Number = 0;
    var setsLost as Number = 0;
    // Seconds each finished game lasted, in MatchState.finishedGames order: from the end of the
    // game before it (its winning point, or End set now), or from the match start for the first
    // game, to its own winning point. Never negative, even when the watch's clock went back.
    var gameDurations as Array<Number>;
    // The longest game, as an index in gameDurations (the first one on a tie); null with no game won.
    var longestGame as Number? = null;
    // Points decided by a Golden, Silver or Star point, and those we won.
    var decidingPointsPlayed as Number = 0;
    var decidingPointsWon as Number = 0;
    // Tie-breaks played to the end, the super tie-break included, and those we won.
    var tieBreaksPlayed as Number = 0;
    var tieBreaksWon as Number = 0;
    // Seconds from the match start to the last point, over the points played: the time before the
    // first point, the changeovers and the pauses count. Whole seconds, halves rounded up, never
    // negative; null with no point played.
    var averagePointTime as Number? = null;
    // Our longest run of points won in a row, across games, tie-breaks and sets: only a point they win
    // breaks it, never End set now. 0 until we win a point. Theirs isn't kept.
    var longestStreak as Number = 0;

    // Points we served, a tie-break's included, and those we won.
    var servePointsPlayed as Number? = null;
    var servePointsWon as Number? = null;
    // Points they served, and those we won.
    var returnPointsPlayed as Number? = null;
    var returnPointsWon as Number? = null;
    // Our service games (regular games: a tie-break is no one's), those we held and those they broke.
    var serviceGamesPlayed as Number? = null;
    var serviceGamesHeld as Number? = null;
    var breaksConceded as Number? = null;
    // Their service games, and those we broke.
    var returnGamesPlayed as Number? = null;
    var breaksWon as Number? = null;
    // Our break points (the next point would have won us their service game, a deciding point
    // included), and those we won: each one broke.
    var breakPointsPlayed as Number? = null;
    var breakPointsConverted as Number? = null;
    // Their break points on our serve, and those we won.
    var breakPointsFaced as Number? = null;
    var breakPointsSaved as Number? = null;

    function initialize() {
        gameDurations = [] as Array<Number>;
    }

    // The percentages are rounded to the nearest whole number, and null when nothing was played.
    function getPointsWonPercent() as Number? {
        return percent(pointsWon, pointsWon + pointsLost);
    }

    function getServePointsWonPercent() as Number? {
        return percent(servePointsWon, servePointsPlayed);
    }

    function getReturnPointsWonPercent() as Number? {
        return percent(returnPointsWon, returnPointsPlayed);
    }

    // Halves round up. Below 200 played, 0 and 100 only ever mean none and all.
    private static function percent(part as Number?, whole as Number?) as Number? {
        if (part == null || whole == null || whole == 0) {
            return null;
        }
        return (part * 100 + whole / 2) / whole;
    }
}

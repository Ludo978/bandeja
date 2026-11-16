import Toybox.Lang;

// A finished set, for the summary's set table and the score text. Per-team
// arrays are indexed by Team. Read-only once it's in MatchState.setScores.
class SetScore {

    // Games won. 0-0 for a super tie-break, which counts no games.
    var games as Array<Number>;
    // Points of the tie-break that won the set, or of the super tie-break. Null when the set had
    // none, or when End set now dropped the tie-break in progress.
    var tieBreakPoints as Array<Number>?;
    // The final set, played as a super tie-break: tieBreakPoints is its score.
    var superTieBreak as Boolean;
    var winner as Team;
    // Given by End set now (EVENT_END_SET) instead of played out.
    var endedEarly as Boolean;

    function initialize(games as Array<Number>, tieBreakPoints as Array<Number>?, superTieBreak as Boolean,
            winner as Team, endedEarly as Boolean) {
        self.games = games;
        self.tieBreakPoints = tieBreakPoints;
        self.superTieBreak = superTieBreak;
        self.winner = winner;
        self.endedEarly = endedEarly;
    }

    // What the set shows for the team: its games, or its points for a super tie-break ("10-8").
    function getScore(team as Team) as Number {
        var points = tieBreakPoints;
        return superTieBreak && points != null ? points[team] : games[team];
    }

    function copy() as SetScore {
        var points = tieBreakPoints;
        return new SetScore([games[TEAM_US], games[TEAM_THEM]],
            points == null ? null : [points[TEAM_US], points[TEAM_THEM]], superTieBreak, winner, endedEarly);
    }

    function equals(other as Object?) as Boolean {
        if (other instanceof SetScore) {
            var points = tieBreakPoints;
            var otherPoints = other.tieBreakPoints;
            var samePoints = points == null || otherPoints == null
                ? points == otherPoints
                : points[TEAM_US] == otherPoints[TEAM_US] && points[TEAM_THEM] == otherPoints[TEAM_THEM];
            return samePoints
                && games[TEAM_US] == other.games[TEAM_US]
                && games[TEAM_THEM] == other.games[TEAM_THEM]
                && superTieBreak == other.superTieBreak
                && winner == other.winner
                && endedEarly == other.endedEarly;
        }
        return false;
    }

    // For test messages.
    function toString() as String {
        var points = tieBreakPoints;
        return "" + games[TEAM_US] + "-" + games[TEAM_THEM]
            + (points == null ? "" : " (" + points[TEAM_US] + "-" + points[TEAM_THEM] + ")")
            + (superTieBreak ? " super" : "")
            + " to " + winner
            + (endedEarly ? " ended" : "");
    }
}

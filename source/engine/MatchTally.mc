import Toybox.Lang;

// The stats of a match as its events add up, kept in the state (MatchState.tally) and
// fed by ScoringEngine.apply(): the pause, the summary and the save read them with no replay
// (MatchState.getStats()), and undo and resume give them back with the rest of the state, so they
// always agree with the score.
//
// Serve stats credit a game's points to the team serving it when it ends, the server
// MatchState.finishedGames keeps: the serving team doesn't change during a game, so a Fix serving
// team in the middle of one, the first one included when serve tracking starts late, holds for
// the points played before it too. Until then the game's points are only counted by what they can
// turn out to be: served by the team of its first turn or by the other one (a tie-break's turns),
// a game point for us, for them. A game that ends with no known serving team counts in no serve
// stat.
//
// The average time per point needs only the last point's time (getStats() takes the match start)
// and our longest streak the run in progress and the longest so far. Neither can be taken back by
// arithmetic, so undo and resume give them back as they give back the rest: the last snapshot (or
// the new match) with the events after it applied again.
//
// The counts are one array of Numbers (the constants below), so a copy, a comparison and an undo
// snapshot cost a single array each.
class MatchTally {

    // Points decided by a Golden, Silver or Star point, and those we won.
    private static const DECIDING_PLAYED = 0;
    private static const DECIDING_WON = 1;
    // Tie-breaks played to the end, the super tie-break included, and those we won.
    private static const TIE_BREAKS_PLAYED = 2;
    private static const TIE_BREAKS_WON = 3;
    // 1 once a point was credited to a known serving team: the serve stats aren't null.
    private static const TRACKED = 4;
    private static const SERVE_POINTS = 5;
    private static const SERVE_POINTS_WON = 6;
    private static const RETURN_POINTS = 7;
    private static const RETURN_POINTS_WON = 8;
    private static const SERVICE_GAMES = 9;
    private static const HELD = 10;
    private static const RETURN_GAMES = 11;
    private static const BREAKS = 12;
    private static const BREAK_POINTS = 13;
    private static const CONVERTED = 14;
    private static const FACED = 15;
    private static const SAVED = 16;
    // The game in progress, until its serving team is final: its points served by the team of its
    // first turn (all of a regular game's) and by the other team, and its game points for each team,
    // each with those we won.
    private static const FIRST_TURN = 17;
    private static const FIRST_TURN_WON = 18;
    private static const OTHER_TURN = 19;
    private static const OTHER_TURN_WON = 20;
    private static const GAME_POINTS_US = 21;
    private static const GAME_POINTS_US_WON = 22;
    private static const GAME_POINTS_THEM = 23;
    private static const GAME_POINTS_THEM_WON = 24;
    // When the match's first game ended, if it began at the match start, which the log doesn't
    // hold (getStats() takes it): its duration in gameDurations is then a placeholder. -1 otherwise.
    private static const FIRST_GAME_END = 25;
    // When the last point was played (seconds, wall clock); 0 before the first point.
    private static const LAST_POINT_TIME = 26;
    // The points we have won in a row since they last won one, and the longest such run.
    private static const STREAK = 27;
    private static const LONGEST_STREAK = 28;
    private static const COUNTS = 29;

    // How many Numbers pack() adds.
    static const PACKED_SIZE = COUNTS + 1;

    private var _counts as Array<Number>;
    // Seconds each finished game lasted, in MatchState.finishedGames order, never negative. Only
    // grows as the match goes on.
    var gameDurations as Array<Number>;

    function initialize() {
        _counts = new Array<Number>[COUNTS];
        for (var i = 0; i < COUNTS; i++) {
            _counts[i] = 0;
        }
        _counts[FIRST_GAME_END] = -1;
        gameDurations = [] as Array<Number>;
    }

    // The point about to be played at time, won by winner, in the state before it; deciding is
    // MatchState.isDecidingPoint() there, which ScoringEngine has already worked out.
    function point(state as MatchState, winner as Team, deciding as Boolean, time as Number) as Void {
        var counts = _counts;
        var won = winner == TEAM_US ? 1 : 0;
        counts[LAST_POINT_TIME] = time;
        // Only a point they win breaks our streak: a game, a set or End set now doesn't.
        if (won == 1) {
            var streak = counts[STREAK] + 1;
            counts[STREAK] = streak;
            if (streak > counts[LONGEST_STREAK]) {
                counts[LONGEST_STREAK] = streak;
            }
        } else {
            counts[STREAK] = 0;
        }
        if (deciding) {
            counts[DECIDING_PLAYED] += 1;
            counts[DECIDING_WON] += won;
        }
        if (state.gameType != GAME_REGULAR) {
            // No break points in a tie-break, only turns.
            if (state.getServeTurn() % 2 == 1) {
                counts[OTHER_TURN] += 1;
                counts[OTHER_TURN_WON] += won;
                return;
            }
        } else {
            // A game point: a deciding point, or the point that would give the team 4 points and a
            // 2-point lead (MatchConfig.isGameWon(), MatchSituation.isGamePoint()).
            var us = state.gamePoints[TEAM_US];
            var them = state.gamePoints[TEAM_THEM];
            if (deciding || (us >= 3 && us > them)) {
                counts[GAME_POINTS_US] += 1;
                counts[GAME_POINTS_US_WON] += won;
            }
            if (deciding || (them >= 3 && them > us)) {
                counts[GAME_POINTS_THEM] += 1;
                counts[GAME_POINTS_THEM_WON] += won;
            }
        }
        counts[FIRST_TURN] += 1;
        counts[FIRST_TURN_WON] += won;
    }

    // Finished game index (MatchState.finishedGames) has just ended at time. It began at gameStart,
    // MatchState.gameStartTime before the point: null for the match start, which only the match's
    // first game can have.
    function gameEnded(state as MatchState, index as Number, time as Number, gameStart as Number?) as Void {
        var counts = _counts;
        if (gameStart == null) {
            counts[FIRST_GAME_END] = time;
            gameDurations.add(0);
        } else {
            var duration = time - gameStart;
            gameDurations.add(duration > 0 ? duration : 0);
        }
        var server = state.getFinishedGameServer(index);
        var won = state.getFinishedGameWinner(index) == TEAM_US ? 1 : 0;
        credit(counts, server);
        clearGame();
        if (state.getFinishedGameType(index) != GAME_REGULAR) {
            counts[TIE_BREAKS_PLAYED] += 1;
            counts[TIE_BREAKS_WON] += won;
        } else if (server == TEAM_US) {
            counts[SERVICE_GAMES] += 1;
            counts[HELD] += won;
        } else if (server == TEAM_THEM) {
            counts[RETURN_GAMES] += 1;
            counts[BREAKS] += won;
        }
    }

    // End set now drops the game in progress, which server was serving: its points were played.
    function gameDropped(server as Team?) as Void {
        credit(_counts, server);
        clearGame();
    }

    // The stats as they stand in state, whose tally this is, the first game having begun at
    // matchStart (seconds, wall clock: the START that ended the warm-up). The game in progress, or
    // the one End match left unfinished, counts with the team serving it now.
    function getStats(state as MatchState, matchStart as Number) as MatchStats {
        var stats = new MatchStats();
        stats.pointsWon = state.pointsWon[TEAM_US];
        stats.pointsLost = state.pointsWon[TEAM_THEM];
        stats.gamesWon = state.getGamesWon(TEAM_US);
        stats.gamesLost = state.getGamesWon(TEAM_THEM);
        stats.setsWon = state.getSetsWon(TEAM_US);
        stats.setsLost = state.getSetsWon(TEAM_THEM);
        var counts = _counts.slice(0, null);
        stats.decidingPointsPlayed = counts[DECIDING_PLAYED];
        stats.decidingPointsWon = counts[DECIDING_WON];
        stats.tieBreaksPlayed = counts[TIE_BREAKS_PLAYED];
        stats.tieBreaksWon = counts[TIE_BREAKS_WON];
        // From the match start to the last point, over the points played, halves rounded up.
        var played = stats.pointsWon + stats.pointsLost;
        if (played > 0) {
            var seconds = counts[LAST_POINT_TIME] - matchStart;
            stats.averagePointTime = seconds > 0 ? (seconds + played / 2) / played : 0;
        }
        stats.longestStreak = counts[LONGEST_STREAK];

        var durations = gameDurations.slice(0, null);
        if (counts[FIRST_GAME_END] >= 0) {
            var first = counts[FIRST_GAME_END] - matchStart;
            durations[0] = first > 0 ? first : 0;
        }
        stats.gameDurations = durations;
        for (var i = 0; i < durations.size(); i++) {
            var longest = stats.longestGame;
            if (longest == null || durations[i] > durations[longest]) {
                stats.longestGame = i;
            }
        }

        credit(counts, state.servingTeam);
        if (counts[TRACKED] == 1) {
            stats.servePointsPlayed = counts[SERVE_POINTS];
            stats.servePointsWon = counts[SERVE_POINTS_WON];
            stats.returnPointsPlayed = counts[RETURN_POINTS];
            stats.returnPointsWon = counts[RETURN_POINTS_WON];
            stats.serviceGamesPlayed = counts[SERVICE_GAMES];
            stats.serviceGamesHeld = counts[HELD];
            stats.breaksConceded = counts[SERVICE_GAMES] - counts[HELD];
            stats.returnGamesPlayed = counts[RETURN_GAMES];
            stats.breaksWon = counts[BREAKS];
            stats.breakPointsPlayed = counts[BREAK_POINTS];
            stats.breakPointsConverted = counts[CONVERTED];
            stats.breakPointsFaced = counts[FACED];
            stats.breakPointsSaved = counts[SAVED];
        }
        return stats;
    }

    // Adds the points of the game in progress to counts, served by server (in a tie-break, the team
    // of its first turn); nothing when it isn't known.
    private static function credit(counts as Array<Number>, server as Team?) as Void {
        var first = counts[FIRST_TURN];
        var other = counts[OTHER_TURN];
        if (server == null || first + other == 0) {
            return;
        }
        counts[TRACKED] = 1;
        if (server == TEAM_US) {
            counts[SERVE_POINTS] += first;
            counts[SERVE_POINTS_WON] += counts[FIRST_TURN_WON];
            counts[RETURN_POINTS] += other;
            counts[RETURN_POINTS_WON] += counts[OTHER_TURN_WON];
            counts[FACED] += counts[GAME_POINTS_THEM];
            counts[SAVED] += counts[GAME_POINTS_THEM_WON];
        } else {
            counts[SERVE_POINTS] += other;
            counts[SERVE_POINTS_WON] += counts[OTHER_TURN_WON];
            counts[RETURN_POINTS] += first;
            counts[RETURN_POINTS_WON] += counts[FIRST_TURN_WON];
            counts[BREAK_POINTS] += counts[GAME_POINTS_US];
            counts[CONVERTED] += counts[GAME_POINTS_US_WON];
        }
    }

    private function clearGame() as Void {
        for (var i = FIRST_TURN; i <= GAME_POINTS_THEM_WON; i++) {
            _counts[i] = 0;
        }
    }

    function copy() as MatchTally {
        var other = new MatchTally();
        other.unpack(pack(), 0, self);
        return other;
    }

    // The counts, then the number of game durations: ScoringEngine's undo snapshots
    // (MatchState.pack()).
    function pack() as Array<Number?> {
        var packed = _counts.slice(0, null) as Array<Number?>;
        packed.add(gameDurations.size());
        return packed;
    }

    // Takes back what pack() gave, at offset in packed, the game durations from later, the tally of
    // a later state of the same match: they only grow.
    function unpack(packed as Array<Number?>, offset as Number, later as MatchTally) as Void {
        _counts = packed.slice(offset, offset + COUNTS) as Array<Number>;
        gameDurations = later.gameDurations.slice(0, packed[offset + COUNTS] as Number);
    }

    function equals(other as Object?) as Boolean {
        if (!(other instanceof MatchTally)) {
            return false;
        }
        var mine = pack();
        var others = other.pack();
        mine.addAll(gameDurations as Array<Number?>);
        others.addAll(other.gameDurations as Array<Number?>);
        if (mine.size() != others.size()) {
            return false;
        }
        for (var i = 0; i < mine.size(); i++) {
            if (mine[i] != others[i]) {
                return false;
            }
        }
        return true;
    }

    // For test messages.
    function toString() as String {
        return "tally " + _counts + " " + gameDurations;
    }
}

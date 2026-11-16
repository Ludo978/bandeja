import Toybox.Lang;

// The stats of a match worked out by replaying its whole log, as the app once did:
// the tests' reference, which the stats the state adds up as the events come
// (MatchTally) must equal. Too slow for the app on a long match (the watchdog), so only in
// test builds. Use compute().
//
// Serve stats credit a game's points to the team serving it when it ends, the server
// MatchState.finishedGames keeps: the serving team doesn't change during a game, so a Fix serving
// team in the middle of one, the first one included when serve tracking starts late, holds for
// the points played before it too. A game that ends with no known serving team counts in no
// serve stat. A score edit (EDIT_SCORE) sets the score only: the games and sets
// read from the state follow it, the other stats count what was played on the watch, and the game in
// progress goes on through it.
(:test)
class StatsCalculator {

    // A point of the game in progress, kept until the game's serving team is final: these flags.
    private static const POINT_WON_BY_THEM = 1;
    // The point would have won the game for us, for them: a game point, a break point for the
    // receivers. Regular games only.
    private static const POINT_GAME_POINT_US = 2;
    private static const POINT_GAME_POINT_THEM = 4;
    // A tie-break point served by the team that didn't serve its first point.
    private static const POINT_OTHER_TURN = 8;

    private var _config as MatchConfig;
    private var _stats as MatchStats;
    private var _gamePoints as Array<Number>;
    // A point was credited to a serving team: the serve stats aren't null.
    private var _tracked as Boolean = false;
    private var _servePoints as Number = 0;
    private var _servePointsWon as Number = 0;
    private var _returnPoints as Number = 0;
    private var _returnPointsWon as Number = 0;
    private var _serviceGames as Number = 0;
    private var _held as Number = 0;
    private var _broken as Number = 0;
    private var _returnGames as Number = 0;
    private var _breaks as Number = 0;
    private var _breakPoints as Number = 0;
    private var _converted as Number = 0;
    private var _faced as Number = 0;
    private var _saved as Number = 0;
    // The last point's time; null before the first point.
    private var _lastPointTime as Number? = null;
    // Points we have won in a row since they last won one, and the longest such run already over.
    private var _run as Number = 0;
    private var _longestRun as Number = 0;

    // The stats of the match with this format and log (ScoringEngine.getLog()'s form), whose first
    // game began at matchStart (seconds, wall clock: the START that ended the warm-up, which the
    // app keeps with the log). Null when the log is malformed or one of its events is refused.
    static function compute(config as MatchConfig, log as Object?, matchStart as Number) as MatchStats? {
        if (!(log instanceof Array) || log.size() % ScoringEngine.LOG_NUMBERS_PER_EVENT != 0) {
            return null;
        }
        return new StatsCalculator(config).replay(log, matchStart);
    }

    // Only compute() makes one.
    function initialize(config as MatchConfig) {
        _config = config;
        _stats = new MatchStats();
        _gamePoints = [] as Array<Number>;
    }

    // compute() once the log has the right shape: call compute(). Before each event, notes what it
    // plays; after it, the game it ended. Public only because the static compute() can't reach a
    // private or protected method at run time.
    function replay(log as Array, matchStart as Number) as MatchStats? {
        var state = ScoringEngine.newState(_config);
        for (var offset = 0; offset < log.size(); ) {
            var event = MatchEvent.fromLog(log, offset);
            if (event == null) {
                return null;
            }
            offset += event.getSize();
            var type = event.type;
            var games = state.finishedGames.size();
            var gameStart = state.getGameStartTime(matchStart);
            if (type == EVENT_POINT_US || type == EVENT_POINT_THEM) {
                addPoint(state, type == EVENT_POINT_US ? TEAM_US : TEAM_THEM);
                _lastPointTime = event.time;
            } else if (type == EVENT_END_SET) {
                // The game in progress is dropped, but its points were played.
                creditPoints(state.servingTeam);
            }
            if (!ScoringEngine.apply(_config, state, event)) {
                return null;
            }
            if (state.finishedGames.size() > games) {
                addGame(state, games, event.time - gameStart);
            }
        }
        // The game in progress, or the one End match left unfinished.
        creditPoints(state.servingTeam);
        return finish(state, matchStart);
    }

    // The point about to be played, won by winner: counted if it decides the game, and kept with
    // what it could have won until the game's serving team is final.
    private function addPoint(state as MatchState, winner as Team) as Void {
        var won = winner == TEAM_US;
        // Only a point they win ends our run: games, sets and End set now don't.
        if (won) {
            _run += 1;
        } else {
            endRun();
        }
        if (state.isDecidingPoint()) {
            _stats.decidingPointsPlayed += 1;
            _stats.decidingPointsWon += won ? 1 : 0;
        }
        var point = won ? 0 : POINT_WON_BY_THEM;
        if (state.isTieBreak()) {
            point += state.getServeTurn() % 2 == 1 ? POINT_OTHER_TURN : 0;
        } else {
            point += MatchSituation.isGamePoint(_config, state, TEAM_US) ? POINT_GAME_POINT_US : 0;
            point += MatchSituation.isGamePoint(_config, state, TEAM_THEM) ? POINT_GAME_POINT_THEM : 0;
        }
        _gamePoints.add(point);
    }

    // The points of the game that just ended or was dropped go to server, the team that served it
    // (in a tie-break, its first point); with no serving team known they count in no serve stat.
    private function creditPoints(server as Team?) as Void {
        if (server != null) {
            var receivers = MatchState.otherTeam(server);
            var breakPoint = receivers == TEAM_US ? POINT_GAME_POINT_US : POINT_GAME_POINT_THEM;
            for (var i = 0; i < _gamePoints.size(); i++) {
                var point = _gamePoints[i];
                var won = (point & POINT_WON_BY_THEM) == 0 ? 1 : 0;
                var otherTurn = (point & POINT_OTHER_TURN) != 0;
                if ((server == TEAM_US) != otherTurn) {
                    _servePoints += 1;
                    _servePointsWon += won;
                } else {
                    _returnPoints += 1;
                    _returnPointsWon += won;
                }
                if ((point & breakPoint) != 0) {
                    if (receivers == TEAM_US) {
                        _breakPoints += 1;
                        _converted += won;
                    } else {
                        _faced += 1;
                        _saved += won;
                    }
                }
                _tracked = true;
            }
        }
        _gamePoints = [] as Array<Number>;
    }

    // Finished game index has just ended, duration seconds after it began.
    private function addGame(state as MatchState, index as Number, duration as Number) as Void {
        _stats.gameDurations.add(duration > 0 ? duration : 0);
        var server = state.getFinishedGameServer(index);
        var won = state.getFinishedGameWinner(index) == TEAM_US;
        creditPoints(server);
        if (state.getFinishedGameType(index) != GAME_REGULAR) {
            _stats.tieBreaksPlayed += 1;
            _stats.tieBreaksWon += won ? 1 : 0;
        } else if (server == TEAM_US) {
            _serviceGames += 1;
            if (won) {
                _held += 1;
            } else {
                _broken += 1;
            }
        } else if (server == TEAM_THEM) {
            _returnGames += 1;
            _breaks += won ? 1 : 0;
        }
    }

    private function endRun() as Void {
        if (_run > _longestRun) {
            _longestRun = _run;
        }
        _run = 0;
    }

    // The stats, with the totals of the state the log gave, the first game having begun at matchStart.
    private function finish(state as MatchState, matchStart as Number) as MatchStats {
        var stats = _stats;
        stats.pointsWon = state.pointsWon[TEAM_US];
        stats.pointsLost = state.pointsWon[TEAM_THEM];
        // From the match start to the last point, the changeovers and pauses in it, over the points
        // played: whole seconds, halves rounded up, never negative.
        var last = _lastPointTime;
        var played = stats.pointsWon + stats.pointsLost;
        if (last != null && played > 0) {
            var seconds = last - matchStart;
            stats.averagePointTime = seconds <= 0 ? 0 : (seconds.toFloat() / played + 0.5).toNumber();
        }
        endRun();
        stats.longestStreak = _longestRun;
        stats.gamesWon = state.getGamesWon(TEAM_US);
        stats.gamesLost = state.getGamesWon(TEAM_THEM);
        stats.setsWon = state.getSetsWon(TEAM_US);
        stats.setsLost = state.getSetsWon(TEAM_THEM);
        var durations = stats.gameDurations;
        for (var i = 0; i < durations.size(); i++) {
            var longest = stats.longestGame;
            if (longest == null || durations[i] > durations[longest]) {
                stats.longestGame = i;
            }
        }
        if (_tracked) {
            stats.servePointsPlayed = _servePoints;
            stats.servePointsWon = _servePointsWon;
            stats.returnPointsPlayed = _returnPoints;
            stats.returnPointsWon = _returnPointsWon;
            stats.serviceGamesPlayed = _serviceGames;
            stats.serviceGamesHeld = _held;
            stats.breaksConceded = _broken;
            stats.returnGamesPlayed = _returnGames;
            stats.breaksWon = _breaks;
            stats.breakPointsPlayed = _breakPoints;
            stats.breakPointsConverted = _converted;
            stats.breakPointsFaced = _faced;
            stats.breakPointsSaved = _saved;
        }
        return stats;
    }
}

import Toybox.Lang;

// One of our two players in doubles. In singles it's always PLAYER_ME.
enum Player {
    PLAYER_ME = 0,
    PLAYER_PARTNER = 1
}

// The half of the court the server serves from, as the server sees it.
enum Side {
    SIDE_RIGHT = 0, // the deuce court: an even number of points played in the game
    SIDE_LEFT = 1   // an odd number
}

// The game in progress.
enum GameType {
    GAME_REGULAR = 0,        // 0, 15, 30, 40, AD under the game's deuce mode
    GAME_TIE_BREAK = 1,      // at T-T: plain points to the format's length, win by two
    GAME_SUPER_TIE_BREAK = 2 // the final set as one tie-break to 10 (Tie-break only: 7 or 10), win by two
}

// The match from our side. The values are the FIT Result codes: never renumber.
enum MatchResult {
    RESULT_LOSS = 0,
    RESULT_WIN = 1,
    RESULT_UNFINISHED = 2,
    RESULT_DRAW = 3
}

// The match as the screens, menus, stats and FIT fields read it. Only ScoringEngine writes it, from
// the config and the event log. Per-team arrays are indexed by Team.
// A new field must also go into copy(), equals(), toString(), pack() and unpack(): the tests that
// compare a full replay with the state updated event by event, or after an undo, rely on equals().
class MatchState {

    // getPointDisplay() for the advantage.
    static const POINTS_AD = -1;
    // Longest getScoreText(): the FIT Score field holds 48 bytes, terminator included.
    static const SCORE_TEXT_MAX = 47;
    // In place of the sets a score text too long leaves out, before the latest ones (getScoreTextIn()).
    static const SETS_LEFT_OUT = "..";
    // Tie-break points between two changes of ends.
    static const CHANGE_OF_ENDS_POINTS = 6;
    // In a finishedGames code, a server not known.
    private static const SERVER_UNKNOWN = 2;
    // A finishedGames code's parts: the game's type, server and winner below GAME_PART, then the set's
    // score after it, each team below SCORE_PART, then the set's index above SET_PART, at most SET_MAX
    // (Free play's sets have no end; a Number holds 214 of them).
    private static const GAME_PART = 1000;
    private static const SCORE_PART = 100;
    private static const SET_PART = 10000000;
    // Also the last lap's cap (LapValues.forUnfinished()), so every lap's set number agrees.
    static const SET_MAX = 199;
    // pack()'s values before the tally's.
    private static const PACKED_FIELDS = 20;

    // Points won in the whole match.
    var pointsWon as Array<Number>;
    // Points won in the current game, from 0-0. Deuces don't reset them: 5-4 is AD-40 after
    // deuce 2. In a tie-break, its points.
    var gamePoints as Array<Number>;
    // Games won in the current set. A super tie-break counts none: they stay 0-0 in it.
    var games as Array<Number>;
    // Regular game, tie-break, or super tie-break (the whole final set).
    var gameType as GameType = GAME_REGULAR;
    // Finished sets, oldest first. Its size is the current set's index (0 = first set).
    var setScores as Array<SetScore>;
    // Deuce mode chosen for the next games: the config's, then the last SET_DEUCE_MODE.
    var deuceMode as DeuceMode = DEUCE_ADVANTAGE;
    // Rule of the game in progress: deuceMode as it stood at the game's first point,
    // and deuceMode itself until that point is played.
    var gameDeuceMode as DeuceMode = DEUCE_ADVANTAGE;
    // Team serving the current game, passed to the other team after each game. In a
    // tie-break, the team that serves its first point: getServingTeam() gives the team serving
    // now. FIX_SERVING_TEAM sets it, the "Who serves first?" answer included; null while unknown
    // (serve tracking off), and then nothing rotates.
    var servingTeam as Team? = null;
    // Our player who serves our current or next service game, the other one after each game we
    // serve in doubles. In a tie-break, our player for our first turn in it: getServingPlayer()
    // gives the one serving now. Flipped by SWAP_OUR_SERVER, which also records the "Who serves
    // first for us?" answer.
    var ourServer as Player = PLAYER_ME;
    // From the config. In singles our only player is PLAYER_ME.
    var doubles as Boolean = true;
    // The last event changed who serves as the screen shows it: the serving team, or our player
    // when we serve (their two players aren't told apart). Never once the match is over.
    var serverChanged as Boolean = false;
    // The last event made the players change ends: a point that won a game leaving an
    // odd number of games in its set (a tie-break counts as one), or the 6th, 12th... point of a
    // tie-break. Never once the match is over, and never for End set now.
    var changeOfEnds as Boolean = false;
    // Finished games of the match, oldest first, one code each: getFinishedGameServer(),
    // getFinishedGameWinner(), getFinishedGameType(), getFinishedGameSet(), getFinishedGameScore().
    // A game dropped by End set now, or left unfinished by End match, isn't in it, nor are the games
    // an edit sets (EDIT_SCORE): only the games played on the watch.
    var finishedGames as Array<Number>;
    // No event can follow: a team won setsToWin sets (never in Free play), or END_MATCH ended the match
    // early, leaving the unfinished set as it stood.
    var matchOver as Boolean = false;
    // Events in the log.
    var eventCount as Number = 0;
    // Time of the last event (seconds, wall clock); null before the first event.
    var lastEventTime as Number? = null;
    // When the current game began (seconds, wall clock): the point that won the game before it, or
    // End set now. Null in the match's first game, which begins at the match start: the app keeps
    // that time, the log doesn't. getGameStartTime() fills it in.
    var gameStartTime as Number? = null;
    // The stats as the events add up: getStats() gives them.
    var tally as MatchTally;

    // The state before any event, for any format: ScoringEngine.newState() fills in what comes
    // from the config.
    function initialize() {
        pointsWon = [0, 0];
        gamePoints = [0, 0];
        games = [0, 0];
        setScores = [] as Array<SetScore>;
        finishedGames = [] as Array<Number>;
        tally = new MatchTally();
    }

    // The stats of the match so far, its first game having begun at matchStart (seconds,
    // wall clock: the START that ended the warm-up, which the app keeps). No replay: for the pause,
    // the summary and the save.
    function getStats(matchStart as Number) as MatchStats {
        return tally.getStats(self, matchStart);
    }

    // What the screen shows for the team's points: 0, 15, 30, 40, or POINTS_AD when it has the
    // advantage (the other team shows 40). In a tie-break, the plain count.
    function getPointDisplay(team as Team) as Number {
        var mine = gamePoints[team];
        return isTieBreak() ? mine : pointDisplay(mine, gamePoints[team == TEAM_US ? TEAM_THEM : TEAM_US]);
    }

    // What a regular game's point counts show for one team, mine against theirs: 0, 15, 30, 40, or
    // POINTS_AD (also the Edit score menu's lists).
    static function pointDisplay(mine as Number, theirs as Number) as Number {
        if (theirs >= 3 && mine > theirs) {
            return POINTS_AD;
        }
        return mine < 3 ? 15 * mine : 40;
    }

    // How many times the current game has reached 40-40: 0 before the first deuce, 1 from deuce 1
    // through the advantage that follows it, and so on. 0 in a tie-break.
    function getDeuceCount() as Number {
        if (isTieBreak()) {
            return 0;
        }
        var low = gamePoints[TEAM_US] < gamePoints[TEAM_THEM] ? gamePoints[TEAM_US] : gamePoints[TEAM_THEM];
        return low >= 3 ? low - 2 : 0;
    }

    // 40-40 right now. Never in a tie-break.
    function isDeuce() as Boolean {
        return !isTieBreak() && gamePoints[TEAM_US] == gamePoints[TEAM_THEM] && gamePoints[TEAM_US] >= 3;
    }

    // The next point decides the game: Golden point at deuce 1, Silver at deuce 2, Star at deuce 3,
    // following the rule of the game in progress.
    function isDecidingPoint() as Boolean {
        return isDeuce() && getDeuceCount() == decidingDeuce(gameDeuceMode);
    }

    // A tie-break or the super tie-break: plain points, no deuce rule.
    function isTieBreak() as Boolean {
        return gameType != GAME_REGULAR;
    }

    // Serve turns before the current point: 0 in a regular game, served by one player. In a
    // tie-break the first point is turn 0, then each turn is two points, alternating the teams.
    function getServeTurn() as Number {
        return isTieBreak() ? (gamePoints[TEAM_US] + gamePoints[TEAM_THEM] + 1) / 2 : 0;
    }

    // The team serving the current point; null while unknown (serve tracking off).
    function getServingTeam() as Team? {
        var team = servingTeam;
        return team == null || getServeTurn() % 2 == 0 ? team : otherTeam(team);
    }

    // Our player serving the current point, for the YOU / PARTNER caption; null when
    // they serve or the serving team is unknown. Our turns in a tie-break alternate our players.
    function getServingPlayer() as Player? {
        if (getServingTeam() != TEAM_US) {
            return null;
        }
        // Our turns are every other one, so getServeTurn() / 2 counts ours before this one.
        if (doubles && (getServeTurn() / 2) % 2 == 1) {
            return ourServer == PLAYER_ME ? PLAYER_PARTNER : PLAYER_ME;
        }
        return ourServer;
    }

    // The side the current point is served from: right after an even number of points in the
    // game or tie-break, left after an odd number. Null on a deciding point, where the
    // receivers choose, and while the serving team is unknown.
    function getServeSide() as Side? {
        if (servingTeam == null || isDecidingPoint()) {
            return null;
        }
        return (gamePoints[TEAM_US] + gamePoints[TEAM_THEM]) % 2 == 0 ? SIDE_RIGHT : SIDE_LEFT;
    }

    // When the current game began, for its duration on the data page and the stats:
    // gameStartTime, or matchStart (the START that ended the warm-up) until a game is won or End
    // set now.
    function getGameStartTime(matchStart as Number) as Number {
        var time = gameStartTime;
        return time != null ? time : matchStart;
    }

    // In a tie-break or the super tie-break, the number of its points played at which the players
    // next change ends: 6, then 12, 18... (the "CHANGE ENDS AT 6" caption). Null in a
    // regular game.
    function getChangeOfEndsAt() as Number? {
        if (!isTieBreak()) {
            return null;
        }
        var played = gamePoints[TEAM_US] + gamePoints[TEAM_THEM];
        return (played / CHANGE_OF_ENDS_POINTS + 1) * CHANGE_OF_ENDS_POINTS;
    }

    // Who served finished game index (0 = the first game of the match): in a tie-break, who served
    // its first point. Null when the serving team was unknown. Holds and breaks compare it with
    // getFinishedGameWinner().
    function getFinishedGameServer(index as Number) as Team? {
        var server = finishedGames[index] / 10 % 10;
        return server == SERVER_UNKNOWN ? null : server as Team;
    }

    function getFinishedGameWinner(index as Number) as Team {
        return (finishedGames[index] % 10) as Team;
    }

    function getFinishedGameType(index as Number) as GameType {
        return (finishedGames[index] / 100 % 10) as GameType;
    }

    // The set finished game index was played in, 0 for the first (SET_MAX at most).
    function getFinishedGameSet(index as Number) as Number {
        return finishedGames[index] / SET_PART;
    }

    // The team's score in the set right after finished game index: its games (7-6 after a tie-break),
    // or its points after the super tie-break (10-8), at most 99. With an edit the set's games count
    // from the edited score (the lap fields).
    function getFinishedGameScore(index as Number, team as Team) as Number {
        var score = finishedGames[index] / GAME_PART;
        return team == TEAM_US ? score / SCORE_PART % SCORE_PART : score % SCORE_PART;
    }

    // A finishedGames entry, in decimal from the right: the winner, the server (2 when unknown), the
    // game type, their score in the set right after the game and ours (2 digits each: the set's games,
    // or the super tie-break's points), then the set's index. 100,010 is the first game of the match,
    // a break: they served, we won, 1-0; 20,810,221 a super tie-break in the third set, won 8-10 by
    // them with no serving team known.
    static function finishedGameCode(set as Number, us as Number, them as Number, type as GameType, server as Team?,
            winner as Team) as Number {
        var max = SCORE_PART - 1;
        var score = ((set < SET_MAX ? set : SET_MAX) * SCORE_PART + (us < max ? us : max)) * SCORE_PART
            + (them < max ? them : max);
        return score * GAME_PART + 100 * type + 10 * (server == null ? SERVER_UNKNOWN : server as Number) + winner;
    }

    static function otherTeam(team as Team) as Team {
        return team == TEAM_US ? TEAM_THEM : TEAM_US;
    }

    // The team's score in the current set: its games, or its points in a super tie-break.
    function getCurrentSetScore(team as Team) as Number {
        return gameType == GAME_SUPER_TIE_BREAK ? gamePoints[team] : games[team];
    }

    // The team ahead in the current set (getCurrentSetScore()), which End set now gives the set to;
    // null when level, and the player then names the team.
    function getSetLeader() as Team? {
        return ahead(getCurrentSetScore(TEAM_US), getCurrentSetScore(TEAM_THEM));
    }

    // Sets won, a super tie-break included.
    function getSetsWon(team as Team) as Number {
        var count = 0;
        for (var i = 0; i < setScores.size(); i++) {
            if (setScores[i].winner == team) {
                count++;
            }
        }
        return count;
    }

    // Games won in the match, the current set's included. A super tie-break counts none.
    function getGamesWon(team as Team) as Number {
        var count = games[team];
        for (var i = 0; i < setScores.size(); i++) {
            count += setScores[i].games[team];
        }
        return count;
    }

    // The winner once the match is over: more sets, then more games in the unfinished set, then
    // more points in the current game. Null for a draw, and while the match goes on.
    function getWinner() as Team? {
        if (!matchOver) {
            return null;
        }
        var winner = ahead(getSetsWon(TEAM_US), getSetsWon(TEAM_THEM));
        if (winner == null) {
            winner = ahead(games[TEAM_US], games[TEAM_THEM]);
        }
        if (winner == null) {
            winner = ahead(gamePoints[TEAM_US], gamePoints[TEAM_THEM]);
        }
        return winner;
    }

    function getResult() as MatchResult {
        if (!matchOver) {
            return RESULT_UNFINISHED;
        }
        var winner = getWinner();
        if (winner == null) {
            return RESULT_DRAW;
        }
        return winner == TEAM_US ? RESULT_WIN : RESULT_LOSS;
    }

    // The compact score, our side first: each set's games, or the super tie-break's
    // points, "6-4 3-6 10-8". The unfinished set ends with a star, "6-4 3-2*": it shows once a
    // point is played in it, or as "0-0*" when nothing else would. At most SCORE_TEXT_MAX characters:
    // the FIT Score field.
    function getScoreText() as String {
        return getScoreTextIn(SCORE_TEXT_MAX);
    }

    // getScoreText() in at most max characters. A longer score (Free play's many sets; five sets with
    // two-digit scores take 30) keeps its latest sets, the unfinished one and its star included, after
    // SETS_LEFT_OUT in place of the others: ".. 7-6 6-4 2-1*". A set too long for max on its own (none
    // in a real match) is cut.
    function getScoreTextIn(max as Number) as String {
        var parts = [] as Array<String>;
        var count = setScores.size();
        for (var i = 0; i < count; i++) {
            parts.add(setScores[i].getScore(TEAM_US) + "-" + setScores[i].getScore(TEAM_THEM));
        }
        if (count == 0 || games[TEAM_US] + games[TEAM_THEM] + gamePoints[TEAM_US] + gamePoints[TEAM_THEM] > 0) {
            parts.add(getCurrentSetScore(TEAM_US) + "-" + getCurrentSetScore(TEAM_THEM) + "*");
        }
        var text = parts[parts.size() - 1];
        var first = parts.size() - 1;
        // The latest parts that fit, with room for SETS_LEFT_OUT and its space while some are left out.
        while (first > 0 && text.length() + 1 + parts[first - 1].length()
                + (first > 1 ? SETS_LEFT_OUT.length() + 1 : 0) <= max) {
            first--;
            text = parts[first] + " " + text;
        }
        if (first > 0) {
            text = SETS_LEFT_OUT + " " + text;
        }
        return text.length() > max ? text.substring(0, max) as String : text;
    }

    function copy() as MatchState {
        var other = new MatchState();
        other.pointsWon = [pointsWon[TEAM_US], pointsWon[TEAM_THEM]];
        other.gamePoints = [gamePoints[TEAM_US], gamePoints[TEAM_THEM]];
        other.games = [games[TEAM_US], games[TEAM_THEM]];
        other.gameType = gameType;
        for (var i = 0; i < setScores.size(); i++) {
            other.setScores.add(setScores[i].copy());
        }
        other.deuceMode = deuceMode;
        other.gameDeuceMode = gameDeuceMode;
        other.servingTeam = servingTeam;
        other.ourServer = ourServer;
        other.doubles = doubles;
        other.serverChanged = serverChanged;
        other.changeOfEnds = changeOfEnds;
        other.finishedGames = finishedGames.slice(0, null);
        other.matchOver = matchOver;
        other.eventCount = eventCount;
        other.lastEventTime = lastEventTime;
        other.gameStartTime = gameStartTime;
        other.tally = tally.copy();
        return other;
    }

    // The state as an array, for ScoringEngine's undo snapshots: a few hundred bytes where a copy()
    // takes about a kilobyte late in a match. The lists aren't in it, only their sizes: unpack() takes
    // finishedGames and the tally's game durations, which only grow as the match goes on, from a later
    // state, and setScores from the list the snapshot keeps (an edit replaces the sets).
    function pack() as Array<Number?> {
        var packed = [pointsWon[TEAM_US], pointsWon[TEAM_THEM], gamePoints[TEAM_US], gamePoints[TEAM_THEM],
            games[TEAM_US], games[TEAM_THEM], gameType as Number, deuceMode as Number, gameDeuceMode as Number,
            servingTeam as Number?, ourServer as Number, doubles ? 1 : 0, serverChanged ? 1 : 0,
            changeOfEnds ? 1 : 0, matchOver ? 1 : 0, eventCount, lastEventTime, gameStartTime,
            setScores.size(), finishedGames.size()] as Array<Number?>;
        packed.addAll(tally.pack());
        return packed;
    }

    // The state pack() gave, its finished sets taken from sets, the state's setScores list when it
    // was packed (it only grows until an edit puts a new list in the state), its other lists from
    // later, a state of the same match at least as far into it (the current one, for an undo).
    static function unpack(packed as Array<Number?>, sets as Array<SetScore>, later as MatchState) as MatchState {
        var state = new MatchState();
        state.pointsWon = [packed[0] as Number, packed[1] as Number];
        state.gamePoints = [packed[2] as Number, packed[3] as Number];
        state.games = [packed[4] as Number, packed[5] as Number];
        state.gameType = packed[6] as GameType;
        state.deuceMode = packed[7] as DeuceMode;
        state.gameDeuceMode = packed[8] as DeuceMode;
        state.servingTeam = packed[9] as Team?;
        state.ourServer = packed[10] as Player;
        state.doubles = packed[11] == 1;
        state.serverChanged = packed[12] == 1;
        state.changeOfEnds = packed[13] == 1;
        state.matchOver = packed[14] == 1;
        state.eventCount = packed[15] as Number;
        state.lastEventTime = packed[16];
        state.gameStartTime = packed[17];
        state.setScores = sets.slice(0, packed[18] as Number);
        state.finishedGames = later.finishedGames.slice(0, packed[19] as Number);
        state.tally.unpack(packed, PACKED_FIELDS, later.tally);
        return state;
    }

    function equals(other as Object?) as Boolean {
        if (other instanceof MatchState) {
            return pointsWon[TEAM_US] == other.pointsWon[TEAM_US]
                && pointsWon[TEAM_THEM] == other.pointsWon[TEAM_THEM]
                && gamePoints[TEAM_US] == other.gamePoints[TEAM_US]
                && gamePoints[TEAM_THEM] == other.gamePoints[TEAM_THEM]
                && games[TEAM_US] == other.games[TEAM_US]
                && games[TEAM_THEM] == other.games[TEAM_THEM]
                && gameType == other.gameType
                && sameSetScores(other.setScores)
                && deuceMode == other.deuceMode
                && gameDeuceMode == other.gameDeuceMode
                && servingTeam == other.servingTeam
                && ourServer == other.ourServer
                && doubles == other.doubles
                && serverChanged == other.serverChanged
                && changeOfEnds == other.changeOfEnds
                && sameNumbers(finishedGames, other.finishedGames)
                && matchOver == other.matchOver
                && eventCount == other.eventCount
                && lastEventTime == other.lastEventTime
                && gameStartTime == other.gameStartTime
                && tally.equals(other.tally);
        }
        return false;
    }

    // For test messages.
    function toString() as String {
        var sets = "";
        for (var i = 0; i < setScores.size(); i++) {
            sets += (i == 0 ? "" : ", ") + setScores[i].toString();
        }
        return "points " + pointsWon[TEAM_US] + "-" + pointsWon[TEAM_THEM]
            + ", sets [" + sets + "]"
            + ", game " + gamePoints[TEAM_US] + "-" + gamePoints[TEAM_THEM]
            + ", games " + games[TEAM_US] + "-" + games[TEAM_THEM]
            + ", game type " + gameType
            + ", deuce mode " + deuceMode
            + ", game deuce mode " + gameDeuceMode
            + ", serving " + servingTeam
            + ", our server " + ourServer
            + ", doubles " + doubles
            + ", server changed " + serverChanged
            + ", change of ends " + changeOfEnds
            + ", finished games " + finishedGames
            + ", over " + matchOver
            + ", events " + eventCount
            + ", last at " + lastEventTime
            + ", game from " + gameStartTime
            + ", " + tally;
    }

    private function sameSetScores(others as Array<SetScore>) as Boolean {
        if (others.size() != setScores.size()) {
            return false;
        }
        for (var i = 0; i < setScores.size(); i++) {
            if (!setScores[i].equals(others[i])) {
                return false;
            }
        }
        return true;
    }

    private static function sameNumbers(mine as Array<Number>, others as Array<Number>) as Boolean {
        if (others.size() != mine.size()) {
            return false;
        }
        for (var i = 0; i < mine.size(); i++) {
            if (mine[i] != others[i]) {
                return false;
            }
        }
        return true;
    }

    // The team with the higher count; null when level.
    private static function ahead(us as Number, them as Number) as Team? {
        if (us == them) {
            return null;
        }
        return us > them ? TEAM_US : TEAM_THEM;
    }

    // The deuce at which the mode's next point decides the game; 0 for Advantage, which has none.
    static function decidingDeuce(mode as DeuceMode) as Number {
        if (mode == DEUCE_GOLDEN) {
            return 1;
        } else if (mode == DEUCE_SILVER) {
            return 2;
        } else if (mode == DEUCE_STAR) {
            return 3;
        }
        return 0;
    }
}

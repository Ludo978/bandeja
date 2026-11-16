import Toybox.Application;
import Toybox.Lang;

// What EDIT_SCORE sets: the whole score of a match the watch didn't follow from its start
// (the app started late, points missed). The finished sets as MatchState.setScores holds them (each
// with its games, the tie-break's points when one decided it, or the super tie-break's points, and
// whether End set now gave it), the current set's games, and the current game's points as
// MatchState.gamePoints counts them: 3-3 is 40-40 at deuce 1, 4-3 AD-40 after it, 5-5 deuce 3 (a
// Star point); in a tie-break or the super tie-break, its points. Read-only once in an event.
//
// Stored after its event's code and time (MatchEvent.addTo()), so the event spans several pairs of
// the log: a pair per finished set, (its games as us x 100 + them) x 10 + its
// flags (1: won by them, 2: given by End set now, 4: the super tie-break), then its tie-break's or
// super tie-break's points as us x 100 + them, -1 for none; then a pair for the current set, its
// games and the game's points, each as us x 100 + them. The values are stored: never change them.
class ScoreEdit {

    // The most games or points an edit gives a team in a set or a game: two decimal digits in the
    // stored form, far beyond any real match. Also the most finished sets an edit holds (Free play has no
    // last set).
    static const MAX = 99;
    // Numbers in the stored form for each finished set, and for the current set.
    static const SET_NUMBERS = 2;

    // A team pair in one Number: us x PAIR + them.
    private static const PAIR = 100;
    // A finished set's games pair x FLAGS + its flags.
    private static const FLAGS = 10;
    private static const FLAG_THEM = 1;
    private static const FLAG_ENDED_EARLY = 2;
    private static const FLAG_SUPER_TIE_BREAK = 4;
    private static const FLAGS_ALL = 8;
    private static const NO_TIE_BREAK = -1;

    // The finished sets, oldest first.
    var sets as Array<SetScore>;
    // The current set's games per Team, 0-0 in the super tie-break.
    var games as Array<Number>;
    // The current game's points per Team: a regular game's point counts, or a tie-break's points.
    var points as Array<Number>;

    function initialize(sets as Array<SetScore>, games as Array<Number>, points as Array<Number>) {
        self.sets = sets;
        self.games = games;
        self.points = points;
    }

    // Numbers in the stored form, after the event's code and time.
    function getSize() as Number {
        return SET_NUMBERS * (sets.size() + 1);
    }

    // Appends the stored form to a log.
    function addTo(log as Array<Application.Storage.ValueType>) as Void {
        for (var i = 0; i < sets.size(); i++) {
            var set = sets[i];
            var flags = (set.winner == TEAM_THEM ? FLAG_THEM : 0) + (set.endedEarly ? FLAG_ENDED_EARLY : 0)
                + (set.superTieBreak ? FLAG_SUPER_TIE_BREAK : 0);
            log.add(pair(set.games) * FLAGS + flags);
            var points = set.tieBreakPoints;
            log.add(points == null ? NO_TIE_BREAK : pair(points));
        }
        log.add(pair(games));
        log.add(pair(points));
    }

    // The edit stored at offset in log with count finished sets (the caller checked that the log holds
    // them); null when a value isn't a Number of the stored form, or out of range.
    static function fromLog(log as Array, offset as Number, count as Number) as ScoreEdit? {
        var sets = [] as Array<SetScore>;
        for (var i = 0; i < count; i++) {
            var code = log[offset] as Object?;
            var tieBreak = log[offset + 1] as Object?;
            if (!(code instanceof Number) || !(tieBreak instanceof Number) || code < 0 || code % FLAGS >= FLAGS_ALL
                    || tieBreak < NO_TIE_BREAK) {
                return null;
            }
            var flags = code % FLAGS;
            sets.add(new SetScore(pairOf(code / FLAGS), tieBreak == NO_TIE_BREAK ? null : pairOf(tieBreak),
                (flags & FLAG_SUPER_TIE_BREAK) != 0, (flags & FLAG_THEM) != 0 ? TEAM_THEM : TEAM_US,
                (flags & FLAG_ENDED_EARLY) != 0));
            offset += SET_NUMBERS;
        }
        var games = log[offset] as Object?;
        var points = log[offset + 1] as Object?;
        if (!(games instanceof Number) || !(points instanceof Number) || games < 0 || points < 0) {
            return null;
        }
        var edit = new ScoreEdit(sets, pairOf(games), pairOf(points));
        return edit.isValid() ? edit : null;
    }

    // Two counts per pair, each 0 to MAX, a winner for each set and MAX sets at most: what the stored form
    // can hold. Whether the format allows the score is canApply()'s.
    function isValid() as Boolean {
        if (!isPair(games) || !isPair(points) || sets.size() > MAX) {
            return false;
        }
        for (var i = 0; i < sets.size(); i++) {
            var set = sets[i];
            var tieBreak = set.tieBreakPoints;
            if (!isPair(set.games) || (tieBreak != null && !isPair(tieBreak))
                    || (set.winner != TEAM_US && set.winner != TEAM_THEM)) {
                return false;
            }
        }
        return true;
    }

    // Whether the edit can follow state, a match in config not over: every finished set is
    // one the format allows, played out or given by End set now, the super tie-break where the format
    // has it; neither team has the sets that win the match; the set in progress isn't won, nor its
    // game, and a regular game isn't past its deciding point, under the rule it would be played with;
    // and the score changes (an edit that changes nothing would make an undo that changes nothing).
    function canApply(config as MatchConfig, state as MatchState) as Boolean {
        var won = [0, 0];
        for (var i = 0; i < sets.size(); i++) {
            var set = sets[i];
            if (set.superTieBreak != config.isSuperTieBreakSet(i) || !isFinishedSet(config, set)) {
                return false;
            }
            won[set.winner] += 1;
        }
        if (config.winsMatch(won[TEAM_US]) || config.winsMatch(won[TEAM_THEM])) {
            return false;
        }
        var type = getGameType(config);
        if (type == GAME_SUPER_TIE_BREAK) {
            if (games[TEAM_US] != 0 || games[TEAM_THEM] != 0) {
                return false;
            }
        } else if (!isSetInProgress(config, games[TEAM_US], games[TEAM_THEM])) {
            return false;
        }
        return isGameInProgress(config, type, getGameDeuceMode(state), points[TEAM_US], points[TEAM_THEM])
            && !isScoreOf(state);
    }

    // The game in progress after the edit: the super tie-break in the format's final set when it has
    // one, a tie-break at T-T, otherwise a regular game.
    function getGameType(config as MatchConfig) as GameType {
        if (config.isSuperTieBreakSet(sets.size())) {
            return GAME_SUPER_TIE_BREAK;
        }
        var at = config.tieBreakAt;
        return config.hasTieBreak && games[TEAM_US] == at && games[TEAM_THEM] == at ? GAME_TIE_BREAK : GAME_REGULAR;
    }

    // The deuce rule of the game after the edit, in state before it: the game in progress goes on with
    // its rule, and at 0-0, as any game before its first point, takes the mode chosen last.
    function getGameDeuceMode(state as MatchState) as DeuceMode {
        return points[TEAM_US] == 0 && points[TEAM_THEM] == 0 ? state.deuceMode : state.gameDeuceMode;
    }

    // The score is the state's own: its finished sets, the current set's games and the game's points.
    function isScoreOf(state as MatchState) as Boolean {
        var others = state.setScores;
        if (others.size() != sets.size() || !samePair(games, state.games) || !samePair(points, state.gamePoints)) {
            return false;
        }
        for (var i = 0; i < sets.size(); i++) {
            if (!sets[i].equals(others[i])) {
                return false;
            }
        }
        return true;
    }

    function equals(other as Object?) as Boolean {
        if (!(other instanceof ScoreEdit) || other.sets.size() != sets.size() || !samePair(games, other.games)
                || !samePair(points, other.points)) {
            return false;
        }
        for (var i = 0; i < sets.size(); i++) {
            if (!sets[i].equals(other.sets[i])) {
                return false;
            }
        }
        return true;
    }

    // "6-4 to 0, 7-6 (7-5) to 0 | 2-1 2-1", for test messages, an invalid edit's included.
    function toString() as String {
        var text = "";
        for (var i = 0; i < sets.size(); i++) {
            text += (i == 0 ? "" : ", ") + (sets[i].games.size() == 2 ? sets[i].toString() : sets[i].games.toString());
        }
        return text + " | " + pairText(games) + " " + pairText(points);
    }

    private static function pairText(values as Array<Number>) as String {
        return values.size() == 2 ? values[TEAM_US] + "-" + values[TEAM_THEM] : values.toString();
    }

    // A finished set as the format allows it, its winner as it says. Public, like the two
    // below, for the Edit score menu's lists (EditScoreRules), which offer only what an edit accepts.
    static function isFinishedSet(config as MatchConfig, set as SetScore) as Boolean {
        var winner = set.winner;
        var loser = MatchState.otherTeam(winner);
        var games = set.games;
        var points = set.tieBreakPoints;
        if (set.superTieBreak) {
            // Its points are its score; End set now gives it to the team ahead in them, or the one named.
            if (games[TEAM_US] != 0 || games[TEAM_THEM] != 0 || points == null) {
                return false;
            }
            return set.endedEarly
                ? points[winner] >= points[loser] && isGameInProgress(config, GAME_SUPER_TIE_BREAK, DEUCE_ADVANTAGE,
                    points[TEAM_US], points[TEAM_THEM])
                : isWonOnLastPoint(config, GAME_SUPER_TIE_BREAK, points[winner], points[loser]);
        }
        if (set.endedEarly) {
            // End set now: the set was in progress, a tie-break in it dropped, the team given it not behind.
            return points == null && games[winner] >= games[loser]
                && isSetInProgress(config, games[TEAM_US], games[TEAM_THEM]);
        }
        var at = config.tieBreakAt;
        if (points != null) {
            return config.hasTieBreak && games[winner] == at + 1 && games[loser] == at
                && isWonOnLastPoint(config, GAME_TIE_BREAK, points[winner], points[loser]);
        }
        // Won by games: the set was in progress before its last game, short of its tie-break.
        return config.isSetWon(games[winner], games[loser]) && isSetInProgress(config, games[winner] - 1, games[loser])
            && !(config.hasTieBreak && games[winner] - 1 == at && games[loser] == at);
    }

    // Games a set in progress can have: not won by either team, and no more than T each with a tie-break
    // (at T-T the tie-break is played).
    static function isSetInProgress(config as MatchConfig, us as Number, them as Number) as Boolean {
        var at = config.tieBreakAt;
        return !config.isSetWon(us, them) && !config.isSetWon(them, us)
            && (!config.hasTieBreak || (us <= at && them <= at));
    }

    // Points a game in progress can have: not won by either team, and a regular game not past its
    // deciding point under mode (deuce n is n + 2 points each, and the deciding point ends the game).
    static function isGameInProgress(config as MatchConfig, type as GameType, mode as DeuceMode, us as Number,
            them as Number) as Boolean {
        if (config.isGameWon(type, us, them) || config.isGameWon(type, them, us)) {
            return false;
        }
        var deciding = MatchState.decidingDeuce(mode);
        return type != GAME_REGULAR || deciding == 0 || (us <= deciding + 2 && them <= deciding + 2);
    }

    // The game, a tie-break or the super tie-break, was won by its last point, so play stopped there.
    private static function isWonOnLastPoint(config as MatchConfig, type as GameType, won as Number,
            lost as Number) as Boolean {
        return config.isGameWon(type, won, lost) && !config.isGameWon(type, won - 1, lost);
    }

    private static function isPair(values as Array<Number>) as Boolean {
        return values.size() == 2 && values[0] >= 0 && values[0] <= MAX && values[1] >= 0 && values[1] <= MAX;
    }

    private static function samePair(mine as Array<Number>, others as Array<Number>) as Boolean {
        return mine[TEAM_US] == others[TEAM_US] && mine[TEAM_THEM] == others[TEAM_THEM];
    }

    private static function pair(values as Array<Number>) as Number {
        return values[TEAM_US] * PAIR + values[TEAM_THEM];
    }

    private static function pairOf(value as Number) as Array<Number> {
        return [value / PAIR, value % PAIR];
    }
}

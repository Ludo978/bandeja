import Toybox.Application;
import Toybox.Lang;

// A line of the summary's set table: a finished set, or the one the match ended in.
class SummaryRow {

    // After SET n or SUPER TB on the set the match ended in (End match), as in the score text.
    static const STAR = "*";

    // The set's number, from 1.
    var setNumber as Number;
    // The final set played as a super tie-break: SUPER TB in place of SET n.
    var superTieBreak as Boolean;
    // Indexed by Team: the set's games, or the super tie-break's points (SetScore.getScore()).
    var score as Array<Number>;
    // The team the set went to; null for the set the match ended in, starred.
    var winner as Team?;

    function initialize(setNumber as Number, superTieBreak as Boolean, score as Array<Number>, winner as Team?) {
        self.setNumber = setNumber;
        self.superTieBreak = superTieBreak;
        self.score = score;
        self.winner = winner;
    }
}

// A saved match as the history keeps it and as its summary shows it: the summary
// is worked out from this record, at the match end (HistoryRecord.of()) as from the history
// (fromValue()), so a stored match's summary shows what its own summary showed. Never the event
// log: the date (the match start), the format, the result, the set table, the stats as they stood at
// the save (MatchState.getStats()) and the activity's timer, average and maximum heart rates and
// calories.
//
// Stored form (toValue()): a dictionary typed for Application.Storage, with (keys never renamed)
//   "start"    the match start, seconds (Time.now().value()): the match's date
//   "config"   the format, in MatchConfig.toDictionary()'s form, as picked for the match (a deuce
//              mode changed during it isn't in it)
//   "result"   the MatchResult (the FIT Result codes)
//   "sets"     the set table, ROW_SIZE values a row: our score, theirs, the winner (a Team, null for
//              the set the match ended in) and the super tie-break (a Boolean)
//   "stats"    the stats in statsValue()'s order, null for a stat the match doesn't give (serve
//              tracking off, no game won, no point); the key is missing for a record with no stats
//   "activity" the timer in seconds, the average and maximum heart rates and the calories, each null
//              when the watch didn't give it
//   "earlier"  optional: [ours, theirs], the sets each team won before the ones in "sets", which
//              keeps the latest ROWS_MAX rows (Free play's sets have no end); missing when none is left
//              out, as in every record stored before
//   "names"    optional: [ours, theirs], the team names typed in the Garmin Connect app when
//              the match was saved (Settings.getTeamNames()), each a String or null for none; missing
//              when neither team had one, as in every record stored before, which shows US / THEM
// A key or a stat added later must be optional with a default, and a stat goes at the end of "stats",
// so the records stored by older versions keep loading; unknown keys are ignored.
class HistoryRecord {

    // Values a row takes in "sets".
    static const ROW_SIZE = 4;
    // The most rows a record keeps, the latest: the summary's table holds them on its own page,
    // five as a best of 5's, so no other format ever has more.
    static const ROWS_MAX = 5;
    // Values in "stats" (statsValue()'s order: never reorder, add at the end), and the places never null.
    static const STATS_SIZE = 26;
    private static const REQUIRED_STATS = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12] as Array<Number>;

    // When the match started (seconds, wall clock): its date.
    var start as Number;
    var config as MatchConfig;
    var result as MatchResult;
    // The set table: the finished sets, then the set the match ended in where the score text stars it,
    // ROWS_MAX at most, the latest.
    var rows as Array<SummaryRow>;
    // The sets each team won before the rows (none but in a Free play of more than ROWS_MAX sets),
    // indexed by Team.
    var earlier as Array<Number> = [0, 0];
    // Null shows every stat as none. Read back from storage, gameDurations holds the longest game only.
    var stats as MatchStats?;
    // The activity's timer in seconds (the summary's duration), its average and maximum heart rates and
    // its calories, each null when the watch doesn't give it.
    var timer as Number?;
    var averageHeartRate as Number?;
    var maxHeartRate as Number?;
    var calories as Number?;
    // The team names, indexed by Team, each null for none (US / THEM), as Settings.readTeamName() gives
    // them: kept with the match, so a later rename leaves it as it was.
    var names as Array<String?> = [null, null];

    // activity: [timer seconds, average heart rate, maximum heart rate, calories], each nullable
    // (MatchFlow.activityValues()). Past ROWS_MAX rows, the first ones go into earlier: they are
    // finished sets, the set the match ended in being the last row.
    function initialize(start as Number, config as MatchConfig, result as MatchResult, rows as Array<SummaryRow>,
            stats as MatchStats?, activity as Array<Number?>) {
        self.start = start;
        self.config = config;
        self.result = result;
        var dropped = rows.size() - ROWS_MAX;
        for (var i = 0; i < dropped; i++) {
            var winner = rows[i].winner;
            if (winner != null) {
                earlier[winner] += 1;
            }
        }
        self.rows = dropped > 0 ? rows.slice(dropped, null) : rows;
        self.stats = stats;
        timer = activity[0];
        averageHeartRate = activity[1];
        maxHeartRate = activity[2];
        calories = activity[3];
    }

    // The match as it stands, its stats added up with the score (no replay), and the activity's values.
    static function of(match as CurrentMatch, activity as Array<Number?>) as HistoryRecord {
        var state = match.getState();
        return new HistoryRecord(match.start, match.engine.getConfig(), state.getResult(), rowsOf(state),
            state.getStats(match.start), activity);
    }

    // The finished sets, then the set the match ended in where the score text stars it
    // (MatchState.getScoreText()): once a point was played in it, or 0-0 when nothing else would
    // show. A match won, or ended right after a set, has none: its next set is still 0-0. A match
    // saved before its end has its set in progress there too.
    static function rowsOf(state as MatchState) as Array<SummaryRow> {
        var rows = [] as Array<SummaryRow>;
        var sets = state.setScores;
        for (var i = 0; i < sets.size(); i++) {
            var set = sets[i];
            rows.add(new SummaryRow(i + 1, set.superTieBreak, [set.getScore(TEAM_US), set.getScore(TEAM_THEM)],
                set.winner));
        }
        var played = state.games[TEAM_US] + state.games[TEAM_THEM] + state.gamePoints[TEAM_US]
            + state.gamePoints[TEAM_THEM];
        if (sets.size() == 0 || played > 0) {
            rows.add(new SummaryRow(sets.size() + 1, state.gameType == GAME_SUPER_TIE_BREAK,
                [state.getCurrentSetScore(TEAM_US), state.getCurrentSetScore(TEAM_THEM)], null));
        }
        return rows;
    }

    // A point was played: a match saved before its first point isn't kept.
    function hasPoint() as Boolean {
        var m = stats;
        return m != null && m.pointsWon + m.pointsLost > 0;
    }

    // Some sets are left out before the rows (earlier).
    function hasEarlier() as Boolean {
        return earlier[TEAM_US] + earlier[TEAM_THEM] > 0;
    }

    // Sets won, indexed by Team, those before the rows included.
    function getSetsWon() as Array<Number> {
        var sets = [earlier[TEAM_US], earlier[TEAM_THEM]];
        for (var i = 0; i < rows.size(); i++) {
            var winner = rows[i].winner;
            if (winner != null) {
                sets[winner]++;
            }
        }
        return sets;
    }

    function toValue() as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType> {
        var sets = [] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < rows.size(); i++) {
            var row = rows[i];
            var winner = row.winner;
            sets.addAll([row.score[TEAM_US], row.score[TEAM_THEM], winner != null ? winner as Number : null,
                row.superTieBreak]);
        }
        var value = {
            "start" => start,
            "config" => config.toDictionary(),
            "result" => result as Number,
            "sets" => sets,
            "activity" => [timer, averageHeartRate, maxHeartRate, calories] as Array<Application.Storage.ValueType>
        } as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>;
        var m = stats;
        if (m != null) {
            value["stats"] = statsValue(m);
        }
        if (hasEarlier()) {
            value["earlier"] = [earlier[TEAM_US], earlier[TEAM_THEM]] as Array<Application.Storage.ValueType>;
        }
        if (names[TEAM_US] != null || names[TEAM_THEM] != null) {
            value["names"] = [names[TEAM_US], names[TEAM_THEM]] as Array<Application.Storage.ValueType>;
        }
        return value;
    }

    // The record in value (toValue()'s form), or null when it can't be read: a key missing or
    // mistyped, an invalid format, a result, a row or a stat out of place, names that aren't two
    // Strings or nulls. A stored name goes through Settings.readTeamName() again. Never throws.
    static function fromValue(value as Object?) as HistoryRecord? {
        try {
            if (!(value instanceof Dictionary)) {
                return null;
            }
            var start = value.get("start") as Object?;
            var config = MatchConfig.fromDictionary(value.get("config") as Object?);
            var result = value.get("result") as Object?;
            var storedEarlier = value.get("earlier") as Object?;
            var earlier = storedEarlier == null ? [0, 0] : numbers(storedEarlier, 2);
            if (earlier == null || earlier[TEAM_US] == null || earlier[TEAM_THEM] == null) {
                return null;
            }
            var rows = rowsFrom(value.get("sets") as Object?, 1 + (earlier[TEAM_US] as Number) + (earlier[TEAM_THEM] as Number));
            var activity = numbers(value.get("activity") as Object?, 4);
            if (!(start instanceof Number) || config == null || !(result instanceof Number) || result < RESULT_LOSS
                    || result > RESULT_DRAW || rows == null || rows.size() > ROWS_MAX || activity == null) {
                return null;
            }
            var names = namesFrom(value.get("names") as Object?);
            if (names == null) {
                return null;
            }
            var stats = null as MatchStats?;
            var storedStats = value.get("stats") as Object?;
            if (storedStats != null) {
                stats = statsFrom(storedStats);
                if (stats == null) {
                    return null;
                }
            }
            var record = new HistoryRecord(start, config, result as MatchResult, rows, stats, activity);
            record.earlier = [earlier[TEAM_US] as Number, earlier[TEAM_THEM] as Number];
            record.names = names;
            return record;
        } catch (e) {
            return null;
        }
    }

    // toValue()'s "names", [null, null] when it's missing, or null: not an array of two Strings or
    // nulls. Values past the two come from a later version: ignored.
    private static function namesFrom(value as Object?) as Array<String?>? {
        if (value == null) {
            return [null, null];
        }
        if (!(value instanceof Array) || value.size() < 2) {
            return null;
        }
        var names = [null, null] as Array<String?>;
        for (var team = 0; team < 2; team++) {
            var name = value[team] as Object?;
            if (name != null && !(name instanceof String)) {
                return null;
            }
            names[team] = Settings.readTeamName(name);
        }
        return names;
    }

    // The stats as "stats" holds them: the points, games and sets won and lost, the longest game's
    // seconds, the deciding points and tie-breaks played and won, the average time per point, our
    // longest streak, then the serve stats (null with serve tracking off), in MatchStats' order.
    private static function statsValue(m as MatchStats) as Array<Application.Storage.ValueType> {
        var longest = m.longestGame;
        return [m.pointsWon, m.pointsLost, m.gamesWon, m.gamesLost, m.setsWon, m.setsLost,
            longest != null ? m.gameDurations[longest] : null,
            m.decidingPointsPlayed, m.decidingPointsWon, m.tieBreaksPlayed, m.tieBreaksWon,
            m.averagePointTime, m.longestStreak,
            m.servePointsPlayed, m.servePointsWon, m.returnPointsPlayed, m.returnPointsWon,
            m.serviceGamesPlayed, m.serviceGamesHeld, m.breaksConceded, m.returnGamesPlayed, m.breaksWon,
            m.breakPointsPlayed, m.breakPointsConverted, m.breakPointsFaced, m.breakPointsSaved
        ] as Array<Application.Storage.ValueType>;
    }

    // statsValue()'s form, or null. Values past STATS_SIZE come from a later version: ignored.
    private static function statsFrom(value as Object?) as MatchStats? {
        var v = numbers(value, STATS_SIZE);
        if (v == null) {
            return null;
        }
        for (var i = 0; i < REQUIRED_STATS.size(); i++) {
            if (v[REQUIRED_STATS[i]] == null) {
                return null;
            }
        }
        var m = new MatchStats();
        m.pointsWon = v[0] as Number;
        m.pointsLost = v[1] as Number;
        m.gamesWon = v[2] as Number;
        m.gamesLost = v[3] as Number;
        m.setsWon = v[4] as Number;
        m.setsLost = v[5] as Number;
        var longest = v[6];
        if (longest != null) {
            m.gameDurations = [longest];
            m.longestGame = 0;
        }
        m.decidingPointsPlayed = v[7] as Number;
        m.decidingPointsWon = v[8] as Number;
        m.tieBreaksPlayed = v[9] as Number;
        m.tieBreaksWon = v[10] as Number;
        m.averagePointTime = v[11];
        m.longestStreak = v[12] as Number;
        m.servePointsPlayed = v[13];
        m.servePointsWon = v[14];
        m.returnPointsPlayed = v[15];
        m.returnPointsWon = v[16];
        m.serviceGamesPlayed = v[17];
        m.serviceGamesHeld = v[18];
        m.breaksConceded = v[19];
        m.returnGamesPlayed = v[20];
        m.breaksWon = v[21];
        m.breakPointsPlayed = v[22];
        m.breakPointsConverted = v[23];
        m.breakPointsFaced = v[24];
        m.breakPointsSaved = v[25];
        return m;
    }

    // toValue()'s "sets", the first row set number first, or null: whole rows, scores that are numbers of
    // 0 or more, a winner that is a team or null, a Boolean super tie-break.
    private static function rowsFrom(value as Object?, first as Number) as Array<SummaryRow>? {
        if (!(value instanceof Array) || value.size() % ROW_SIZE != 0) {
            return null;
        }
        var rows = [] as Array<SummaryRow>;
        for (var i = 0; i < value.size(); i += ROW_SIZE) {
            var us = value[i] as Object?;
            var them = value[i + 1] as Object?;
            var winner = value[i + 2] as Object?;
            var superTieBreak = value[i + 3] as Object?;
            if (!(us instanceof Number) || !(them instanceof Number) || us < 0 || them < 0
                    || (winner != null && (!(winner instanceof Number) || (winner != TEAM_US && winner != TEAM_THEM)))
                    || !(superTieBreak instanceof Boolean)) {
                return null;
            }
            rows.add(new SummaryRow(first + i / ROW_SIZE, superTieBreak, [us, them], winner as Team?));
        }
        return rows;
    }

    // value's first count values, each a Number of 0 or more or null; null when value isn't an array of
    // at least count of them.
    private static function numbers(value as Object?, count as Number) as Array<Number?>? {
        if (!(value instanceof Array) || value.size() < count) {
            return null;
        }
        var list = [] as Array<Number?>;
        for (var i = 0; i < count; i++) {
            var item = value[i] as Object?;
            if (item != null && (!(item instanceof Number) || item < 0)) {
                return null;
            }
            list.add(item as Number?);
        }
        return list;
    }
}

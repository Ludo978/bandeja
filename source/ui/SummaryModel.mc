import Toybox.Lang;

// A stat on the summary: its label and its value as shown.
class SummaryStat {

    var label as ResourceId;
    var value as String;

    function initialize(label as ResourceId, value as String) {
        self.label = label;
        self.value = value;
    }
}

// What the match summary shows (mockup "Match summary"), worked out once when it opens,
// from the match's record (HistoryRecord), the one the history keeps, so a stored match's
// summary shows the same; without the screen, so it's unit-tested: SummaryView loads the
// strings and draws it.
//
// The header says the result, WON in our color or LOST in theirs, DRAW in white (an early end);
// the sets score, our side first; the set table, one row per finished set (SET n, SUPER TB, or
// TIE-BREAK for Tie-break only's), and the set the match ended in when End match stopped it during
// one, starred (as the score text), each set's winner in its color and the loser in grey. Then the stats, as the
// mockup's grid shows them: the duration (the activity timer), the average heart rate, the points
// won-lost and the serve points won %; on the pages below, the maximum heart rate, the calories, the
// games won-lost, the breaks won-conceded, the deciding points and tie-breaks won / played, the
// break points won and saved, the return points won % and the longest game, then the average time
// per point and our best streak (as the stats page writes them). A value the watch or the match
// doesn't give is NONE: a heart rate the watch has no reading for, the serve stats with serve
// tracking off, a percentage of nothing played, the average with no point.
//
// Pages: the first holds the header, the sets score and the table, with the grid under it when the
// table has GRID_ROWS rows or fewer (always but in best of 5); the stats the first page doesn't hold
// follow on pages of PAGE_STATS.
//
// The team names over the table's columns: the record's, typed in the Garmin Connect app,
// US and THEM for a team with none, in capitals like them (nameText()). Each is centered on its
// column, unless that would bring it closer than NAMES_GAP / 2 to the middle between the columns:
// then it moves out, ours to the left and theirs to the right (nameCenters()), so the defaults stay
// where the mockup has them and two long names keep apart, each on its own side.
class SummaryModel {

    static const NONE = "--";
    // The set table rows the first page holds with the grid under them (the mockup's 3).
    static const GRID_ROWS = 3;
    // The stats in the first page's grid, and on each later page.
    static const GRID_STATS = 4;
    static const PAGE_STATS = 6;
    // The set table's columns, ours then theirs (mockup x): the team names sit over them.
    static const COLUMNS = [262, 322] as Array<Number>;
    // The least room between the two team names, about the middle between the columns.
    static const NAMES_GAP = 16;

    var result as MatchResult;
    // Sets won, indexed by Team.
    var sets as Array<Number>;
    var rows as Array<SummaryRow>;
    // The match was Tie-break only: its one row is TIE-BREAK, not SUPER TB.
    var tieBreakOnly as Boolean;
    // Every stat, in page order: the grid's first.
    var stats as Array<SummaryStat>;
    // The team names, indexed by Team, null for none (shown as US / THEM). The match's own summary
    // takes them again when a change comes from the Garmin Connect app (SummaryView.applySettings()).
    var names as Array<String?>;

    // record is the match over, as HistoryRecord.of() takes it when the summary opens, or as the
    // history read it back: its stats (null shows none) and the activity's timer, average and
    // maximum heart rates and calories, each null when the watch didn't give it.
    function initialize(record as HistoryRecord) {
        result = record.result;
        sets = record.getSetsWon();
        rows = record.rows;
        tieBreakOnly = record.config.isTieBreakOnly();
        names = [record.names[TEAM_US], record.names[TEAM_THEM]];
        var m = record.stats;
        var timerSeconds = record.timer;
        stats = [
            new SummaryStat(Rez.Strings.StatDuration,
                timerSeconds != null ? TimeText.duration(timerSeconds, true) : NONE),
            new SummaryStat(Rez.Strings.StatAvgHr, number(record.averageHeartRate)),
            new SummaryStat(Rez.Strings.StatPoints, m != null ? pair(m.pointsWon, m.pointsLost) : NONE),
            new SummaryStat(Rez.Strings.StatServe, m != null ? percent(m.getServePointsWonPercent()) : NONE),
            new SummaryStat(Rez.Strings.StatMaxHr, number(record.maxHeartRate)),
            new SummaryStat(Rez.Strings.DataCalories, number(record.calories))
        ];
        if (m == null) {
            var labels = [Rez.Strings.StatGames, Rez.Strings.StatBreaks, Rez.Strings.StatDeciding,
                Rez.Strings.StatTieBreaks, Rez.Strings.StatBreakPointsWon, Rez.Strings.StatBreakPointsSaved,
                Rez.Strings.StatReturn, Rez.Strings.StatLongestGame, Rez.Strings.StatPerPoint, Rez.Strings.StatStreak];
            for (var i = 0; i < labels.size(); i++) {
                stats.add(new SummaryStat(labels[i], NONE));
            }
            return;
        }
        var breaksWon = m.breaksWon;
        var breaksConceded = m.breaksConceded;
        var longest = m.longestGame;
        var average = m.averagePointTime;
        stats.addAll([
            new SummaryStat(Rez.Strings.StatGames, pair(m.gamesWon, m.gamesLost)),
            new SummaryStat(Rez.Strings.StatBreaks,
                breaksWon != null && breaksConceded != null ? pair(breaksWon, breaksConceded) : NONE),
            new SummaryStat(Rez.Strings.StatDeciding, outOf(m.decidingPointsWon, m.decidingPointsPlayed)),
            new SummaryStat(Rez.Strings.StatTieBreaks, outOf(m.tieBreaksWon, m.tieBreaksPlayed)),
            new SummaryStat(Rez.Strings.StatBreakPointsWon, outOf(m.breakPointsConverted, m.breakPointsPlayed)),
            new SummaryStat(Rez.Strings.StatBreakPointsSaved, outOf(m.breakPointsSaved, m.breakPointsFaced)),
            new SummaryStat(Rez.Strings.StatReturn, percent(m.getReturnPointsWonPercent())),
            new SummaryStat(Rez.Strings.StatLongestGame,
                longest != null ? TimeText.duration(m.gameDurations[longest], false) : NONE),
            new SummaryStat(Rez.Strings.StatPerPoint, average != null ? TimeText.duration(average, false) : NONE),
            new SummaryStat(Rez.Strings.StatStreak, m.longestStreak.toString())
        ]);
    }

    // WON, LOST or DRAW; UNFINISHED for a match saved before its end (the pause menu's Save, the low
    // battery save), which only the history shows: the match's own summary opens once the
    // match is over.
    static function headerString(result as MatchResult) as ResourceId? {
        return result == RESULT_WIN ? Rez.Strings.SummaryWon
            : result == RESULT_LOSS ? Rez.Strings.SummaryLost
            : result == RESULT_DRAW ? Rez.Strings.SummaryDraw
            : result == RESULT_UNFINISHED ? Rez.Strings.SummaryUnfinished
            : null;
    }

    // The winner's color in the theme, white for a draw and an unfinished match.
    static function headerColor(result as MatchResult, theme as ThemeSetting) as Number {
        return result == RESULT_WIN ? Palette.teamColor(theme, TEAM_US)
            : result == RESULT_LOSS ? Palette.teamColor(theme, TEAM_THEM)
            : Palette.TEXT;
    }

    // A row's label: SET n (the score screen's SET $1$, which takes the set's number), SUPER TB for the
    // final set's super tie-break, or TIE-BREAK (the banner's word) for Tie-break only's one set.
    function rowLabel(row as SummaryRow) as ResourceId {
        if (!row.superTieBreak) {
            return Rez.Strings.CaptionSet;
        }
        return tieBreakOnly ? Rez.Strings.BannerTieBreak : Rez.Strings.SummarySuperTb;
    }

    // A team's number in a row: in the team's color in the theme when it won the set, grey otherwise
    // (the loser, and both in the set the match ended in).
    static function scoreColor(row as SummaryRow, team as Team, theme as ThemeSetting) as Number {
        return row.winner == team ? Palette.teamColor(theme, team) : Palette.MUTED;
    }

    // A team name as the summary writes it: in capitals, as US and THEM, each character that has a
    // capital the watch's fonts draw (Settings.isNameChar()) as that capital, any other as typed ("ß",
    // whose capital "ẞ" they lack).
    static function nameText(name as String) as String {
        var chars = name.toCharArray();
        var text = "";
        for (var i = 0; i < chars.size(); i++) {
            var char = chars[i].toString();
            var upper = char.toUpper();
            var drawn = upper.length() > 0;
            var capitals = upper.toCharArray();
            for (var j = 0; j < capitals.size(); j++) {
                drawn = drawn && Settings.isNameChar(capitals[j].toNumber());
            }
            text += drawn ? upper : char;
        }
        return text;
    }

    // Where the two team names go, each width wide (mockup pixels): their centers, ours then theirs.
    // Each on its column, moved out if it would come closer than NAMES_GAP / 2 to the middle between
    // the columns.
    static function nameCenters(widths as Array<Float>) as Array<Float> {
        var middle = (COLUMNS[TEAM_US] + COLUMNS[TEAM_THEM]) / 2.0;
        var ours = COLUMNS[TEAM_US].toFloat();
        var theirs = COLUMNS[TEAM_THEM].toFloat();
        var ourRight = middle - NAMES_GAP / 2.0;
        var theirLeft = middle + NAMES_GAP / 2.0;
        if (ours + widths[TEAM_US] / 2.0 > ourRight) {
            ours = ourRight - widths[TEAM_US] / 2.0;
        }
        if (theirs - widths[TEAM_THEM] / 2.0 < theirLeft) {
            theirs = theirLeft + widths[TEAM_THEM] / 2.0;
        }
        return [ours, theirs];
    }

    // "2 - 1", our side first, as the overlay writes a score.
    function getSetsText() as String {
        return sets[TEAM_US] + " - " + sets[TEAM_THEM];
    }

    function getPageCount() as Number {
        var rest = stats.size() - getStats(0).size();
        return 1 + (rest + PAGE_STATS - 1) / PAGE_STATS;
    }

    // The stats on a page: the grid's under the table on the first one when it fits, then the
    // others PAGE_STATS at a time; none past the last page.
    function getStats(page as Number) as Array<SummaryStat> {
        var from = firstStat(page);
        var to = page == 0 ? firstStat(1) : from + PAGE_STATS;
        if (to > stats.size()) {
            to = stats.size();
        }
        return from < to ? stats.slice(from, to) : [] as Array<SummaryStat>;
    }

    // The index in stats of a page's first stat.
    function firstStat(page as Number) as Number {
        if (page == 0) {
            return 0;
        }
        return (rows.size() <= GRID_ROWS ? GRID_STATS : 0) + (page - 1) * PAGE_STATS;
    }

    private static function number(value as Number?) as String {
        return value != null ? value.toString() : NONE;
    }

    // Won-lost, our side first.
    private static function pair(us as Number, them as Number) as String {
        return us + "-" + them;
    }

    // Won / played, NONE when the count needs serve tracking and it was off.
    private static function outOf(won as Number?, played as Number?) as String {
        return won != null && played != null ? won + "/" + played : NONE;
    }

    private static function percent(value as Number?) as String {
        return value != null ? value + "%" : NONE;
    }
}

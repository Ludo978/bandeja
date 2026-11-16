import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The history list's lines, one native menu item per stored match, newest first: its label
// the result and the score, "W 6-4 6-3", its sublabel the date and the duration, "12 Nov · 1h12"; for
// an empty history, one line saying so. Worked out from the records alone, so they're unit-tested;
// HistoryMenu makes the items. What fits was measured in the simulator with the menu's fonts: the
// format doesn't (its summary's table shows the sets and the super tie-break), nor a score longer than
// LABEL_MAX characters, which shows the sets won instead. The glance writes the newest
// match with the same letters and duration (LastMatch, glance code, which holds them), from the value
// glanceValue() gives.
module HistoryText {

    // The longest label shown with each set's score: a best of 5 with one-digit sets ("W 6-4 3-6 7-6
    // 4-6 6-2"), its digits all as wide. Measured on the FR265S, the menu's label font (FONT_TINY, and
    // FONT_AUX1 focused) writes it 304 px wide, of the 316 the focused line shows.
    const LABEL_MAX = 21;

    // [label, sublabel] for each record, in order; one line with no sublabel when there's none.
    function lines(records as Array<HistoryRecord>) as Array<[String, String?]> {
        var lines = [] as Array<[String, String?]>;
        if (records.size() == 0) {
            lines.add([text(Rez.Strings.HistoryEmpty), null]);
        }
        for (var i = 0; i < records.size(); i++) {
            lines.add([label(records[i]), subLabel(records[i])]);
        }
        return lines;
    }

    // The result's letter (W, L or D; none for a match saved unfinished, its summary saying so), then
    // the score: "W 6-4 6-3", "D 6-4 4-6 2-2*", "6-3 2-1*". Past LABEL_MAX characters (two-digit sets
    // in a best of 5, a long Free play), the sets won as the summary writes them: "W 3 - 2".
    function label(record as HistoryRecord) as String {
        var score = score(record);
        // The letter and its space take 2.
        if (score.length() > (resultLetter(record.result) != null ? LABEL_MAX - 2 : LABEL_MAX)) {
            score = setsWon(record);
        }
        return LastMatch.label(record.result as Number, score);
    }

    // The sets won, our side first, as the summary writes them: "2 - 1".
    function setsWon(record as HistoryRecord) as String {
        var sets = record.getSetsWon();
        return sets[TEAM_US] + " - " + sets[TEAM_THEM];
    }

    // The glance's value for record (LastMatch's stored form): its result, its score, its sets won and
    // its timer. A record that keeps only the latest sets (a long Free play) gives the sets won as its
    // score, as its history line shows them.
    function glanceValue(record as HistoryRecord) as Array<Application.Storage.ValueType> {
        var sets = setsWon(record);
        return [record.result as Number, record.hasEarlier() ? sets : score(record), sets, record.timer];
    }

    // Each set's score, our side first, as the summary's table has them: the games, or the super
    // tie-break's points, and the set the match ended in starred, as the score text writes it:
    // "6-4 3-6 10-8", "6-4 3-2*"; after "..", as there, when the record keeps only the latest sets
    // (a long Free play): ".. 6-4 3-6 7-6 2-6 7-5".
    function score(record as HistoryRecord) as String {
        var rows = record.rows;
        var score = record.hasEarlier() ? MatchState.SETS_LEFT_OUT : "";
        for (var i = 0; i < rows.size(); i++) {
            var row = rows[i];
            score += (score.length() == 0 ? "" : " ") + row.score[TEAM_US] + "-" + row.score[TEAM_THEM]
                + (row.winner == null ? SummaryRow.STAR : "");
        }
        return score;
    }

    function resultLetter(result as MatchResult) as ResourceId? {
        return LastMatch.letter(result as Number);
    }

    // The date, then the duration when the watch gave a timer: "12 Nov · 1h12".
    function subLabel(record as HistoryRecord) as String {
        var line = date(record.start);
        var timer = record.timer;
        return timer != null ? line + FormatText.SEPARATOR + duration(timer) : line;
    }

    // The match start's day and month, the month's short name as the watch writes it in its language
    // (Gregorian): "12 Nov", "12 Nov." in French.
    function date(start as Number) as String {
        var info = Gregorian.info(new Time.Moment(start), Time.FORMAT_MEDIUM);
        return Lang.format(text(Rez.Strings.HistoryDate), [info.day, info.month]);
    }

    // "1h12" from an hour on, "48 min" under it, the minutes rounded down; the glance's form.
    function duration(seconds as Number) as String {
        return LastMatch.duration(seconds);
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

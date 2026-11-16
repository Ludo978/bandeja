import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The last saved match as the glance shows it: one small value, written with its history
// record (HistoryStore.add()), so the glance never reads the history (it has 64 KB). It holds no text
// in a language, so the glance writes it in the watch's language of the moment:
//   [result, score, sets, timer]
//   result  the match's MatchResult (the FIT Result codes)
//   score   each set's score, our side first, the set the match ended in starred: "6-4 3-6 10-8"
//           (HistoryText.score(); the sets won for a long Free play, whose record keeps its latest sets)
//   sets    the sets won, our side first, "2 - 1": shown in place of the score when that doesn't fit
//   timer   the activity's timer in seconds, null when the watch gave none
// Values past these four come from a later version: ignored. Glance code: loaded in the glance with
// GlanceView, so it uses nothing of the engine or the screens. The history list writes its lines with
// the same letters and duration (HistoryText).
(:glance)
module LastMatch {

    // Storage key: never rename.
    const KEY = "lastMatch";
    const SIZE = 4;
    // As FormatText's.
    const SEPARATOR = " · ";
    // The result codes as stored, MatchResult's (the engine's, out of the glance's reach): never change.
    const LOSS = 0;
    const WIN = 1;
    const DRAW = 3;

    // The stored value, or null when there's none or the store can't be read.
    function read() as Object? {
        try {
            return Application.Storage.getValue(KEY);
        } catch (e) {
            return null;
        }
    }

    // What the glance shows for value (read()), the line to try first first: "Last: W 6-4 6-3 · 1h12",
    // then the same with the sets won, "Last: W 2 - 0 · 1h12". No value, or one that can't be read: one
    // line saying no match was played yet.
    function lines(value as Object?) as Array<String> {
        if (value instanceof Array && value.size() >= SIZE) {
            var result = value[0] as Object?;
            var score = value[1] as Object?;
            var sets = value[2] as Object?;
            var timer = value[3] as Object?;
            if (result instanceof Number && score instanceof String && sets instanceof String
                    && (timer == null || timer instanceof Number)) {
                var end = timer != null ? SEPARATOR + duration(timer) : "";
                var last = text(Rez.Strings.GlanceLast);
                return [Lang.format(last, [label(result, score) + end]), Lang.format(last, [label(result, sets) + end])];
            }
        }
        return [text(Rez.Strings.HistoryEmpty)];
    }

    // The result's letter, then the score: "W 6-4 6-3"; the score alone for a match saved unfinished or
    // a result this version doesn't know.
    function label(result as Number, score as String) as String {
        var letter = letter(result);
        if (letter == null) {
            return score;
        }
        return score.length() > 0 ? text(letter) + " " + score : text(letter);
    }

    // W, L or D (French V, D, N), by the result's FIT Result code: none for a match saved unfinished.
    function letter(result as Number) as ResourceId? {
        return result == WIN ? Rez.Strings.HistoryWon
            : result == LOSS ? Rez.Strings.HistoryLost
            : result == DRAW ? Rez.Strings.HistoryDraw
            : null;
    }

    // "1h12" from an hour on, "48 min" under it, the minutes rounded down.
    function duration(seconds as Number) as String {
        var minutes = seconds < 0 ? 0 : seconds / 60;
        if (minutes < 60) {
            return Lang.format(text(Rez.Strings.HistoryMinutes), [minutes]);
        }
        return Lang.format(text(Rez.Strings.HistoryHours), [minutes / 60, (minutes % 60).format("%02d")]);
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

import Toybox.Lang;

// The last court time alert given (CourtBooking.alert). The values are stored: never renumber.
enum CourtAlert {
    COURT_NONE = 0,
    COURT_TEN = 1,          // 10 minutes left
    COURT_FIVE = 2,         // 5 minutes left
    COURT_TIME = 3,         // the end time: TIME
    COURT_KEEP_PLAYING = 4  // Keep playing, picked once the time is up: no more alerts, no TIME banner
}

// A timed match's court booking: the booking's end time, picked at match setup, and the
// alerts given, without the screens, so it's unit-tested with times passed in. now is the wall clock
// in seconds (Time.now().value()), so the warm-up, the pauses and a late START never change the time
// left; localSeconds is the watch's clock time, seconds since midnight (System.getClockTime()), which
// the clock times offered at setup follow.
//
// The end time is the next occurrence of the clock time picked, at most 4 hours ahead (endFor()), so
// a booking ending after midnight works. Neither it nor the alerts given are events: undo changes
// neither. The match holder keeps them (CurrentMatch.court) and they're stored with the match
// (MatchStore), so a resume counts down to the same end and gives no alert twice.
class CourtBooking {

    // The warnings, in seconds left; TIME LEFT shows from the second one.
    static const WARNING_TEN = 600;
    static const WARNING_FIVE = 300;
    // The clock times offered: 5-minute steps, at most 4 hours ahead.
    static const STEP = 300;
    static const WINDOW = 4 * 3600;
    // The pre-fill: now + 90 minutes, to the nearest half hour.
    static const PREFILL = 90 * 60;
    static const PREFILL_ROUND = 1800;
    static const DAY = 86400;

    // When the booking ends, in seconds (Time.now().value()'s clock).
    var end as Number;
    var alert as CourtAlert;

    function initialize(end as Number, alert as CourtAlert) {
        self.end = end;
        self.alert = alert;
    }

    // The clock times offered at setup, as minutes since midnight: every STEP after now, up to WINDOW
    // ahead (48 of them), oldest first.
    static function choices(localSeconds as Number) as Array<Number> {
        var times = [] as Array<Number>;
        for (var t = localSeconds / STEP * STEP + STEP; t <= localSeconds + WINDOW; t += STEP) {
            times.add(t % DAY / 60);
        }
        return times;
    }

    // The clock time offered first: now + 90 minutes to the nearest half hour, half way rounding up
    // (bookings end on the hour or the half hour), as minutes since midnight.
    static function prefill(localSeconds as Number) as Number {
        var t = localSeconds + PREFILL + PREFILL_ROUND / 2;
        return t / PREFILL_ROUND * PREFILL_ROUND % DAY / 60;
    }

    // The end time for a clock time picked (minutes since midnight): its next occurrence, at most
    // WINDOW ahead (00:30 picked at 23:10 is in 80 minutes). Further ahead than that it's behind us:
    // a booking already over, never tomorrow's.
    static function endFor(minute as Number, now as Number, localSeconds as Number) as Number {
        var ahead = ((minute * 60 - localSeconds) % DAY + DAY) % DAY;
        if (ahead > WINDOW) {
            ahead -= DAY;
        }
        return now + ahead;
    }

    // The court time left at now, in seconds, never below 0.
    function getLeft(now as Number) as Number {
        var left = end - now;
        return left > 0 ? left : 0;
    }

    function isTimeUp(now as Number) as Boolean {
        return now - end >= 0;
    }

    // The time is up and the player hasn't picked Keep playing: the TIME banner, and Finish and Keep
    // playing in the pause menu.
    function offersFinish(now as Number) as Boolean {
        return isTimeUp(now) && alert != COURT_KEEP_PLAYING;
    }

    // The alert due at now, COURT_NONE when none, and it's given: each once. When a tick skips over
    // a threshold (a menu over the screen, a late tick, a resume), only the last one due is given,
    // and the one skipped never comes. Nothing after Keep playing.
    function take(now as Number) as CourtAlert {
        var left = end - now;
        var due = left <= 0 ? COURT_TIME : left <= WARNING_FIVE ? COURT_FIVE : left <= WARNING_TEN ? COURT_TEN
            : COURT_NONE;
        if (due <= alert) {
            return COURT_NONE;
        }
        alert = due;
        return due;
    }

    // Keep playing, once the time is up: no more alerts, and the TIME banner goes.
    function keepPlaying() as Void {
        alert = COURT_KEEP_PLAYING;
    }

    // The court time's net banner, the lowest priority: TIME LEFT in the last 5 minutes, then
    // TIME until Finish or Keep playing; BANNER_NONE otherwise.
    function getBanner(now as Number) as Banner {
        var left = end - now;
        if (left > WARNING_FIVE) {
            return BANNER_NONE;
        } else if (left > 0) {
            return BANNER_TIME_LEFT;
        }
        return alert == COURT_KEEP_PLAYING ? BANNER_NONE : BANNER_TIME;
    }
}

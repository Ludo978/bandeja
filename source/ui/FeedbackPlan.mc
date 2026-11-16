import Toybox.Lang;

// What may play at an event: the Vibration and Sounds settings, the watch's own
// vibration and tones settings (System.getDeviceSettings()), which always win, and the Change of
// ends alert setting. Feedback.channels() reads them at each event, so a change mid-match
// counts at once.
class FeedbackChannels {

    var vibration as VibrationSetting;
    var sounds as Boolean;
    var vibrateOn as Boolean;
    var tonesOn as Boolean;
    // Off, a change of ends adds nothing to the point's feedback.
    var endsAlert as Boolean;

    function initialize(vibration as VibrationSetting, sounds as Boolean, vibrateOn as Boolean, tonesOn as Boolean,
            endsAlert as Boolean) {
        self.vibration = vibration;
        self.sounds = sounds;
        self.vibrateOn = vibrateOn;
        self.tonesOn = tonesOn;
        self.endsAlert = endsAlert;
    }

    // An important event (game, set, match, change of ends, court time) buzzes unless Vibration is
    // Off, any other only with Every point; nothing buzzes with the watch's vibration off.
    function vibrates(important as Boolean) as Boolean {
        if (!vibrateOn || vibration == VIBRATION_OFF) {
            return false;
        }
        return important || vibration == VIBRATION_EVERY_POINT;
    }

    // The important events' tones: Sounds on and the watch's tones on.
    function beeps() as Boolean {
        return sounds && tonesOn;
    }
}

// The feedback for one event, worked out from the event and the channels: the vibrate
// calls and the tones. Numbers only, so it's unit-tested; Feedback plays it with Attention.
//
// Forerunners only buzz at one strength, so events differ by the count and length of their pulses.
// A pattern alternates pulses and silences, in ms: [on, off, on, ..., on]. One vibrate call plays a
// whole pattern, its silences as zero-duty profiles (a real pause on the FR265), but a call
// takes at most MAX_PROFILES profiles, pulses and silences both, and more crashes the app, uncatchably.
// So a longer pattern is cut at its longest silence (the 600 ms pause before the game or set pulses),
// as often as needed, and each part is a call of its own, started when the silence before it ends.
// The tones are sequences of notes, each one playTone() call, also with its start: a part's tones
// start with its first pulse (the change of ends has one note for each of its two long pulses).
class FeedbackPlan {

    // Pulse and silence lengths, in ms (felt on the wrist on the FR265).
    static const SHORT = 150;
    static const MEDIUM = 400;
    static const LONG = 800;
    // Between the pulses of a group.
    static const GAP = 250;
    // Between the point pulses and the game or set pulses.
    static const PAUSE = 600;

    // From a press that wrote a game's lap to the change of ends' pulses: the watch's own lap alert, a
    // beep and a buzz (about 1 s, estimated), then the PAUSE that sets the parts of a pattern apart,
    // rounded up. Kept: on the watch the pulses are felt apart from the alert.
    static const LAP_ALERT_WAIT = 2000;

    // The most profiles one Attention.vibrate() call takes.
    static const MAX_PROFILES = 8;

    // The vibrate calls, each a pattern of at most MAX_PROFILES steps that starts and ends with a
    // pulse, in the order they play, and when each starts, in ms after the event.
    var calls as Array<Array<Number>> = [] as Array<Array<Number>>;
    var starts as Array<Number> = [] as Array<Number>;
    // The tones, each [frequency in Hz, duration in ms, ...] for one playTone() call, in the order
    // they play, and when each starts, in ms after the event. Empty for none.
    var tones as Array<Array<Number>> = [] as Array<Array<Number>>;
    var toneStarts as Array<Number> = [] as Array<Number>;
    // The event is important and Sounds and the watch's tones are on: addTones() keeps its tones.
    private var _beeps as Boolean = false;

    // After a point that counted: its team's pulses (US 1 short, THEM 2 short); for a game, then a
    // pause and 1 long pulse, and 1 tone; for a set or the match, a pause and 3 long pulses, and
    // rising tones. A point that wins only the point is not important: no buzz with Important only.
    // Nothing of its own when lap: the point wrote its game's lap, and the watch's own lap alert, a
    // beep and a buzz, answers it. So a game or a set plays its pattern only when won
    // again after its winning point was undone (no second lap, no alert); the match point writes no
    // lap. When ends (the point makes the players change ends, ScoreInput.ends) and the alert is on:
    // 2 long pulses more, important, each with its tone. After the point's pulses and a pause; after
    // a lap, LAP_ALERT_WAIT after the press, once the watch's lap alert is over. Never at the match
    // point (the engine never says the ends change once the match is over).
    static function point(team as Team, won as PointWon, lap as Boolean, ends as Boolean,
            channels as FeedbackChannels) as FeedbackPlan {
        ends = ends && won != WON_MATCH && channels.endsAlert;
        var pattern = [] as Array<Number>;
        var tones = [] as Array<Number>;
        if (!lap) {
            pattern = team == TEAM_US ? [SHORT] : [SHORT, GAP, SHORT];
            if (won != WON_POINT) {
                pattern.addAll([PAUSE, LONG]);
                tones = gameTones();
            }
            if (won == WON_SET || won == WON_MATCH) {
                pattern.addAll([GAP, LONG, GAP, LONG]);
                tones = setTones();
            }
        }
        // When the change of ends' pulses start, before the lap's wait.
        var at = 0;
        if (ends) {
            if (pattern.size() > 0) {
                pattern.add(PAUSE);
                at = duration(pattern);
            }
            pattern.addAll([LONG, GAP, LONG]);
        }
        var plan = new FeedbackPlan(pattern, won != WON_POINT || ends, tones, channels);
        if (ends) {
            plan.addTones(at, endsTone());
            plan.addTones(at + LONG + GAP, endsTone());
        }
        return lap ? plan.delay(LAP_ALERT_WAIT) : plan;
    }

    // After an undo, of any event: 1 medium pulse, only with Every point, no tone.
    static function undo(channels as FeedbackChannels) as FeedbackPlan {
        return new FeedbackPlan([MEDIUM], false, [] as Array<Number>, channels);
    }

    // The court time's warnings at T-10 and T-5 and its TIME alert: 3 short pulses, a pause,
    // 3 short again (11 profiles: two calls, the second 1550 ms after the first starts), and 3 tones.
    // Important: they play with Important only.
    static function court(channels as FeedbackChannels) as FeedbackPlan {
        return new FeedbackPlan([SHORT, GAP, SHORT, GAP, SHORT, PAUSE, SHORT, GAP, SHORT, GAP, SHORT], true,
            courtTones(), channels);
    }

    // The court time: 3 falling notes, the last held, unlike a set's rising ones.
    static function courtTones() as Array<Number> {
        return [4000, 200, 3200, 200, 2500, 400];
    }

    // A game: 1 tone. A loud note a small beeper plays well (2500 and 4000 Hz were heard on the FR265).
    static function gameTones() as Array<Number> {
        return [4000, 300];
    }

    // A set or the match: 3 rising notes, the last held.
    static function setTones() as Array<Number> {
        return [2500, 150, 3200, 150, 4000, 400];
    }

    // The change of ends: one note at the start of each of its 2 long pulses, so 2 separate beeps,
    // unlike the other events' runs of notes, and lower than the game's.
    static function endsTone() as Array<Number> {
        return [3200, 400];
    }

    // Any event, from its whole pattern ([on, off, ..., on], any length) starting at the event,
    // whether it's important (it buzzes with Important only) and its tones, played at the event (only
    // if it's important, with Sounds on). point(), undo() and court() build theirs here; addTones()
    // adds later tones, delay() moves the whole plan later.
    function initialize(pattern as Array<Number>, important as Boolean, tones as Array<Number>,
            channels as FeedbackChannels) {
        if (channels.vibrates(important) && pattern.size() > 0) {
            cut(pattern, 0, pattern.size(), 0);
        }
        _beeps = important && channels.beeps();
        addTones(0, tones);
    }

    // Tones that start at ms after the event, after those already added; dropped unless the event is
    // important and Sounds and the watch's tones are on.
    function addTones(at as Number, tones as Array<Number>) as FeedbackPlan {
        if (_beeps && tones.size() > 0) {
            self.tones.add(tones);
            toneStarts.add(at);
        }
        return self;
    }

    // Everything starts ms later.
    function delay(ms as Number) as FeedbackPlan {
        for (var i = 0; i < starts.size(); i++) {
            starts[i] += ms;
        }
        for (var i = 0; i < toneStarts.size(); i++) {
            toneStarts[i] += ms;
        }
        return self;
    }

    // Nothing plays.
    function isEmpty() as Boolean {
        return calls.size() == 0 && tones.size() == 0;
    }

    // When the next call or tones still to play start, in ms after the event, the calls before index
    // call and the tones before index tone being played: the earlier of the two, null when none is
    // left.
    function nextStart(call as Number, tone as Number) as Number? {
        var next = call < starts.size() ? starts[call] : null;
        if (tone < toneStarts.size() && (next == null || toneStarts[tone] < next)) {
            next = toneStarts[tone];
        }
        return next;
    }

    // A pattern's length, in ms.
    static function duration(pattern as Array<Number>) as Number {
        var total = 0;
        for (var i = 0; i < pattern.size(); i++) {
            total += pattern[i];
        }
        return total;
    }

    // Adds pattern[from, to) as calls, the first starting start ms after the event: one call if it
    // fits, otherwise cut at its longest silence (the last one on a tie) and each side the same way.
    private function cut(pattern as Array<Number>, from as Number, to as Number, start as Number) as Void {
        if (to - from <= MAX_PROFILES) {
            calls.add(pattern.slice(from, to));
            starts.add(start);
            return;
        }
        var at = from + 1;
        for (var i = from + 3; i < to - 1; i += 2) {
            if (pattern[i] >= pattern[at]) {
                at = i;
            }
        }
        cut(pattern, from, at, start);
        var next = start;
        for (var i = from; i <= at; i++) {
            next += pattern[i];
        }
        cut(pattern, at + 1, to, next);
    }
}

import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// What can happen in a match. The values are stored: never renumber. A new type gets the
// next number, a payload rule in isValid() and a branch in ScoringEngine.apply().
enum EventType {
    EVENT_POINT_US = 0,
    EVENT_POINT_THEM = 1,
    EVENT_SWAP_OUR_SERVER = 2,  // our two players swap their serving order (doubles only)
    EVENT_FIX_SERVING_TEAM = 3, // payload: the Team serving now
    EVENT_SET_DEUCE_MODE = 4,   // payload: the new DeuceMode, applied from the next game
    EVENT_END_SET = 5,          // payload: the Team given the set when games are level, else null
    EVENT_END_MATCH = 6,        // early end: "End match", court time over
    EVENT_EDIT_SCORE = 7        // no payload: the score it sets is MatchEvent.edit
}

// The values are stored: never renumber. Also the index of per-team arrays in MatchState.
enum Team {
    TEAM_US = 0,
    TEAM_THEM = 1
}

// One entry of the match log. Treat it as read-only once it's in a log.
//
// Stored as two Numbers, its code (getCode()) and its time; EDIT_SCORE adds its score after them
// (ScoreEdit), so it spans several pairs of the log and its code says how many: addTo(), fromLog().
class MatchEvent {

    private static const CODE_PAYLOAD_STEP = 100;
    // A pair of the log: the code and the time.
    private static const PAIR_NUMBERS = 2;

    var type as EventType;
    // Wall clock in seconds since the Unix epoch, taken when the event was created. It survives a
    // reboot, but can go backwards if the watch's clock changes, so nothing relies on its order.
    var time as Number;
    // FIX_SERVING_TEAM: a Team. SET_DEUCE_MODE: a DeuceMode. END_SET: a Team or null. Others: null.
    var payload as Number?;
    // EDIT_SCORE: the score it sets. Others: null.
    var edit as ScoreEdit? = null;

    // Tests and replay pass explicit times; the app creates events with now().
    function initialize(type as EventType, time as Number, payload as Number?) {
        self.type = type;
        self.time = time;
        self.payload = payload;
    }

    // An event happening now, stamped with the watch's clock.
    static function now(type as EventType, payload as Number?) as MatchEvent {
        return new MatchEvent(type, Time.now().value(), payload);
    }

    // EDIT_SCORE at time, setting the score edit.
    static function editScore(time as Number, edit as ScoreEdit) as MatchEvent {
        var event = new MatchEvent(EVENT_EDIT_SCORE, time, null);
        event.edit = edit;
        return event;
    }

    // Known type, payload as the type needs it, time not before 1970. For EDIT_SCORE a score the
    // stored form can hold; whether the format allows it is ScoringEngine.canApply()'s.
    function isValid() as Boolean {
        var score = edit;
        if (time < 0) {
            return false;
        }
        if (type == EVENT_EDIT_SCORE) {
            return payload == null && score != null && score.isValid();
        }
        if (score != null) {
            return false;
        }
        if (type == EVENT_FIX_SERVING_TEAM) {
            return isTeam(payload);
        }
        if (type == EVENT_SET_DEUCE_MODE) {
            return payload != null && payload >= DEUCE_ADVANTAGE && payload <= DEUCE_SILVER;
        }
        if (type == EVENT_END_SET) {
            return payload == null || isTeam(payload);
        }
        return type >= EVENT_POINT_US && type <= EVENT_END_MATCH && payload == null;
    }

    // Type and payload in one stored Number (a valid event only): the type, plus
    // 100 x (payload + 1) when there is one. 203 is FIX_SERVING_TEAM THEM, 304 SET_DEUCE_MODE STAR.
    // EDIT_SCORE: 7 plus 100 x (its finished sets + 1), so 207 for a score with one finished set.
    function getCode() as Number {
        var score = edit;
        if (score != null) {
            return type + CODE_PAYLOAD_STEP * (score.sets.size() + 1);
        }
        return payload == null ? type as Number : type + CODE_PAYLOAD_STEP * (payload + 1);
    }

    // Numbers in the stored form: a pair, more for EDIT_SCORE (a pair per finished set and one for the
    // current set).
    function getSize() as Number {
        var score = edit;
        return PAIR_NUMBERS + (score == null ? 0 : score.getSize());
    }

    // Appends the stored form to a log: the code, the time, then for EDIT_SCORE its score.
    function addTo(log as Array<Application.Storage.ValueType>) as Void {
        log.add(getCode());
        log.add(time);
        var score = edit;
        if (score != null) {
            score.addTo(log);
        }
    }

    // The size of the stored form at offset in a log the engine built, from its code alone.
    static function sizeAt(log as Array<Application.Storage.ValueType>, offset as Number) as Number {
        var code = log[offset] as Number;
        return code % CODE_PAYLOAD_STEP == EVENT_EDIT_SCORE ? PAIR_NUMBERS * (code / CODE_PAYLOAD_STEP + 1) : PAIR_NUMBERS;
    }

    // The event stored at offset in log (addTo()'s form); null when the log doesn't hold all of it, a
    // value isn't a Number of the stored form, or the event is invalid.
    static function fromLog(log as Object?, offset as Number) as MatchEvent? {
        if (!(log instanceof Array) || offset < 0 || offset + PAIR_NUMBERS > log.size()) {
            return null;
        }
        var code = log[offset] as Object?;
        var time = log[offset + 1] as Object?;
        if (!(code instanceof Number) || !(time instanceof Number) || code < 0) {
            return null;
        }
        var slot = code / CODE_PAYLOAD_STEP;
        var type = (code % CODE_PAYLOAD_STEP) as EventType;
        if (type != EVENT_EDIT_SCORE) {
            var event = new MatchEvent(type, time, slot == 0 ? null : slot - 1);
            return event.isValid() ? event : null;
        }
        // The code counts the finished sets, plus one.
        if (slot == 0 || offset + PAIR_NUMBERS + ScoreEdit.SET_NUMBERS * slot > log.size()) {
            return null;
        }
        var score = ScoreEdit.fromLog(log, offset + PAIR_NUMBERS, slot - 1);
        if (score == null) {
            return null;
        }
        var event = editScore(time, score);
        return event.isValid() ? event : null;
    }

    // Reads getCode()'s form and a time; null when either isn't a Number or the event is invalid. An
    // EDIT_SCORE needs its score too, so it's null here: fromLog() reads it. The quick way to read an
    // event of one pair, which the engine's replays try first (the watchdog).
    static function fromCode(code as Object?, time as Object?) as MatchEvent? {
        if (!(code instanceof Number) || !(time instanceof Number) || code < 0) {
            return null;
        }
        var slot = code / CODE_PAYLOAD_STEP;
        var event = new MatchEvent((code % CODE_PAYLOAD_STEP) as EventType, time, slot == 0 ? null : slot - 1);
        return event.isValid() ? event : null;
    }

    function equals(other as Object?) as Boolean {
        if (other instanceof MatchEvent) {
            var score = edit;
            var otherScore = other.edit;
            return type == other.type && time == other.time && payload == other.payload
                && (score == null || otherScore == null ? score == otherScore : score.equals(otherScore));
        }
        return false;
    }

    function toString() as String {
        var score = edit;
        return "[" + type + ", " + time + (payload == null ? "" : ", " + payload) + (score == null ? "" : ", " + score) + "]";
    }

    private static function isTeam(value as Number?) as Boolean {
        return value == TEAM_US || value == TEAM_THEM;
    }
}

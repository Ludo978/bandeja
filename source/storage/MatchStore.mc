import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// A match read back from storage (MatchStore): its engine, replayed from the stored format and log,
// its start, Indoor / Outdoor and a timed match's court booking.
class StoredMatch {

    var engine as ScoringEngine;
    var start as Number;
    var outdoor as Boolean;
    var court as CourtBooking? = null;

    function initialize(engine as ScoringEngine, start as Number, outdoor as Boolean) {
        self.engine = engine;
        self.start = start;
        self.outdoor = outdoor;
    }
}

// A stored match being read back at launch (MatchStore.startLoad()): the format, the start and
// Indoor / Outdoor at once, and the log, its full parts first when it has some, then the log replayed
// STEP_EVENTS events a step (a score edit counts as one, never cut in two), so a long match never runs
// into the watchdog's limit in one callback. Never throws: everything runs in try/catch,
// and a value that isn't a match, a part missing or a log that doesn't replay reads as no match. The
// log read from storage becomes the engine's own (ScoringEngine.takeLog()): a long match's log isn't
// held twice.
class MatchLoad {

    // Events replayed per step(): about a third of what one callback can replay before the watchdog
    // trips in the simulator, 300 to 350.
    static const STEP_EVENTS = 100;

    private var _engine as ScoringEngine? = null;
    private var _log as Object? = null;
    private var _start as Number = 0;
    private var _outdoor as Boolean = false;
    private var _court as CourtBooking? = null;
    // Pairs in the log (an event each, a score edit more), and those not replayed yet; null once the
    // load is over.
    private var _total as Number = 0;
    private var _left as Number? = null;
    private var _stored as StoredMatch? = null;
    // The log's full parts in storage (MatchStore.PART_KEY).
    private var _parts as Number = 0;
    // The load holds the replay mark (MatchStore.startLoad()).
    private var _marked as Boolean;

    // value as read from storage; null reads as a bad match.
    function initialize(value as Object?, marked as Boolean) {
        _marked = marked;
        try {
            if (!(value instanceof Dictionary)) {
                return;
            }
            var config = MatchConfig.fromDictionary(value.get("config") as Object?);
            var start = value.get("start") as Object?;
            var outdoor = value.get("outdoor") as Object?;
            var parts = value.get("parts") as Object?;
            parts = parts == null ? 0 : parts;
            var log = value.get("log") as Object?;
            if (config == null || !(start instanceof Number) || !(outdoor instanceof Boolean) || !(parts instanceof Number)
                    || parts < 0 || parts > MatchStore.PARTS_MAX || !(log instanceof Array)) {
                return;
            }
            if (parts > 0) {
                log = MatchStore.readLog(parts, log);
            }
            if (!(log instanceof Array) || log.size() % ScoringEngine.LOG_NUMBERS_PER_EVENT != 0) {
                return;
            }
            _total = log.size() / ScoringEngine.LOG_NUMBERS_PER_EVENT;
            _left = _total;
            var engine = new ScoringEngine(config);
            // Read from storage, the log is the load's own: the engine keeps it (and grows it).
            if (marked || parts > 0) {
                engine.takeLog(log as Array<Application.Storage.ValueType>);
            }
            _engine = engine;
            _parts = parts;
            _log = log;
            _start = start;
            _outdoor = outdoor;
            _court = MatchStore.courtFrom(value);
        } catch (e) {
            _engine = null;
            _left = null;
        }
    }

    // Replays the next STEP_EVENTS events. True once the load is over, the match read or found bad
    // (getStored()); the replay mark then goes, if it holds it (MatchStore.endLoad()).
    function step() as Boolean {
        var engine = _engine;
        if (engine != null && _left != null) {
            try {
                _left = engine.addFromLog(_log, STEP_EVENTS);
            } catch (e) {
                _left = null;
            }
            if (_left == 0) {
                var stored = new StoredMatch(engine, _start, _outdoor);
                stored.court = _court;
                _stored = stored;
                // The log as stored: the next write adds to its parts.
                if (_marked) {
                    MatchStore.loaded(engine, _parts);
                }
            } else if (_left != null) {
                return false;
            }
        }
        _engine = null;
        _log = null;
        _left = null;
        if (_marked) {
            _marked = false;
            MatchStore.endLoad();
        }
        return true;
    }

    // How much of the log is replayed, 0 to 1.
    function getProgress() as Float {
        var left = _left;
        return left == null || _total == 0 ? 1.0 : (_total - left).toFloat() / _total;
    }

    // Once step() is true: the match, or null when it can't be read or replayed (Discard only).
    function getStored() as StoredMatch? {
        return _stored;
    }
}

// The match being played, in Application.Storage, so a crash, a stop or a flat battery
// never loses its score: from the START that starts it (MatchFlow.startMatch()) to the exit after
// Save or Discard (MatchFlow.exit()). One value under KEY, written after every event: the format
// (MatchConfig.toDictionary()), the match start, Indoor / Outdoor (GPS for the resumed session), the
// log in its stored form (ScoringEngine.getLog()) and, for a timed match, the court booking's end time
// and the last alert given. Serve tracking needs nothing more: the answers are events.
// A long log is stored in parts of PART_NUMBERS Numbers: its full parts each under PART_KEY and
// their index, written once when they fill up, "parts" saying how many, and the rest under "log"; so a
// write after an event takes about a part at most whatever the match's length (a 30 KB value written
// whole took over 90 KB of memory while written). A key added later must be
// optional with a default, so matches stored by older versions keep loading (a log in one piece, as
// before parts, has no "parts").
module MatchStore {

    // Storage keys: never rename.
    const KEY = "match";
    // A full part of the log: PART_KEY + its index, from 0 ("matchLog0"), PART_NUMBERS Numbers each.
    const PART_KEY = "matchLog";
    const PART_NUMBERS = 1000;
    // The most full parts a log has (ScoringEngine.LOG_MAX).
    const PARTS_MAX = ScoringEngine.LOG_MAX / PART_NUMBERS;
    // Set while the stored match is replayed at launch, removed once the replay is over or left
    // (BACK, the app stopped). Still set at the next launch, it means the replay ended the app (the
    // watchdog or the memory, which no try/catch catches): the match then reads as bad, so the app
    // never replays it again.
    const REPLAY_KEY = "matchReplay";

    // The last write's time and the longest one, in ms (System.getTimer()), for the debug readout.
    var lastWrite as Number = 0;
    var longestWrite as Number = 0;
    // A launch replay holds the mark (startLoad() to endLoad()).
    var _loading as Boolean = false;
    // The match whose log's parts are stored, and how many: those KEY's value counts.
    var _partsOf as ScoringEngine? = null;
    var _parts as Number = 0;

    // Writes the match: the log's parts that filled since the last write, then KEY's value with the rest.
    // The parts it holds stay as they are; when an undo went back into one, KEY's value first takes the
    // log from there, so storage holds the whole match between any two writes (a crash).
    function save(engine as ScoringEngine, start as Number, outdoor as Boolean, court as CourtBooking?) as Void {
        var before = System.getTimer();
        var stored = engine == _partsOf ? _parts : 0;
        var kept = engine.getLogKept() / PART_NUMBERS;
        var valid = stored < kept ? stored : kept;
        var full = engine.getLogSize() / PART_NUMBERS;
        if (valid < stored) {
            write(KEY, valueOf(engine, start, outdoor, court, valid));
        }
        for (var part = valid; part < full; part++) {
            write(PART_KEY + part, engine.getLogPart(part * PART_NUMBERS, (part + 1) * PART_NUMBERS));
        }
        write(KEY, valueOf(engine, start, outdoor, court, full));
        engine.markLog();
        _partsOf = engine;
        _parts = full;
        lastWrite = System.getTimer() - before;
        if (lastWrite > longestWrite) {
            longestWrite = lastWrite;
        }
    }

    // The match as one value, its whole log under "log" (the stored form of a log of less than a part).
    function toValue(engine as ScoringEngine, start as Number, outdoor as Boolean, court as CourtBooking?)
            as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType> {
        return valueOf(engine, start, outdoor, court, 0);
    }

    // KEY's value with parts full parts of the log under PART_KEY: "parts" (none for 0) and the rest of
    // the log under "log".
    function valueOf(engine as ScoringEngine, start as Number, outdoor as Boolean, court as CourtBooking?,
            parts as Number) as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType> {
        var value = {
            "config" => engine.getConfig().toDictionary(),
            "start" => start,
            "outdoor" => outdoor,
            "log" => engine.getLogPart(parts * PART_NUMBERS, engine.getLogSize())
        } as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>;
        if (parts > 0) {
            value["parts"] = parts;
        }
        if (court != null) {
            value["courtEnd"] = court.end;
            value["courtAlert"] = court.alert as Number;
        }
        return value;
    }

    // The whole log: the parts full parts read from storage, then rest; null when a part is missing or
    // not PART_NUMBERS long.
    function readLog(parts as Number, rest as Array) as Array? {
        var log = null as Array?;
        for (var part = 0; part < parts; part++) {
            var numbers = read(PART_KEY + part);
            if (!(numbers instanceof Array) || numbers.size() != PART_NUMBERS) {
                return null;
            }
            if (log == null) {
                log = numbers;
            } else {
                log.addAll(numbers);
            }
        }
        if (log != null) {
            log.addAll(rest);
        }
        return log;
    }

    // A launch replay of engine's log is over: its first parts full parts are those stored.
    function loaded(engine as ScoringEngine, parts as Number) as Void {
        engine.markLog();
        _partsOf = engine;
        _parts = parts;
    }

    // The court booking stored in value, or null: untimed, stored before timed matches existed, or
    // unreadable. A booking never makes the match itself unreadable; an alert that can't be read
    // reads as none given.
    function courtFrom(value as Dictionary) as CourtBooking? {
        var end = value.get("courtEnd") as Object?;
        if (!(end instanceof Number)) {
            return null;
        }
        var alert = value.get("courtAlert") as Object?;
        if (!(alert instanceof Number) || alert < COURT_NONE || alert > COURT_KEEP_PLAYING) {
            alert = COURT_NONE;
        }
        return new CourtBooking(end, alert as CourtAlert);
    }

    // The match in value, or null when value isn't one or its log doesn't replay, read in one go.
    // Never throws (MatchLoad).
    function fromValue(value as Object?) as StoredMatch? {
        var load = new MatchLoad(value, false);
        while (!load.step()) {
        }
        return load.getStored();
    }

    // Something is stored, readable or not: the launch prompt shows.
    function isStored() as Boolean {
        try {
            return Application.Storage.getValue(KEY) != null;
        } catch (e) {
            return true;
        }
    }

    // The launch replay of the stored match (isStored()), a step at a time: MatchLoad.step() until
    // it's true, then MatchLoad.getStored(), null when it can't be read or replayed (Discard only).
    // The replay mark is set from here to the end of the load; when it's already set, the last
    // replay ended the app, and the load is over at once with no match.
    function startLoad() as MatchLoad {
        var value = read(KEY);
        var marked = false;
        if (read(REPLAY_KEY) != null) {
            value = null;
        } else if (value != null) {
            write(REPLAY_KEY, true);
            _loading = true;
            marked = true;
        }
        return new MatchLoad(value, marked);
    }

    // The launch replay is over, or left before the end (BACK, the app stopped): its mark goes.
    // Nothing when no replay holds it.
    function endLoad() as Void {
        if (_loading) {
            remove(REPLAY_KEY);
            _loading = false;
        }
    }

    // Save or Discard: nothing to resume.
    function clear() as Void {
        remove(KEY);
        remove(REPLAY_KEY);
        for (var part = 0; part <= PARTS_MAX; part++) {
            remove(PART_KEY + part);
        }
        _partsOf = null;
        _parts = 0;
    }

    function read(key as String) as Object? {
        try {
            return Application.Storage.getValue(key);
        } catch (e) {
            return null;
        }
    }

    // A write the store refuses is dropped, never a crash: the match plays on, and the last value
    // written stays for a resume.
    function write(key as String, value as Application.Storage.ValueType) as Void {
        try {
            Application.Storage.setValue(key, value);
        } catch (e) {
        }
    }

    function remove(key as String) as Void {
        try {
            Application.Storage.deleteValue(key);
        } catch (e) {
        }
    }
}

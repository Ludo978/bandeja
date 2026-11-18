import Toybox.Application;
import Toybox.Lang;

// A match in progress: its format, its event log and the state they give.
// Pure and deterministic: no UI, storage or clock; events bring their own time.
//
// A new event is applied to the current state, so a press costs one event, not a replay of the
// whole log (latency), and the stats add up in the same pass (MatchTally). Undo goes back
// to the last snapshot of the state, kept every SNAPSHOT_EVERY events, and replays the few events
// after it, so its cost doesn't grow with the match (the watchdog). Resume replays the stored
// log a step at a time (addFromLog()). Every path goes through apply(), so they can't disagree.
//
// The log is kept in its stored form, a flat array of Numbers, oldest first: each event a pair,
// LOG_NUMBERS_PER_EVENT Numbers (MatchEvent.getCode(), then the time), and EDIT_SCORE more pairs
// after its own (its score, MatchEvent.addTo()). 300 events take about 3 KB in memory and in storage.
// An edit is still one event for undo, the snapshots and the resume's steps. The log holds LOG_MAX
// Numbers at most: past that, add() refuses every event but End match. The log is never
// copied whole (memory): undo shortens it in place, a resume can take the stored array as
// it is (takeLog()), and storage writes it a part at a time (getLogSize(), getLogPart(), MatchStore).
class ScoringEngine {

    // Numbers of an event's pair in the log: all of an event but EDIT_SCORE, which spans more.
    static const LOG_NUMBERS_PER_EVENT = 2;
    // The most Numbers the log holds, about 3,000 events: the longest match the watch
    // keeps within the app's memory budget; stored whole as one value, it
    // would take 30.8 KB of the 32 KB a value of Application.Storage holds (5 bytes a Number). Every event
    // but End match leaves room for an End match after it, so the match can always be ended (and
    // saved).
    static const LOG_MAX = 6100;
    // Events between two undo snapshots: an undo replays fewer than this many.
    static const SNAPSHOT_EVERY = 32;

    private var _config as MatchConfig;
    // The log is _log's first _size Numbers. Past them, room for the next events (nulls, or the Numbers
    // an undo took off), and during a resume from a stored log taken as it is (takeLog()) its events not
    // added yet, up to _takenSize. The array grows by capacityFor(): a copy of the whole log, so it grows
    // early and to LOG_MAX at the latest at half of it, never late in a long match (memory).
    private var _log as Array<Application.Storage.ValueType>;
    private var _size as Number = 0;
    private var _takenSize as Number = 0;
    // The log's first Numbers still as they were at markLog(): an undo since may have taken some off.
    private var _kept as Number = 0;
    private var _state as MatchState;
    // MatchState.pack() after every SNAPSHOT_EVERY events: the first one after SNAPSHOT_EVERY
    // events, the next after twice as many, and so on. With each, the state's list of finished sets
    // then (an edit puts a new list in the state, so it still holds the sets as they were) and the
    // log's size then, where the next event starts.
    private var _snapshots as Array<Array<Number?> >;
    private var _snapshotSets as Array<Array<SetScore> >;
    private var _snapshotEnds as Array<Number>;

    // A new match, before its first event.
    function initialize(config as MatchConfig) {
        _config = config.copy();
        _log = [] as Array<Application.Storage.ValueType>;
        _state = newState(_config);
        _snapshots = [] as Array<Array<Number?> >;
        _snapshotSets = [] as Array<Array<SetScore> >;
        _snapshotEnds = [] as Array<Number>;
    }

    // Resume: the match for a stored log (getLog()'s form), or null when the log is malformed or
    // doesn't replay. In one go: a long log is resumed with addFromLog(), a step at a time.
    static function restore(config as MatchConfig, log as Object?) as ScoringEngine? {
        var engine = new ScoringEngine(config);
        return engine.addFromLog(log, -1) == 0 ? engine : null;
    }

    // A resume from a stored log the caller gives away (read from storage, held by nothing else), then
    // passes to addFromLog(): the engine keeps that array as its log, so the log isn't held twice while
    // its events are added, and gives it room for the next events now, while the rest of the match isn't
    // in memory yet. Only before the first event.
    function takeLog(log as Array<Application.Storage.ValueType>) as Void {
        if (_size == 0) {
            _takenSize = log.size();
            log.addAll(new [capacityFor(_takenSize) - _takenSize] as Array<Application.Storage.ValueType>);
            _log = log;
        }
    }

    // The log array's size once it grows from size Numbers: twice that, 64 at least, LOG_MAX at most
    // (a pair more for a log already at it or past it, a stored one).
    static function capacityFor(size as Number) as Number {
        var capacity = size < 32 ? 64 : 2 * size;
        if (capacity > LOG_MAX) {
            capacity = LOG_MAX;
        }
        return capacity > size ? capacity : size + LOG_NUMBERS_PER_EVENT;
    }

    // Resume a step at a time: adds the events of a stored log (getLog()'s form) that follow those
    // already in, at most maxEvents of them (-1: all), so a long log goes in over several calls, each
    // within the watchdog's limit. An edit counts as one event and is never cut in
    // two. Returns how much of the log is left to add, in pairs (LOG_NUMBERS_PER_EVENT Numbers: the
    // events left when the log holds no edit), or null when the log is malformed or one of its events
    // is refused: the engine is then left half-built.
    function addFromLog(log as Object?, maxEvents as Number) as Number? {
        if (!(log instanceof Array)) {
            return null;
        }
        // The engine's log is the stored log's beginning: the next event starts where it ends. The log
        // taken as it is ends where it ended then.
        var offset = _size;
        var end = log == _log ? _takenSize : log.size();
        if (end % LOG_NUMBERS_PER_EVENT != 0) {
            return null;
        }
        for (var added = 0; offset < end && added != maxEvents; added++) {
            // read(), written out: the watchdog bounds this loop's steps, and the call costs about 3 %.
            var event = MatchEvent.fromCode(log[offset] as Object?, log[offset + 1] as Object?);
            if (event == null) {
                event = MatchEvent.fromLog(log, offset);
            }
            // A stored log was written within LOG_MAX: its room isn't checked again.
            if (event == null || !append(event)) {
                return null;
            }
            offset += event.edit == null ? LOG_NUMBERS_PER_EVENT : event.getSize();
        }
        return (end - offset) / LOG_NUMBERS_PER_EVENT;
    }

    // The state after the events of a log in getLog()'s form; null when the log is malformed or
    // one of its events is refused.
    static function replay(config as MatchConfig, log as Object?) as MatchState? {
        if (!(log instanceof Array) || log.size() % LOG_NUMBERS_PER_EVENT != 0) {
            return null;
        }
        var state = newState(config);
        for (var offset = 0; offset < log.size(); ) {
            var event = read(log, offset);
            if (event == null || !apply(config, state, event)) {
                return null;
            }
            offset += event.edit == null ? LOG_NUMBERS_PER_EVENT : event.getSize();
        }
        return state;
    }

    // The event at offset in a log whose size is even and above offset: an event of one pair read the
    // quick way (MatchEvent.fromCode()), an edit, or a bad event (null), by MatchEvent.fromLog().
    private static function read(log as Object, offset as Number) as MatchEvent? {
        var numbers = log as Array;
        var event = MatchEvent.fromCode(numbers[offset] as Object?, numbers[offset + 1] as Object?);
        return event != null ? event : MatchEvent.fromLog(log, offset);
    }

    // The state before any event.
    static function newState(config as MatchConfig) as MatchState {
        var state = new MatchState();
        state.deuceMode = config.deuceMode;
        state.gameDeuceMode = config.deuceMode;
        state.gameType = config.isSuperTieBreakSet(0) ? GAME_SUPER_TIE_BREAK : GAME_REGULAR;
        state.doubles = config.doubles;
        return state;
    }

    // Whether the event can follow the state. Once accepted an event is never refused on replay,
    // since this depends only on the events before it.
    static function canApply(config as MatchConfig, state as MatchState, event as MatchEvent) as Boolean {
        if (state.matchOver || !event.isValid()) {
            return false;
        }
        var type = event.type;
        if (type == EVENT_SWAP_OUR_SERVER) {
            return config.doubles;
        }
        // An event that changes nothing would make an undo that changes nothing.
        if (type == EVENT_FIX_SERVING_TEAM) {
            return event.payload != state.getServingTeam();
        }
        if (type == EVENT_SET_DEUCE_MODE) {
            return event.payload != state.deuceMode;
        }
        // The leader takes the set; the player names a team only when it's level.
        if (type == EVENT_END_SET) {
            return (event.payload == null) != (state.getSetLeader() == null);
        }
        // A score the format allows, that ends no match and changes something.
        if (type == EVENT_EDIT_SCORE) {
            return (event.edit as ScoreEdit).canApply(config, state);
        }
        return true;
    }

    // Applies the event to the state in place. False, with the state untouched, when canApply()
    // refuses it.
    static function apply(config as MatchConfig, state as MatchState, event as MatchEvent) as Boolean {
        if (!canApply(config, state, event)) {
            return false;
        }
        var server = state.getServingTeam();
        var player = state.getServingPlayer();
        state.changeOfEnds = false;
        var type = event.type;
        if (type == EVENT_POINT_US || type == EVENT_POINT_THEM) {
            var team = type == EVENT_POINT_US ? TEAM_US : TEAM_THEM;
            var games = state.finishedGames.size();
            var gameStart = state.gameStartTime;
            state.pointsWon[team] += 1;
            scorePoint(config, state, team, event.time);
            // A point that wins a game starts the next one.
            if (state.finishedGames.size() > games) {
                state.tally.gameEnded(state, games, event.time, gameStart);
                state.gameStartTime = event.time;
            }
        } else if (type == EVENT_SWAP_OUR_SERVER) {
            ServeTracker.swapOurServer(state);
        } else if (type == EVENT_FIX_SERVING_TEAM) {
            ServeTracker.fixServingTeam(state, event.payload as Team);
        } else if (type == EVENT_SET_DEUCE_MODE) {
            state.deuceMode = event.payload as DeuceMode;
            // The game in progress keeps its rule; one with no point played yet, such
            // as between games, takes the new one.
            if (state.gamePoints[TEAM_US] == 0 && state.gamePoints[TEAM_THEM] == 0) {
                state.gameDeuceMode = state.deuceMode;
            }
        } else if (type == EVENT_END_SET) {
            // The game in progress is dropped; its points stay in pointsWon and in the stats, and its
            // server, who never had the game, serves the next one, which starts now.
            state.tally.gameDropped(state.servingTeam);
            var leader = state.getSetLeader();
            endSet(config, state, (leader != null ? leader : event.payload) as Team, true);
            state.gameStartTime = event.time;
        } else if (type == EVENT_END_MATCH) {
            // The unfinished set stays as it is: MatchState.getResult() reads it.
            state.matchOver = true;
        } else if (type == EVENT_EDIT_SCORE) {
            editScore(config, state, event.edit as ScoreEdit);
        }
        // Whether the event changed the server shown and the ends: neither once the match is over.
        state.serverChanged = !state.matchOver
            && (state.getServingTeam() != server || state.getServingPlayer() != player);
        state.changeOfEnds = state.changeOfEnds && !state.matchOver;
        state.eventCount += 1;
        state.lastEventTime = event.time;
        return true;
    }

    // A point won by team. A game goes to the first team with 4 points and a 2-point lead, or to
    // the winner of a deciding point; a tie-break to the first with its length in
    // points and a 2-point lead, with no deciding point. The point is played at time.
    private static function scorePoint(config as MatchConfig, state as MatchState, team as Team,
            time as Number) as Void {
        var deciding = state.isDecidingPoint();
        state.tally.point(state, team, deciding, time);
        state.gamePoints[team] += 1;
        ServeTracker.pointPlayed(state);
        var won = state.gamePoints[team];
        var lost = state.gamePoints[team == TEAM_US ? TEAM_THEM : TEAM_US];
        if (deciding || config.isGameWon(state.gameType, won, lost)) {
            winGame(config, state, team);
        }
    }

    // The game goes to team. A tie-break wins the set, and so do N games or more with a
    // 2-game lead; otherwise the next game starts, as a tie-break at T-T. A super tie-break is the
    // whole set and counts no games. Either way the serve passes on, a tie-break counting as one
    // game, so the pair that didn't serve first in it opens the next set.
    private static function winGame(config as MatchConfig, state as MatchState, team as Team) as Void {
        var type = state.gameType;
        if (type != GAME_SUPER_TIE_BREAK) {
            state.games[team] += 1;
        }
        ServeTracker.gameWon(state, team);
        var won = state.games[team];
        var lost = state.games[team == TEAM_US ? TEAM_THEM : TEAM_US];
        if (type != GAME_REGULAR || config.isSetWon(won, lost)) {
            endSet(config, state, team, false);
            return;
        }
        var tieBreak = config.hasTieBreak && won == config.tieBreakAt && lost == config.tieBreakAt;
        startGame(state, tieBreak ? GAME_TIE_BREAK : GAME_REGULAR);
    }

    // The set goes to winner, played out or given by End set now (endedEarly). The match is over
    // once winner has setsToWin sets (never in Free play); otherwise the next set starts at 0-0, as the
    // super tie-break when it's the final set of a format that has one.
    private static function endSet(config as MatchConfig, state as MatchState, winner as Team,
            endedEarly as Boolean) as Void {
        var type = state.gameType;
        // The super tie-break's points are the set's score. A tie-break cut short by End set now is
        // dropped, like any game in progress.
        var tieBreakPoints = type == GAME_SUPER_TIE_BREAK || (type == GAME_TIE_BREAK && !endedEarly)
            ? [state.gamePoints[TEAM_US], state.gamePoints[TEAM_THEM]] : null;
        state.setScores.add(new SetScore([state.games[TEAM_US], state.games[TEAM_THEM]], tieBreakPoints,
            type == GAME_SUPER_TIE_BREAK, winner, endedEarly));
        state.games[TEAM_US] = 0;
        state.games[TEAM_THEM] = 0;
        state.matchOver = config.winsMatch(state.getSetsWon(winner));
        var superTieBreak = !state.matchOver && config.isSuperTieBreakSet(state.setScores.size());
        startGame(state, superTieBreak ? GAME_SUPER_TIE_BREAK : GAME_REGULAR);
    }

    // The score the edit sets: the finished sets, the current set's games and the game's
    // points, and the game type they give. Nothing else changes: the points won and the stats count
    // what was played on the watch, the serving team and our server stay as they were (in a tie-break,
    // who serves now follows from its points, as always), the players don't change ends, and the game
    // in progress goes on, with its start, its points so far in the stats and its deuce rule (at 0-0,
    // the mode chosen last). The sets go in a new list: the undo snapshots keep the old one.
    private static function editScore(config as MatchConfig, state as MatchState, edit as ScoreEdit) as Void {
        var sets = [] as Array<SetScore>;
        for (var i = 0; i < edit.sets.size(); i++) {
            sets.add(edit.sets[i].copy());
        }
        state.setScores = sets;
        state.games = [edit.games[TEAM_US], edit.games[TEAM_THEM]];
        state.gameDeuceMode = edit.getGameDeuceMode(state);
        state.gamePoints = [edit.points[TEAM_US], edit.points[TEAM_THEM]];
        state.gameType = edit.getGameType(config);
    }

    // The next game starts at 0-0 with the deuce mode chosen last.
    private static function startGame(state as MatchState, type as GameType) as Void {
        state.gamePoints[TEAM_US] = 0;
        state.gamePoints[TEAM_THEM] = 0;
        state.gameDeuceMode = state.deuceMode;
        state.gameType = type;
    }

    // The format the match started with. Read-only: the deuce mode in play is in the state.
    function getConfig() as MatchConfig {
        return _config;
    }

    // The current state. Read-only, and undo() replaces it: get it again after every change.
    function getState() as MatchState {
        return _state;
    }

    // The log in its stored form, for replay() and the tests: a copy when an undo left Numbers past its
    // end. Read-only. Storage writes it a part at a time (getLogPart()).
    function getLog() as Array<Application.Storage.ValueType> {
        return _size == _log.size() ? _log : _log.slice(0, _size);
    }

    // The log's size in Numbers.
    function getLogSize() as Number {
        return _size;
    }

    // The log holds only the serve's set-up: no event, or only FIX_SERVING_TEAM and SWAP_OUR_SERVER,
    // the "Who serves first?" answers and any serve correction made before anything else. Read from the
    // log's start, so it stops at the match's first other event.
    function isServeSetUpOnly() as Boolean {
        for (var offset = 0; offset < _size; offset += LOG_NUMBERS_PER_EVENT) {
            // An edit, which spans more Numbers, reads as null here: not a serve event.
            var event = MatchEvent.fromCode(_log[offset] as Object?, _log[offset + 1] as Object?);
            if (event == null || (event.type != EVENT_FIX_SERVING_TEAM && event.type != EVENT_SWAP_OUR_SERVER)) {
                return false;
            }
        }
        return true;
    }

    // A copy of the log's Numbers from from to to (to past the log's end: to its end).
    function getLogPart(from as Number, to as Number) as Array<Application.Storage.ValueType> {
        return _log.slice(from, to < _size ? to : _size);
    }

    // The match is saved and about to leave: the log and the undo snapshots go, the state
    // stays (the screens still show it), so the history's write has their memory. Nothing
    // is added or undone after.
    function release() as Void {
        _log = [] as Array<Application.Storage.ValueType>;
        _size = 0;
        _takenSize = 0;
        _kept = 0;
        _snapshots = [] as Array<Array<Number?> >;
        _snapshotSets = [] as Array<Array<SetScore> >;
        _snapshotEnds = [] as Array<Number>;
    }

    // The log as it is now is the one getLogKept() compares with (MatchStore: the log as stored).
    function markLog() as Void {
        _kept = _size;
    }

    // How many of the log's first Numbers are as they were at markLog(): all of them then, fewer once an
    // undo took some off (the events after it are other Numbers).
    function getLogKept() as Number {
        return _kept;
    }

    // The event at position index in the log, 0 being the oldest (index < getState().eventCount).
    function getEvent(index as Number) as MatchEvent {
        return MatchEvent.fromLog(_log, offsetOf(index)) as MatchEvent;
    }

    // Where event index starts in the log: index pairs in, when the log holds no edit; otherwise the
    // last snapshot before it says where its events start, and the few after it are skipped.
    private function offsetOf(index as Number) as Number {
        if (_size == _state.eventCount * LOG_NUMBERS_PER_EVENT) {
            return index * LOG_NUMBERS_PER_EVENT;
        }
        var kept = index / SNAPSHOT_EVERY;
        var offset = kept > 0 ? _snapshotEnds[kept - 1] : 0;
        for (var i = kept * SNAPSHOT_EVERY; i < index; i++) {
            offset += MatchEvent.sizeAt(_log, offset);
        }
        return offset;
    }

    function canAdd(event as MatchEvent) as Boolean {
        return hasRoom(event) && canApply(_config, _state, event);
    }

    // The log has room for the event (LOG_MAX): its Numbers, and but for End match an End match's after
    // them.
    function hasRoom(event as MatchEvent) as Boolean {
        return event.type == EVENT_END_MATCH ? _size + event.getSize() <= LOG_MAX : hasRoomFor(event.getSize());
    }

    // The log has room for an event of numbers Numbers other than End match, and an End match after it.
    function hasRoomFor(numbers as Number) as Boolean {
        return _size + numbers + LOG_NUMBERS_PER_EVENT <= LOG_MAX;
    }

    // The log has no room left for an event of one pair other than End match (hasRoom()): the longest
    // match the watch keeps.
    function isFull() as Boolean {
        return !hasRoomFor(LOG_NUMBERS_PER_EVENT);
    }

    // Appends the event and updates the state. False, changing nothing, when it's refused, or the log has
    // no room for it (hasRoom()).
    function add(event as MatchEvent) as Boolean {
        return hasRoom(event) && append(event);
    }

    // add() without the room check, for a stored log.
    private function append(event as MatchEvent) as Boolean {
        if (!apply(_config, _state, event)) {
            return false;
        }
        if (event.edit == null) {
            put(event.getCode());
            put(event.time);
        } else {
            var numbers = [] as Array<Application.Storage.ValueType>;
            event.addTo(numbers);
            for (var i = 0; i < numbers.size(); i++) {
                put(numbers[i] as Number);
            }
        }
        if (_state.eventCount % SNAPSHOT_EVERY == 0) {
            _snapshots.add(_state.pack());
            _snapshotSets.add(_state.setScores);
            _snapshotEnds.add(_size);
        }
        return true;
    }

    // Writes the log's next Number, in the room past the log (from a stored log taken as it is, over the
    // same Number), the array grown first when it's full (capacityFor()).
    private function put(number as Number) as Void {
        if (_size == _log.size()) {
            _log.addAll(new [capacityFor(_size) - _size] as Array<Application.Storage.ValueType>);
        }
        _log[_size] = number;
        _size++;
    }

    // Removes the last event, whatever its type: the state goes back to the last snapshot before it
    // and the events in between are applied again. Returns the removed event (the UI names it in the
    // "Undone" toast), or null when there's nothing to undo. The state is a new object.
    function undo() as MatchEvent? {
        var count = _state.eventCount - 1;
        if (count < 0) {
            return null;
        }
        // The snapshots taken at count events or fewer stay.
        var kept = count / SNAPSHOT_EVERY;
        if (_snapshots.size() > kept) {
            _snapshots = _snapshots.slice(0, kept);
            _snapshotSets = _snapshotSets.slice(0, kept);
            _snapshotEnds = _snapshotEnds.slice(0, kept);
        }
        var state = kept > 0 ? MatchState.unpack(_snapshots[kept - 1], _snapshotSets[kept - 1], _state) : newState(_config);
        var offset = kept > 0 ? _snapshotEnds[kept - 1] : 0;
        for (var i = state.eventCount; i < count; i++) {
            // Can't be refused: every event in the log was accepted after the ones before it.
            var event = read(_log, offset) as MatchEvent;
            apply(_config, state, event);
            offset += event.edit == null ? LOG_NUMBERS_PER_EVENT : event.getSize();
        }
        var removed = MatchEvent.fromLog(_log, offset) as MatchEvent;
        _size = offset;
        if (offset < _kept) {
            _kept = offset;
        }
        _state = state;
        return removed;
    }
}

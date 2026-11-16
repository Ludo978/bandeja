import Toybox.Lang;
import Toybox.Test;

// Random matches against every rule at once: every format of
// TestKit.formats(), every event type, score edits included, refused events, and undos, one at a time
// or many in a row, across undo snapshots. The fast paths (an event applied to the state, undo from a
// snapshot, resume a step at a time) must always give what a full replay of the log gives.

(:test)
function randomMatchesTest(logger as Logger) as Boolean {
    // Serve tracking answered before the first point, off throughout, or started by a late Fix serving
    // team, each format recorded through a fake session. After every step: the set rules
    // (TestKit.checkRules()), the situation's flags, banner and caption against what the next point
    // would do (checkNextPoint()), the server against the rotation as the serve rules state it
    // (RandomMatchTests.Walk), and the side; after every event the server changed and change of ends
    // flags and the server each finished game keeps; one lap written per finished game at its winning
    // point, the match point's but, with its game's values, never a second one after an undo, and the
    // save adding the last. A score edit is taken exactly when TestKit.possibleEdit() allows it, and
    // moves neither the rotation nor the laps; at every step a random edit is also probed
    // without adding it, the engine and possibleEdit() agreeing. After every undo, every 25 steps and at the
    // end the state equals a full replay of the log; every 25 steps and at the end the stats equal the
    // reference (StatsCalculator).
    var formats = TestKit.formats();
    var seen = {} as Dictionary<String, Number>;
    for (var f = 0; f < formats.size(); f++) {
        var walk = new RandomMatchTests.Walk(formats[f], f, seen);
        walk.run(200);
    }
    // Each case came up often enough for the checks to mean something.
    var least = {
        "swap" => 10, "fix" => 10, "fix in a tie-break" => 1, "deuce mode" => 10, "end set" => 10, "ended early" => 3,
        "won" => 3, "refused" => 10, "undo" => 100, "tie-break" => 5, "super tie-break" => 1, "deciding point" => 10,
        "break point" => 50, "set point" => 50, "match point" => 10, "deuce banner" => 10, "tie-break banner" => 20,
        "same sex" => 1, "server changed" => 100, "ends in a tie-break" => 3, "tracked" => 10, "laps" => 100,
        "edit" => 20, "edit refused" => 20, "edit to a tie-break" => 3, "undo of an edit" => 3, "probe taken" => 500,
        "probe refused" => 500
    } as Dictionary<String, Number>;
    logger.debug("edits taken " + seen.get("edit") + ", refused " + seen.get("edit refused") + ", to a tie-break "
        + seen.get("edit to a tie-break") + ", undone " + seen.get("undo of an edit") + "; probed edits taken "
        + seen.get("probe taken") + ", refused " + seen.get("probe refused"));
    var keys = least.keys();
    for (var i = 0; i < keys.size(); i++) {
        var count = seen.get(keys[i]);
        var min = least.get(keys[i]) as Number;
        Test.assertMessage((count != null ? count : 0) >= min, keys[i] + ": " + count);
    }
    return true;
}

(:test)
function randomLongMatchesTest(logger as Logger) as Boolean {
    // Undo from the snapshots and resume a step at a time: random matches past
    // ten undo snapshots, long sets with no tie-break and a super tie-break, score edits among the
    // events. Resumed in steps of 1, 7, SNAPSHOT_EVERY and 100 events, an edit counting as one, the
    // engine is the one a whole replay gives, its snapshots included (40 undos agree); a refused event
    // stops the resume at its step. Then undone back to the start: each undo gives back its event, and
    // the state a full replay of the shortened log, every 25 events and on each side of every snapshot.
    var k = ScoringEngine.SNAPSHOT_EVERY;
    var configs = [TestKit.format(3, 10, 10, false), TestKit.preset(PRESET_BEST_OF_3_SUPER_TB)];
    for (var c = 0; c < configs.size(); c++) {
        var config = configs[c];
        var engine = TestKit.newMatch(config, "Partner");
        var seed = 23 + c;
        var time = TestKit.T0;
        for (var steps = 0; engine.getState().eventCount < 10 * k && steps < 800; steps++) {
            seed = TestKit.nextRandom(seed);
            time += 20 + seed % 40;
            if (engine.getState().matchOver) {
                engine.undo();
            } else {
                engine.add(TestKit.randomEvent(config, engine.getState(), seed, time, true));
            }
        }
        var count = engine.getState().eventCount;
        Test.assertMessage(count >= 10 * k, "format " + c + ": " + count + " events");
        TestKit.assertMatchesReplay(engine, "format " + c);

        var log = engine.getLog();
        var offsets = TestKit.offsetsOf(log);
        var sizes = [1, 7, k, 100];
        for (var i = 0; i < sizes.size(); i++) {
            var message = "format " + c + ", steps of " + sizes[i];
            var other = new ScoringEngine(config);
            var calls = 0;
            var left = count as Number?;
            while (left != null && left > 0) {
                left = other.addFromLog(log, sizes[i]);
                calls++;
                // What's left is counted in pairs; a step stops at an event's end, never inside an edit.
                var added = other.getState().eventCount;
                Test.assertMessage(added == (calls * sizes[i] < count ? calls * sizes[i] : count)
                    && other.getLog().size() == offsets[added]
                    && left == (log.size() - other.getLog().size()) / ScoringEngine.LOG_NUMBERS_PER_EVENT,
                    message + ": " + left + " left");
            }
            Test.assertEqual(calls, (count + sizes[i] - 1) / sizes[i]);
            Test.assert(other.addFromLog(log, sizes[i]) == 0);
            Test.assertEqual(other.getLog().toString(), log.toString());
            TestKit.assertSameState(other.getState(), engine.getState(), message);
            var copy = ScoringEngine.restore(config, log) as ScoringEngine;
            for (var undo = 0; undo < 40; undo++) {
                copy.undo();
                other.undo();
            }
            TestKit.assertSameState(other.getState(), copy.getState(), message + ", undone");
            TestKit.assertMatchesReplay(other, message + ", undone");
        }

        // A refused event (a point after the end of the match) at event 120: steps of 50 stop at the third.
        var n = ScoringEngine.LOG_NUMBERS_PER_EVENT;
        var bad = log.slice(0, TestKit.offsetOf(log, 119));
        bad.addAll([EVENT_END_MATCH as Number, time, EVENT_POINT_US as Number, time]);
        bad.addAll(log.slice(TestKit.offsetOf(log, 121), null));
        var stopped = new ScoringEngine(config);
        Test.assert(stopped.addFromLog(bad, 50) == (bad.size() - TestKit.offsetOf(bad, 50)) / n);
        Test.assert(stopped.addFromLog(bad, 50) == (bad.size() - TestKit.offsetOf(bad, 100)) / n);
        Test.assert(stopped.addFromLog(bad, 50) == null);
        Test.assert(ScoringEngine.restore(config, bad) == null);

        while (count > 0) {
            var last = engine.getEvent(count - 1);
            var undone = engine.undo();
            count--;
            Test.assertMessage(undone != null && undone.equals(last) && engine.getState().eventCount == count,
                "format " + c + ", undid " + undone);
            if ((count + 1) % k <= 2 || count % TestKit.REPLAY_EVERY == 0) {
                TestKit.assertMatchesReplay(engine, "format " + c + ", " + count + " events");
            }
        }
        Test.assert(engine.undo() == null);
    }
    return true;
}

(:test)
module RandomMatchTests {

    // One random match, with the rotation model and the laps it checks against.
    class Walk {

        private var _config as MatchConfig;
        private var _engine as ScoringEngine;
        private var _f as Number;
        // 0: the serve answered before the first point, 1: serve tracking off throughout, 2: started
        // by a late Fix serving team.
        private var _tracking as Number;
        private var _seen as Dictionary<String, Number>;
        // The rotation after each number of events, as (position + 1) * 2 + swapped. The
        // position is the current game's place in the cycle ME, THEM, PARTNER, THEM (ME, THEM in
        // singles), -1 while the serving team is unknown: it moves one place per game, a tie-break
        // counting as one, and a Fix serving team moves it one place to the team named. With swapped,
        // our two players trade places in the cycle.
        private var _rotation as Array<Number> = [0] as Array<Number>;
        private var _size as Number;
        private var _recorder as TestKit.FakeRecorder = new TestKit.FakeRecorder();
        private var _session as SessionManager;
        private var _laps as LapCommitter;
        // The lap expected for each finished game, worked out when it last ended.
        private var _expected as Array<String> = [] as Array<String>;
        // The most games closed so far (finished, but the match point's).
        private var _closed as Number = 0;
        private var _start as Number = 0;

        function initialize(config as MatchConfig, f as Number, seen as Dictionary<String, Number>) {
            _config = config;
            _engine = new ScoringEngine(config);
            _f = f;
            _tracking = f % 3;
            _seen = seen;
            _size = config.doubles ? 4 : 2;
            _session = new SessionManager(_recorder);
            _laps = new LapCommitter(_session);
            Test.assert(_session.start(false, true) && _session.startMatch());
            if (_tracking == 0) {
                var answer = TestKit.answer(config, f);
                add(new MatchEvent(EVENT_FIX_SERVING_TEAM, TestKit.T0, answer.find("Opponents") == null ? TEAM_US : TEAM_THEM), "answer");
                if (answer.find("Partner") != null) {
                    add(new MatchEvent(EVENT_SWAP_OUR_SERVER, TestKit.T0 + 1, null), "answer");
                }
                _start = _engine.getState().eventCount;
            }
        }

        function run(steps as Number) as Void {
            var seed = 1000 + 37 * _f;
            var time = TestKit.T0 + 60;
            for (var step = 0; step < steps; step++) {
                var message = "format " + _f + ", step " + step;
                seed = TestKit.nextRandom(seed);
                time += 20 + seed % 40;
                var state = _engine.getState();
                if (state.matchOver || (seed % 30 == 0 && state.eventCount > _start)) {
                    undo(state.matchOver ? (seed / 30) % 25 + 1 : (seed / 30) % 6 + 1, message);
                } else {
                    add(TestKit.randomEvent(_config, state, seed, time, _tracking != 1), message);
                }
                check(message);
                probeEdit(TestKit.nextRandom(seed + step), time, message);
                TestKit.assertMatchesReplayAt(_engine, step, message);
                if (step % TestKit.REPLAY_EVERY == TestKit.REPLAY_EVERY - 1) {
                    checkStats(message);
                }
            }
            var end = "format " + _f + ", end";
            TestKit.assertMatchesReplay(_engine, end);
            checkStats(end);
            // The save writes the last lap: the last finished game's, or the one left unfinished.
            Test.assert(_session.save());
            Test.assertMessage(_recorder.laps.size() == 2 + _closed, end + ": laps at the save");
            if (_closed < _engine.getState().finishedGames.size()) {
                Test.assertEqualMessage(_recorder.laps[1 + _closed], _expected[_closed], end + ": last lap");
            }
            note("laps", _recorder.laps.size());
        }

        // Adds the event, which the engine takes when canAdd() says so, and checks what it changed.
        function add(event as MatchEvent, message as String) as Void {
            var state = _engine.getState();
            var count = state.eventCount;
            var accepted = _engine.canAdd(event);
            var before = TestKit.server(state);
            var games = state.finishedGames.size();
            var sets = state.setScores.size();
            var played = state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM];
            var turn = state.isTieBreak() && played > 0 ? (played - 1) / 2 + 1 : 0;
            var tieBreak = state.isTieBreak();
            var deciding = state.isDecidingPoint();
            var code = _rotation[_rotation.size() - 1];
            var type = event.type;
            if (type == EVENT_EDIT_SCORE) {
                Test.assertMessage(accepted == TestKit.possibleEdit(_config, state, event.edit as ScoreEdit),
                    message + ": edit " + (accepted ? "taken" : "refused") + ", " + event + " at " + TestKit.sets(state));
                note(accepted ? "edit" : "edit refused", 1);
            }
            Test.assertMessage(_engine.add(event) == accepted, message + ": added " + event);
            if (!accepted) {
                Test.assertMessage(_engine.getState().eventCount == count, message + ": refused " + event);
                note("refused", 1);
                return;
            }
            state = _engine.getState();
            var position = code / 2 - 1;
            var swapped = code % 2;
            if (type == EVENT_SWAP_OUR_SERVER) {
                swapped = 1 - swapped;
                note("swap", 1);
            } else if (type == EVENT_FIX_SERVING_TEAM) {
                if (position < 0) {
                    // The team named serves the current point: in a tie-break, the turns before it follow.
                    var first = turn % 2 == 0 ? event.payload : MatchState.otherTeam(event.payload as Team);
                    position = first == TEAM_US ? 0 : _size - 1;
                } else {
                    position = (position + (position % 2 == 1 ? 1 : _size - 1)) % _size;
                }
                note(tieBreak ? "fix in a tie-break" : "fix", 1);
            } else if (type == EVENT_SET_DEUCE_MODE) {
                note("deuce mode", 1);
            } else if (type == EVENT_END_SET) {
                note("end set", 1);
            } else if (type == EVENT_EDIT_SCORE) {
                // The serve stays as it was, and no game ends.
                Test.assertMessage(state.finishedGames.size() == games, message + ": games after an edit");
                note("edit to a tie-break", state.isTieBreak() ? 1 : 0);
            } else if (state.finishedGames.size() > games) {
                var server = position < 0 ? null : position % 2 == 1 ? TEAM_THEM : TEAM_US;
                Test.assertMessage(state.getFinishedGameServer(games) == server, message + ": game served by "
                    + state.getFinishedGameServer(games) + " at " + TestKit.sets(state));
                position = position < 0 ? position : (position + 1) % _size;
                var lap = TestKit.expectedLap(state, games);
                if (_expected.size() > games) {
                    _expected[games] = lap;
                } else {
                    _expected.add(lap);
                }
                var gameType = state.getFinishedGameType(games);
                note(gameType == GAME_TIE_BREAK ? "tie-break" : gameType == GAME_SUPER_TIE_BREAK ? "super tie-break" : "game", 1);
            }
            if (deciding && (type == EVENT_POINT_US || type == EVENT_POINT_THEM)) {
                note("deciding point", 1);
            }
            if (state.matchOver) {
                note(type == EVENT_END_MATCH ? "ended early" : "won", 1);
            }
            _rotation.add((position + 1) * 2 + swapped);
            TestKit.checkFlags(event, state, before, games, sets, message);
            note("server changed", state.serverChanged ? 1 : 0);
            note("ends in a tie-break", state.changeOfEnds && state.isTieBreak() ? 1 : 0);
            updateLaps(message);
        }

        // Undoes up to count events, never the serve answer, then checks the state against a replay.
        function undo(count as Number, message as String) as Void {
            for (var i = 0; i < count && _engine.getState().eventCount > _start; i++) {
                var last = _engine.getEvent(_engine.getState().eventCount - 1);
                var undone = _engine.undo();
                Test.assertMessage(undone != null && undone.equals(last), message + ": undid " + undone);
                updateLaps(message);
                note("undo", 1);
                note("undo of an edit", last.type == EVENT_EDIT_SCORE ? 1 : 0);
            }
            _rotation = _rotation.slice(0, _engine.getState().eventCount + 1);
            TestKit.assertMatchesReplay(_engine, message + ", undone");
        }

        // The laps written: one per game closed so far, each with its values when it ended,
        // and said so only when the change wrote one. And the record field, the point differential.
        private function updateLaps(message as String) as Void {
            var state = _engine.getState();
            var written = _laps.getCommitted();
            var wrote = _laps.update(state);
            var finished = state.finishedGames.size();
            var closed = state.matchOver ? finished - 1 : finished;
            _closed = closed > _closed ? closed : _closed;
            Test.assertMessage(_laps.getCommitted() == _closed && _recorder.laps.size() == 1 + _closed, message + ": laps");
            Test.assertMessage(wrote == (_closed > written), message + ": lap written");
            for (var i = written; i < _closed; i++) {
                Test.assertEqualMessage(_recorder.laps[1 + i], _expected[i], message + ": lap " + i);
            }
            Test.assertMessage(_recorder.pointDifferential == state.pointsWon[TEAM_US] - state.pointsWon[TEAM_THEM],
                message + ": point differential");
        }

        // A random score edit, not added: the engine would take it exactly when possibleEdit() does.
        private function probeEdit(seed as Number, time as Number, message as String) as Void {
            var state = _engine.getState();
            var event = MatchEvent.editScore(time, TestKit.randomEdit(_config, seed));
            var possible = TestKit.possibleEdit(_config, state, event.edit as ScoreEdit);
            if (_engine.canAdd(event) != possible) {
                Test.assertMessage(false, message + ": edit " + event + (possible ? " refused" : " taken") + " at " + TestKit.sets(state));
            }
            note(possible ? "probe taken" : "probe refused", 1);
        }

        // The rules every state follows, the situation and the serve.
        private function check(message as String) as Void {
            var state = _engine.getState();
            TestKit.checkRules(_config, state, message);
            var situation = TestKit.checkNextPoint(_config, state, message);
            note("break point", situation.breakPoint != null ? 1 : 0);
            note("set point", situation.setPoint != null ? 1 : 0);
            note("match point", situation.matchPoint != null ? 1 : 0);
            note("deuce banner", situation.banner == BANNER_DEUCE ? 1 : 0);
            note("tie-break banner", situation.banner == BANNER_TIE_BREAK ? 1 : 0);
            note("same sex", situation.caption == CAPTION_SAME_SEX_RECEIVES ? 1 : 0);
            TestKit.checkSide(state, message);
            var code = _rotation[_rotation.size() - 1];
            var position = code / 2 - 1;
            var expected = "?";
            if (position >= 0) {
                var played = state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM];
                var p = (position + (state.isTieBreak() && played > 0 ? (played - 1) / 2 + 1 : 0)) % _size;
                expected = p % 2 == 1 ? "THEM" : (p == 0) != (code % 2 == 1) ? "ME" : "PARTNER";
            }
            var actual = TestKit.server(state);
            if (!actual.equals(expected)) {
                Test.assertMessage(false, message + ": " + actual + " serves instead of " + expected + " at " + TestKit.sets(state));
            }
        }

        // The stats equal the reference and agree with the state; the games fit between the match start
        // and the last event; with serve tracking off they have no serve stats, and from the start every
        // point is a serve or a return point (none before the first point: nothing to credit, which
        // Tie-break only, one game, often meets after an undo or End set now at 0-0).
        private function checkStats(message as String) as Void {
            var stats = TestKit.computeStats(_engine, TestKit.T0);
            var total = 0;
            for (var i = 0; i < stats.gameDurations.size(); i++) {
                total += stats.gameDurations[i];
            }
            var last = _engine.getState().lastEventTime;
            Test.assertMessage(total <= (last == null ? 0 : last - TestKit.T0), message + ": durations");
            if (_tracking == 1) {
                Test.assertMessage(stats.servePointsPlayed == null, message + ": tracked");
            } else if (_tracking == 0) {
                var played = stats.pointsWon + stats.pointsLost;
                var served = stats.servePointsPlayed;
                var returned = stats.returnPointsPlayed;
                Test.assertMessage(played == 0 ? served == null && returned == null
                    : served != null && returned != null && served + returned == played, message + ": serve and return points");
            }
            note("tracked", stats.breakPointsPlayed != null ? 1 : 0);
        }

        private function note(key as String, count as Number) as Void {
            var before = _seen.get(key);
            _seen.put(key, (before == null ? 0 : before) + count);
        }
    }
}

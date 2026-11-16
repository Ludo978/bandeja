import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Debug builds only: canned matches that open the score screen in a fixed state, to compare it with
// the mockups and check the edge cases in the simulator. Opened from the sensor lock's
// debug menu (hold UP before recording): the fixture's events are played into a new match, a step
// at a time behind LoadView when they're many (FixtureLoad), then the session starts without a
// warm-up, the app holds the match, as resumed (its laps start with the game in progress), and the
// score screen shows it, with no serve question. The mockup fixtures also show the mockup's time
// and heart rate, and on the data page its calories and game time ("Mockup: in play" is the
// data page mockup's match), over ZONES; "Mockup: summary" is one press from the summary mockup,
// which shows its values too; "Mockup: stats" shows the stats page mockup's stats,
// its points 42 s apart. The moves are those of the MatchSituationTest.mc tests: U or T a game, u or t
// a point.
(:debug)
class ScoreFixture {

    var name as String;
    var config as MatchConfig;
    // The serve answers: "Me", "Partner", "Opponents Me", "Opponents Partner", or "" (the server
    // unknown).
    var answer as String;
    var moves as String;
    // [elapsed seconds, heart rate, calories, this game's seconds] as the mockups show them, then the
    // summary's maximum heart rate if any, or null for the real ones.
    var frozen as Array<Number>?;
    // Seconds from the match start to the first point and between points; 0: every event at the match
    // start. The match then starts that long before now for each point (ScoreFixtures.start()).
    var pace as Number = 0;

    function initialize(name as String, config as MatchConfig, answer as String, moves as String,
            frozen as Array<Number>?) {
        self.name = name;
        self.config = config;
        self.answer = answer;
        self.moves = moves;
        self.frozen = frozen;
    }

    // A new engine with the answers and the moves played, every event at time (the points pace apart
    // after it).
    function engine(time as Number) as ScoringEngine {
        var engine = new ScoringEngine(config);
        play(engine, time, 0, -1);
        return engine;
    }

    // Plays the moves from index next on into engine, every event at time, the n-th point pace * n after
    // it, the answers first when next is 0, at most maxEvents points (-1: all). Returns the index of
    // the next move to play, moves.length() once all are played: the next call goes on from there.
    function play(engine as ScoringEngine, time as Number, next as Number, maxEvents as Number) as Number {
        if (next == 0 && !answer.equals("")) {
            engine.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, time, answer.find("Opponents") == null ? TEAM_US : TEAM_THEM));
            if (answer.find("Partner") != null) {
                engine.add(new MatchEvent(EVENT_SWAP_OUR_SERVER, time, null));
            }
        }
        var chars = moves.toCharArray();
        var added = 0;
        while (next < chars.size() && added != maxEvents) {
            var move = chars[next];
            var type = move == 'U' || move == 'u' ? EVENT_POINT_US : EVENT_POINT_THEM;
            // A game goes on until a point ends it or the match; a point, a space or a refused point
            // is one move.
            var points = engine.getState().pointsWon;
            var at = time + pace * (points[TEAM_US] + points[TEAM_THEM] + 1);
            var done = move == ' ' || !engine.add(new MatchEvent(type, at, null));
            if (!done) {
                added++;
                var state = engine.getState();
                done = (move != 'U' && move != 'T') || state.matchOver
                    || state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM] == 0;
            }
            if (done) {
                next++;
            }
        }
        return next;
    }
}

// Debug builds only: a fixture's moves played FixtureLoad.STEP_EVENTS points a step (LoadView), then
// its match opened (ScoreFixtures.open()). BACK goes back to the sensor lock: nothing records yet.
(:debug)
class FixtureLoad extends LoadJob {

    // As many as MatchLoad's, which costs about the same per event.
    static const STEP_EVENTS = MatchLoad.STEP_EVENTS;

    private var _fixture as ScoreFixture;
    private var _flow as WarmUpFlow;
    private var _engine as ScoringEngine;
    private var _time as Number;
    private var _next as Number = 0;

    function initialize(fixture as ScoreFixture, flow as WarmUpFlow, time as Number) {
        LoadJob.initialize();
        _fixture = fixture;
        _flow = flow;
        _engine = new ScoringEngine(fixture.config);
        _time = time;
    }

    function step() as Boolean {
        _next = _fixture.play(_engine, _time, _next, STEP_EVENTS);
        return _next >= _fixture.moves.length();
    }

    function getProgress() as Float {
        return _next.toFloat() / _fixture.moves.length();
    }

    function done() as Void {
        ScoreFixtures.open(_fixture, _flow, _engine, _time);
    }

    function back() as Void {
        var view = new WarmUpView(_flow);
        WatchUi.switchToView(view, new WarmUpDelegate(view), WatchUi.SLIDE_RIGHT);
    }
}

(:debug)
module ScoreFixtures {

    // Heart rate zones that put the mockups' heart rates in their zones (139 in zone 3, 152 in 4,
    // 171 in 5), 152 where the data page mockup has its marker, 8/15 of the way along zone 4.
    const ZONES = [100, 120, 132, 144, 159, 175] as Array<Number>;

    // The mockups first, then the edge cases.
    function all() as Array<ScoreFixture> {
        var mixed = new MatchConfig();
        mixed.mixed = true;
        var superTieBreak = new MatchConfig();
        superTieBreak.applyPreset(PRESET_BEST_OF_3_SUPER_TB);
        var singles = new MatchConfig();
        singles.doubles = false;
        // Sets to 2 games, so the five rows fit in a few presses.
        var bestOf5 = new MatchConfig();
        bestOf5.setsToWin = 3;
        bestOf5.gamesToWin = 2;
        bestOf5.tieBreakAt = 2;
        bestOf5.hasTieBreak = false;
        var shortSets = new MatchConfig();
        shortSets.applyPreset(PRESET_SHORT_SETS);
        var bestOf5Preset = new MatchConfig();
        bestOf5Preset.applyPreset(PRESET_BEST_OF_5);
        var tieBreak7 = new MatchConfig();
        tieBreak7.applyPreset(PRESET_TIE_BREAK_7);
        var tieBreak10 = new MatchConfig();
        tieBreak10.applyPreset(PRESET_TIE_BREAK_10);
        var freePlay = new MatchConfig();
        freePlay.applyPreset(PRESET_FREE_PLAY);
        var starPoint = "UUUUUU UTUTUTTTT UUTUTUU uuuttt ut ut";
        return [
            new ScoreFixture("Mockup: in play", new MatchConfig(), "Opponents Me", "UTTTTTT UTUTUTU ututu", [2537, 152, 486, 134]),
            new ScoreFixture("Mockup: star point", new MatchConfig(), "Me", starPoint, [4865, 171, 905, 288]),
            new ScoreFixture("Mockup: tie-break", new MatchConfig(), "Me", "UTUTUTUTUTUT ututututt", [3520, 139, 652, 415]),
            new ScoreFixture("Server unknown", new MatchConfig(), "", "U uut", null),
            new ScoreFixture("Super tie-break", superTieBreak, "Me", "UUUUUU TTTTTT uuttuuttuu", null),
            new ScoreFixture("AD us", new MatchConfig(), "Me", "uuuttt u", null),
            new ScoreFixture("AD them", new MatchConfig(), "Me", "uuuttt t", null),
            new ScoreFixture("Match point", new MatchConfig(), "Me", "UUUUUU UUUUUT uuu", null),
            new ScoreFixture("Deuce 2", new MatchConfig(), "Me", "uuuttt ut", null),
            new ScoreFixture("Mixed star point", mixed, "Me", starPoint, null),
            new ScoreFixture("Singles", singles, "Me", "u", null),
            // One press from the game, set and match overlays; "Mockup: in play" and "Match
            // point" are the game's and the match's.
            new ScoreFixture("Set point them", new MatchConfig(), "Me", "UTTUTTT ttt", null),
            new ScoreFixture("Tie-break set point", new MatchConfig(), "Me", "UTUTUTUTUTUT uuuuuuttttt", null),
            new ScoreFixture("Super TB match point", superTieBreak, "Me", "UUUUUU TTTTTT uuuuuuuuutttttttt", null),
            // DOWN wins the summary mockup's match, 6-4 3-6 10-8, its duration and heart rates
            // frozen (the maximum heart rate only shows on the summary).
            new ScoreFixture("Mockup: summary", superTieBreak, "Me", "UTUTUTUTUU UTUTUTTTT uuuuuuuuutttttttt",
                [5050, 148, 905, 0, 171]),
            // Best of 5 with no tie-break, a long set first: the summary's five rows.
            new ScoreFixture("Best of 5 match point", bestOf5, "Me",
                "UTUTUTUTUTUTUTUTUU TT UU TT U uuu", null),
            // The Best of 5 preset at 6-4 3-6 7-6 (7-5) 4-6 5-4 40-15, two sets each: three
            // pips a team, two filled; DOWN wins it 3-2, the summary's five rows of sets of 6.
            new ScoreFixture("Best of 5: 5th set", bestOf5Preset, "Me",
                "UTUTUTUTUU UTUTUTTTT UTUTUTUTUTUT uuuuuttttt uu UTUTUTUTTT UTUTUTUTU uuut", null),
            // The Short sets preset: 4-2, then the tie-break at 4-4, 2-1.
            new ScoreFixture("Short sets tie-break", shortSets, "Me", "UTUTUU UTUTUTUT uut", null),
            // Tie-break only at its match point: to 7 at 6-5 (DOWN wins it 7-5), to 10 at 9-8.
            new ScoreFixture("Tie-break to 7: 6-5", tieBreak7, "Me", "uuuuuttttt u", null),
            new ScoreFixture("Tie-break to 10: 9-8", tieBreak10, "Opponents Me", "uuuuuuuuu tttttttt", null),
            // DOWN wins the 7th game of set 2, 5-2: the "Game won + change ends" mockup's overlay with
            // its CHANGE ENDS pill (the mockup's 5 - 3, 8 games, brings no change of ends).
            new ScoreFixture("Game + change ends", new MatchConfig(), "Opponents Me", "UTTTTTT UTUTUU ututu", null),
            // Free play in its fifth set, three sets won to one: the sets won as numbers.
            new ScoreFixture("Free play: set 5", freePlay, "Me", "UUUUUU TTTTTT UUUUUU UTUTUTUTUU UTU uut", null),
            stats()
        ];
    }

    // The stats page mockup's match: set 1, 4-3, 30-15, we served first, a point every 42 s.
    // 21-17 points (55 %), 14 of our 21 serve points (67 %), 0:42 a point, a best streak of 6 (the
    // last 4 points of game 3 and the first 2 of game 4).
    function stats() as ScoreFixture {
        var fixture = new ScoreFixture("Mockup: stats", new MatchConfig(), "Me",
            "uutuu tuttt uuuu uutuu tuutuu tttt uttutt utu", null);
        fixture.pace = 42;
        return fixture;
    }

    // From the sensor lock: the fixture's moves, at once when they fit in a step, else behind
    // LoadView in place of the lock (FixtureLoad), then its match opens. With a pace, the match starts
    // as long before now as its points take, so its last point is now.
    function start(fixture as ScoreFixture, flow as WarmUpFlow) as Void {
        var time = Time.now().value();
        if (fixture.pace > 0) {
            var points = fixture.engine(time).getState().pointsWon;
            time -= fixture.pace * (points[TEAM_US] + points[TEAM_THEM]);
        }
        var job = new FixtureLoad(fixture, flow, time);
        if (job.step()) {
            job.done();
        } else {
            WatchUi.switchToView(new LoadView(job), new LoadDelegate(job), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // The fixture's engine, its events at time, becomes the match: recording without a warm-up, the
    // match held as resumed (no burst of laps for the games already played), the score screen in
    // place of the lock or LoadView. The error screen when the watch refuses the session.
    function open(fixture as ScoreFixture, flow as WarmUpFlow, engine as ScoringEngine, time as Number) as Void {
        flow.config = fixture.config;
        flow.warmUp = false;
        var session = getSessionManager();
        if (flow.start(time) != STEP_MATCH) {
            showSessionError(session);
            return;
        }
        var laps = getLapCommitter();
        var match = new CurrentMatch(engine, time, flow.outdoor, session, laps);
        match.court = flow.court;
        laps.resume(engine.getState());
        var view = MatchFlow.showScore(match);
        var frozen = fixture.frozen;
        if (frozen != null) {
            view.fix(frozen, ZONES);
        }
    }
}

// Debug builds only: the sensor lock's debug menu (hold UP before recording): the score fixtures,
// then a session the watch refuses (the error screen), then stored matches for the launch
// prompt, each written before the app exits: one whose log can't be replayed (Discard
// only), and long ones, 300, 600 and 1,000 events into the third set, for long matches within the
// watchdog and the times of the writes (the match menu's debug item shows them), then Free
// play at 3,000 events, and at the longest match kept but FULL_ROOM points (the log's limit,
// ScoringEngine.LOG_MAX). Then the history filled with 20 matches (HistoryFixtures) or
// emptied, back on the lock. Last, a change made as the Garmin Connect app makes it, applied a few
// seconds later (DebugSettings).
(:debug)
module DebugMenu {

    const REFUSED_SESSION = -1;
    const STORED_BAD = -2;
    const STORED_FREE_PLAY = -3;
    const STORED_FREE_PLAY_FULL = -4;
    const HISTORY_FULL = -10;
    const HISTORY_CLEAR = -11;
    const CONNECT_CHANGE = -12;
    // A long match's item is its event count, negated.
    const LONG_EVENTS = [300, 600, 1000] as Array<Number>;
    // The long Free play match's events, and the points the full one has room for.
    const FREE_PLAY_EVENTS = 3000;
    const FULL_ROOM = 3;

    function open(lock as WarmUpDelegate) as Void {
        var menu = new WatchUi.Menu2({:title => "Debug"});
        var fixtures = ScoreFixtures.all();
        for (var i = 0; i < fixtures.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(fixtures[i].name, null, i, null));
        }
        menu.addItem(new WatchUi.MenuItem("Refused session", null, REFUSED_SESSION, null));
        menu.addItem(new WatchUi.MenuItem("Stored: bad log", "then exit", STORED_BAD, null));
        for (var i = 0; i < LONG_EVENTS.size(); i++) {
            menu.addItem(new WatchUi.MenuItem("Stored: " + LONG_EVENTS[i] + " events", "then exit", -LONG_EVENTS[i], null));
        }
        menu.addItem(new WatchUi.MenuItem("Stored: free play " + FREE_PLAY_EVENTS, "then exit", STORED_FREE_PLAY, null));
        menu.addItem(new WatchUi.MenuItem("Stored: free play full", FULL_ROOM + " points left, then exit",
            STORED_FREE_PLAY_FULL, null));
        menu.addItem(new WatchUi.MenuItem("History: 20 matches", null, HISTORY_FULL, null));
        menu.addItem(new WatchUi.MenuItem("History: clear", null, HISTORY_CLEAR, null));
        menu.addItem(new WatchUi.MenuItem("Connect change", DebugSettings.nextName(), CONNECT_CHANGE, null));
        WatchUi.pushView(menu, new DebugMenuDelegate(lock, fixtures), WatchUi.SLIDE_UP);
    }

    // A stored match the launch replays as bad: its second event doesn't exist.
    function storeBad() as Void {
        var now = Time.now().value();
        MatchStore.write(MatchStore.KEY, {"config" => new MatchConfig().toDictionary(), "start" => now,
            "outdoor" => false, "log" => [EVENT_POINT_US as Number, now, 7, now]});
    }

    // A long match of events events stored as at a crash (Best of 3, Advantage, Indoor), a point
    // every 30 s up to now.
    function storeLong(events as Number) as Void {
        var start = Time.now().value() - 30 * events;
        store(longConfig(), start, longLog(events, start));
    }

    // A match stored as MatchStore.save() stores it: the log's full parts, then the match with the rest.
    function store(config as MatchConfig, start as Number, log as Array<Number>) as Void {
        MatchStore.clear();
        var parts = log.size() / MatchStore.PART_NUMBERS;
        for (var part = 0; part < parts; part++) {
            MatchStore.write(MatchStore.PART_KEY + part, log.slice(part * MatchStore.PART_NUMBERS,
                (part + 1) * MatchStore.PART_NUMBERS) as Array<Application.Storage.ValueType>);
        }
        var value = {"config" => config.toDictionary(), "start" => start, "outdoor" => false,
            "log" => log.slice(parts * MatchStore.PART_NUMBERS, null)} as Dictionary<Application.Storage.KeyType, Application.Storage.ValueType>;
        if (parts > 0) {
            value["parts"] = parts;
        }
        MatchStore.write(MatchStore.KEY, value);
    }

    function longConfig() as MatchConfig {
        var config = new MatchConfig();
        config.deuceMode = DEUCE_ADVANTAGE;
        return config;
    }

    // A long Free play match of events events stored as at a crash (Star point, Indoor), a point every
    // 20 s up to now (freePlayLog()).
    function storeFreePlay(events as Number) as Void {
        var start = Time.now().value() - 20 * events;
        store(freePlayConfig(), start, freePlayLog(events, start));
    }

    // The Free play match with room for FULL_ROOM more points (ScoringEngine.hasRoom()) and End match.
    function fullEvents() as Number {
        return (ScoringEngine.LOG_MAX / ScoringEngine.LOG_NUMBERS_PER_EVENT) - 1 - FULL_ROOM;
    }

    function freePlayConfig() as MatchConfig {
        var config = new MatchConfig();
        config.applyPreset(PRESET_FREE_PLAY);
        return config;
    }

    // Free play's sets as the long match plays them (FREE_PLAY_SETS), each game's winner in turn, U us or
    // T them; a set at 6-6 goes on to the tie-break, won by the set's last letter.
    const FREE_PLAY_SETS = ["UTUTUTUTUU", "UTUTUTTTT", "UTUTUTUTUTUTU", "TTUTTUTT", "UTUTUTUTUTUU"] as Array<String>;

    // The log of a long match in freePlayConfig(), its first event at start and the others 20 s apart:
    // Me serving first, then sets 6-4, 3-6, 7-6 (7-5), 2-6 and 7-5 again and again, about 60 points a set,
    // so 3,000 events end in set 48. Each game is won 4-2 (no deuce), a tie-break 7-5. Written as the
    // log, without the engine, as longLog().
    function freePlayLog(events as Number, start as Number) as Array<Number> {
        var log = [new MatchEvent(EVENT_FIX_SERVING_TEAM, start, TEAM_US).getCode(), start] as Array<Number>;
        var count = 1;
        for (var set = 0; count < events; set++) {
            var games = FREE_PLAY_SETS[set % FREE_PLAY_SETS.size()].toCharArray();
            for (var game = 0; game < games.size() && count < events; game++) {
                var us = games[game] == 'U';
                // The winner's 4 points (7 in a tie-break) and the loser's 2 (5), in turn, the winner's
                // last two together.
                var lost = game == 12 ? 5 : 2;
                for (var point = 0; point < 2 * lost + 2 && count < events; point++) {
                    var won = point >= 2 * lost || point % 2 == 0;
                    log.add((won == us ? EVENT_POINT_US : EVENT_POINT_THEM) as Number);
                    log.add(start + 20 * count);
                    count++;
                }
            }
        }
        return log;
    }

    // The log of a long match in longConfig(), its first event at start and the others 30 s apart:
    // Me serving first, then every game goes to deuce (events - 100) / 90 times (2 for 300 events,
    // 10 for 1,000), the loser of each game (the two teams in turn) taking its first point and the
    // winner its last two. Each set goes to 6-6 and a tie-break, ours then theirs, so 300, 600 and
    // 1,000 events end in the third set with the match not over. Written as the log, without the
    // engine: adding 1,000 events in one callback would trip the watchdog.
    function longLog(events as Number, start as Number) as Array<Number> {
        var deuces = (events - 100) / 90;
        var log = [new MatchEvent(EVENT_FIX_SERVING_TEAM, start, TEAM_US).getCode(), start] as Array<Number>;
        var count = 1;
        var set = 0;
        var game = 0;
        while (count < events) {
            var tieBreak = game == 12;
            var us = tieBreak ? set % 2 == 0 : game % 2 == 0;
            // Points each before the winner's last two: to 7 in a tie-break.
            var level = 2 + deuces;
            level = tieBreak && level < 5 ? 5 : level;
            for (var point = 0; point < 2 * level + 2 && count < events; point++) {
                var won = point >= 2 * level || point % 2 == 1;
                log.add((won == us ? EVENT_POINT_US : EVENT_POINT_THEM) as Number);
                log.add(start + 30 * count);
                count++;
            }
            game++;
            if (game > 12) {
                game = 0;
                set++;
            }
        }
        return log;
    }
}

(:debug)
class DebugMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _lock as WarmUpDelegate;
    private var _fixtures as Array<ScoreFixture>;

    function initialize(lock as WarmUpDelegate, fixtures as Array<ScoreFixture>) {
        Menu2InputDelegate.initialize();
        _lock = lock;
        _fixtures = fixtures;
    }

    // Back on the lock first, which the next screen then replaces.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Number;
        if (id == DebugMenu.HISTORY_FULL || id == DebugMenu.HISTORY_CLEAR || id == DebugMenu.CONNECT_CHANGE) {
            if (id == DebugMenu.HISTORY_FULL) {
                HistoryFixtures.fill();
            } else if (id == DebugMenu.HISTORY_CLEAR) {
                HistoryStore.clear();
            } else {
                DebugSettings.schedule();
            }
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (id <= DebugMenu.STORED_BAD) {
            if (id == DebugMenu.STORED_BAD) {
                DebugMenu.storeBad();
            } else if (id == DebugMenu.STORED_FREE_PLAY) {
                DebugMenu.storeFreePlay(DebugMenu.FREE_PLAY_EVENTS);
            } else if (id == DebugMenu.STORED_FREE_PLAY_FULL) {
                DebugMenu.storeFreePlay(DebugMenu.fullEvents());
            } else {
                DebugMenu.storeLong(-id);
            }
            getSessionManager().disableSensors();
            System.exit();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == DebugMenu.REFUSED_SESSION) {
            _lock.debugRefusedSession();
        } else {
            _lock.debugFixture(_fixtures[id]);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

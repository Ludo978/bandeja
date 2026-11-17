import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The tests' shared helpers, kept out of release builds: formats, events and moves, the texts the
// tests compare with, the rules every state must follow, a fake recorder, and the match set up as
// the app sets it up.
//
// Moves (play()): an upper-case letter is a game won by that team, U us or T them, which wins every
// point until the game ends; a lower-case one is a single point; "<" undoes the last event; spaces
// are only for reading. Events are 30 s apart (nextTime()). Serve answers (newMatch()): "Me",
// "Partner", "Opponents Me", "Opponents Partner", or "" for serve tracking off.
(:test)
module TestKit {

    // A fixed wall-clock time (2026-10-29, seconds since the Unix epoch): tests never read the clock.
    const T0 = 1793280000;
    // The START that ended the warm-up in the stats tests: 15 s before the first event.
    const START = T0 - 15;
    // When the menu items are picked in the tests.
    const MENU_TIME = T0 + 600;
    const MODES = [DEUCE_ADVANTAGE, DEUCE_GOLDEN, DEUCE_STAR, DEUCE_SILVER];
    // Random tests replay the whole log only every REPLAY_EVERY steps: a replay costs the whole log.
    const REPLAY_EVERY = 25;

    // What checkSteps() and checkEvent() compare: game(), sets(), serveFlags(), situation().
    const VIEW_GAME = 0;
    const VIEW_SETS = 1;
    const VIEW_SERVE = 2;
    const VIEW_SITUATION = 3;

    // Formats ------------------------------------------------------------------------------------

    // This set structure (sets to win, N, T, a tie-break or not), tie-breaks to 7, Star point.
    function format(setsToWin as Number, gamesToWin as Number, tieBreakAt as Number,
            hasTieBreak as Boolean) as MatchConfig {
        var config = new MatchConfig();
        config.setsToWin = setsToWin;
        config.gamesToWin = gamesToWin;
        config.tieBreakAt = tieBreakAt;
        config.hasTieBreak = hasTieBreak;
        Test.assertMessage(config.isValid(), "invalid format");
        return config;
    }

    function preset(preset as Preset) as MatchConfig {
        var config = new MatchConfig();
        config.applyPreset(preset);
        return config;
    }

    // The default format (best of 3, doubles) with this deuce mode.
    function withMode(mode as DeuceMode) as MatchConfig {
        var config = new MatchConfig();
        config.deuceMode = mode;
        return config;
    }

    // Best of 5 Fast4 with no tie-break, TB to 10, a final super tie-break, Golden Point, singles,
    // mixed: every field away from the default.
    function custom() as MatchConfig {
        var config = format(3, 4, 3, false);
        config.tieBreakPoints = 10;
        config.superTieBreak = true;
        config.deuceMode = DEUCE_GOLDEN;
        config.doubles = false;
        config.mixed = true;
        return config;
    }

    // The default format as toDictionary() stores it.
    function storedBestOf3() as Dictionary<String, Object?> {
        return {
            "setsToWin" => 2, "gamesToWin" => 6, "tieBreakAt" => 6, "hasTieBreak" => true, "tieBreakPoints" => 7,
            "superTieBreak" => false, "deuceMode" => 2, "doubles" => true, "mixed" => false
        } as Dictionary<String, Object?>;
    }

    // The random tests' formats: the presets (Tie-break only to 7 and 10 and Free play among them) and
    // custom set structures (N = 2 to 6, T = N or N - 1, no tie-break), every deuce mode, tie-breaks to 7
    // and 10, super tie-breaks, best of 1 to 5 and no end, in doubles, mixed doubles and singles.
    function formats() as Array<MatchConfig> {
        var list = [] as Array<MatchConfig>;
        var presets = MatchConfig.presets();
        for (var i = 0; i < presets.size(); i++) {
            var p = preset(presets[i]);
            p.deuceMode = MODES[i % 4] as DeuceMode;
            list.add(p);
        }
        var config = format(2, 4, 4, true);
        config.superTieBreak = true;
        config.tieBreakPoints = 10;
        list.add(config);
        config = format(2, 4, 3, true);
        config.deuceMode = DEUCE_GOLDEN;
        list.add(config);
        config = format(2, 6, 6, false);
        config.superTieBreak = true;
        config.deuceMode = DEUCE_ADVANTAGE;
        list.add(config);
        config = format(3, 6, 6, true);
        config.tieBreakPoints = 10;
        config.deuceMode = DEUCE_SILVER;
        list.add(config);
        config = format(3, 2, 1, true);
        config.superTieBreak = true;
        list.add(config);
        var singles = [preset(PRESET_BEST_OF_3), preset(PRESET_BEST_OF_3_SUPER_TB), format(2, 4, 3, true),
            preset(PRESET_TIE_BREAK_10), preset(PRESET_FREE_PLAY)];
        singles[2].deuceMode = DEUCE_GOLDEN;
        for (var i = 0; i < singles.size(); i++) {
            singles[i].doubles = false;
            list.add(singles[i]);
        }
        for (var i = 1; i < list.size(); i += 3) {
            list[i].mixed = true;
        }
        return list;
    }

    // The super tie-break's length, worked out apart from MatchConfig: 10, or with one
    // set to win (Tie-break only, the one set played as a super tie-break) the tie-break's, 7 or 10.
    function superLength(config as MatchConfig) as Number {
        return config.setsToWin == 1 ? config.tieBreakPoints : 10;
    }

    // Whether a team with sets sets has won the match, worked out apart from MatchConfig: never
    // in Free play, whose setsToWin is 0, else at setsToWin.
    function winsMatch(config as MatchConfig, sets as Number) as Boolean {
        return config.setsToWin > 0 && sets >= config.setsToWin;
    }

    // The most sets a match lasts, setsToWin * 2 - 1, or null for Free play, which has no end.
    function mostSets(config as MatchConfig) as Number? {
        return config.setsToWin > 0 ? 2 * config.setsToWin - 1 : null;
    }

    // Best of 3 sets of 2 games, tie-break at 1-1, Golden Point: short matches with every case.
    function shortSets() as MatchConfig {
        var config = format(2, 2, 1, true);
        config.deuceMode = DEUCE_GOLDEN;
        return config;
    }

    // A match scored by hand (StatsCalculatorTest), set by set, Me serving first, and its stats.
    const HAND_SCORED_SETS = ["utttuuu uuutu", "tttt tttuuuu ttuutttutt", "tttuuut uuuu uuttuuuttt uu"];
    const HAND_SCORED = "points 29-27 52%, games 5-3, sets 2-1, deciding 2/3, tie-breaks 1/2, durations 225 150 120 210 300 210 120 360, longest 7"
        + ", per point 30 s, streak 6 | serve 14/26 54%, return 15/30 50%, held 2/3, conceded 1, broke 2/3, break points 2/4, saved 3/4";

    function handScoredMatch() as ScoringEngine {
        var engine = newMatch(shortSets(), "Me");
        for (var i = 0; i < HAND_SCORED_SETS.size(); i++) {
            play(engine, HAND_SCORED_SETS[i] as String);
        }
        return engine;
    }

    // A serve answer for the format, a different one for each index.
    function answer(config as MatchConfig, index as Number) as String {
        if (!config.doubles) {
            return index % 2 == 0 ? "Me" : "Opponents Me";
        }
        return ["Me", "Partner", "Opponents Me", "Opponents Partner"][index % 4] as String;
    }

    // Events and moves ---------------------------------------------------------------------------

    function nextTime(engine as ScoringEngine) as Number {
        return T0 + 30 * engine.getState().eventCount;
    }

    // A new match with the serve answer logged as the app logs it: FIX_SERVING_TEAM,
    // then SWAP_OUR_SERVER for Partner.
    function newMatch(config as MatchConfig, answer as String) as ScoringEngine {
        var engine = new ScoringEngine(config);
        logAnswer(engine, null, answer);
        return engine;
    }

    // A new match after the serve answer and the moves.
    function matchOf(config as MatchConfig, answer as String, moves as String) as ScoringEngine {
        var engine = newMatch(config, answer);
        play(engine, moves);
        return engine;
    }

    function logAnswer(engine as ScoringEngine, match as CurrentMatch?, answer as String) as Void {
        if (!answer.equals("")) {
            addThrough(engine, match, EVENT_FIX_SERVING_TEAM, answer.find("Opponents") == null ? TEAM_US : TEAM_THEM);
            if (answer.find("Partner") != null) {
                addThrough(engine, match, EVENT_SWAP_OUR_SERVER, null);
            }
        }
    }

    // Adds the event at the next time, which must be accepted, and returns it.
    function add(engine as ScoringEngine, type as EventType, payload as Number?) as MatchEvent {
        return addThrough(engine, null, type, payload);
    }

    // The same, through the match holder when there is one.
    function addThrough(engine as ScoringEngine, match as CurrentMatch?, type as EventType, payload as Number?) as MatchEvent {
        var event = new MatchEvent(type, nextTime(engine), payload);
        Test.assertMessage(addEvent(engine, match, event), "refused " + event);
        return event;
    }

    function addEvent(engine as ScoringEngine, match as CurrentMatch?, event as MatchEvent) as Boolean {
        if (match != null) {
            return match.add(event);
        }
        return engine.add(event);
    }

    // A point for "u" or "U" (us), "t" or "T" (them), at the next time, not added.
    function point(engine as ScoringEngine, team as String) as MatchEvent {
        var us = team.equals("u") || team.equals("U");
        return new MatchEvent(us ? EVENT_POINT_US : EVENT_POINT_THEM, nextTime(engine), null);
    }

    function play(engine as ScoringEngine, moves as String) as Void {
        playThrough(engine, null, moves);
    }

    // Plays the moves through the match holder when there is one, as the app does.
    function playThrough(engine as ScoringEngine, match as CurrentMatch?, moves as String) as Void {
        for (var i = 0; i < moves.length(); i++) {
            var step = moves.substring(i, i + 1) as String;
            if (step.equals("<")) {
                var undone = null as MatchEvent?;
                if (match != null) {
                    undone = match.undo();
                } else {
                    undone = engine.undo();
                }
                Test.assertMessage(undone != null, "nothing to undo");
            } else if (!step.equals(" ")) {
                move(engine, match, step, false);
            }
        }
    }

    // One move: a point, or a whole game. With check, each point is undone and played again, and
    // undo must give back the state before it.
    function move(engine as ScoringEngine, match as CurrentMatch?, step as String, check as Boolean) as Void {
        var wholeGame = step.equals("U") || step.equals("T");
        for (var i = 0; i < 100; i++) {
            var state = engine.getState();
            var games = state.finishedGames.size();
            var before = check ? state.copy() : null;
            var event = point(engine, step);
            Test.assertMessage(addEvent(engine, match, event), "refused " + event);
            if (before != null) {
                var undone = engine.undo();
                Test.assertMessage(undone != null && undone.equals(event), "undid " + undone);
                assertSameState(engine.getState(), before, "undo of " + event);
                Test.assert(engine.add(event));
            }
            state = engine.getState();
            if (!wholeGame || state.matchOver || state.finishedGames.size() > games) {
                return;
            }
        }
        Test.assertMessage(false, "the game never ended");
    }

    function undoTo(engine as ScoringEngine, eventCount as Number) as Void {
        while (engine.getState().eventCount > eventCount) {
            engine.undo();
        }
    }

    // The stored form of the events, as ScoringEngine.getLog() keeps it.
    function logOf(events as Array<MatchEvent>) as Array<Number> {
        var stored = [] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < events.size(); i++) {
            events[i].addTo(stored);
        }
        var log = [] as Array<Number>;
        for (var i = 0; i < stored.size(); i++) {
            log.add(stored[i] as Number);
        }
        return log;
    }

    // Where event index starts in a log in getLog()'s form, walking the events before it.
    function offsetOf(log as Object, index as Number) as Number {
        var offset = 0;
        for (var i = 0; i < index; i++) {
            offset += (MatchEvent.fromLog(log, offset) as MatchEvent).getSize();
        }
        return offset;
    }

    // Where each event of the log starts, then the log's size.
    function offsetsOf(log as Object) as Array<Number> {
        var offsets = [0] as Array<Number>;
        for (var offset = 0; offset < (log as Array).size(); ) {
            offset += (MatchEvent.fromLog(log, offset) as MatchEvent).getSize();
            offsets.add(offset);
        }
        return offsets;
    }

    // Every event type, in an order a new doubles match accepts: serve answers, a deuce mode change, a
    // game won by us, a point, a set ended with us ahead, a set ended level given to them, the end.
    function oneOfEachType() as Array<MatchEvent> {
        var t = T0;
        return [
            new MatchEvent(EVENT_FIX_SERVING_TEAM, t, TEAM_THEM), new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 1, null),
            new MatchEvent(EVENT_SET_DEUCE_MODE, t + 5, DEUCE_GOLDEN), new MatchEvent(EVENT_POINT_US, t + 40, null),
            new MatchEvent(EVENT_POINT_US, t + 80, null), new MatchEvent(EVENT_POINT_US, t + 120, null),
            new MatchEvent(EVENT_POINT_US, t + 160, null), new MatchEvent(EVENT_POINT_THEM, t + 200, null),
            new MatchEvent(EVENT_END_SET, t + 230, null), new MatchEvent(EVENT_END_SET, t + 240, TEAM_THEM),
            new MatchEvent(EVENT_END_MATCH, t + 250, null)
        ];
    }

    // Every type with every payload it accepts.
    function everyValidEvent() as Array<MatchEvent> {
        var t = T0;
        return [
            new MatchEvent(EVENT_POINT_US, t, null), new MatchEvent(EVENT_POINT_THEM, t + 25, null),
            new MatchEvent(EVENT_SWAP_OUR_SERVER, t + 40, null), new MatchEvent(EVENT_FIX_SERVING_TEAM, t + 41, TEAM_US),
            new MatchEvent(EVENT_FIX_SERVING_TEAM, t + 42, TEAM_THEM), new MatchEvent(EVENT_SET_DEUCE_MODE, t + 50, DEUCE_ADVANTAGE),
            new MatchEvent(EVENT_SET_DEUCE_MODE, t + 51, DEUCE_GOLDEN), new MatchEvent(EVENT_SET_DEUCE_MODE, t + 52, DEUCE_STAR),
            new MatchEvent(EVENT_SET_DEUCE_MODE, t + 53, DEUCE_SILVER), new MatchEvent(EVENT_END_SET, t + 60, null),
            new MatchEvent(EVENT_END_SET, t + 61, TEAM_US), new MatchEvent(EVENT_END_SET, t + 62, TEAM_THEM),
            new MatchEvent(EVENT_END_MATCH, t + 70, null),
            // Time 0 is still a time.
            new MatchEvent(EVENT_POINT_US, 0, null),
            MatchEvent.editScore(t + 80, edit("6-4 6-7(5-7) 3-2EU | 1-0 4-3"))
        ];
    }

    // Events whose payload doesn't fit the type, of unknown type, or with a negative time.
    function invalidEvents() as Array<MatchEvent> {
        var t = T0;
        return [
            new MatchEvent(EVENT_POINT_US, t, TEAM_US), new MatchEvent(EVENT_POINT_THEM, t, TEAM_THEM),
            new MatchEvent(EVENT_SWAP_OUR_SERVER, t, PLAYER_PARTNER), new MatchEvent(EVENT_FIX_SERVING_TEAM, t, null),
            new MatchEvent(EVENT_FIX_SERVING_TEAM, t, 2), new MatchEvent(EVENT_FIX_SERVING_TEAM, t, -1),
            new MatchEvent(EVENT_SET_DEUCE_MODE, t, null), new MatchEvent(EVENT_SET_DEUCE_MODE, t, 4),
            new MatchEvent(EVENT_SET_DEUCE_MODE, t, -1), new MatchEvent(EVENT_END_SET, t, 2),
            new MatchEvent(EVENT_END_SET, t, -1), new MatchEvent(EVENT_END_MATCH, t, TEAM_US),
            new MatchEvent(-1 as EventType, t, null), new MatchEvent(8 as EventType, t, null),
            new MatchEvent(EVENT_POINT_US, -1, null),
            // A score edit with no score, a payload or a count the stored form can't hold; a score on
            // another type.
            new MatchEvent(EVENT_EDIT_SCORE, t, null), new MatchEvent(EVENT_EDIT_SCORE, t, 0),
            MatchEvent.editScore(t, new ScoreEdit([], [-1, 0], [0, 0])), MatchEvent.editScore(t, new ScoreEdit([], [0, 0], [0, 100])),
            MatchEvent.editScore(t, new ScoreEdit([], [0], [0, 0])), MatchEvent.editScore(t, edit("100-98 | 0-0 0-0")),
            MatchEvent.editScore(t, edit("7-6(100-98) | 0-0 0-0")), MatchEvent.editScore(-1, edit("| 1-0 0-0")),
            withEdit(new MatchEvent(EVENT_POINT_US, t, null), edit("| 1-0 0-0"))
        ];
    }

    function withEdit(event as MatchEvent, edit as ScoreEdit) as MatchEvent {
        event.edit = edit;
        return event;
    }

    function repeat(text as String, count as Number) as String {
        var result = "";
        for (var i = 0; i < count; i++) {
            result += text;
        }
        return result;
    }

    // Small deterministic generator (period 65536), so the tests never depend on Math.rand().
    function nextRandom(seed as Number) as Number {
        return (seed * 75 + 74) % 65537;
    }

    // Mostly points, sometimes a swap of our order, a deuce mode change, End set now (now and then
    // naming a team the wrong way round, which is refused), End match, a score edit (randomEdit(), often
    // refused), and with fix a Fix serving team. Swaps in singles and changes that change nothing are
    // refused too.
    function randomEvent(config as MatchConfig, state as MatchState, seed as Number, time as Number,
            fix as Boolean) as MatchEvent {
        var roll = seed % 50;
        var pick = seed / 50;
        if (roll == 8 || roll == 9) {
            return MatchEvent.editScore(time, randomEdit(config, pick));
        } else if (roll == 1) {
            return new MatchEvent(EVENT_SWAP_OUR_SERVER, time, null);
        } else if ((roll == 2 || roll == 3) && fix) {
            return new MatchEvent(EVENT_FIX_SERVING_TEAM, time, pick % 2);
        } else if (roll == 4 || roll == 5) {
            return new MatchEvent(EVENT_SET_DEUCE_MODE, time, pick % 4);
        } else if (roll == 6) {
            var level = (state.getSetLeader() == null) != (pick % 5 == 0);
            return new MatchEvent(EVENT_END_SET, time, level ? pick % 2 : null);
        } else if (roll == 7 && pick % 2 == 0) {
            return new MatchEvent(EVENT_END_MATCH, time, null);
        }
        return new MatchEvent(pick % 2 == 0 ? EVENT_POINT_US : EVENT_POINT_THEM, time, null);
    }

    // Score edits ----------------------------------------------------------------------------------

    // The score edit a text gives, in sets()'s form but with the game's point counts: the finished sets
    // ("6-4", "7-6(7-5)", a super tie-break "S10-8", "E" and the team for a set End set now gave,
    // "3-2EU", or a team to force a winner, "6-6U"), "|", then the current set's games and the game's
    // point counts. "6-4 | 2-1 2-1" is 6-4 then 2-1 and 30-15; "| 6-6 3-2" a tie-break at 3-2. A set's
    // winner is the team with more games (more points in a super tie-break), us when level.
    function edit(text as String) as ScoreEdit {
        var bar = text.find("|") as Number;
        var words = wordsOf(text.substring(0, bar) as String);
        var current = wordsOf(text.substring(bar + 1, text.length()) as String);
        var sets = [] as Array<SetScore>;
        for (var i = 0; i < words.size(); i++) {
            sets.add(editedSet(words[i]));
        }
        return new ScoreEdit(sets, pairOf(current[0]), pairOf(current[1]));
    }

    // EDIT_SCORE with the edit of the text, at the next time.
    function editEvent(engine as ScoringEngine, text as String) as MatchEvent {
        return MatchEvent.editScore(nextTime(engine), edit(text));
    }

    function editedSet(word as String) as SetScore {
        var superTieBreak = (word.substring(0, 1) as String).equals("S");
        if (superTieBreak) {
            word = word.substring(1, word.length()) as String;
        }
        var early = word.find("E") != null;
        var winner = null as Team?;
        var last = word.substring(word.length() - 1, word.length()) as String;
        if (last.equals("U") || last.equals("T")) {
            winner = last.equals("U") ? TEAM_US : TEAM_THEM;
            word = word.substring(0, word.length() - (early ? 2 : 1)) as String;
        }
        var tieBreak = null as Array<Number>?;
        var open = word.find("(");
        if (open != null) {
            tieBreak = pairOf(word.substring(open + 1, word.length() - 1) as String);
            word = word.substring(0, open) as String;
        }
        var score = pairOf(word);
        if (winner == null) {
            winner = score[TEAM_THEM] > score[TEAM_US] ? TEAM_THEM : TEAM_US;
        }
        return new SetScore(superTieBreak ? [0, 0] : score, superTieBreak ? score : tieBreak, superTieBreak,
            winner as Team, early);
    }

    // "7-5" as [7, 5].
    function pairOf(text as String) as Array<Number> {
        var dash = text.find("-") as Number;
        return [(text.substring(0, dash) as String).toNumber() as Number,
            (text.substring(dash + 1, text.length()) as String).toNumber() as Number];
    }

    function wordsOf(text as String) as Array<String> {
        var words = [] as Array<String>;
        var word = "";
        for (var i = 0; i <= text.length(); i++) {
            var c = i < text.length() ? text.substring(i, i + 1) as String : " ";
            if (!c.equals(" ")) {
                word += c;
            } else if (word.length() > 0) {
                words.add(word);
                word = "";
            }
        }
        return words;
    }

    // Whether a score edit can follow the state in config, worked out apart from ScoreEdit from the
    // scoring and edit rules: two counts of 0 to 99 everywhere; every finished set won as
    // the rules allow, or given by End set now while in progress to a team not behind, its tie-break
    // dropped; the super tie-break where the format has it; neither team with the sets to win; the set
    // and the game in progress not won, a regular game not past its deciding point (the game's rule, at
    // 0-0 the mode chosen last); a match not over; and a score that isn't the state's own.
    function possibleEdit(config as MatchConfig, state as MatchState, edit as ScoreEdit) as Boolean {
        var counts = [edit.games, edit.points] as Array<Array<Number> >;
        for (var i = 0; i < edit.sets.size(); i++) {
            counts.add(edit.sets[i].games);
            var points = edit.sets[i].tieBreakPoints;
            if (points != null) {
                counts.add(points);
            }
        }
        for (var i = 0; i < counts.size(); i++) {
            var c = counts[i];
            if (c.size() != 2 || c[0] < 0 || c[1] < 0 || c[0] > 99 || c[1] > 99) {
                return false;
            }
        }
        if (state.matchOver) {
            return false;
        }
        var won = [0, 0];
        for (var i = 0; i < edit.sets.size(); i++) {
            var set = edit.sets[i];
            if (set.superTieBreak != config.isSuperTieBreakSet(i) || !possibleSet(config, set)) {
                return false;
            }
            won[set.winner] += 1;
        }
        if (winsMatch(config, won[TEAM_US]) || winsMatch(config, won[TEAM_THEM]) || edit.sets.size() > 99) {
            return false;
        }
        var games = edit.games;
        var points = edit.points;
        var regular = false;
        var length = superLength(config);
        if (config.isSuperTieBreakSet(edit.sets.size())) {
            if (games[0] + games[1] > 0) {
                return false;
            }
        } else {
            var at = config.tieBreakAt;
            if (isWon(games, config.gamesToWin) || (config.hasTieBreak && (games[0] > at || games[1] > at))) {
                return false;
            }
            regular = !config.hasTieBreak || games[0] != at || games[1] != at;
            length = regular ? 4 : config.tieBreakPoints;
        }
        if (isWon(points, length)) {
            return false;
        }
        if (regular) {
            var mode = points[0] + points[1] == 0 ? state.deuceMode : state.gameDeuceMode;
            var limit = [null, 1, 3, 2][mode as Number] as Number?;
            var low = points[0] < points[1] ? points[0] : points[1];
            var deuces = low >= 3 ? low - 2 : 0;
            if (limit != null && (deuces > limit || (deuces == limit && points[0] != points[1]))) {
                return false;
            }
        }
        return !sameScore(state, edit);
    }

    // A finished set in an edit as the rules allow it.
    function possibleSet(config as MatchConfig, set as SetScore) as Boolean {
        var winner = set.winner;
        var loser = MatchState.otherTeam(winner);
        var games = set.games;
        var points = set.tieBreakPoints;
        var at = config.tieBreakAt;
        if (set.superTieBreak) {
            if (games[0] + games[1] > 0 || points == null) {
                return false;
            }
            return set.endedEarly ? points[winner] >= points[loser] && !isWon(points, superLength(config))
                : wonExactly(points, winner, superLength(config));
        } else if (set.endedEarly) {
            return points == null && games[winner] >= games[loser] && !isWon(games, config.gamesToWin)
                && (!config.hasTieBreak || (games[0] <= at && games[1] <= at));
        } else if (points != null) {
            return config.hasTieBreak && games[winner] == at + 1 && games[loser] == at
                && wonExactly(points, winner, config.tieBreakPoints);
        }
        return wonExactly(games, winner, config.gamesToWin) && (!config.hasTieBreak || games[winner] <= at + 1);
    }

    // The edit's score is the state's.
    function sameScore(state as MatchState, edit as ScoreEdit) as Boolean {
        if (edit.sets.size() != state.setScores.size() || !pair(edit.games).equals(pair(state.games))
                || !pair(edit.points).equals(pair(state.gamePoints))) {
            return false;
        }
        for (var i = 0; i < edit.sets.size(); i++) {
            if (!edit.sets[i].equals(state.setScores[i])) {
                return false;
            }
        }
        return true;
    }

    // A random score for an edit in config: finished sets, mostly fewer than the match needs and won as
    // the rules allow (by games, in a tie-break, now and then given by End set now), then the current
    // set's games and the game's points, about half of them in the range a set or a game in progress
    // always has. The rest are often impossible (a set not won, past its tie-break or the deciding
    // point, the sets that end the match, the super tie-break with games, a count below 0), so the
    // engine must refuse them.
    function randomEdit(config as MatchConfig, seed as Number) as ScoreEdit {
        var rolls = [seed] as Array<Number>;
        var n = config.gamesToWin;
        var at = config.tieBreakAt;
        var won = [0, 0];
        var sets = [] as Array<SetScore>;
        var setsMost = mostSets(config);
        var count = roll(rolls, setsMost != null ? setsMost : 6);
        for (var i = 0; i < count; i++) {
            var winner = roll(rolls, 2) as Team;
            if (setsMost != null && won[winner] >= config.setsToWin - 1 && roll(rolls, 8) != 0) {
                winner = MatchState.otherTeam(winner);
            }
            won[winner] += 1;
            sets.add(randomSet(config, i, winner, rolls));
        }
        var games = [0, 0];
        var points = [roll(rolls, 12), roll(rolls, 12)];
        if (!config.isSuperTieBreakSet(count)) {
            var top = roll(rolls, 2) == 0 ? n : (config.hasTieBreak ? at + 2 : n + 3);
            games = [roll(rolls, top), roll(rolls, top)];
            if (config.hasTieBreak && roll(rolls, 4) == 0) {
                games = [at, at];
            }
            var tieBreak = config.hasTieBreak && games[0] == at && games[1] == at;
            var most = roll(rolls, 2) == 0 ? 4 : tieBreak ? 9 : 7;
            points = [roll(rolls, most), roll(rolls, most)];
        } else if (roll(rolls, 10) == 0) {
            games = [1, 0];
        }
        return new ScoreEdit(sets, games, points);
    }

    // A finished set won by winner, set index of the format, as randomEdit() makes them.
    function randomSet(config as MatchConfig, index as Number, winner as Team, rolls as Array<Number>) as SetScore {
        var loser = MatchState.otherTeam(winner);
        var n = config.gamesToWin;
        var at = config.tieBreakAt;
        var games = [0, 0];
        var points = null as Array<Number>?;
        var early = false;
        var kind = roll(rolls, 10);
        var superTieBreak = config.isSuperTieBreakSet(index);
        if (superTieBreak) {
            points = [0, 0];
            points[winner] = superLength(config);
            points[loser] = roll(rolls, 9);
        } else if (kind == 0) {
            // Given by End set now while in progress.
            var top = (config.hasTieBreak ? at : n - 1) + 1;
            var a = roll(rolls, top);
            var b = roll(rolls, top);
            games[winner] = a > b ? a : b;
            games[loser] = a > b ? b : a;
            early = true;
        } else if (kind <= 3 && config.hasTieBreak) {
            games[winner] = at + 1;
            games[loser] = at;
            var length = config.tieBreakPoints;
            var extra = roll(rolls, 3) == 0 ? roll(rolls, 4) + 1 : 0;
            points = [0, 0];
            points[winner] = length + extra;
            points[loser] = extra > 0 ? length + extra - 2 : roll(rolls, length - 1);
        } else {
            games[winner] = n;
            games[loser] = roll(rolls, n - 1);
            if (roll(rolls, 4) == 0 && (!config.hasTieBreak || at == n)) {
                var top = config.hasTieBreak ? n + 1 : n + 1 + roll(rolls, 3);
                games[winner] = top;
                games[loser] = top - 2;
            }
        }
        if (roll(rolls, 12) == 0) {
            games[winner] -= 1;
        }
        return new SetScore(games, points, superTieBreak, winner, early);
    }

    // The next of the random numbers in rolls[0], from 0 to below n.
    function roll(rolls as Array<Number>, n as Number) as Number {
        rolls[0] = nextRandom(rolls[0]);
        return (rolls[0] / 7) % n;
    }

    // Texts the tests compare ---------------------------------------------------------------------

    function describe(engine as ScoringEngine, view as Number) as String {
        var state = engine.getState();
        if (view == VIEW_GAME) {
            return game(state);
        } else if (view == VIEW_SETS) {
            return sets(state);
        } else if (view == VIEW_SERVE) {
            return serveFlags(state);
        }
        return situation(engine.getConfig(), state);
    }

    // The game: games, points, then "deuce <n>" once the game reached 40-40 n times and "deciding"
    // when the next point decides it: "2-2 40-40 deuce 3 deciding".
    function game(state as MatchState) as String {
        var text = pair(state.games) + " " + pointText(state.getPointDisplay(TEAM_US)) + "-"
            + pointText(state.getPointDisplay(TEAM_THEM));
        var deuces = state.getDeuceCount();
        text += deuces > 0 ? " deuce " + deuces : "";
        return state.isDecidingPoint() ? text + " deciding" : text;
    }

    function pointText(value as Number) as String {
        return value == MatchState.POINTS_AD ? "AD" : value.toString();
    }

    function pair(values as Array<Number>) as String {
        return values[TEAM_US].toString() + "-" + values[TEAM_THEM].toString();
    }

    // The match: each finished set, then "|" and the current set's games and points. A set won in a
    // tie-break adds its points, "7-6(7-5)"; a super tie-break is "S10-8"; a set given by End set now
    // ends with "E" and the team given it, "4-2EU". The points read "tb 3-2" in a tie-break, "stb 5-3"
    // in a super tie-break, and " over" closes a match that is over: "6-4 7-6(7-5) | 2-1 30-15".
    function sets(state as MatchState) as String {
        var text = "";
        for (var i = 0; i < state.setScores.size(); i++) {
            var score = state.setScores[i];
            var points = score.tieBreakPoints;
            if (score.superTieBreak) {
                text += "S" + pair(points as Array<Number>);
            } else {
                text += pair(score.games) + (points == null ? "" : "(" + pair(points) + ")");
            }
            text += score.endedEarly ? (score.winner == TEAM_US ? "EU " : "ET ") : " ";
        }
        text += "| " + pair(state.games) + " ";
        if (state.gameType == GAME_TIE_BREAK) {
            text += "tb ";
        } else if (state.gameType == GAME_SUPER_TIE_BREAK) {
            text += "stb ";
        }
        text += pointText(state.getPointDisplay(TEAM_US)) + "-" + pointText(state.getPointDisplay(TEAM_THEM));
        return state.matchOver ? text + " over" : text;
    }

    // Who serves the current point: ME, PARTNER, THEM, or "?" when unknown.
    function server(state as MatchState) as String {
        var team = state.getServingTeam();
        if (team == null) {
            return "?";
        }
        return team == TEAM_THEM ? "THEM" : state.getServingPlayer() == PLAYER_ME ? "ME" : "PARTNER";
    }

    // server(), then the side: R, L, or "-" on a deciding point; "?" alone when unknown.
    function serve(state as MatchState) as String {
        var text = server(state);
        if (text.equals("?")) {
            return text;
        }
        var side = state.getServeSide();
        return text + (side == null ? " -" : side == SIDE_RIGHT ? " R" : " L");
    }

    // serve(), then " new" when the last event changed the server and " ends" when it made the
    // players change ends: "PARTNER L new".
    function serveFlags(state as MatchState) as String {
        return serve(state) + (state.serverChanged ? " new" : "") + (state.changeOfEnds ? " ends" : "");
    }

    // The finished games: who served (U, T, "?"), then who won, "tb" or "stb" before a tie-break or
    // super tie-break: "UU TU tbUT".
    function games(state as MatchState) as String {
        var text = "";
        for (var i = 0; i < state.finishedGames.size(); i++) {
            var type = state.getFinishedGameType(i);
            var team = state.getFinishedGameServer(i);
            text += (i == 0 ? "" : " ") + (type == GAME_TIE_BREAK ? "tb" : type == GAME_SUPER_TIE_BREAK ? "stb" : "")
                + (team == null ? "?" : team == TEAM_US ? "U" : "T")
                + (state.getFinishedGameWinner(i) == TEAM_US ? "U" : "T");
        }
        return text;
    }

    // The banner and its style, the caption, then the flags with their team, "-" for none:
    // "STAR POINT deciding | RECEIVERS CHOOSE | break T, set U, match U, deciding".
    function situation(config as MatchConfig, state as MatchState) as String {
        var s = new MatchSituation(config, state);
        return bannerText(s) + " | " + captionText(s) + " | " + flagsText(s);
    }

    // "DEUCE 2 info", "-" for none. A number where none belongs shows as "#n".
    function bannerText(situation as MatchSituation) as String {
        var banner = situation.banner;
        var names = ["-", "STAR POINT", "SILVER POINT", "GOLDEN POINT", "MATCH POINT", "SET POINT", "BREAK POINT",
            "DEUCE " + situation.bannerNumber, "TIE-BREAK"];
        var all = [BANNER_NONE, BANNER_STAR_POINT, BANNER_SILVER_POINT, BANNER_GOLDEN_POINT, BANNER_MATCH_POINT,
            BANNER_SET_POINT, BANNER_BREAK_POINT, BANNER_DEUCE, BANNER_TIE_BREAK];
        var index = all.indexOf(banner);
        var text = index < 0 ? "banner " + banner : names[index] as String;
        if (banner != BANNER_DEUCE && situation.bannerNumber != 0) {
            text += " #" + situation.bannerNumber;
        }
        if (banner == BANNER_NONE) {
            return text;
        }
        var style = situation.getBannerStyle();
        return text + (style == BANNER_STYLE_INFO ? " info" : style == BANNER_STYLE_PRESSURE ? " pressure" : " deciding");
    }

    // "SET 2", "-" for none. A number where none belongs shows as "#n".
    function captionText(situation as MatchSituation) as String {
        var caption = situation.caption;
        var number = situation.captionNumber;
        if (caption == CAPTION_SET) {
            return "SET " + number;
        } else if (caption == CAPTION_CHANGE_ENDS_AT) {
            return "CHANGE ENDS AT " + number;
        }
        var text = caption == CAPTION_RECEIVERS_CHOOSE ? "RECEIVERS CHOOSE"
            : caption == CAPTION_SAME_SEX_RECEIVES ? "SAME SEX RECEIVES" : "-";
        return number == 0 ? text : text + " #" + number;
    }

    function flagsText(situation as MatchSituation) as String {
        var text = "";
        var breakPoint = situation.breakPoint;
        var setPoint = situation.setPoint;
        var matchPoint = situation.matchPoint;
        text += breakPoint != null ? ", break " + teamText(breakPoint) : "";
        text += setPoint != null ? ", set " + teamText(setPoint) : "";
        text += matchPoint != null ? ", match " + teamText(matchPoint) : "";
        text += situation.decidingPoint ? ", deciding" : "";
        text += situation.tieBreak ? ", tie-break" : "";
        return text.length() == 0 ? "-" : text.substring(2, text.length()) as String;
    }

    function teamText(team as Team) as String {
        return team == TEAM_US ? "U" : "T";
    }

    // Stats, won / played, "-" for null: "points 8-4 67%, games 2-0, sets 1-0, deciding 1/1,
    // tie-breaks 0/0, durations 225 150, longest 0, per point 31 s, streak 6 | serve 4/7 57%,
    // return 4/5 80%, held 1/1, conceded 0, broke 1/1, break points 1/2, saved 3/3".
    function stats(stats as MatchStats) as String {
        return statsMatch(stats) + " | " + statsServe(stats);
    }

    // The stats that don't need serve tracking.
    function statsMatch(stats as MatchStats) as String {
        return "points " + stats.pointsWon + "-" + stats.pointsLost + " " + percentText(stats.getPointsWonPercent())
            + ", games " + stats.gamesWon + "-" + stats.gamesLost + ", sets " + stats.setsWon + "-" + stats.setsLost
            + ", deciding " + stats.decidingPointsWon + "/" + stats.decidingPointsPlayed
            + ", tie-breaks " + stats.tieBreaksWon + "/" + stats.tieBreaksPlayed
            + ", durations " + durationsText(stats) + ", longest " + text(stats.longestGame) + ", " + statsPoints(stats);
    }

    // The average time per point and our longest streak: "per point 31 s, streak 6", "per point -,
    // streak 0" with no point played.
    function statsPoints(stats as MatchStats) as String {
        var time = stats.averagePointTime;
        return "per point " + (time == null ? "-" : time + " s") + ", streak " + stats.longestStreak;
    }

    // The stats that need serve tracking.
    function statsServe(stats as MatchStats) as String {
        return "serve " + ratio(stats.servePointsWon, stats.servePointsPlayed) + " "
            + percentText(stats.getServePointsWonPercent())
            + ", return " + ratio(stats.returnPointsWon, stats.returnPointsPlayed) + " "
            + percentText(stats.getReturnPointsWonPercent())
            + ", held " + ratio(stats.serviceGamesHeld, stats.serviceGamesPlayed) + ", conceded " + text(stats.breaksConceded)
            + ", broke " + ratio(stats.breaksWon, stats.returnGamesPlayed)
            + ", break points " + ratio(stats.breakPointsConverted, stats.breakPointsPlayed)
            + ", saved " + ratio(stats.breakPointsSaved, stats.breakPointsFaced);
    }

    function durationsText(stats as MatchStats) as String {
        var text = "";
        for (var i = 0; i < stats.gameDurations.size(); i++) {
            text += (i == 0 ? "" : " ") + stats.gameDurations[i];
        }
        return text.length() == 0 ? "-" : text;
    }

    function text(value as Number?) as String {
        return value == null ? "-" : value.toString();
    }

    function percentText(value as Number?) as String {
        return value == null ? "-" : value.toString() + "%";
    }

    function ratio(part as Number?, whole as Number?) as String {
        return part == null || whole == null ? "-" : part.toString() + "/" + whole.toString();
    }

    // Checks ---------------------------------------------------------------------------------------

    function assertSameState(actual as MatchState?, expected as MatchState, message as String) as Void {
        Test.assertMessage(actual != null, message + ": no state");
        if (!(actual as MatchState).equals(expected)) {
            Test.assertMessage(false, message + ": " + actual + " instead of " + expected);
        }
    }

    // The state updated event by event equals a replay of the whole log.
    function assertMatchesReplay(engine as ScoringEngine, message as String) as Void {
        assertSameState(ScoringEngine.replay(engine.getConfig(), engine.getLog()), engine.getState(), message + ", replay");
    }

    // The same in a random test's step: every REPLAY_EVERY steps only.
    function assertMatchesReplayAt(engine as ScoringEngine, step as Number, message as String) as Void {
        if (step % REPLAY_EVERY == REPLAY_EVERY - 1) {
            assertMatchesReplay(engine, message);
        }
    }

    // Adds the event, undoes it, and checks that it changed the state, that undo gave it back and left
    // everything as before. The event is left undone.
    function checkUndo(engine as ScoringEngine, event as MatchEvent, message as String) as Void {
        var before = engine.getState().copy();
        var count = engine.getLog().size();
        Test.assertMessage(engine.add(event), message + ": refused");
        Test.assertMessage(!engine.getState().equals(before), message + ": no effect");
        assertMatchesReplay(engine, message);
        var undone = engine.undo();
        Test.assertMessage(undone != null && undone.equals(event), message + ": undid " + undone);
        Test.assertEqual(engine.getLog().size(), count);
        assertSameState(engine.getState(), before, message + ": undo");
    }

    // A refused event changes neither the log nor the state, and canAdd() says so beforehand.
    function checkRefused(engine as ScoringEngine, event as MatchEvent, message as String) as Void {
        var before = engine.getState().copy();
        var count = engine.getLog().size();
        Test.assertMessage(!engine.canAdd(event), message + ": canAdd");
        Test.assertMessage(!engine.add(event), message + ": added");
        Test.assertEqual(engine.getLog().size(), count);
        assertSameState(engine.getState(), before, message + ": changed the state");
    }

    function checkRefusedType(engine as ScoringEngine, type as EventType, payload as Number?) as Void {
        var event = new MatchEvent(type, nextTime(engine), payload);
        checkRefused(engine, event, event.toString());
    }

    // Plays each step's move (one letter, a point or a game; the last point is undone and played
    // again) and checks the view after it, a full replay and the set rules.
    function checkSteps(engine as ScoringEngine, view as Number, steps as Array<Array<String> >) as Void {
        for (var i = 0; i < steps.size(); i++) {
            var message = "step " + i + " " + steps[i][0];
            move(engine, null, steps[i][0], true);
            check(engine, view, steps[i][1], message);
        }
    }

    // Adds an event at the next time, checking that undo gives back the state before it, then the view.
    function checkEvent(engine as ScoringEngine, view as Number, type as EventType, payload as Number?,
            expected as String) as Void {
        var event = new MatchEvent(type, nextTime(engine), payload);
        checkUndo(engine, event, event.toString());
        Test.assert(engine.add(event));
        check(engine, view, expected, event.toString());
    }

    // The view reads as expected, the state equals a full replay and follows the set rules.
    function check(engine as ScoringEngine, view as Number, expected as String, message as String) as Void {
        var actual = describe(engine, view);
        Test.assertMessage(actual.equals(expected), message + ": " + actual + " at " + sets(engine.getState()));
        assertMatchesReplay(engine, message);
        checkRules(engine.getConfig(), engine.getState(), message);
    }

    // Each case is the moves of a new match after the answer, and the view they lead to.
    function checkCases(config as MatchConfig, answer as String, view as Number, cases as Array<Array<String> >) as Void {
        for (var i = 0; i < cases.size(); i++) {
            var engine = newMatch(config, answer);
            play(engine, cases[i][0]);
            check(engine, view, cases[i][1], "\"" + cases[i][0] + "\"");
        }
    }

    // The set rules: every finished set was won as the rules allow (or given by End
    // set now to a team not behind), the set and the game in progress aren't already won, the game type
    // fits the score, the counts agree, and a match won is over with nothing left in play.
    function checkRules(config as MatchConfig, state as MatchState, message as String) as Void {
        var sets = [0, 0];
        var games = [state.games[TEAM_US], state.games[TEAM_THEM]];
        var count = state.setScores.size();
        var mostSets = mostSets(config);
        Test.assertMessage(mostSets == null || count <= mostSets, message + ": too many sets");
        for (var i = 0; i < count; i++) {
            var score = state.setScores[i];
            checkFinishedSet(config, score, config.isSuperTieBreakSet(i), message);
            sets[score.winner] += 1;
            games[TEAM_US] += score.games[TEAM_US];
            games[TEAM_THEM] += score.games[TEAM_THEM];
        }
        Test.assertMessage(state.getSetsWon(TEAM_US) == sets[TEAM_US] && state.getSetsWon(TEAM_THEM) == sets[TEAM_THEM]
            && state.getGamesWon(TEAM_US) == games[TEAM_US] && state.getGamesWon(TEAM_THEM) == games[TEAM_THEM],
            message + ": sets or games won");
        var most = sets[TEAM_US] > sets[TEAM_THEM] ? sets[TEAM_US] : sets[TEAM_THEM];
        Test.assertMessage(mostSets == null || most <= config.setsToWin, message + ": sets past the end of the match");
        if (winsMatch(config, most)) {
            Test.assertMessage(state.matchOver && state.gameType == GAME_REGULAR
                && state.games[TEAM_US] + state.games[TEAM_THEM] + state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM] == 0
                && state.getWinner() == (sets[TEAM_US] > sets[TEAM_THEM] ? TEAM_US : TEAM_THEM), message + ": match won");
        } else if (!state.matchOver) {
            checkSetInProgress(config, state, message);
            Test.assertMessage(state.getResult() == RESULT_UNFINISHED && state.getWinner() == null, message + ": result");
        }
    }

    // The set and the game in progress aren't won yet, the game type fits the games, and a regular
    // game's deuces follow its deuce mode.
    function checkSetInProgress(config as MatchConfig, state as MatchState, message as String) as Void {
        var us = state.games[TEAM_US];
        var them = state.games[TEAM_THEM];
        var type = GAME_REGULAR;
        var length = 4;
        if (config.isSuperTieBreakSet(state.setScores.size())) {
            type = GAME_SUPER_TIE_BREAK;
            length = superLength(config);
            Test.assertMessage(us == 0 && them == 0, message + ": games in a super tie-break");
        } else {
            Test.assertMessage(!isWon([us, them], config.gamesToWin), message + ": set already won");
            if (config.hasTieBreak) {
                Test.assertMessage(us <= config.tieBreakAt && them <= config.tieBreakAt, message + ": set past its tie-break");
                if (us == config.tieBreakAt && them == config.tieBreakAt) {
                    type = GAME_TIE_BREAK;
                    length = config.tieBreakPoints;
                }
            }
        }
        Test.assertMessage(state.gameType == type && state.isTieBreak() == (type != GAME_REGULAR), message + ": game type");
        Test.assertMessage(!isWon(state.gamePoints, length), message + ": game already won");
        if (type != GAME_REGULAR) {
            Test.assertMessage(state.getDeuceCount() == 0 && !state.isDeuce() && !state.isDecidingPoint(),
                message + ": deuce in a tie-break");
            return;
        }
        var deuce = state.getPointDisplay(TEAM_US) == 40 && state.getPointDisplay(TEAM_THEM) == 40;
        Test.assertMessage(state.isDeuce() == deuce, message + ": deuce");
        var limit = [null, 1, 3, 2][state.gameDeuceMode as Number] as Number?;
        Test.assertMessage(limit == null || state.getDeuceCount() <= limit, message + ": deuce count");
        Test.assertMessage(state.isDecidingPoint() == (deuce && state.getDeuceCount() == limit), message + ": deciding point");
    }

    // A finished set was won as the rules allow, or given by End set now to a team not behind.
    function checkFinishedSet(config as MatchConfig, score as SetScore, superTieBreak as Boolean, message as String) as Void {
        message += ", set " + score;
        Test.assertMessage(score.superTieBreak == superTieBreak, message + ": super tie-break");
        var winner = score.winner;
        var loser = MatchState.otherTeam(winner);
        var points = score.tieBreakPoints;
        if (superTieBreak) {
            Test.assertMessage(score.games[TEAM_US] == 0 && score.games[TEAM_THEM] == 0 && points != null,
                message + ": super tie-break score");
            var counts = points as Array<Number>;
            Test.assertMessage(score.endedEarly ? counts[winner] >= counts[loser]
                : wonExactly(counts, winner, superLength(config)), message + ": super tie-break not won");
        } else if (score.endedEarly) {
            Test.assertMessage(points == null && score.games[winner] >= score.games[loser], message + ": ended early");
        } else if (points != null) {
            Test.assertMessage(config.hasTieBreak && score.games[winner] == config.tieBreakAt + 1
                && score.games[loser] == config.tieBreakAt && wonExactly(points, winner, config.tieBreakPoints),
                message + ": tie-break set");
        } else {
            Test.assertMessage(wonExactly(score.games, winner, config.gamesToWin)
                && (!config.hasTieBreak || score.games[winner] <= config.tieBreakAt + 1), message + ": set not won");
        }
    }

    // Someone reached length with a 2-point lead.
    function isWon(counts as Array<Number>, length as Number) as Boolean {
        var us = counts[TEAM_US];
        var them = counts[TEAM_THEM];
        return (us >= length && us - them >= 2) || (them >= length && them - us >= 2);
    }

    // The winner reached length with a 2-point lead, and play stopped there.
    function wonExactly(counts as Array<Number>, winner as Team, length as Number) as Boolean {
        var won = counts[winner];
        var lead = won - counts[MatchState.otherTeam(winner)];
        return won >= length && lead >= 2 && (won == length || lead == 2);
    }

    // The situation against what the next point would do for each team: a break point
    // wins the game for the receivers of a regular game, a set point wins the set, a match point the
    // match. The banner is the first in the order whose flag holds, the caption follows the rules,
    // and nothing shows once the match is over. Returns the situation.
    function checkNextPoint(config as MatchConfig, state as MatchState, message as String) as MatchSituation {
        var found = new MatchSituation(config, state);
        if (state.matchOver) {
            Test.assertMessage(situation(config, state).equals("- | - | -"), message + ": over");
            return found;
        }
        var teams = [TEAM_US, TEAM_THEM] as Array<Team>;
        for (var i = 0; i < teams.size(); i++) {
            var team = teams[i];
            var after = state.copy();
            Test.assert(ScoringEngine.apply(config, after, new MatchEvent(team == TEAM_US ? EVENT_POINT_US : EVENT_POINT_THEM, T0, null)));
            var game = after.finishedGames.size() > state.finishedGames.size();
            var breaks = game && !state.isTieBreak() && state.getServingTeam() == MatchState.otherTeam(team);
            if ((found.breakPoint == team) != breaks || (found.setPoint == team) != (after.setScores.size() > state.setScores.size())
                    || (found.matchPoint == team) != after.matchOver) {
                Test.assertMessage(false, message + ": flags " + flagsText(found) + " at " + sets(state));
            }
        }
        Test.assertMessage(found.decidingPoint == state.isDecidingPoint() && found.tieBreak == state.isTieBreak(),
            message + ": deciding point or tie-break");
        var mode = state.gameDeuceMode;
        var banner = BANNER_NONE;
        if (found.decidingPoint) {
            banner = mode == DEUCE_GOLDEN ? BANNER_GOLDEN_POINT : mode == DEUCE_SILVER ? BANNER_SILVER_POINT : BANNER_STAR_POINT;
        } else if (found.matchPoint != null) {
            banner = BANNER_MATCH_POINT;
        } else if (found.setPoint != null) {
            banner = BANNER_SET_POINT;
        } else if (found.breakPoint != null) {
            banner = BANNER_BREAK_POINT;
        } else if ((mode == DEUCE_STAR || mode == DEUCE_SILVER) && state.getDeuceCount() > 0) {
            banner = BANNER_DEUCE;
        } else if (found.tieBreak) {
            banner = BANNER_TIE_BREAK;
        }
        if (found.banner != banner || found.bannerNumber != (banner == BANNER_DEUCE ? state.getDeuceCount() : 0)) {
            Test.assertMessage(false, message + ": banner " + bannerText(found) + " at " + sets(state));
        }
        var caption = CAPTION_SET;
        var number = state.setScores.size() + 1;
        if (found.decidingPoint) {
            caption = config.mixed && config.doubles ? CAPTION_SAME_SEX_RECEIVES : CAPTION_RECEIVERS_CHOOSE;
            number = 0;
        } else if (found.tieBreak) {
            caption = CAPTION_CHANGE_ENDS_AT;
            number = state.getChangeOfEndsAt() as Number;
        }
        if (found.caption != caption || found.captionNumber != number) {
            Test.assertMessage(false, message + ": caption " + captionText(found) + " at " + sets(state));
        }
        return found;
    }

    // Right after an even number of points in the game, left after an odd one; no side on
    // a deciding point or while the server is unknown.
    function checkSide(state as MatchState, message as String) as Void {
        var side = state.getServeSide();
        var expected = null as Side?;
        if (state.getServingTeam() != null && !state.isDecidingPoint()) {
            expected = (state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM]) % 2 == 0 ? SIDE_RIGHT : SIDE_LEFT;
        }
        Test.assertMessage(side == expected, message + ": side");
    }

    // After an event added to a state whose server (server()), finished games and sets were before,
    // games and sets: the server changed when server() did, and ends changed after a point that won a
    // game leaving an odd number of games in its set, or that made a tie-break's points a multiple of
    // 6. Neither once the match is over.
    function checkFlags(event as MatchEvent, state as MatchState, before as String, games as Number,
            sets as Number, message as String) as Void {
        if (state.serverChanged != (!state.matchOver && !server(state).equals(before))) {
            Test.assertMessage(false, message + ": server changed after " + event);
        }
        var ends = false;
        if (event.type == EVENT_POINT_US || event.type == EVENT_POINT_THEM) {
            if (state.finishedGames.size() > games) {
                var set = state.setScores.size() > sets ? state.setScores[sets].games : state.games;
                ends = (set[TEAM_US] + set[TEAM_THEM]) % 2 == 1;
            } else if (state.isTieBreak()) {
                ends = (state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM]) % 6 == 0;
            }
        }
        if (state.changeOfEnds != (ends && !state.matchOver)) {
            Test.assertMessage(false, message + ": change of ends after " + event + " at " + sets(state));
        }
    }

    // The state's stats, after checking that they equal those of a replay of the log (StatsCalculator,
    // the reference), every one that stats() writes, and agree with the state.
    function computeStats(engine as ScoringEngine, matchStart as Number) as MatchStats {
        var stats = engine.getState().getStats(matchStart);
        assertSameStats(stats, StatsCalculator.compute(engine.getConfig(), engine.getLog(), matchStart), "stats");
        checkConsistent(stats, engine.getState(), "stats");
        return stats;
    }

    function assertSameStats(actual as MatchStats, expected as MatchStats?, message as String) as Void {
        Test.assertMessage(expected != null, message + ": the log doesn't replay");
        var text = stats(actual);
        var reference = stats(expected as MatchStats);
        Test.assertMessage(text.equals(reference), message + ": " + text + " instead of " + reference);
    }

    // Every stat that needs serve tracking is null.
    function checkServeNull(stats as MatchStats, message as String) as Void {
        Test.assertMessage(statsServe(stats).equals("serve - -, return - -, held -, conceded -, broke -, break points -, saved -")
            && stats.servePointsWon == null && stats.returnPointsWon == null && stats.serviceGamesPlayed == null
            && stats.returnGamesPlayed == null && stats.breakPointsPlayed == null && stats.breakPointsFaced == null,
            message + ": " + statsServe(stats));
    }

    // The stats agree with the state they come from: its totals, one duration per finished game and
    // the longest, the tie-breaks, holds and breaks of its finished games, and with each other: a break
    // won is a break point converted, a break conceded a break point not saved. Serve stats are null
    // exactly when no game ended with a known serving team and no point was credited. The average
    // time per point is null exactly when no point was played, and the longest streak is 0 exactly
    // when we won none.
    function checkConsistent(stats as MatchStats, state as MatchState, message as String) as Void {
        Test.assertMessage(stats.pointsWon == state.pointsWon[TEAM_US] && stats.pointsLost == state.pointsWon[TEAM_THEM]
            && stats.gamesWon == state.getGamesWon(TEAM_US) && stats.gamesLost == state.getGamesWon(TEAM_THEM)
            && stats.setsWon == state.getSetsWon(TEAM_US) && stats.setsLost == state.getSetsWon(TEAM_THEM)
            && stats.decidingPointsWon <= stats.decidingPointsPlayed, message + ": totals");
        var time = stats.averagePointTime;
        Test.assertMessage((time == null) == (stats.pointsWon + stats.pointsLost == 0) && (time == null || time >= 0)
            && stats.longestStreak <= stats.pointsWon && (stats.longestStreak == 0) == (stats.pointsWon == 0),
            message + ": " + statsPoints(stats));
        var count = state.finishedGames.size();
        Test.assertMessage(stats.gameDurations.size() == count, message + ": durations " + stats.gameDurations.size());
        var longest = null as Number?;
        // Tie-breaks played and won, our service games played and held, theirs played and broken.
        var counts = [0, 0, 0, 0, 0, 0];
        var known = false;
        for (var i = 0; i < count; i++) {
            var duration = stats.gameDurations[i];
            Test.assertMessage(duration >= 0, message + ": duration " + duration);
            if (longest == null || duration > stats.gameDurations[longest]) {
                longest = i;
            }
            var server = state.getFinishedGameServer(i);
            var index = state.getFinishedGameType(i) != GAME_REGULAR ? 0 : server == TEAM_US ? 2 : 4;
            if (index == 0 || server != null) {
                counts[index] += 1;
                counts[index + 1] += state.getFinishedGameWinner(i) == TEAM_US ? 1 : 0;
            }
            known = known || server != null;
        }
        Test.assertMessage(stats.longestGame == longest && stats.tieBreaksPlayed == counts[0] && stats.tieBreaksWon == counts[1],
            message + ": longest game or tie-breaks");
        if (stats.servePointsPlayed == null) {
            Test.assertMessage(!known, message + ": no serve stats for games with a known server");
            checkServeNull(stats, message);
            return;
        }
        var served = stats.servePointsPlayed as Number;
        var returned = stats.returnPointsPlayed as Number;
        var servedWon = stats.servePointsWon as Number;
        var returnedWon = stats.returnPointsWon as Number;
        Test.assertMessage(servedWon <= served && returnedWon <= returned && servedWon + returnedWon <= stats.pointsWon
            && served + returned <= stats.pointsWon + stats.pointsLost, message + ": serve and return points");
        Test.assertMessage(stats.serviceGamesPlayed == counts[2] && stats.serviceGamesHeld == counts[3]
            && stats.breaksConceded == counts[2] - counts[3] && stats.returnGamesPlayed == counts[4]
            && stats.breaksWon == counts[5], message + ": service and return games");
        Test.assertMessage(stats.breakPointsConverted == stats.breaksWon
            && (stats.breakPointsConverted as Number) <= (stats.breakPointsPlayed as Number)
            && (stats.breakPointsFaced as Number) - (stats.breakPointsSaved as Number) == stats.breaksConceded,
            message + ": break points");
    }

    // The lap of finished game index, worked out apart from LapValues right after the point
    // that won it: the set and its games after the game, or the set's score when it ended the set,
    // then the outcome: 0 we held, 1 we broke, 2 they held, 3 they broke, 4 a tie-break, 5 no serving
    // team.
    function expectedLap(state as MatchState, index as Number) as String {
        var type = state.getFinishedGameType(index);
        var server = state.getFinishedGameServer(index);
        var winner = state.getFinishedGameWinner(index);
        var outcome = LAP_TIE_BREAK;
        if (type == GAME_REGULAR) {
            outcome = server == null ? LAP_NO_SERVE : server == TEAM_US ? (winner == TEAM_US ? LAP_WE_HELD : LAP_THEY_BROKE)
                : (winner == TEAM_THEM ? LAP_THEY_HELD : LAP_WE_BROKE);
        }
        var sets = state.setScores.size();
        if (state.games[TEAM_US] + state.games[TEAM_THEM] == 0) {
            var set = state.setScores[sets - 1];
            return sets + " " + set.getScore(TEAM_US) + "-" + set.getScore(TEAM_THEM) + " " + outcome;
        }
        return (sets + 1) + " " + pair(state.games) + " " + outcome;
    }

    function assertNear(actual as Numeric, expected as Numeric, tolerance as Numeric) as Void {
        Test.assertMessage((actual - expected).abs() <= tolerance, "expected " + expected + " +/- " + tolerance + ", got " + actual);
    }

    // Storage -------------------------------------------------------------------------------------

    // The stored values of these keys, to put back with restore() when the test is done.
    function backup(keys as Array<String>) as Array<Application.Storage.ValueType> {
        var saved = [] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < keys.size(); i++) {
            saved.add(Application.Storage.getValue(keys[i]));
        }
        return saved;
    }

    function restore(keys as Array<String>, saved as Array<Application.Storage.ValueType>) as Void {
        for (var i = 0; i < keys.size(); i++) {
            var value = saved[i];
            if (value == null) {
                Application.Storage.deleteValue(keys[i]);
            } else {
                Application.Storage.setValue(keys[i], value);
            }
        }
    }

    // The stored match's keys, its log's parts included.
    function matchKeys() as Array<String> {
        var keys = [MatchStore.KEY, MatchStore.REPLAY_KEY];
        for (var part = 0; part <= MatchStore.PARTS_MAX; part++) {
            keys.add(MatchStore.PART_KEY + part);
        }
        return keys;
    }

    // The launch replay in one go: the stored match, or null.
    function loadStored() as StoredMatch? {
        var load = MatchStore.startLoad();
        while (!load.step()) {
        }
        return load.getStored();
    }

    function storedValue(config as Object?, start as Object?, outdoor as Object?, log as Object?) as Dictionary<String, Object?> {
        return {"config" => config, "start" => start, "outdoor" => outdoor, "log" => log} as Dictionary<String, Object?>;
    }

    // The app's side ------------------------------------------------------------------------------

    // The score screen of the match: each team's points, games and pips (x won, o not yet),
    // the dot's mockup position and our player serving, "-" for none: "US 40 g4 oo | THEM 30 g3 xo |
    // dot 391 221 | -".
    function screen(model as ScoreModel) as String {
        var server = model.server;
        return screenTeam(model, TEAM_US, "US") + " | " + screenTeam(model, TEAM_THEM, "THEM") + " | dot " + dot(model.dot)
            + " | " + (server == null ? "-" : server == PLAYER_ME ? "ME" : "PARTNER");
    }

    function screenTeam(model as ScoreModel, team as Team, name as String) as String {
        var pips = "";
        for (var i = 0; i < model.pips; i++) {
            pips += model.isPipFilled(team, i) ? "x" : "o";
        }
        return name + " " + ScoreModel.pointsText(model.points[team], "AD") + " g" + model.games[team] + " " + pips;
    }

    function dot(position as Array<Number>?) as String {
        return position == null ? "-" : position[0] + " " + position[1];
    }

    // The match as the app reads it back at launch.
    function storedOf(match as CurrentMatch) as StoredMatch {
        var stored = MatchStore.fromValue(MatchStore.toValue(match.engine, match.start, match.outdoor, match.court));
        Test.assert(stored != null);
        return stored as StoredMatch;
    }

    // expected as a watch with a touchscreen has it: without one, the menus leave out Touch scoring.
    function assertItems(actual as Array<MatchMenuItem>, expected as Array<MatchMenuItem>, message as String) as Void {
        if (!Settings.hasTouchScreen()) {
            expected = expected.slice(0, null);
            expected.remove(ITEM_TOUCH_SCORING);
        }
        Test.assertEqualMessage(actual.toString(), expected.toString(), message);
    }

    function assertCalls(recorder as FakeRecorder, expected as Array<String>, message as String) as Void {
        Test.assertEqualMessage(recorder.calls.toString(), expected.toString(), message);
    }

    // A Recorder for unit tests, which can't record a real session. It notes each call
    // as a word: "create", "start", "stop", "lap", "save", "discard", "sensors" (heart rate only),
    // "sensors+gps", "sensors off", "values " with the lap values (LapValues.toString()), and
    // "session" for the session values (kept in sessionValues). The point differential isn't noted:
    // it changes with every point (pointDifferentials keeps each value set).
    class FakeRecorder {

        var calls as Array<String> = [] as Array<String>;
        // The laps the FIT file would hold, each as the lap values it was written with: one per
        // addLap(), and the last one at a save() that works. As on the watch, the values set last go
        // into every lap until they're set again; "none" before any.
        var laps as Array<String> = [] as Array<String>;
        private var _lapValues as String = "none";
        var sessionValues as SessionValues? = null;
        // The record field: 0 from the start, as FitFields sets it, then each value set.
        var pointDifferential as Number = 0;
        var pointDifferentials as Array<Number> = [] as Array<Number>;
        // What the watch answers.
        var createFails as Boolean = false;
        var startResult as Boolean = true;
        var saveResult as Boolean = true;
        // GPS as the sensors were last set, and whether it was ever on.
        var gps as Boolean = false;
        var gpsEverOn as Boolean = false;

        function initialize() {
        }

        function createSession() as Void {
            calls.add("create");
            if (createFails) {
                throw new Lang.InvalidValueException("no Padel");
            }
        }

        function start() as Boolean {
            calls.add("start");
            return startResult;
        }

        function stop() as Void {
            calls.add("stop");
        }

        function setLapValues(values as LapValues) as Void {
            _lapValues = values.toString();
            calls.add("values " + _lapValues);
        }

        function setSessionValues(values as SessionValues) as Void {
            calls.add("session");
            sessionValues = values;
        }

        function setPointDifferential(value as Number) as Void {
            pointDifferential = value;
            pointDifferentials.add(value);
        }

        function addLap() as Void {
            calls.add("lap");
            laps.add(_lapValues);
        }

        function save() as Boolean {
            calls.add("save");
            if (saveResult) {
                laps.add(_lapValues);
            }
            return saveResult;
        }

        function discard() as Void {
            calls.add("discard");
        }

        function enableSensors(gps as Boolean) as Void {
            calls.add(gps ? "sensors+gps" : "sensors");
            self.gps = gps;
            gpsEverOn = gpsEverOn || gps;
        }

        function disableSensors() as Void {
            calls.add("sensors off");
            gps = false;
        }

        // Forgets the calls so far, so a test can check only what comes next.
        function clear() as Void {
            calls = [] as Array<String>;
        }
    }

    // The flow from PLAY, with the format's defaults, over a session that records through a fake.
    class Flow {

        var recorder as FakeRecorder;
        var session as SessionManager;
        var laps as LapCommitter;
        var flow as WarmUpFlow;

        function initialize(outdoor as Boolean, warmUp as Boolean) {
            recorder = new FakeRecorder();
            session = new SessionManager(recorder);
            laps = new LapCommitter(session);
            flow = new WarmUpFlow(new MatchConfig(), outdoor, warmUp, session, laps);
        }
    }

    // A stored match resumed on a new session, as Resume at the launch prompt does.
    class Resumed {

        var recorder as FakeRecorder = new FakeRecorder();
        var session as SessionManager;
        var laps as LapCommitter;
        var match as CurrentMatch;

        function initialize(stored as StoredMatch) {
            session = new SessionManager(recorder);
            laps = new LapCommitter(session);
            var resumed = MatchRecovery.resume(stored, session, laps);
            Test.assert(resumed != null);
            match = resumed as CurrentMatch;
        }

        function play(moves as String) as Void {
            playThrough(match.engine, match, moves);
        }
    }

    // A match as the app plays it: started through the warm-up flow at T0 in config (after the warm-up,
    // lap 1, when warmUp is on), recorded through a fake, the serve answer logged through the match
    // holder, with the menus' rules and the score screen's input and motion over it.
    // The screen height Rig.tap() taps on (FR265); the upper half is 0 to 207.
    const TAP_HEIGHT = 416;

    class Rig {

        var recorder as FakeRecorder;
        var session as SessionManager;
        var laps as LapCommitter;
        var match as CurrentMatch;
        var engine as ScoringEngine;
        var rules as MatchMenuRules;
        var input as ScoreInput;
        var motion as ScoreMotion = new ScoreMotion();
        // The overlay the last input ended.
        var ended as ScoreOverlay? = null;

        function initialize(config as MatchConfig, answer as String, warmUp as Boolean) {
            var test = new Flow(false, warmUp);
            test.flow.config = config;
            if (warmUp) {
                Test.assertEqual(test.flow.start(T0), STEP_WARM_UP);
            }
            Test.assertEqual(test.flow.start(T0), STEP_MATCH);
            recorder = test.recorder;
            session = test.session;
            laps = test.laps;
            match = test.flow.getMatch() as CurrentMatch;
            engine = match.engine;
            rules = new MatchMenuRules(match, session);
            input = new ScoreInput(match, session);
            logAnswer(engine, match, answer);
        }

        // Moves through the match holder.
        function play(moves as String) as Void {
            playThrough(engine, match, moves);
        }

        function add(type as EventType, payload as Number?) as Void {
            addThrough(engine, match, type, payload);
        }

        function getState() as MatchState {
            return engine.getState();
        }

        // A key at now: the score screen's input acts, then the motion follows, as ScoreDelegate passes them.
        function press(key as WatchUi.Key, now as Number) as ScoreAction {
            return follow(input.key(key, now), now);
        }

        function swipe(direction as WatchUi.SwipeDirection, now as Number) as ScoreAction {
            return follow(input.swipe(direction, now), now);
        }

        // A tap y pixels from the top of the FR265's 416 px screen, on the page showing (touch
        // scoring).
        function tap(y as Number, now as Number) as ScoreAction {
            return follow(input.tap(y, TAP_HEIGHT, motion.page, now), now);
        }

        // A touch other than a tap or a swipe: a hold, its release, a drag, a flick.
        function touch(now as Number) as ScoreAction {
            return follow(input.touch(now), now);
        }

        function follow(action as ScoreAction, now as Number) as ScoreAction {
            ended = motion.input(action, input.team, input.won, input.ends, engine.getState(), now);
            return action;
        }

        // Points won in the match by each team.
        function assertPoints(us as Number, them as Number, message as String) as Void {
            var won = engine.getState().pointsWon;
            Test.assertMessage(won[TEAM_US] == us && won[TEAM_THEM] == them, message + ": " + pair(won));
        }

        // A menu item logged one event, code (MatchEvent.getCode(): a score edit's says how many sets it
        // holds), after the state before; BACK on the score screen undoes it, named by toast, and gives
        // back that state exactly.
        function assertUndone(before as MatchState, code as Number, toast as ResourceId, message as String) as Void {
            var count = engine.getState().eventCount;
            var logged = engine.getEvent(count - 1).getCode();
            Test.assertMessage(count == before.eventCount + 1 && logged == code, message + ": logged " + logged);
            Test.assertEqual(input.key(WatchUi.KEY_ESC, 0), INPUT_UNDO);
            Test.assertMessage(input.toast == toast, message + ": toast");
            assertSameState(engine.getState(), before, message + ": undo");
        }
    }
}

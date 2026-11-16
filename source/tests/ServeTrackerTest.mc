import Toybox.Lang;
import Toybox.Test;

// Serve and sides: the answers to "Who serves first?", the serving team alternating
// every game and each team's players alternating (A1, B1, A2, B2), a tie-break counting as one game
// whose first point is served by the next server, then two points each, the set after a tie-break
// opened by the pair that didn't serve first in it, the side by point parity and none on a deciding
// point, swap and fix at any time, change of ends, and serve tracking off. RandomMatchTest checks the
// rotation in random matches of every format.
//
// The serve is written as TestKit.serveFlags() gives it: who serves the current point (ME, PARTNER,
// THEM, "?" when unknown), the side (R, L, "-" on a deciding point), then " new" when the last event
// changed the server and " ends" when it made the players change ends: "PARTNER L new".

(:test)
function serveFirstServerAnswersTest(logger as Logger) as Boolean {
    // "Who serves first? Me / Partner / Opponents" and, after Opponents, "Who serves first for us? Me /
    // Partner" are logged as FIX_SERVING_TEAM, then SWAP_OUR_SERVER for Partner.
    // The serving team then alternates every game, and our players too.
    var engine = new ScoringEngine(new MatchConfig());
    Test.assertEqual(TestKit.serveFlags(engine.getState()), "?");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_US, "ME R new");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"], ["T", "PARTNER R new"], ["U", "THEM R new ends"],
        ["T", "ME R new"]]);
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "PARTNER R new");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"], ["T", "ME R new"]]);
    engine = new ScoringEngine(new MatchConfig());
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_THEM, "THEM R new");
    Test.assert(engine.getState().ourServer == PLAYER_ME && engine.getState().getServingPlayer() == null);
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "ME R new ends"], ["T", "THEM R new"], ["U", "PARTNER R new ends"]]);
    // Opponents, then Partner: our order changes, not who serves now.
    engine = TestKit.newMatch(new MatchConfig(), "Opponents Me");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "PARTNER R new ends"], ["T", "THEM R new"], ["U", "ME R new ends"]]);
    return true;
}

(:test)
function serveRotationAcrossSetsTest(logger as Logger) as Boolean {
    // A normal set boundary: the rotation simply continues. Me first: ME, THEM, PARTNER,
    // THEM. 6-4 is ten games, so the next set's first game is the eleventh of the rotation; 6-3 is
    // nine, so the next set's first is the twentieth. Best of 5 for room.
    var engine = TestKit.newMatch(TestKit.format(3, 6, 6, true), "Me");
    TestKit.play(engine, "UTUTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "PARTNER R new"], ["U", "THEM R new ends"], ["T", "ME R new"]]);
    TestKit.play(engine, "UTUTUU");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"]]);
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 6-3 | 0-0 0-0");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "ME R new ends"], ["T", "THEM R new"]]);
    return true;
}

(:test)
function serveTieBreakTest(logger as Logger) as Boolean {
    // The tie-break's first point is served by the next server in the rotation, then two points each,
    // first from the left then from the right; ends change every 6 points; it counts as one game.
    // Me first: the 13th game, the tie-break, is ME's.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTUTUTUTUTU");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "ME R new"]]);
    Test.assert(engine.getState().getChangeOfEndsAt() == 6);
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [
        ["u", "THEM L new"], ["t", "THEM R"], ["t", "PARTNER L new"], ["u", "PARTNER R"], ["u", "THEM L new"], ["t", "THEM R ends"],
        ["t", "ME L new"]
    ]);
    // 8-6: the set, 13 games, so ends change. We served the tie-break's first point, so they open the
    // next set (they also served its last point, so no new server on screen).
    TestKit.play(engine, "uuttuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM R ends"]]);
    Test.assertEqual(TestKit.sets(engine.getState()), "7-6(8-6) | 0-0 0-0");
    // The tie-break counted as ME's game: PARTNER serves our first game of the set.
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "PARTNER R new ends"], ["U", "THEM R new"], ["U", "ME R new ends"]]);
    return true;
}

(:test)
function serveSetAfterTieBreakTest(logger as Logger) as Boolean {
    // After a set decided by a tie-break, the pair that didn't serve first in it serves first,
    // whoever won it and however long it was. Opponents then Me: the rotation is THEM, ME,
    // THEM, PARTNER, so they serve the tie-break first and we open the next set with ME, who served
    // first for us in the tie-break.
    var engine = TestKit.newMatch(new MatchConfig(), "Opponents Me");
    TestKit.play(engine, TestKit.repeat("UT", 6));
    var tieBreak = engine.getState().eventCount;
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "ME L new"], ["u", "ME R"], ["u", "THEM L new"]]);
    TestKit.play(engine, "uuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "ME R new ends"]]);
    Test.assertEqual(TestKit.sets(engine.getState()), "7-6(7-0) | 0-0 0-0");
    // A long tie-break, 9-7.
    TestKit.undoTo(engine, tieBreak);
    TestKit.play(engine, TestKit.repeat("ut", 7) + "uu");
    Test.assert(TestKit.sets(engine.getState()).equals("7-6(9-7) | 0-0 0-0") && TestKit.serve(engine.getState()).equals("ME R"));
    // Lost by us.
    TestKit.undoTo(engine, tieBreak);
    TestKit.play(engine, "T");
    Test.assertEqual(TestKit.serveFlags(engine.getState()), "ME R new ends");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"], ["U", "PARTNER R new"]]);
    return true;
}

(:test)
function serveSuperTieBreakTest(logger as Logger) as Boolean {
    // The super tie-break is served like a tie-break: the next server in the rotation, then two points
    // each, ends every 6 points. Me first; 6-4 then 3-6 is 19 games, so THEM serve first. Once the
    // match is won nothing changes any more.
    var config = TestKit.preset(PRESET_BEST_OF_3_SUPER_TB);
    var engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UTUTUTUTUU UTUTUTTT");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "THEM R new ends"], ["u", "ME L new"], ["t", "ME R"], ["u", "THEM L new"]]);
    TestKit.play(engine, "tu");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "PARTNER R ends"]]);
    Test.assert(engine.getState().getChangeOfEndsAt() == 12);
    TestKit.play(engine, "uuuuuuu");
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 3-6 S10-3 | 0-0 0-0 over");
    Test.assert(!engine.getState().serverChanged && !engine.getState().changeOfEnds);

    // After a set decided by a tie-break, the pair that didn't serve first in it opens the super
    // tie-break: PARTNER serves the 23rd game, the tie-break, so they open, then ME serves our turn.
    engine = TestKit.newMatch(config, "Me");
    TestKit.play(engine, "UTUTUTUTUU " + TestKit.repeat("UT", 6));
    Test.assertEqual(TestKit.serve(engine.getState()), "PARTNER R");
    TestKit.play(engine, "T");
    Test.assertEqual(TestKit.serve(engine.getState()), "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "ME L new"]]);
    return true;
}

(:test)
function serveTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only is served as a tie-break from its first point: the first server
    // serves it, then the turns are two points each, first from the left then from the right, each
    // pair's players alternating; ends change every 6 points, never on the match point (here the 12th,
    // 7-5). Me first.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_7), "Me");
    Test.assert(TestKit.serveFlags(engine.getState()).equals("ME R new") && engine.getState().getChangeOfEndsAt() == 6);
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [
        ["u", "THEM L new"], ["t", "THEM R"], ["t", "PARTNER L new"], ["u", "PARTNER R"], ["u", "THEM L new"], ["t", "THEM R ends"],
        ["t", "ME L new"], ["u", "ME R"], ["t", "THEM L new"], ["u", "THEM R"], ["u", "PARTNER L new"]
    ]);
    Test.assert(engine.getState().getChangeOfEndsAt() == 12 && TestKit.sets(engine.getState()).equals("| 0-0 stb 6-5"));
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM R"]]);
    var state = engine.getState();
    Test.assert(TestKit.sets(state).equals("S7-5 | 0-0 0-0 over") && !state.changeOfEnds && !state.serverChanged);
    Test.assertEqual(TestKit.games(state), "stbUU");

    // To 10, Opponents then Partner: they serve the first point, then PARTNER our first turn, ME our
    // second; ends at 6, 12 and 18 points.
    engine = TestKit.newMatch(TestKit.preset(PRESET_TIE_BREAK_10), "Opponents Partner");
    Test.assertEqual(TestKit.serve(engine.getState()), "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [
        ["t", "PARTNER L new"], ["u", "PARTNER R"], ["u", "THEM L new"], ["t", "THEM R"], ["t", "ME L new"], ["u", "ME R ends"]
    ]);
    for (var played = 7; played <= 18; played++) {
        TestKit.play(engine, played % 2 == 0 ? "u" : "t");
        state = engine.getState();
        Test.assertMessage(state.changeOfEnds == (played % 6 == 0)
            && state.getChangeOfEndsAt() == (played / 6 + 1) * 6, "point " + played);
    }
    // Singles: ME, then THEM two points, ME two points.
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    config.doubles = false;
    engine = TestKit.newMatch(config, "Me");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "THEM L new"], ["t", "THEM R"], ["u", "ME L new"], ["u", "ME R"],
        ["t", "THEM L new"], ["u", "THEM R ends"]]);
    return true;
}

(:test)
function serveSinglesTest(logger as Logger) as Boolean {
    // Singles: the same rotation with two players, so only the teams alternate, in games and in
    // tie-breaks. There is no server order to swap.
    var config = new MatchConfig();
    config.doubles = false;
    var engine = TestKit.newMatch(config, "Me");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"], ["T", "ME R new"]]);
    TestKit.checkRefusedType(engine, EVENT_SWAP_OUR_SERVER, null);
    TestKit.play(engine, "UTUTUTUTUT");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM L new"], ["u", "THEM R"], ["u", "ME L new"]]);
    // 7-0: we served the tie-break's first point, so they open the next set.
    TestKit.play(engine, "uuu");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM R ends"], ["T", "ME R new ends"]]);
    engine = TestKit.newMatch(config, "Opponents Me");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "ME R new ends"]]);
    return true;
}

(:test)
function serveSideTest(logger as Logger) as Boolean {
    // Right (deuce court) after an even number of points in the game, left after an odd number,
    // whatever the score, advantages and deuces included; the next game from the right. On
    // a deciding point the receivers choose: no side, the server stays known. With serve
    // tracking off there is no side anyway.
    var engine = TestKit.newMatch(TestKit.withMode(DEUCE_ADVANTAGE), "Me");
    Test.assertEqual(TestKit.serve(engine.getState()), "ME R");
    TestKit.play(engine, "utututu");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "ME R"], ["t", "ME L"], ["u", "ME R"], ["u", "ME L"], ["u", "THEM R new ends"]]);
    var modes = [DEUCE_GOLDEN, DEUCE_SILVER, DEUCE_STAR];
    var deuces = ["uuuttt", "uuuttt ut", "uuuttt ut ut"];
    for (var i = 0; i < modes.size(); i++) {
        engine = TestKit.newMatch(TestKit.withMode(modes[i]), "Opponents Me");
        TestKit.play(engine, deuces[i]);
        var state = engine.getState();
        Test.assertMessage(state.isDecidingPoint() && TestKit.serve(state).equals("THEM -") && state.getServeSide() == null
            && state.getServingTeam() == TEAM_THEM, "mode " + modes[i]);
        TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "ME R new ends"]]);
    }
    engine = new ScoringEngine(TestKit.withMode(DEUCE_GOLDEN));
    TestKit.play(engine, "uuuttt");
    Test.assert(engine.getState().isDecidingPoint() && engine.getState().getServeSide() == null);
    return true;
}

(:test)
function serveSwapAndFixTest(logger as Logger) as Boolean {
    // Swap our server order and Fix serving team, at any time: each event's undo gives back
    // the exact state before it (TestKit.checkEvent()).
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    // Swap mid-game while we serve: PARTNER serves on, and ME serves our next game.
    TestKit.play(engine, "ut");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "PARTNER R new");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "PARTNER L"], ["U", "THEM R new ends"]]);
    // Swap between games while they serve: who serves now doesn't change.
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "PARTNER R new"]]);
    // Fix between games: they serve this game, and PARTNER, who didn't get to serve, serves our next.
    TestKit.checkRefusedType(engine, EVENT_FIX_SERVING_TEAM, TEAM_US);
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_THEM, "THEM R new");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "PARTNER R new ends"]]);
    // Fix mid-game.
    TestKit.play(engine, "tt");
    var before = engine.getState().copy();
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_THEM, "THEM R new");
    TestKit.checkRefusedType(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "THEM L"], ["T", "PARTNER R new"]]);
    Test.assertEqual(TestKit.games(engine.getState()), "UU TT TU TT");
    // Undo back across the game and the fix: exactly as before.
    TestKit.play(engine, "<<<");
    TestKit.assertSameState(engine.getState(), before, "undo to before the fix");
    Test.assertEqual(TestKit.serveFlags(engine.getState()), "PARTNER R");
    return true;
}

(:test)
function serveSwapAndFixInTieBreakTest(logger as Logger) as Boolean {
    // In a tie-break, Fix serving team names the team serving the current point, and the turns around
    // it follow; a swap swaps all our turns. Me first: ME serves the tie-break's first point.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, TestKit.repeat("UT", 6));
    var tieBreak = engine.getState().eventCount;
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["u", "THEM L new"]]);
    TestKit.checkRefusedType(engine, EVENT_FIX_SERVING_TEAM, TEAM_THEM);
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_US, "ME L new");
    Test.assert(engine.getState().servingTeam == TEAM_THEM);
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "ME R"], ["u", "THEM L new"]]);
    // 7-3: they served the first turn now, so we open the next set, with ME.
    TestKit.play(engine, "utt");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "ME R ends"]]);
    Test.assertEqual(TestKit.sets(engine.getState()), "7-6(7-3) | 0-0 0-0");

    // A swap while they serve: PARTNER now served our first turn, so ME serves our next one.
    TestKit.undoTo(engine, tieBreak);
    TestKit.play(engine, "u");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "THEM L");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["t", "THEM R"], ["t", "ME L new"]]);
    // 3-7: the tie-break was our game, PARTNER's after the swap, so ME serves our next game.
    TestKit.play(engine, "uut");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "THEM R ends"], ["U", "ME R new ends"]]);
    // A swap while we serve changes the server now.
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "PARTNER R new");
    return true;
}

(:test)
function serveChangeOfEndsTest(logger as Logger) as Boolean {
    // Change of ends: after game 1, 3, 5... of a set, so at the end of a set when its game
    // count is odd, and after the next set's first game otherwise; every 6 points in a tie-break,
    // where the caption gives the next change (6, 12, 18). Never once the match is over, and never
    // for other events, End set now included. The alert itself is the app's: the engine only says when.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "u");
    Test.assert(!engine.getState().changeOfEnds && engine.getState().getChangeOfEndsAt() == null);
    TestKit.play(engine, "uuu");
    Test.assert(engine.getState().changeOfEnds);
    // Games 2 to 11: game 10 ends the set at 6-4 with no change, the next set's first game changes.
    var moves = "TUTUTUTUUU";
    for (var i = 0; i < moves.length(); i++) {
        TestKit.play(engine, moves.substring(i, i + 1) as String);
        Test.assertMessage(engine.getState().changeOfEnds == (i % 2 == 1), "game " + (i + 2));
    }
    // 1-6: seven games, the end of the set changes.
    TestKit.play(engine, "TTTTT");
    Test.assert(!engine.getState().changeOfEnds);
    TestKit.play(engine, "T");
    Test.assert(TestKit.sets(engine.getState()).equals("6-4 1-6 | 0-0 0-0") && engine.getState().changeOfEnds);
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN, "THEM R");
    // A tie-break: ends at 6 and 12 points; it wins the match, 13 games, but no change once it's over.
    TestKit.play(engine, TestKit.repeat("UT", 6) + " ututu");
    Test.assert(!engine.getState().changeOfEnds && engine.getState().getChangeOfEndsAt() == 6);
    TestKit.play(engine, "t");
    Test.assert(engine.getState().changeOfEnds && engine.getState().getChangeOfEndsAt() == 12);
    TestKit.play(engine, "ututut");
    Test.assert(engine.getState().changeOfEnds && engine.getState().getChangeOfEndsAt() == 18);
    TestKit.play(engine, "uu");
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 1-6 7-6(8-6) | 0-0 0-0 over");
    Test.assert(!engine.getState().changeOfEnds);

    // End set now never changes ends: the change after the set's last odd game was made then.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTU");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_END_SET, null, "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["T", "ME R new ends"]]);
    // A match won on an odd game: no change.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UTUTUTUTUU UTUTUTUUU");
    Test.assertEqual(TestKit.sets(engine.getState()), "6-4 6-3 | 0-0 0-0 over");
    Test.assert(!engine.getState().changeOfEnds && !engine.getState().serverChanged);
    return true;
}

(:test)
function serveTrackingOffTest(logger as Logger) as Boolean {
    // With serve tracking off nothing is asked, so no FIX_SERVING_TEAM: the serving team stays unknown,
    // and so does everything worked out from it, finished games included; scoring and change of ends
    // are the same (RandomMatchTest plays such matches). Fix serving team later on starts the rotation
    // from there, with our order as it stands.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UTUTUTUTUU UTUTUT uut");
    var state = engine.getState();
    Test.assert(TestKit.serve(state).equals("?") && state.servingTeam == null && state.getServeSide() == null);
    Test.assert(state.getFinishedGameServer(9) == null && state.changeOfEnds == false);
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UT");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_SWAP_OUR_SERVER, null, "?");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_FIX_SERVING_TEAM, TEAM_US, "PARTNER R new");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "THEM R new ends"], ["T", "ME R new"]]);
    Test.assertEqual(TestKit.games(engine.getState()), "?U ?T UU TT");
    return true;
}

(:test)
function serveEndSetAndEndMatchTest(logger as Logger) as Boolean {
    // End set now drops the game in progress: its server, who never had the game, serves the next
    // set's first game. Best of 5 for room.
    var engine = TestKit.newMatch(TestKit.format(3, 6, 6, true), "Me");
    TestKit.play(engine, "UTU");
    // Between games: they serve the next set's first game, as they would have the next game.
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_END_SET, null, "THEM R");
    TestKit.checkSteps(engine, TestKit.VIEW_SERVE, [["U", "ME R new ends"], ["t", "ME L"]]);
    // Mid-game: ME serves the next set's first game again, from the right.
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_END_SET, null, "ME R");
    Test.assertEqual(TestKit.sets(engine.getState()), "2-1EU 1-0EU | 0-0 0-0");
    Test.assertEqual(engine.getState().finishedGames.size(), 4);
    // In a tie-break: the team and player who served its first point serve the next set's first
    // game, as no tie-break decided the set.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, TestKit.repeat("UT", 6) + " utt");
    Test.assertEqual(TestKit.serve(engine.getState()), "PARTNER L");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_END_SET, TEAM_THEM, "ME R new");
    Test.assertEqual(engine.getState().finishedGames.size(), 12);
    // End match leaves the unfinished game's server as it was (the last lap reads it).
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UT u");
    TestKit.checkEvent(engine, TestKit.VIEW_SERVE, EVENT_END_MATCH, null, "PARTNER L");
    return true;
}

(:test)
function serveFinishedGamesTest(logger as Logger) as Boolean {
    // Each finished game keeps who served it (a tie-break: who served its first point), who won it and
    // its type, for holds and breaks and the lap outcome: "UU" is a game we held, "TU"
    // one we broke. Undo takes the game back out.
    var engine = TestKit.newMatch(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "Me");
    TestKit.play(engine, TestKit.repeat("UT", 6) + " U TTTTTT " + TestKit.repeat("u", 10));
    var state = engine.getState();
    Test.assertEqual(TestKit.sets(state), "7-6(7-0) 0-6 S10-0 | 0-0 0-0 over");
    Test.assertEqual(TestKit.games(state), "UU TT UU TT UU TT UU TT UU TT UU TT tbUU TT UT TT UT TT UT stbTU");
    Test.assertEqual(state.finishedGames.size(), state.getGamesWon(TEAM_US) + state.getGamesWon(TEAM_THEM) + 1);
    engine.undo();
    Test.assertEqual(TestKit.sets(engine.getState()), "7-6(7-0) 0-6 | 0-0 stb 9-0");
    Test.assertEqual(engine.getState().finishedGames.size(), 19);
    return true;
}

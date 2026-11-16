import Toybox.Lang;
import Toybox.Test;

// Match situation flags, and the net banner and bottom caption of the score screen:
// break, set and match points with the team each belongs to, the deciding point and the tie-break;
// the one banner shown, by priority (STAR / SILVER / GOLDEN POINT > MATCH POINT > SET POINT > BREAK
// POINT > DEUCE n > TIE-BREAK), and its style; the caption (SET n, CHANGE ENDS AT n, RECEIVERS CHOOSE
// or SAME SEX RECEIVES); nothing once the match is over. RandomMatchTest checks every flag against
// what the next point would do, in random matches of every format.
//
// The situation is written as TestKit.situation() gives it: the banner and its style, the caption,
// then the flags, "-" for none: "BREAK POINT pressure | SET 2 | break U". Each case is the moves of a
// new match after the serve answer ("" for serve tracking off).

(:test)
function situationMockupsTest(logger as Logger) as Boolean {
    // "Score, in play": they won the first set, 4-3 to us, they serve from their left at THEM 30, US
    // 40: our break point, outlined; SET 2 below. "Star point": one set each, 5-2 to us, PARTNER
    // serves at deuce 3: also our match point and their break point, which the deciding point outranks;
    // in mixed doubles the receiver is the same sex as the server. "Tie-break":
    // TIE-BREAK, outlined, the caption at the next change of ends, 12 once the change at 6 is behind
    // (the mockup's "6" is only right up to 5 points played).
    var engine = TestKit.newMatch(new MatchConfig(), "Opponents Me");
    TestKit.play(engine, "UTTTTTT UTUTUTU ututu");
    Test.assert(TestKit.sets(engine.getState()).equals("1-6 | 4-3 40-30") && TestKit.serve(engine.getState()).equals("THEM L"));
    TestKit.check(engine, TestKit.VIEW_SITUATION, "BREAK POINT pressure | SET 2 | break U", "in play");
    var star = "UUUUUU UTUTUTTTT UUTUTUU uuuttt ut ut";
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, star);
    Test.assert(TestKit.game(engine.getState()).equals("5-2 40-40 deuce 3 deciding") && TestKit.serve(engine.getState()).equals("PARTNER -"));
    TestKit.check(engine, TestKit.VIEW_SITUATION, "STAR POINT deciding | RECEIVERS CHOOSE | break T, set U, match U, deciding", "star");
    var mixed = new MatchConfig();
    mixed.mixed = true;
    TestKit.checkCases(mixed, "Me", TestKit.VIEW_SITUATION, [[star, "STAR POINT deciding | SAME SEX RECEIVES | break T, set U, match U, deciding"]]);
    TestKit.checkCases(new MatchConfig(), "Me", TestKit.VIEW_SITUATION, [
        [TestKit.repeat("UT", 6), "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        [TestKit.repeat("UT", 6) + " ututututt", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"]
    ]);
    return true;
}

(:test)
function situationBreakPointTest(logger as Logger) as Boolean {
    // A break point is the receivers' game point in a regular game, for either team: 40-30 or better,
    // their advantage, a deciding point. Not the servers' advantage, nor in a tie-break, where the
    // receivers' game point is a set point. Swapping our order changes nothing; fixing the serving team
    // moves it. Advantage here; they serve the first game.
    var engine = TestKit.newMatch(TestKit.withMode(DEUCE_ADVANTAGE), "Opponents Me");
    TestKit.play(engine, "uu");
    TestKit.checkSteps(engine, TestKit.VIEW_SITUATION, [
        ["u", "BREAK POINT pressure | SET 1 | break U"], ["t", "BREAK POINT pressure | SET 1 | break U"],
        ["t", "BREAK POINT pressure | SET 1 | break U"], ["t", "- | SET 1 | -"], ["u", "BREAK POINT pressure | SET 1 | break U"],
        ["t", "- | SET 1 | -"], ["t", "- | SET 1 | -"]
    ]);
    // 0-1, we serve: the break points are theirs.
    TestKit.play(engine, "t tt");
    TestKit.checkSteps(engine, TestKit.VIEW_SITUATION, [["t", "BREAK POINT pressure | SET 1 | break T"], ["u", "BREAK POINT pressure | SET 1 | break T"]]);
    TestKit.checkCases(TestKit.withMode(DEUCE_GOLDEN), "Opponents Me", TestKit.VIEW_SITUATION, [
        ["uuuttt", "GOLDEN POINT deciding | RECEIVERS CHOOSE | break U, deciding"],
        [TestKit.repeat("UT", 6) + " uuuuuut", "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break"]
    ]);
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "uuut");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_SWAP_OUR_SERVER, null, "- | SET 1 | -");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_FIX_SERVING_TEAM, TEAM_THEM, "BREAK POINT pressure | SET 1 | break U");
    return true;
}

(:test)
function situationSetPointTest(logger as Logger) as Boolean {
    // A set point is a game point that wins the set, for either team, in every set structure: N or more
    // games with a 2-game lead, or the tie-break's game point (to 7 or 10); never at T-T. Serve tracking
    // off, so no break point mixes in.
    TestKit.checkCases(new MatchConfig(), "", TestKit.VIEW_SITUATION, [
        ["UTUTUTUTU uuu", "SET POINT pressure | SET 1 | set U"],
        ["UTUTUTUTU ttt", "- | SET 1 | -"],
        ["UTUTUTUTUT uuu", "- | SET 1 | -"],
        ["UTUTUTUTUTU uuu", "SET POINT pressure | SET 1 | set U"],
        ["TTTTT ttt", "SET POINT pressure | SET 1 | set T"],
        [TestKit.repeat("UT", 6) + " uuuuuu", "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break"],
        [TestKit.repeat("UT", 6) + " ttttttu", "SET POINT pressure | CHANGE ENDS AT 12 | set T, tie-break"],
        [TestKit.repeat("UT", 6) + " " + TestKit.repeat("ut", 6), "TIE-BREAK info | CHANGE ENDS AT 18 | tie-break"],
        [TestKit.repeat("UT", 6) + " " + TestKit.repeat("ut", 6) + "u", "SET POINT pressure | CHANGE ENDS AT 18 | set U, tie-break"]
    ]);
    var config = new MatchConfig();
    config.tieBreakPoints = 10;
    TestKit.checkCases(config, "", TestKit.VIEW_SITUATION, [
        [TestKit.repeat("UT", 6) + " uuuuuuuu", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        [TestKit.repeat("UT", 6) + " uuuuuuuuu", "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break"]
    ]);
    TestKit.checkCases(TestKit.format(2, 9, 8, true), "", TestKit.VIEW_SITUATION, [
        [TestKit.repeat("UT", 7) + " uuu", "- | SET 1 | -"],
        [TestKit.repeat("UT", 7) + "U uuu", "SET POINT pressure | SET 1 | set U"],
        [TestKit.repeat("UT", 8), "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"]
    ]);
    // Short sets: 5-3 wins, the tie-break at 4-4, the match point in the second set's.
    TestKit.checkCases(TestKit.preset(PRESET_SHORT_SETS), "", TestKit.VIEW_SITUATION, [
        ["UTUTUT uuu", "- | SET 1 | -"],
        ["UTUTUTU uuu", "SET POINT pressure | SET 1 | set U"],
        ["UTUTUTUT", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        ["UUUU UTUTUTUT uuuuuu", "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"]
    ]);
    TestKit.checkCases(TestKit.format(2, 4, 3, true), "", TestKit.VIEW_SITUATION, [
        ["UTUTU uuu", "SET POINT pressure | SET 1 | set U"],
        ["UTUTUT", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"]
    ]);
    TestKit.checkCases(TestKit.format(2, 6, 6, false), "", TestKit.VIEW_SITUATION, [
        [TestKit.repeat("UT", 6) + " uuu", "- | SET 1 | -"],
        [TestKit.repeat("UT", 6) + "U uuu", "SET POINT pressure | SET 1 | set U"]
    ]);
    return true;
}

(:test)
function situationMatchPointTest(logger as Logger) as Boolean {
    // A match point is a set point in the last set a team needs, for either team: a tie-break's and the
    // super tie-break's points included. With one set, every set point is a match point.
    TestKit.checkCases(new MatchConfig(), "", TestKit.VIEW_SITUATION, [
        ["UUUUUU UUUUU uuu", "MATCH POINT pressure | SET 2 | set U, match U"],
        ["UUUUUU TTTTT ttt", "SET POINT pressure | SET 2 | set T"],
        ["UUUUUU TTTTTT TTTTT ttt", "MATCH POINT pressure | SET 3 | set T, match T"],
        ["UUUUUU TTTTTT " + TestKit.repeat("UT", 6) + " uuuuuu", "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"]
    ]);
    TestKit.checkCases(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "", TestKit.VIEW_SITUATION, [
        ["UUUUUU TTTTTT " + TestKit.repeat("u", 8), "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["UUUUUU TTTTTT " + TestKit.repeat("u", 9), "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"],
        ["UUUUUU TTTTTT " + TestKit.repeat("ut", 8) + "t", "MATCH POINT pressure | CHANGE ENDS AT 18 | set T, match T, tie-break"],
        ["UUUUUU TTTTTT " + TestKit.repeat("ut", 9), "TIE-BREAK info | CHANGE ENDS AT 24 | tie-break"]
    ]);
    TestKit.checkCases(TestKit.preset(PRESET_PRO_SET), "", TestKit.VIEW_SITUATION, [
        ["UUUUUUUU uuu", "MATCH POINT pressure | SET 1 | set U, match U"]
    ]);
    // Best of 5: three sets to win, so the fifth set's set point is either team's match point.
    TestKit.checkCases(TestKit.preset(PRESET_BEST_OF_5), "", TestKit.VIEW_SITUATION, [
        ["UUUUUU UUUUU uuu", "SET POINT pressure | SET 2 | set U"],
        ["UUUUUU UUUUUU UUUUU uuu", "MATCH POINT pressure | SET 3 | set U, match U"],
        ["UUUUUU TTTTTT UUUUUU TTTTTT TTTTT ttt", "MATCH POINT pressure | SET 5 | set T, match T"]
    ]);
    return true;
}

(:test)
function situationTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only is captioned as a tie-break from its first point: TIE-BREAK,
    // CHANGE ENDS AT n; each set point is a match point (one set), at 6 points to 7 and 9 to 10, from
    // either team; win by two, so level at 6-6 is none; no break point (it's no one's service game), no
    // deciding point whatever the deuce mode; nothing once it's won.
    var config = TestKit.preset(PRESET_TIE_BREAK_7);
    config.deuceMode = DEUCE_GOLDEN;
    TestKit.checkCases(config, "Me", TestKit.VIEW_SITUATION, [
        ["", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        ["uuuttt", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["uuuuuu", "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"],
        ["uuuuuttttt", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["uuuuutttttt", "MATCH POINT pressure | CHANGE ENDS AT 12 | set T, match T, tie-break"],
        ["uuuuuutttttt", "TIE-BREAK info | CHANGE ENDS AT 18 | tie-break"],
        ["uuuuuuttttttu", "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break"],
        ["uuuuuuu", "- | - | -"]
    ]);
    TestKit.checkCases(TestKit.preset(PRESET_TIE_BREAK_10), "", TestKit.VIEW_SITUATION, [
        ["uuuuuu", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["uuuuuuuu", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["uuuuuuuuu", "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"],
        [TestKit.repeat("ut", 9) + "t", "MATCH POINT pressure | CHANGE ENDS AT 24 | set T, match T, tie-break"],
        [TestKit.repeat("ut", 10), "TIE-BREAK info | CHANGE ENDS AT 24 | tie-break"],
        [TestKit.repeat("t", 10), "- | - | -"]
    ]);
    return true;
}

(:test)
function situationDeuceBannerTest(logger as Logger) as Boolean {
    // DEUCE 1 and DEUCE 2 count the deuces before a Star or Silver point and stay through the advantage
    // after each; Golden's first deuce is its deciding point, and Advantage has no counter.
    // We serve, so our advantage carries no flag and theirs is a break point.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "uuutt");
    TestKit.checkSteps(engine, TestKit.VIEW_SITUATION, [
        ["t", "DEUCE 1 info | SET 1 | -"], ["u", "DEUCE 1 info | SET 1 | -"], ["t", "DEUCE 2 info | SET 1 | -"],
        ["u", "DEUCE 2 info | SET 1 | -"], ["t", "STAR POINT deciding | RECEIVERS CHOOSE | break T, deciding"], ["u", "- | SET 1 | -"]
    ]);
    TestKit.checkCases(TestKit.withMode(DEUCE_SILVER), "Me", TestKit.VIEW_SITUATION, [
        ["uuuttt u", "DEUCE 1 info | SET 1 | -"],
        ["uuuttt ut", "SILVER POINT deciding | RECEIVERS CHOOSE | break T, deciding"]
    ]);
    TestKit.checkCases(TestKit.withMode(DEUCE_GOLDEN), "Me", TestKit.VIEW_SITUATION, [
        ["uuuttt", "GOLDEN POINT deciding | RECEIVERS CHOOSE | break T, deciding"]
    ]);
    TestKit.checkCases(TestKit.withMode(DEUCE_ADVANTAGE), "Me", TestKit.VIEW_SITUATION, [
        ["uuuttt", "- | SET 1 | -"],
        ["uuuttt utututut u", "- | SET 1 | -"],
        ["uuuttt utututut t", "BREAK POINT pressure | SET 1 | break T"]
    ]);
    // A deuce mode change waits for the next game: the banners follow the game's rule.
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "uuuttt");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_SET_DEUCE_MODE, DEUCE_GOLDEN, "DEUCE 1 info | SET 1 | -");
    TestKit.play(engine, "utut");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "STAR POINT deciding | RECEIVERS CHOOSE | break T, deciding", "star game");
    TestKit.play(engine, "u tttuuu");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "GOLDEN POINT deciding | RECEIVERS CHOOSE | break U, deciding", "golden game");
    return true;
}

(:test)
function situationPriorityTest(logger as Logger) as Boolean {
    // Each step of the order, with every flag that holds: STAR / SILVER / GOLDEN POINT > MATCH POINT >
    // SET POINT > BREAK POINT > DEUCE n > TIE-BREAK > none. DEUCE n and TIE-BREAK never meet: a
    // tie-break has no deuce.
    var golden = TestKit.preset(PRESET_ONE_SET);
    golden.deuceMode = DEUCE_GOLDEN;
    TestKit.checkCases(golden, "Me", TestKit.VIEW_SITUATION, [
        ["UUUUU uuuttt", "GOLDEN POINT deciding | RECEIVERS CHOOSE | break U, set U, match U, deciding"]
    ]);
    TestKit.checkCases(TestKit.withMode(DEUCE_SILVER), "Me", TestKit.VIEW_SITUATION, [
        ["TTTTT uuuttt ut", "SILVER POINT deciding | RECEIVERS CHOOSE | break U, set T, deciding"]
    ]);
    TestKit.checkCases(new MatchConfig(), "Opponents Me", TestKit.VIEW_SITUATION, [
        ["UUUUUU TUUUUU uuu", "MATCH POINT pressure | SET 2 | break U, set U, match U"],
        ["TUUUUU uuu", "SET POINT pressure | SET 1 | break U, set U"],
        ["uuuttt u", "BREAK POINT pressure | SET 1 | break U"],
        ["uuuttt ut", "DEUCE 2 info | SET 1 | -"],
        [TestKit.repeat("UT", 6) + " uuuuuut", "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break"],
        [TestKit.repeat("UT", 6), "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        ["", "- | SET 1 | -"]
    ]);
    return true;
}

(:test)
function situationCaptionTest(logger as Logger) as Boolean {
    // SET n in a set, the next set's number after End set now; CHANGE ENDS AT n in a tie-break and the
    // super tie-break, n the points played at the next change of ends; on a deciding point RECEIVERS
    // CHOOSE, or SAME SEX RECEIVES in mixed doubles. Mixed means nothing in singles.
    TestKit.checkCases(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "", TestKit.VIEW_SITUATION, [
        ["UUUUUU", "- | SET 2 | -"],
        ["UUUUUU " + TestKit.repeat("UT", 6) + " ututu", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        ["UUUUUU " + TestKit.repeat("UT", 6) + " ututut", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["UUUUUU " + TestKit.repeat("UT", 6) + " T", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"]
    ]);
    var engine = TestKit.newMatch(new MatchConfig(), "");
    TestKit.play(engine, "UU u");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_END_SET, null, "- | SET 2 | -");
    var config = TestKit.withMode(DEUCE_GOLDEN);
    config.mixed = true;
    TestKit.checkCases(config, "", TestKit.VIEW_SITUATION, [["uuuttt", "GOLDEN POINT deciding | SAME SEX RECEIVES | deciding"]]);
    config.doubles = false;
    TestKit.checkCases(config, "Me", TestKit.VIEW_SITUATION, [["uuuttt", "GOLDEN POINT deciding | RECEIVERS CHOOSE | break T, deciding"]]);
    return true;
}

(:test)
function situationServeTrackingOffTest(logger as Logger) as Boolean {
    // Without the serving team nobody is known to receive, so there is no break point. The other flags
    // don't depend on the serve, and the banner falls to the next one in the order. A Fix serving team
    // brings the break point in.
    TestKit.checkCases(new MatchConfig(), "", TestKit.VIEW_SITUATION, [
        ["UTTTTTT UTUTUTU ututu", "- | SET 2 | -"],
        ["UUUUUU UTUTUTTTT UUTUTUU uuuttt ut ut", "STAR POINT deciding | RECEIVERS CHOOSE | set U, match U, deciding"]
    ]);
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "uuuttt u");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "DEUCE 1 info | SET 1 | -", "advantage");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_FIX_SERVING_TEAM, TEAM_THEM, "BREAK POINT pressure | SET 1 | break U");
    return true;
}

(:test)
function situationMatchOverTest(logger as Logger) as Boolean {
    // Nothing once the match is over, whatever the state was left at (End match on a deciding point,
    // or on a set point in a tie-break): no flag, no banner, no caption. An undo back into the match
    // brings them back.
    var engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, "UUUUUU UUUUU uuu u");
    TestKit.check(engine, TestKit.VIEW_SITUATION, "- | - | -", "match won");
    engine.undo();
    TestKit.check(engine, TestKit.VIEW_SITUATION, "MATCH POINT pressure | SET 2 | break U, set U, match U", "undo");
    engine = TestKit.newMatch(TestKit.withMode(DEUCE_GOLDEN), "Me");
    TestKit.play(engine, "uuuttt");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_END_MATCH, null, "- | - | -");
    Test.assert(engine.getState().isDecidingPoint());
    engine = TestKit.newMatch(new MatchConfig(), "Me");
    TestKit.play(engine, TestKit.repeat("UT", 6) + " uuuuuu");
    TestKit.checkEvent(engine, TestKit.VIEW_SITUATION, EVENT_END_MATCH, null, "- | - | -");
    Test.assert(engine.getState().isTieBreak());
    TestKit.checkCases(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "", TestKit.VIEW_SITUATION, [
        ["UUUUUU TTTTTT " + TestKit.repeat("t", 10), "- | - | -"]
    ]);
    return true;
}

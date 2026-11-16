import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The Edit score menu without its native menus: a draft of the score, the match's
// own when the menu opens, each part picked from a list holding only the values the format allows
// with the rest of the draft (EditScoreRules), so the draft is always a score EDIT_SCORE accepts, or
// the match's own; Apply logs it as one event, which BACK on the score screen undoes with "Undone:
// score edit"; nothing is logged before Apply, nor when the menu is left with BACK (the draft is
// dropped). Drafts are written as TestKit.edit() reads edits, with the game's point counts: "6-4 |
// 2-1 2-1" is 6-4, then 2-1 and 30-15. A list of sets is written as TestKit.sets() writes sets:
// "7-6(7-5)", "3-1EU".

(:test)
function editScoreItemsTest(logger as Logger) as Boolean {
    // A finished set's item each, the current set's games (none in the super tie-break, which has no
    // games), the game's points, Add set while another finished set leaves both teams short of the
    // match, Remove set with a finished set, then Apply. The draft starts as the match's score.
    var g = EditScoreRules.ITEM_GAMES;
    var p = EditScoreRules.ITEM_POINTS;
    var add = EditScoreRules.ITEM_ADD_SET;
    var remove = EditScoreRules.ITEM_REMOVE_SET;
    var apply = EditScoreRules.ITEM_APPLY;
    var s = EditScoreRules.ITEM_SET;
    var cases = [
        [new MatchConfig(), "", [g, p, add, apply], "| 0-0 0-0", GAME_REGULAR],
        [new MatchConfig(), "UUUUUU UU u", [s, g, p, add, remove, apply], "6-0 | 2-0 1-0", GAME_REGULAR],
        [new MatchConfig(), "UUUUUU TTTTTT t", [s, s + 1, g, p, remove, apply], "6-0 0-6 | 0-0 0-1", GAME_REGULAR],
        [new MatchConfig(), "UTUTUTUTUTUT uut", [g, p, add, apply], "| 6-6 2-1", GAME_TIE_BREAK],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT u", [s, s + 1, p, remove, apply], "6-0 0-6 | 0-0 1-0",
            GAME_SUPER_TIE_BREAK],
        [TestKit.preset(PRESET_ONE_SET), "UT", [g, p, apply], "| 1-1 0-0", GAME_REGULAR],
        [TestKit.format(3, 6, 6, true), "UUUUUU TTTTTT", [s, s + 1, g, p, add, remove, apply], "6-0 0-6 | 0-0 0-0", GAME_REGULAR],
        // Tie-break only: its points alone, no set to add (one wins the match).
        [TestKit.preset(PRESET_TIE_BREAK_7), "uut", [p, apply], "| 0-0 2-1", GAME_SUPER_TIE_BREAK]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var rules = EditMenuTests.rules(cases[i][0] as MatchConfig, cases[i][1] as String);
        var message = cases[i][1] as String;
        Test.assertEqualMessage(rules.getItems().toString(), (cases[i][2] as Array<Number>).toString(), message);
        Test.assertEqualMessage(EditMenuTests.draft(rules), cases[i][3] as String, message);
        Test.assertMessage(rules.getGameType() == cases[i][4], message + ": game type");
        Test.assertMessage(rules.getSetNumber() == rules.sets.size() + 1, message + ": set number");
    }
    return true;
}

(:test)
function editScoreSetChoicesTest(logger as Logger) as Boolean {
    // A finished set's list: the scores it can be won with in the format, ours, then
    // theirs (our side first); 7-6 with its tie-break won L-(L-2); without a tie-break up to N + 5
    // games. Only the winners that leave both teams short of the sets that win the match. A set End
    // set now gave comes first, as it was; so does a set the list wouldn't hold (longer than N + 5).
    // A 7-6 set keeps its tie-break's points.
    var tieBreak10 = new MatchConfig();
    tieBreak10.tieBreakPoints = 10;
    var cases = [
        [new MatchConfig(), "6-0 6-1 6-2 6-3 6-4 7-5 7-6(7-5) 0-6 1-6 2-6 3-6 4-6 5-7 6-7(5-7)"],
        [TestKit.format(2, 9, 8, true), "9-0 9-1 9-2 9-3 9-4 9-5 9-6 9-7 9-8(7-5) 0-9 1-9 2-9 3-9 4-9 5-9 6-9 7-9 8-9(5-7)"],
        [TestKit.format(2, 4, 4, true), "4-0 4-1 4-2 5-3 5-4(7-5) 0-4 1-4 2-4 3-5 4-5(5-7)"],
        [TestKit.format(2, 4, 3, true), "4-0 4-1 4-2 4-3(7-5) 0-4 1-4 2-4 3-4(5-7)"],
        [TestKit.format(2, 6, 6, false), "6-0 6-1 6-2 6-3 6-4 7-5 8-6 9-7 10-8 11-9 0-6 1-6 2-6 3-6 4-6 5-7 6-8 7-9 8-10 9-11"],
        [tieBreak10, "6-0 6-1 6-2 6-3 6-4 7-5 7-6(10-8) 0-6 1-6 2-6 3-6 4-6 5-7 6-7(8-10)"]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var rules = EditMenuTests.rules(cases[i][0] as MatchConfig, "");
        Test.assertEqualMessage(EditMenuTests.setsText(rules.getSetChoices(0)), cases[i][1] as String, "format " + i);
    }
    var ours = "6-0 6-1 6-2 6-3 6-4 7-5 7-6(7-5)";
    var theirs = "0-6 1-6 2-6 3-6 4-6 5-7 6-7(5-7)";
    // Best of 3, the first set ours: the second can only be theirs; the first, with the second theirs,
    // only ours.
    var rules = EditMenuTests.rules(new MatchConfig(), "UUUUUU");
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(1)), theirs);
    rules.setSet(1, rules.getSetChoices(1)[4]);
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 4-6 | 0-0 0-0");
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(0)), ours);
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(1)), theirs);
    // Best of 5, a set each: either team for a third.
    rules = EditMenuTests.rules(TestKit.format(3, 6, 6, true), "UUUUUU TTTTTT");
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(2)), ours + " " + theirs);
    // Given by End set now: first, as it was. Won in the tie-break 7-3 on the watch: kept.
    rules = EditMenuTests.rules(new MatchConfig(), "UUUT u");
    Test.assert(rules.match.add(new MatchEvent(EVENT_END_SET, TestKit.MENU_TIME, null)));
    rules = new EditScoreRules(rules.match);
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(0)), "3-1EU " + ours + " " + theirs);
    rules = EditMenuTests.rules(new MatchConfig(), "UTUTUTUTUTUT uuuuuu ttt u");
    Test.assertEqual(EditMenuTests.draft(rules), "7-6(7-3) | 0-0 0-0");
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(0)), "6-0 6-1 6-2 6-3 6-4 7-5 7-6(7-3) " + theirs);
    // Longer than the list goes, without a tie-break: first, as it was.
    rules = EditMenuTests.rules(TestKit.format(2, 6, 6, false), TestKit.repeat("UT", 11) + "UU");
    Test.assertEqual(EditMenuTests.setsText(rules.getSetChoices(0)).substring(0, 14) as String, "13-11 6-0 6-1 ");
    return true;
}

(:test)
function editScoreGamesChoicesTest(logger as Logger) as Boolean {
    // The set in progress's games, one team at a time: ours (0 to T with a tie-break, up to N + 5
    // without, and ours now), then theirs among those that go with ours: the set not won, no more than
    // T each with a tie-break (T-T is its tie-break).
    var cases = [
        [new MatchConfig(), "0 1 2 3 4 5 6", [[0, "0 1 2 3 4 5"], [4, "0 1 2 3 4 5"], [5, "0 1 2 3 4 5 6"], [6, "5 6"]]],
        [TestKit.format(2, 4, 3, true), "0 1 2 3", [[2, "0 1 2 3"], [3, "0 1 2 3"]]],
        [TestKit.format(2, 9, 8, true), "0 1 2 3 4 5 6 7 8", [[6, "0 1 2 3 4 5 6 7 8"], [8, "0 1 2 3 4 5 6 7 8"]]],
        [TestKit.format(2, 6, 6, false), "0 1 2 3 4 5 6 7 8 9 10 11", [[0, "0 1 2 3 4 5"], [7, "6 7 8"], [11, "10 11 12"]]]
    ];
    var g = EditScoreRules.ITEM_GAMES;
    for (var i = 0; i < cases.size(); i++) {
        var rules = EditMenuTests.rules(cases[i][0] as MatchConfig, "");
        Test.assertMessage(rules.isByTeam(g), "by team");
        Test.assertEqualMessage(EditMenuTests.numbersText(rules.getOurChoices(g)), cases[i][1] as String, "ours, format " + i);
        var theirs = cases[i][2] as Array<Array>;
        for (var j = 0; j < theirs.size(); j++) {
            Test.assertEqualMessage(EditMenuTests.numbersText(rules.getTheirChoices(g, theirs[j][0] as Number)), theirs[j][1] as String,
                "theirs with " + (theirs[j][0] as Number) + ", format " + i);
        }
    }
    // Ours now stays in the list, past N + 5.
    var rules = EditMenuTests.rules(TestKit.format(2, 6, 6, false), "");
    rules.setPair(g, 13, 12);
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(g)), "0 1 2 3 4 5 6 7 8 9 10 11 12 13");
    return true;
}

(:test)
function editScorePointsChoicesTest(logger as Logger) as Boolean {
    // A regular game's points, one list, in the order a game reaches them, then the deuces the game's
    // rule reaches: Advantage deuce 1 only (no deuce count shows), Golden 40-40, Silver up to its
    // deuce 2, Star up to its deuce 3. The game's rule is the one it's played with: a mode chosen
    // during it waits for the next game. An Advantage game played past deuce 1 keeps its
    // counts in the entry that shows them.
    var start = "0-0 1-0 0-1 2-0 1-1 0-2 3-0 2-1 1-2 0-3 3-1 2-2 1-3 3-2 2-3 3-3";
    var modes = [[DEUCE_ADVANTAGE, " 4-3 3-4"], [DEUCE_GOLDEN, ""], [DEUCE_SILVER, " 4-3 3-4 4-4"],
        [DEUCE_STAR, " 4-3 3-4 4-4 5-4 4-5 5-5"]];
    var p = EditScoreRules.ITEM_POINTS;
    for (var i = 0; i < modes.size(); i++) {
        var rules = EditMenuTests.rules(TestKit.withMode(modes[i][0] as DeuceMode), "");
        Test.assertMessage(!rules.isByTeam(p), "one list");
        Test.assertEqualMessage(EditMenuTests.pairsText(rules.getPointsChoices()), start + modes[i][1], "mode " + modes[i][0]);
    }
    var rules = EditMenuTests.rules(TestKit.withMode(DEUCE_ADVANTAGE), "uuu ttt ut ut u");
    Test.assertEqual(EditMenuTests.draft(rules), "| 0-0 6-5");
    Test.assertEqual(EditMenuTests.pairsText(rules.getPointsChoices()), start + " 6-5 3-4");
    // A Star game at 15-0, then Golden chosen: this game stays Star; at 0-0, Golden.
    var rig = new TestKit.Rig(new MatchConfig(), "", false);
    rig.play("u");
    Test.assert(rig.rules.setDeuceMode(DEUCE_GOLDEN, TestKit.MENU_TIME));
    rules = new EditScoreRules(rig.match);
    Test.assertEqual(EditMenuTests.pairsText(rules.getPointsChoices()), start + (modes[3][1] as String));
    Test.assert(rules.getDeuceMode() == DEUCE_STAR);
    rules.setPair(p, 0, 0);
    Test.assert(rules.getDeuceMode() == DEUCE_GOLDEN);
    rig.play("<<");
    Test.assert(rig.rules.setDeuceMode(DEUCE_GOLDEN, TestKit.MENU_TIME));
    Test.assertEqual(EditMenuTests.pairsText(new EditScoreRules(rig.match).getPointsChoices()), start);
    // A tie-break's points, one team at a time: ours 0 to L + 5 (and ours now), theirs those that
    // leave the tie-break unwon. The super tie-break the same, to 10.
    rules = EditMenuTests.rules(new MatchConfig(), "UTUTUTUTUTUT");
    Test.assert(rules.getGameType() == GAME_TIE_BREAK && rules.isByTeam(p));
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(p)), "0 1 2 3 4 5 6 7 8 9 10 11 12");
    var theirs = [[0, "0 1 2 3 4 5 6"], [6, "0 1 2 3 4 5 6 7"], [7, "6 7 8"], [12, "11 12 13"]];
    for (var i = 0; i < theirs.size(); i++) {
        Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, theirs[i][0] as Number)), theirs[i][1] as String);
    }
    rules.setPair(p, 14, 13);
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(p)), "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14");
    rules = EditMenuTests.rules(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT");
    Test.assert(rules.getGameType() == GAME_SUPER_TIE_BREAK && rules.isByTeam(p));
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(p)), "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15");
    Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, 9)), "0 1 2 3 4 5 6 7 8 9 10");
    Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, 10)), "9 10 11");
    // Tie-break only: to its length, 7 or 10.
    rules = EditMenuTests.rules(TestKit.preset(PRESET_TIE_BREAK_7), "");
    Test.assert(rules.getGameType() == GAME_SUPER_TIE_BREAK && rules.isByTeam(p));
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(p)), "0 1 2 3 4 5 6 7 8 9 10 11 12");
    Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, 6)), "0 1 2 3 4 5 6 7");
    Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, 7)), "6 7 8");
    rules = EditMenuTests.rules(TestKit.preset(PRESET_TIE_BREAK_10), "");
    Test.assertEqual(EditMenuTests.numbersText(rules.getOurChoices(p)), "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15");
    Test.assertEqual(EditMenuTests.numbersText(rules.getTheirChoices(p, 9)), "0 1 2 3 4 5 6 7 8 9 10");
    return true;
}

(:test)
function editScoreSetCountTest(logger as Logger) as Boolean {
    // Add set adds a finished set before the set in progress, Remove set takes the last one off. The
    // current set's games stay when the set in progress can have them (0-0 in the super tie-break), and
    // the points unless the game becomes another kind (a regular game, a tie-break, the super
    // tie-break), which then starts at 0-0. Changing the games does the same to the points.
    var rules = EditMenuTests.rules(new MatchConfig(), "UUT uut");
    Test.assertEqual(EditMenuTests.draft(rules), "| 2-1 2-1");
    Test.assert(rules.canAddSet());
    rules.setSet(0, rules.getSetChoices(0)[4]);
    Test.assertEqual(EditMenuTests.draft(rules), "6-4 | 2-1 2-1");
    Test.assert(rules.canAddSet() && rules.getSetNumber() == 2);
    rules.removeSet();
    Test.assertEqual(EditMenuTests.draft(rules), "| 2-1 2-1");
    var g = EditScoreRules.ITEM_GAMES;
    var p = EditScoreRules.ITEM_POINTS;
    rules.setPair(g, 3, 1);
    Test.assertEqual(EditMenuTests.draft(rules), "| 3-1 2-1");
    rules.setPair(g, 6, 6);
    Test.assertEqual(EditMenuTests.draft(rules), "| 6-6 0-0");
    rules.setPair(p, 3, 2);
    rules.setSet(0, rules.getSetChoices(0)[0]);
    Test.assert(rules.getGameType() == GAME_TIE_BREAK);
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 | 6-6 3-2");
    rules.setPair(g, 6, 5);
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 | 6-5 0-0");
    // Best of 3 with a super tie-break: the second set added, the third is the super tie-break.
    rules = EditMenuTests.rules(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU UTU uu");
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 | 2-1 2-0");
    rules.setSet(1, rules.getSetChoices(1)[0]);
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 0-6 | 0-0 0-0");
    Test.assert(rules.getGameType() == GAME_SUPER_TIE_BREAK && !rules.canAddSet());
    rules.setPair(p, 5, 3);
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 0-6 | 0-0 5-3");
    rules.removeSet();
    Test.assertEqual(EditMenuTests.draft(rules), "6-0 | 0-0 0-0");
    Test.assert(rules.getGameType() == GAME_REGULAR);
    // Best of 3: no third finished set, which would win the match.
    rules = EditMenuTests.rules(new MatchConfig(), "UUUUUU TTTTTT");
    Test.assert(!rules.canAddSet());
    return true;
}

(:test)
function editScoreListsStayPossibleTest(logger as Logger) as Boolean {
    // Random walks through the menu, for each of the random tests' formats and from two states (a new
    // match, and a few games and points in, or a few points in Tie-break only): whatever is picked, the draft stays a score an edit
    // accepts, or the match's own, as ScoreEdit.canApply() and TestKit.possibleEdit() (written apart
    // from it) both say; every list offers something; Apply then logs it, and undo gives back the
    // state before.
    var formats = TestKit.formats();
    var rolls = [11];
    for (var f = 0; f < formats.size(); f++) {
        var config = formats[f];
        // Tie-break only is one game: a few points in.
        var starts = ["", config.isTieBreakOnly() ? "uut ut" : "UTU ut"];
        for (var s = 0; s < starts.size(); s++) {
            var rig = new TestKit.Rig(config, TestKit.answer(config, f), false);
            rig.play(starts[s]);
            var state = rig.getState();
            var rules = new EditScoreRules(rig.match);
            for (var step = 0; step < 30; step++) {
                var picked = EditMenuTests.randomPick(rules, rolls);
                var edit = rules.getEdit();
                var message = "format " + f + ", " + starts[s] + ", step " + step + " (" + picked + "): " + edit;
                Test.assertMessage(edit.canApply(config, state) || edit.isScoreOf(state), message);
                Test.assertMessage(TestKit.possibleEdit(config, state, edit) || TestKit.sameScore(state, edit), message + " (TestKit)");
            }
            var before = state.copy();
            if (!rules.getEdit().isScoreOf(state)) {
                Test.assert(rules.apply(TestKit.MENU_TIME) && rig.getState().eventCount == before.eventCount + 1);
                Test.assertEqual(rig.input.key(WatchUi.KEY_ESC, 0), INPUT_UNDO);
                TestKit.assertSameState(rig.getState(), before, "format " + f + ": undo");
            }
        }
    }
    return true;
}

(:test)
function editScoreApplyTest(logger as Logger) as Boolean {
    // A match the watch joined late: 6-4, then 2-1 and 30-15 in the second set. Add set
    // 6-4, the games 2-1, the points 30-15, Apply: one EDIT_SCORE event (207: one finished set), the
    // score screen's score and the summary's set table follow it, and the saved session has the score
    // string, the sets and the games. BACK on the score screen undoes it with "Undone: score edit" and
    // gives back the state before exactly. Nothing is logged until Apply (BACK from the menu drops the
    // draft), and Apply on the score as it stands logs nothing: it would change nothing.
    var rig = new TestKit.Rig(new MatchConfig(), "Me", false);
    var before = rig.getState().copy();
    var rules = new EditScoreRules(rig.match);
    Test.assert(!rules.apply(TestKit.MENU_TIME) && rig.getState().eventCount == before.eventCount);
    var sets = rules.getSetChoices(0);
    Test.assertEqual(EditMenuTests.setText(sets[4]), "6-4");
    rules.setSet(0, sets[4]);
    var g = EditScoreRules.ITEM_GAMES;
    Test.assert(rules.getOurChoices(g).indexOf(2) == 2 && rules.getTheirChoices(g, 2).indexOf(1) == 1);
    rules.setPair(g, 2, 1);
    var points = rules.getPointsChoices();
    Test.assertEqual(EditMenuTests.pairsText([points[7]]), "2-1");
    rules.setPair(EditScoreRules.ITEM_POINTS, points[7][0], points[7][1]);
    Test.assertEqual(EditMenuTests.draft(rules), "6-4 | 2-1 2-1");
    TestKit.assertSameState(rig.getState(), before, "the draft logs nothing");
    // BACK on the edit menu: the draft is dropped; the next menu starts from the match's score.
    Test.assertEqual(EditMenuTests.draft(new EditScoreRules(rig.match)), "| 0-0 0-0");
    Test.assert(rules.apply(TestKit.MENU_TIME));
    var state = rig.getState();
    Test.assertEqual(TestKit.sets(state), "6-4 | 2-1 30-15");
    Test.assertEqual(state.getScoreText(), "6-4 2-1*");
    var model = new ScoreModel(rig.engine.getConfig(), state, true);
    Test.assert(model.points[TEAM_US] == 30 && model.points[TEAM_THEM] == 15 && model.games[TEAM_US] == 2 && model.games[TEAM_THEM] == 1);
    Test.assert(model.setsWon[TEAM_US] == 1 && model.setsWon[TEAM_THEM] == 0 && model.captionNumber == 2);
    rig.assertUndone(before, 207, Rez.Strings.UndoneScoreEdit, "edit");
    Test.assert(ScoreInput.undoneString(EVENT_EDIT_SCORE) == Rez.Strings.UndoneScoreEdit);
    // Applied again, ended and saved.
    Test.assert(rules.apply(TestKit.MENU_TIME) && rig.rules.endMatch(TestKit.MENU_TIME));
    var rows = HistoryRecord.rowsOf(rig.getState());
    Test.assert(rows.size() == 2 && rows[0].setNumber == 1 && rows[0].winner == TEAM_US && rows[0].score[0] == 6 && rows[0].score[1] == 4);
    Test.assert(rows[1].setNumber == 2 && rows[1].winner == null && rows[1].score[0] == 2 && rows[1].score[1] == 1);
    Test.assert(rig.session.pause() && rig.rules.save());
    var values = rig.recorder.sessionValues as SessionValues;
    Test.assertEqual(values.score, "6-4 2-1*");
    Test.assert(values.result == (RESULT_WIN as Number) && values.sets[0] == 1 && values.sets[1] == 0);
    Test.assert(values.games[0] == 8 && values.games[1] == 5 && values.points[0] == 0 && values.points[1] == 0);
    // Once the match is over, nothing: the match menu has no Edit score then.
    rig = new TestKit.Rig(new MatchConfig(), "", false);
    rules = new EditScoreRules(rig.match);
    rules.setPair(g, 1, 0);
    Test.assert(rig.rules.endMatch(TestKit.MENU_TIME) && !rules.apply(TestKit.MENU_TIME));
    return true;
}

(:test)
function editScoreTextTest(logger as Logger) as Boolean {
    // What the menu and its lists show: scores our side first; a regular game's points as the screen
    // shows them (AD in the watch's language), with the deuce its banner names under the entry (Deuce
    // n with Star and Silver, the deciding point, none with Advantage); a tie-break's as numbers. Item
    // labels: Set n, Game / Tie-break / Super tie-break, Add set, Remove set n, Apply.
    var ad = WatchUi.loadResource(Rez.Strings.PointsAd) as String;
    var regular = [[[0, 0], "0-0"], [[2, 1], "30-15"], [[3, 0], "40-0"], [[3, 3], "40-40"], [[4, 3], ad + "-40"], [[3, 4], "40-" + ad],
        [[6, 5], ad + "-40"]];
    for (var i = 0; i < regular.size(); i++) {
        Test.assertEqual(EditScoreText.points(regular[i][0] as Array<Number>, GAME_REGULAR), regular[i][1] as String);
    }
    Test.assertEqual(EditScoreText.points([4, 3], GAME_TIE_BREAK), "4-3");
    Test.assertEqual(EditScoreText.points([12, 10], GAME_SUPER_TIE_BREAK), "12-10");
    var deuce = WatchUi.loadResource(Rez.Strings.EditDeuce) as String;
    var star = WatchUi.loadResource(Rez.Strings.DeuceStar) as String;
    var names = [[[3, 3], DEUCE_STAR, Lang.format(deuce, [1])], [[4, 3], DEUCE_STAR, Lang.format(deuce, [1])],
        [[5, 4], DEUCE_STAR, Lang.format(deuce, [2])], [[5, 5], DEUCE_STAR, star], [[2, 1], DEUCE_STAR, null],
        [[3, 3], DEUCE_ADVANTAGE, null], [[4, 3], DEUCE_ADVANTAGE, null],
        [[3, 3], DEUCE_GOLDEN, WatchUi.loadResource(Rez.Strings.DeuceGolden) as String],
        [[4, 3], DEUCE_SILVER, Lang.format(deuce, [1])], [[4, 4], DEUCE_SILVER, WatchUi.loadResource(Rez.Strings.DeuceSilver) as String]];
    for (var i = 0; i < names.size(); i++) {
        var name = EditScoreText.deuceName(names[i][0] as Array<Number>, names[i][1] as DeuceMode);
        Test.assertMessage(name == null ? names[i][2] == null : name.equals(names[i][2]), "deuce name " + i + ": " + name);
    }
    var rules = EditMenuTests.rules(new MatchConfig(), "UUUUUU UUT uuu ttt u");
    var set = WatchUi.loadResource(Rez.Strings.EditSet) as String;
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_SET), Lang.format(set, [1]));
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_SET) as String, "6-0");
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_GAMES), Lang.format(set, [2]));
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_GAMES) as String, "2-1");
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_POINTS), WatchUi.loadResource(Rez.Strings.EditGame) as String);
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_POINTS) as String,
        ad + "-40" + FormatText.SEPARATOR + Lang.format(deuce, [1]));
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_REMOVE_SET),
        Lang.format(WatchUi.loadResource(Rez.Strings.EditRemoveSet) as String, [1]));
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_ADD_SET), WatchUi.loadResource(Rez.Strings.EditAddSet) as String);
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_APPLY), WatchUi.loadResource(Rez.Strings.EditApply) as String);
    Test.assert(EditScoreText.value(rules, EditScoreRules.ITEM_APPLY) == null
        && EditScoreText.value(rules, EditScoreRules.ITEM_ADD_SET) == null);
    rules = EditMenuTests.rules(new MatchConfig(), "UTUTUTUTUTUT uut");
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_POINTS), WatchUi.loadResource(Rez.Strings.MenuTieBreak) as String);
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_POINTS) as String, "2-1");
    rules = EditMenuTests.rules(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT u");
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_POINTS), WatchUi.loadResource(Rez.Strings.EditSuperTieBreak) as String);
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_POINTS) as String, "1-0");
    // Tie-break only is a tie-break, not a super tie-break.
    rules = EditMenuTests.rules(TestKit.preset(PRESET_TIE_BREAK_10), "uut");
    Test.assertEqual(EditScoreText.label(rules, EditScoreRules.ITEM_POINTS), WatchUi.loadResource(Rez.Strings.MenuTieBreak) as String);
    Test.assertEqual(EditScoreText.value(rules, EditScoreRules.ITEM_POINTS) as String, "2-1");
    if (System.getDeviceSettings().systemLanguage == System.LANGUAGE_ENG) {
        Test.assertEqual(Lang.format(deuce, [2]), "Deuce 2");
        Test.assertEqual(WatchUi.loadResource(Rez.Strings.UndoneScoreEdit) as String, "Undone: score edit");
    }
    return true;
}

(:test)
module EditMenuTests {

    // The draft after the moves, from a new match in config with serve tracking off.
    function rules(config as MatchConfig, moves as String) as EditScoreRules {
        var rig = new TestKit.Rig(config, "", false);
        rig.play(moves);
        return new EditScoreRules(rig.match);
    }

    // The draft as TestKit.edit() reads an edit, with the game's point counts.
    function draft(rules as EditScoreRules) as String {
        var text = "";
        for (var i = 0; i < rules.sets.size(); i++) {
            text += setText(rules.sets[i]) + " ";
        }
        return text + "| " + TestKit.pair(rules.games) + " " + TestKit.pair(rules.points);
    }

    // As TestKit.sets() writes a set: "6-4", "7-6(7-5)", "3-1EU", "S10-8".
    function setText(set as SetScore) as String {
        var points = set.tieBreakPoints;
        if (set.superTieBreak) {
            return "S" + TestKit.pair(points as Array<Number>);
        }
        return TestKit.pair(set.games) + (points == null ? "" : "(" + TestKit.pair(points) + ")")
            + (set.endedEarly ? (set.winner == TEAM_US ? "EU" : "ET") : "");
    }

    function setsText(sets as Array<SetScore>) as String {
        var text = "";
        for (var i = 0; i < sets.size(); i++) {
            text += (i == 0 ? "" : " ") + setText(sets[i]);
        }
        return text;
    }

    function numbersText(values as Array<Number>) as String {
        var text = "";
        for (var i = 0; i < values.size(); i++) {
            text += (i == 0 ? "" : " ") + values[i];
        }
        return text;
    }

    function pairsText(values as Array<Array<Number> >) as String {
        var text = "";
        for (var i = 0; i < values.size(); i++) {
            text += (i == 0 ? "" : " ") + TestKit.pair(values[i]);
        }
        return text;
    }

    // Picks a random item of the menu but Apply and a random value from its list, as the menu would,
    // and says what it picked.
    function randomPick(rules as EditScoreRules, rolls as Array<Number>) as String {
        var items = rules.getItems();
        var item = items[TestKit.roll(rolls, items.size() - 1)];
        Test.assert(item != EditScoreRules.ITEM_APPLY);
        if (item == EditScoreRules.ITEM_REMOVE_SET) {
            rules.removeSet();
            return "remove";
        } else if (item == EditScoreRules.ITEM_ADD_SET || item >= EditScoreRules.ITEM_SET) {
            var index = item == EditScoreRules.ITEM_ADD_SET ? rules.sets.size() : item - EditScoreRules.ITEM_SET;
            var sets = rules.getSetChoices(index);
            Test.assertMessage(sets.size() > 0, "no set to pick for " + index);
            var set = sets[TestKit.roll(rolls, sets.size())];
            rules.setSet(index, set);
            return "set " + index + " " + setText(set);
        } else if (rules.isByTeam(item)) {
            var ours = rules.getOurChoices(item);
            Test.assertMessage(ours.size() > 0, "none of ours for " + item);
            var us = ours[TestKit.roll(rolls, ours.size())];
            var theirs = rules.getTheirChoices(item, us);
            Test.assertMessage(theirs.size() > 0, "none of theirs for " + item + " with " + us);
            var them = theirs[TestKit.roll(rolls, theirs.size())];
            rules.setPair(item, us, them);
            return "item " + item + " " + us + "-" + them;
        }
        var points = rules.getPointsChoices();
        Test.assert(points.size() > 0);
        var pair = points[TestKit.roll(rolls, points.size())];
        rules.setPair(item, pair[TEAM_US], pair[TEAM_THEM]);
        return "points " + TestKit.pair(pair);
    }
}

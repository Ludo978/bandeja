import Toybox.Lang;
import Toybox.Test;

// The serve questions: "Who serves first? Me / Partner / Opponents" and, after Opponents,
// "Our first server? Me / Partner"; in singles "Me / Opponent" only. Asked when the match has started,
// before the first point, only with serve tracking on. The answers are logged through the match holder
// as FIX_SERVING_TEAM, then SWAP_OUR_SERVER for Partner, so the engine's server and its
// rotation over the first games follow them. BACK on the second question goes back to the first; BACK
// on the first starts with the server unknown.
//
// The log is written as its event codes: 103 FIX_SERVING_TEAM Us, 203 FIX_SERVING_TEAM Them, 2
// SWAP_OUR_SERVER. The rotation is who serves each of the first games, as TestKit.server() writes it.

(:test)
function serveQuestionsAnswersTest(logger as Logger) as Boolean {
    // Me: we serve, I do; Partner: my partner does; Opponents, then Me or Partner: they serve, then our
    // first game goes to the one named. The serving team alternates every game and our players too. In
    // singles one question, Me / Opponent: our only player serves our games.
    ServeQuestionsTests.check(true, [ANSWER_ME], "103", TEAM_US, PLAYER_ME, "ME THEM PARTNER THEM");
    ServeQuestionsTests.check(true, [ANSWER_PARTNER], "103 2", TEAM_US, PLAYER_PARTNER, "PARTNER THEM ME THEM");
    ServeQuestionsTests.check(true, [ANSWER_OPPONENTS, ANSWER_ME], "203", TEAM_THEM, null, "THEM ME THEM PARTNER");
    ServeQuestionsTests.check(true, [ANSWER_OPPONENTS, ANSWER_PARTNER], "203 2", TEAM_THEM, null, "THEM PARTNER THEM ME");
    ServeQuestionsTests.check(false, [ANSWER_ME], "103", TEAM_US, PLAYER_ME, "ME THEM ME THEM");
    ServeQuestionsTests.check(false, [ANSWER_OPPONENTS], "203", TEAM_THEM, null, "THEM ME THEM ME");
    return true;
}

(:test)
function serveQuestionsMenusTest(logger as Logger) as Boolean {
    // Doubles: the first question offers Me, Partner, Opponents and opens on Me; after Opponents, the
    // second offers Me, Partner and opens on Me. Singles: Me, Opponent.
    var questions = new ServeQuestions(ServeQuestionsTests.newMatch(true), true);
    Test.assert(questions.getQuestion() == QUESTION_FIRST && questions.getTitle() == Rez.Strings.ServeFirst);
    ServeQuestionsTests.assertAnswers(questions, [ANSWER_ME, ANSWER_PARTNER, ANSWER_OPPONENTS],
        [Rez.Strings.ServeMe, Rez.Strings.ServePartner, Rez.Strings.ServeOpponents]);
    Test.assertEqual(questions.getFocus(), ANSWER_ME);
    Test.assert(questions.pick(ANSWER_OPPONENTS, ServeQuestionsTests.TIME) == QUESTION_SECOND && questions.getTitle() == Rez.Strings.ServeFirstUs);
    ServeQuestionsTests.assertAnswers(questions, [ANSWER_ME, ANSWER_PARTNER], [Rez.Strings.ServeMe, Rez.Strings.ServePartner]);
    Test.assertEqual(questions.getFocus(), ANSWER_ME);
    questions = new ServeQuestions(ServeQuestionsTests.newMatch(false), true);
    Test.assertEqual(questions.getTitle(), Rez.Strings.ServeFirst);
    ServeQuestionsTests.assertAnswers(questions, [ANSWER_ME, ANSWER_OPPONENTS], [Rez.Strings.ServeMe, Rez.Strings.ServeOpponent]);
    return true;
}

(:test)
function serveQuestionsBackTest(logger as Logger) as Boolean {
    // BACK on the first question: the match starts with the server unknown and nothing logged, nothing
    // more to ask; Fix serving team (the menus) starts the rotation later. BACK on the second
    // question: back to the first, on Opponents, with nothing logged; an answer there then counts as
    // usual; BACK on both: the server unknown. With serve tracking off nothing is asked or logged.
    var match = ServeQuestionsTests.newMatch(true);
    var questions = new ServeQuestions(match, true);
    Test.assertEqual(questions.back(), QUESTION_NONE);
    Test.assert(questions.pick(ANSWER_ME, ServeQuestionsTests.TIME) == QUESTION_NONE && questions.back() == QUESTION_NONE);
    ServeQuestionsTests.assertServer(match, "", null, null);
    Test.assert(match.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, ServeQuestionsTests.TIME, TEAM_US)));
    Test.assertEqual(ServeQuestionsTests.rotation(match, 3), "ME THEM PARTNER");
    match = ServeQuestionsTests.newMatch(true);
    questions = new ServeQuestions(match, true);
    questions.pick(ANSWER_OPPONENTS, ServeQuestionsTests.TIME);
    Test.assert(questions.back() == QUESTION_FIRST && questions.getTitle() == Rez.Strings.ServeFirst);
    Test.assert(questions.getFocus() == ANSWER_OPPONENTS && match.getState().eventCount == 0);
    Test.assertEqual(questions.pick(ANSWER_PARTNER, ServeQuestionsTests.TIME), QUESTION_NONE);
    ServeQuestionsTests.assertServer(match, "103 2", TEAM_US, PLAYER_PARTNER);
    match = ServeQuestionsTests.newMatch(true);
    questions = new ServeQuestions(match, true);
    questions.pick(ANSWER_OPPONENTS, ServeQuestionsTests.TIME);
    questions.back();
    Test.assertEqual(questions.back(), QUESTION_NONE);
    Test.assertEqual(ServeQuestionsTests.rotation(match, 3), "? ? ?");
    match = ServeQuestionsTests.newMatch(true);
    questions = new ServeQuestions(match, false);
    Test.assert(questions.getQuestion() == QUESTION_NONE && questions.pick(ANSWER_ME, ServeQuestionsTests.TIME) == QUESTION_NONE);
    ServeQuestionsTests.assertServer(match, "", null, null);
    return true;
}

(:test)
function serveQuestionsUndoTest(logger as Logger) as Boolean {
    // The answers are events like any other: undo removes them, the last first, back to an
    // unknown server before the first point. Asked again, the same answers log the same events, or with
    // part of them still logged only the rest; another answer logs what makes it true.
    var match = ServeQuestionsTests.newMatch(true);
    new ServeQuestions(match, true).pick(ANSWER_PARTNER, ServeQuestionsTests.TIME);
    Test.assertEqual((match.undo() as MatchEvent).type, EVENT_SWAP_OUR_SERVER);
    ServeQuestionsTests.assertServer(match, "103", TEAM_US, PLAYER_ME);
    Test.assertEqual((match.undo() as MatchEvent).type, EVENT_FIX_SERVING_TEAM);
    ServeQuestionsTests.assertServer(match, "", null, null);
    for (var i = 0; i < 2; i++) {
        var questions = new ServeQuestions(match, true);
        questions.pick(ANSWER_OPPONENTS, ServeQuestionsTests.TIME);
        questions.pick(ANSWER_PARTNER, ServeQuestionsTests.TIME);
        ServeQuestionsTests.assertServer(match, "203 2", TEAM_THEM, null);
        if (i == 0) {
            match.undo();
        }
    }
    new ServeQuestions(match, true).pick(ANSWER_ME, ServeQuestionsTests.TIME);
    ServeQuestionsTests.assertServer(match, "203 2 103 2", TEAM_US, PLAYER_ME);
    return true;
}

(:test)
module ServeQuestionsTests {

    // When the answers are picked: a little after the match start.
    const TIME = TestKit.T0 + 5;

    function newMatch(doubles as Boolean) as CurrentMatch {
        var config = new MatchConfig();
        config.doubles = doubles;
        var rig = new TestKit.Rig(config, "", false);
        return rig.match;
    }

    // Asks the questions with serve tracking on and picks the answers, each but the last leading to the
    // second question, then checks the log, the server and the rotation over the first games.
    function check(doubles as Boolean, answers as Array<ServeAnswer>, codes as String, team as Team, player as Player?,
            expected as String) as Void {
        var match = newMatch(doubles);
        var questions = new ServeQuestions(match, true);
        for (var i = 0; i < answers.size(); i++) {
            var next = questions.pick(answers[i], TIME + i);
            Test.assert(next == (i < answers.size() - 1 ? QUESTION_SECOND : QUESTION_NONE) && questions.getQuestion() == next);
        }
        assertServer(match, codes, team, player);
        Test.assertEqual(rotation(match, 4), expected);
    }

    // The log's codes, getServingTeam() and getServingPlayer().
    function assertServer(match as CurrentMatch, codes as String, team as Team?, player as Player?) as Void {
        var log = match.engine.getLog();
        var actual = "";
        for (var i = 0; i < log.size(); i += 2) {
            actual += (i == 0 ? "" : " ") + log[i];
        }
        var state = match.getState();
        Test.assertMessage(actual.equals(codes) && state.getServingTeam() == team && state.getServingPlayer() == player,
            "log " + actual + ", expected " + codes);
    }

    function assertAnswers(questions as ServeQuestions, answers as Array<ServeAnswer>, labels as Array<ResourceId>) as Void {
        Test.assertEqual(questions.getAnswers().toString(), answers.toString());
        for (var i = 0; i < answers.size(); i++) {
            Test.assertEqual(questions.getLabel(answers[i]), labels[i]);
        }
    }

    // Who serves each of the next games, each won by us in four points.
    function rotation(match as CurrentMatch, games as Number) as String {
        var text = "";
        for (var i = 0; i < games; i++) {
            text += (i == 0 ? "" : " ") + TestKit.server(match.getState());
            TestKit.playThrough(match.engine, match, "U");
        }
        return text;
    }
}

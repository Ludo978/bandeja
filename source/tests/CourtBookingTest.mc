import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The timed match: the court booking's end time, picked at match setup in 5-minute
// steps, pre-filled with now + 90 minutes to the nearest half hour, the next occurrence of that clock
// time at most 4 hours ahead; the time left is the end time minus the watch's current time, whatever
// the warm-up, the pauses or a late START; the warnings at T-10 and T-5 and the TIME alert,
// each once, also across a skipped tick, an undo and a resume; the TIME LEFT and TIME banners, the
// lowest of the net banners; Finish (the early end result) and Keep playing in the pause
// menu once the time is up. The court time's vibration and tones are in FeedbackPlanTest.
//
// Clock times are seconds since midnight (CourtTests.clock()), the end time and now are epoch seconds
// (TestKit.T0 is the watch's now).

(:test)
function courtPrefillTest(logger as Logger) as Boolean {
    // Now + 90 minutes, to the nearest half hour (bookings end on the hour or the half hour), half way
    // rounding up, past midnight too; as minutes since midnight, always one of the times offered.
    var cases = [[19, 30, 0, 21 * 60], [19, 44, 59, 21 * 60], [19, 45, 0, 21 * 60 + 30], [19, 15, 0, 21 * 60], [23, 10, 0, 30],
        [22, 20, 0, 0]] as Array<Array<Number> >;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        Test.assertEqual(CourtBooking.prefill(CourtTests.clock(c[0], c[1], c[2])), c[3]);
    }
    for (var seconds = 0; seconds < CourtBooking.DAY; seconds += 13 * 60 + 7) {
        Test.assertMessage(CourtBooking.choices(seconds).indexOf(CourtBooking.prefill(seconds)) >= 0, "at " + seconds);
    }
    return true;
}

(:test)
function courtChoicesTest(logger as Logger) as Boolean {
    // The clock times offered: every 5 minutes after now (from the next step a few seconds past one),
    // up to 4 hours ahead, so 48 of them, across midnight too. Shown as the watch shows the time: 24 h
    // with two-digit hours, 12 h without AM / PM (never in doubt within 4 hours).
    var choices = CourtBooking.choices(CourtTests.clock(23, 10, 0));
    Test.assert(choices.size() == 48 && choices[0] == 23 * 60 + 15 && choices[9] == 0 && choices[47] == 3 * 60 + 10);
    for (var i = 1; i < choices.size(); i++) {
        Test.assertEqual((choices[i] - choices[i - 1] + 24 * 60) % (24 * 60), 5);
    }
    var later = CourtBooking.choices(CourtTests.clock(19, 2, 30));
    Test.assert(later.size() == 48 && later[0] == 19 * 60 + 5 && later[47] == 23 * 60);
    var labels = CourtMenu.labels(choices, true);
    Test.assert(labels[0].equals("23:15") && labels[9].equals("00:00") && labels[47].equals("03:10"));
    labels = CourtMenu.labels(choices, false);
    Test.assert(labels[0].equals("11:15") && labels[9].equals("12:00") && labels[47].equals("3:10"));
    return true;
}

(:test)
function courtEndTimeTest(logger as Logger) as Boolean {
    // The end time is the next occurrence of the clock time picked, at most 4 hours ahead: 00:30 picked
    // at 23:10 is in 80 minutes, the seconds counting. A time further ahead than that is behind us (a
    // booking already over), never tomorrow's. Every time offered is ahead, by 4 hours at most.
    var now = TestKit.T0;
    var at = CourtTests.clock(23, 10, 0);
    Test.assertEqual(CourtBooking.endFor(30, now, at), now + 80 * 60);
    Test.assertEqual(CourtBooking.endFor(3 * 60 + 10, now, at), now + 4 * 3600);
    Test.assertEqual(CourtBooking.endFor(23 * 60 + 10, now, at), now);
    Test.assertEqual(CourtBooking.endFor(23 * 60, now, at), now - 10 * 60);
    Test.assertEqual(CourtBooking.endFor(3 * 60 + 15, now, at), now + 4 * 3600 + 5 * 60 - CourtBooking.DAY);
    Test.assertEqual(CourtBooking.endFor(30, now, CourtTests.clock(23, 10, 30)), now + 79 * 60 + 30);
    var choices = CourtBooking.choices(at);
    for (var i = 0; i < choices.size(); i++) {
        var ahead = CourtBooking.endFor(choices[i], now, at) - now;
        Test.assertMessage(ahead > 0 && ahead <= CourtBooking.WINDOW, choices[i] + ": " + ahead);
    }
    return true;
}

(:test)
function courtTimeLeftTest(logger as Logger) as Boolean {
    // The court time left from the booking end time. A booking ending after midnight: 00:30
    // picked at 23:10; through midnight, then the end time and after it, never below 0.
    var setup = TestKit.T0;
    var booking = new CourtBooking(CourtBooking.endFor(30, setup, CourtTests.clock(23, 10, 0)), COURT_NONE);
    Test.assertEqual(TimeText.countdown(booking.getLeft(setup)), "80:00");
    Test.assertEqual(TimeText.countdown(booking.getLeft(setup + 50 * 60)), "30:00");
    Test.assert(!booking.isTimeUp(setup + 80 * 60 - 1) && booking.isTimeUp(setup + 80 * 60));
    Test.assert(booking.getLeft(setup + 80 * 60) == 0 && booking.getLeft(setup + 90 * 60) == 0);

    // START pressed after the booking began: the end time picked at setup counts, not the match start;
    // neither the warm-up nor a pause changes the time left. Without a booking the match isn't timed.
    var test = new TestKit.Flow(false, true);
    var court = new CourtBooking(setup + 90 * 60, COURT_NONE);
    test.flow.court = court;
    Test.assertEqual(test.flow.start(setup + 10 * 60), STEP_WARM_UP);
    Test.assertEqual(TimeText.countdown(court.getLeft(setup + 10 * 60)), "80:00");
    Test.assertEqual(test.flow.start(setup + 25 * 60), STEP_MATCH);
    var match = test.flow.getMatch() as CurrentMatch;
    Test.assert(match.court == court && match.start == setup + 25 * 60);
    Test.assertEqual(TimeText.countdown(court.getLeft(setup + 25 * 60)), "65:00");
    Test.assert(test.session.pause());
    Test.assertEqual(TimeText.countdown(court.getLeft(setup + 35 * 60)), "55:00");
    Test.assert(test.session.resume());
    Test.assertEqual(TimeText.countdown(court.getLeft(setup + 4568)), "13:52");
    test = new TestKit.Flow(false, false);
    test.flow.start(setup);
    Test.assert((test.flow.getMatch() as CurrentMatch).court == null);
    return true;
}

(:test)
function courtAlertsTest(logger as Logger) as Boolean {
    // T-10, T-5 and TIME, each once, when its time comes. A tick that skips over a threshold (a menu
    // over the score screen, a late tick): only the last one due, once; the one skipped never comes
    // later. After Keep playing, no more alerts. The stored values are never renumbered.
    var end = TestKit.T0 + 3600;
    CourtTests.checkAlerts(new CourtBooking(end, COURT_NONE), end, [[-601, COURT_NONE], [-600, COURT_TEN], [-600, COURT_NONE],
        [-301, COURT_NONE], [-300, COURT_FIVE], [-299, COURT_NONE], [-1, COURT_NONE], [0, COURT_TIME], [0, COURT_NONE],
        [3600, COURT_NONE]], "in time");
    CourtTests.checkAlerts(new CourtBooking(end, COURT_NONE), end, [[-700, COURT_NONE], [-250, COURT_FIVE], [-200, COURT_NONE],
        [5, COURT_TIME], [6, COURT_NONE]], "skipped");
    CourtTests.checkAlerts(new CourtBooking(end, COURT_NONE), end, [[-4000, COURT_NONE], [120, COURT_TIME], [121, COURT_NONE]],
        "past the end at once");
    var booking = new CourtBooking(end, COURT_TIME);
    booking.keepPlaying();
    Test.assertEqual(booking.alert, COURT_KEEP_PLAYING);
    CourtTests.checkAlerts(booking, end, [[0, COURT_NONE], [3600, COURT_NONE]], "keep playing");
    Test.assert((COURT_NONE as Number) == 0 && (COURT_TEN as Number) == 1 && (COURT_FIVE as Number) == 2
        && (COURT_TIME as Number) == 3 && (COURT_KEEP_PLAYING as Number) == 4);
    return true;
}

(:test)
function courtBannerTest(logger as Logger) as Boolean {
    // TIME LEFT in the last 5 minutes, then TIME until Finish or Keep playing, then nothing.
    var end = TestKit.T0 + 3600;
    var booking = new CourtBooking(end, COURT_NONE);
    Test.assert(booking.getBanner(end - 301) == BANNER_NONE && booking.getBanner(end - 300) == BANNER_TIME_LEFT);
    Test.assert(booking.getBanner(end - 1) == BANNER_TIME_LEFT && !booking.offersFinish(end - 1));
    Test.assert(booking.getBanner(end + 600) == BANNER_TIME && booking.offersFinish(end) && booking.take(end + 600) == COURT_TIME);
    booking.keepPlaying();
    Test.assert(booking.getBanner(end + 601) == BANNER_NONE && !booking.offersFinish(end + 601));

    // On the score screen it's the lowest banner: TIME LEFT, its seconds as its number, outlined
    // yellow; TIME solid yellow. setCourt() says when the banner changed.
    var engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "u");
    var model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    booking = new CourtBooking(end, COURT_NONE);
    Test.assert(!model.setCourt(null, end) && !model.setCourt(booking, end - 301) && model.banner == BANNER_NONE);
    Test.assert(model.setCourt(booking, end - 300));
    CourtTests.assertBanner(model, BANNER_TIME_LEFT, 300, BANNER_STYLE_PRESSURE, "5:00 left");
    Test.assert(!model.setCourt(booking, end - 300) && model.setCourt(booking, end - 299));
    CourtTests.assertBanner(model, BANNER_TIME_LEFT, 299, BANNER_STYLE_PRESSURE, "4:59 left");
    Test.assert(model.setCourt(booking, end));
    CourtTests.assertBanner(model, BANNER_TIME, 0, BANNER_STYLE_DECIDING, "time");
    booking.keepPlaying();
    Test.assert(model.setCourt(booking, end + 1));
    CourtTests.assertBanner(model, BANNER_NONE, 0, BANNER_STYLE_INFO, "keep playing");

    // Any banner of the score comes first: DEUCE 1 stays. Once the match is over, none.
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "uuuttt");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assert(!model.setCourt(new CourtBooking(end, COURT_TIME), end + 60) && model.banner == BANNER_DEUCE);
    engine = new ScoringEngine(new MatchConfig());
    TestKit.play(engine, "UUUUUU UUUUUU");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assert(!model.setCourt(new CourtBooking(end, COURT_NONE), end + 60) && model.banner == BANNER_NONE);

    // Their strings, and the toast each alert brings.
    Test.assert(ScoreModel.bannerString(BANNER_TIME_LEFT) == Rez.Strings.BannerTimeLeft && ScoreModel.bannerString(BANNER_TIME) == Rez.Strings.BannerTime);
    Test.assert(ScoreModel.courtAlertString(COURT_TEN) == Rez.Strings.CourtTen && ScoreModel.courtAlertString(COURT_FIVE) == Rez.Strings.CourtFive);
    Test.assert(ScoreModel.courtAlertString(COURT_TIME) == Rez.Strings.CourtTime && ScoreModel.courtAlertString(COURT_NONE) == null
        && ScoreModel.courtAlertString(COURT_KEEP_PLAYING) == null);
    return true;
}

(:test)
function courtUndoTest(logger as Logger) as Boolean {
    // The end time and the alerts given aren't events: undo changes neither, so nothing is given twice.
    // An alert given leaves the match to be written, so a resume doesn't give it again; none while the
    // match is over (the summary), so undoing back into the match gives it then. Keep playing is
    // written too.
    var keys = TestKit.matchKeys();
    var saved = TestKit.backup(keys);
    try {
        var end = TestKit.T0 + 3600;
        var rig = CourtTests.timed(new MatchConfig(), "UU uu", end);
        rig.match.save();
        Test.assert(rig.match.takeCourtAlert(end - 600) == COURT_TEN && rig.match.isUnsaved());
        rig.match.save();
        rig.play("<<");
        Test.assert(rig.match.takeCourtAlert(end - 590) == COURT_NONE && (rig.match.court as CourtBooking).end == end);
        rig = CourtTests.timed(TestKit.preset(PRESET_ONE_SET), "UUUUUU", end);
        Test.assert(rig.getState().matchOver && rig.match.takeCourtAlert(end - 300) == COURT_NONE);
        rig.play("<");
        Test.assertEqual(rig.match.takeCourtAlert(end - 299), COURT_FIVE);
        rig.match.save();
        Test.assert(rig.match.takeCourtAlert(end) == COURT_TIME);
        rig.match.save();
        rig.match.keepPlaying();
        Test.assert(rig.match.isUnsaved() && (rig.match.court as CourtBooking).alert == COURT_KEEP_PLAYING);
        rig.match.save();
    } finally {
        TestKit.restore(keys, saved);
    }
    return true;
}

(:test)
function courtResumeTest(logger as Logger) as Boolean {
    // The end time and the alerts given are stored with the match: the resumed match counts down to the
    // same end, and gives no alert twice; resumed after the end time with the TIME alert given, no alert
    // again, TIME still offered; after Keep playing, nothing.
    var end = TestKit.T0 + 3600;
    var played = CourtTests.timed(new MatchConfig(), "UUT tu", end);
    Test.assertEqual(played.match.takeCourtAlert(end - 400), COURT_TEN);
    var first = new TestKit.Resumed(TestKit.storedOf(played.match));
    var resumed = first.match;
    var court = resumed.court as CourtBooking;
    Test.assert(court.end == end && court.alert == COURT_TEN && TimeText.countdown(court.getLeft(end - 400)).equals("6:40"));
    Test.assert(resumed.takeCourtAlert(end - 350) == COURT_NONE && resumed.takeCourtAlert(end - 300) == COURT_FIVE);
    var alerts = [COURT_TIME, COURT_KEEP_PLAYING];
    for (var i = 0; i < alerts.size(); i++) {
        played.match.court = new CourtBooking(end, alerts[i]);
        var again = new TestKit.Resumed(TestKit.storedOf(played.match));
        resumed = again.match;
        Test.assert(resumed.takeCourtAlert(end + 60) == COURT_NONE && (resumed.court as CourtBooking).offersFinish(end + 60) == (i == 0));
    }
    // An untimed match stays untimed; a match stored before timed matches existed (no booking keys)
    // loads untimed; a booking that can't be read leaves the match itself, untimed; an unknown alert
    // reads as none given.
    played.match.court = null;
    var untimed = new TestKit.Resumed(TestKit.storedOf(played.match));
    Test.assert(untimed.match.court == null);
    var value = MatchStore.toValue(played.engine, played.match.start, false, new CourtBooking(end, COURT_FIVE));
    Test.assert(value.hasKey("courtEnd") && ((MatchStore.fromValue(value) as StoredMatch).court as CourtBooking).alert == COURT_FIVE);
    value.remove("courtEnd");
    value.remove("courtAlert");
    Test.assert((MatchStore.fromValue(value) as StoredMatch).court == null);
    value["courtEnd"] = "21:30";
    value["courtAlert"] = 2;
    Test.assert((MatchStore.fromValue(value) as StoredMatch).court == null);
    value["courtEnd"] = end;
    value["courtAlert"] = 9;
    Test.assertEqual(((MatchStore.fromValue(value) as StoredMatch).court as CourtBooking).alert, COURT_NONE);
    return true;
}

(:test)
function courtFinishTest(logger as Logger) as Boolean {
    // Once the time is up, the pause menu offers Finish and Keep playing at the top, in place of Resume
    // and End match; the rest stays, and the match menu doesn't change. Before it, and in an untimed
    // match, the usual menu.
    var end = TestKit.MENU_TIME + 3600;
    var rig = CourtTests.timed(new MatchConfig(), "UUUUUU UUT u", end);
    var usual = [ITEM_RESUME, ITEM_END_MATCH, ITEM_SAVE, ITEM_DISCARD, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM, ITEM_DEUCE_MODE,
        ITEM_END_SET, ITEM_SETTINGS] as Array<MatchMenuItem>;
    var timeUp = [ITEM_FINISH, ITEM_KEEP_PLAYING, ITEM_SAVE, ITEM_DISCARD, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM,
        ITEM_DEUCE_MODE, ITEM_END_SET, ITEM_SETTINGS] as Array<MatchMenuItem>;
    TestKit.assertItems(rig.rules.getPauseItems(end - 1), usual, "before the end");
    TestKit.assertItems(rig.rules.getPauseItems(end), timeUp, "time up");
    TestKit.assertItems(rig.rules.getPauseItems(end + 900), timeUp, "15 min later");
    TestKit.assertItems(rig.rules.getMatchItems(), [ITEM_DATA_PAGE, ITEM_STATS_PAGE, ITEM_SWAP_SERVER, ITEM_FIX_SERVING_TEAM,
        ITEM_DEUCE_MODE, ITEM_EDIT_SCORE, ITEM_VIBRATION, ITEM_SOUNDS, ITEM_TOUCH_SCORING], "match menu");
    Test.assert(rig.rules.getLabel(ITEM_FINISH) == Rez.Strings.MenuFinish && rig.rules.getLabel(ITEM_KEEP_PLAYING) == Rez.Strings.MenuKeepPlaying);
    Test.assert(rig.rules.getValue(ITEM_FINISH) == null);
    var untimed = new TestKit.Rig(new MatchConfig(), "", false);
    TestKit.assertItems(untimed.rules.getPauseItems(end + 60), usual, "untimed");

    // Finish ends the match early: sets, then games in the unfinished set, then points, or a
    // draw; the menus of a match over; BACK on the score screen undoes it.
    var cases = [["UUUUUU UUT u", RESULT_WIN, "6-0 2-1*"], ["UUUUUU TTTTTT TU tt", RESULT_LOSS, "6-0 0-6 1-1*"],
        ["UUUUUU TTTTTT ut", RESULT_DRAW, "6-0 0-6 0-0*"]];
    for (var i = 0; i < cases.size(); i++) {
        var moves = cases[i][0] as String;
        rig = CourtTests.timed(new MatchConfig(), moves, end);
        Test.assertMessage(rig.rules.getPauseItems(end)[0] == ITEM_FINISH, moves);
        var before = rig.getState().copy();
        Test.assert(rig.rules.endMatch(end));
        Test.assertMessage(rig.getState().getResult() == cases[i][1] && rig.getState().getScoreText().equals(cases[i][2]), moves);
        TestKit.assertItems(rig.rules.getPauseItems(end), [ITEM_RESUME, ITEM_SAVE, ITEM_DISCARD, ITEM_SETTINGS], moves + ": over");
        rig.assertUndone(before, 6, Rez.Strings.UndoneEndMatch, moves + ": Finish");
        Test.assertMessage(rig.rules.getPauseItems(end)[0] == ITEM_FINISH, moves + ": undone");
    }

    // Keep playing: the timer runs again, no TIME banner, no alert, the usual menu; points still count
    // after the end time, before and after the choice.
    rig = CourtTests.timed(new MatchConfig(), "UUUUUU UUT u", end);
    var court = rig.match.court as CourtBooking;
    Test.assertEqual(rig.match.takeCourtAlert(end), COURT_TIME);
    var events = rig.getState().eventCount;
    Test.assert(rig.session.pause() && rig.rules.keepPlaying() && !rig.session.isPaused());
    Test.assert(court.alert == COURT_KEEP_PLAYING && court.getBanner(end + 60) == BANNER_NONE && rig.match.takeCourtAlert(end + 60) == COURT_NONE);
    TestKit.assertItems(rig.rules.getPauseItems(end + 60), usual, "kept playing");
    Test.assert(rig.getState().eventCount == events && !rig.getState().matchOver);
    Test.assertEqual(rig.input.key(WatchUi.KEY_DOWN, 10000), INPUT_POINT);
    return true;
}

(:test)
module CourtTests {

    // Seconds since midnight.
    function clock(hour as Number, minute as Number, second as Number) as Number {
        return hour * 3600 + minute * 60 + second;
    }

    // Takes the alert at each step's time (seconds from end) and checks the one given.
    function checkAlerts(booking as CourtBooking, end as Number, steps as Array<Array<Number> >, message as String) as Void {
        for (var i = 0; i < steps.size(); i++) {
            var alert = booking.take(end + steps[i][0]);
            Test.assertMessage(alert == steps[i][1], message + ": at " + steps[i][0] + " gave " + alert);
        }
    }

    function assertBanner(model as ScoreModel, banner as Banner, number as Number, style as BannerStyle, message as String) as Void {
        Test.assertMessage(model.banner == banner && model.bannerNumber == number && model.bannerStyle == style,
            message + ": banner " + model.banner + " " + model.bannerNumber + " " + model.bannerStyle);
    }

    // A timed match, its court time ending at end, after moves.
    function timed(config as MatchConfig, moves as String, end as Number) as TestKit.Rig {
        var rig = new TestKit.Rig(config, "", false);
        rig.match.court = new CourtBooking(end, COURT_NONE);
        rig.play(moves);
        return rig;
    }
}

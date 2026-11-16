import Toybox.Lang;
import Toybox.Test;

// What the score screen shows, worked out from the format and the state: the points text
// (0, 15, 30, 40, AD, plain numbers in tie-breaks), the games, the set pips (one per set needed, filled
// when won), the serve dot's quadrant and YOU / PARTNER, the banner and the caption with their strings
// and colors, and the banner pill's width. The drawing itself is compared with the mockups in the
// simulator. A model is written as TestKit.screen() gives it: "US 40 g4 oo | THEM 30 g3 xo | dot 391
// 221 | -".

(:test)
function scoreDotQuadrantTest(logger as Logger) as Boolean {
    // The mini court is seen from our end, like the screen: they serve in the top half, we serve in the
    // bottom half. Our right is the screen's right; their right is the screen's left. A deciding point
    // has no side (the receivers choose): the dot sits on the center line, in the server's half. The
    // server unknown: no ball.
    var cases = [[TEAM_US, SIDE_RIGHT, "391 259"], [TEAM_US, SIDE_LEFT, "365 259"], [TEAM_THEM, SIDE_RIGHT, "365 221"],
        [TEAM_THEM, SIDE_LEFT, "391 221"], [TEAM_US, null, "378 259"], [TEAM_THEM, null, "378 221"], [null, null, "-"],
        [null, SIDE_RIGHT, "-"]];
    for (var i = 0; i < cases.size(); i++) {
        Test.assertEqual(TestKit.dot(ScoreModel.dotPosition(cases[i][0] as Team?, cases[i][1] as Side?)), cases[i][2]);
    }
    return true;
}

(:test)
function scoreMockupsTest(logger as Logger) as Boolean {
    // "Score, in play": they won the first set, 4-3 to us, THEM 30, US 40, they serve from their left
    // (top right quadrant); our break point in yellow outline, SET 2 in grey. "Star point": one set
    // each, 5-2 to us, 40-40 at deuce 3, PARTNER serves: the dot on the center line of our half, PARTNER
    // under the court, the solid yellow banner, RECEIVERS CHOOSE in yellow, or in mixed doubles the FIP
    // mixed rule, in yellow too. "Tie-break": plain numbers, TIE-BREAK outlined in white, the caption at
    // the engine's next change of ends.
    var model = ScoreModelTests.model(new MatchConfig(), "Opponents Me", "UTTTTTT UTUTUTU ututu");
    Test.assertEqual(TestKit.screen(model), "US 40 g4 oo | THEM 30 g3 xo | dot 391 221 | -");
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerBreakPoint, [Palette.BG, Palette.BALL, Palette.BALL]);
    ScoreModelTests.assertCaption(model, CAPTION_SET, Rez.Strings.CaptionSet, Palette.MUTED);
    Test.assertEqual(model.captionNumber, 2);

    var star = "UUUUUU UTUTUTTTT UUTUTUU uuuttt ut ut";
    model = ScoreModelTests.model(new MatchConfig(), "Me", star);
    Test.assertEqual(TestKit.screen(model), "US 40 g5 xo | THEM 40 g2 xo | dot 378 259 | PARTNER");
    Test.assertEqual(ScoreModel.serverString(model.server) as ResourceId, Rez.Strings.ServerPartner);
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerStarPoint, [Palette.BALL, Palette.BALL, Palette.BG]);
    ScoreModelTests.assertCaption(model, CAPTION_RECEIVERS_CHOOSE, Rez.Strings.CaptionReceiversChoose, Palette.BALL);
    var mixed = new MatchConfig();
    mixed.mixed = true;
    model = ScoreModelTests.model(mixed, "Me", star);
    ScoreModelTests.assertCaption(model, CAPTION_SAME_SEX_RECEIVES, Rez.Strings.CaptionSameSexReceives, Palette.BALL);

    model = ScoreModelTests.model(new MatchConfig(), "Me", TestKit.repeat("UT", 6) + " ututututt");
    Test.assertEqual(TestKit.screen(model), "US 4 g6 oo | THEM 5 g6 oo | dot 391 221 | -");
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerTieBreak, [Palette.BG, Palette.TEXT, Palette.TEXT]);
    ScoreModelTests.assertCaption(model, CAPTION_CHANGE_ENDS_AT, Rez.Strings.CaptionChangeEndsAt, Palette.MUTED);
    Test.assertEqual(model.captionNumber, 12);
    return true;
}

(:test)
function scorePointsTextTest(logger as Logger) as Boolean {
    // Tie-break points are plain numbers, two digits included; AD in the language's word, which needs a
    // font with letters (the number fonts' fallbacks have none). The advantage for each team: AD against
    // 40 (DEUCE 1 while we serve, their break point when it's theirs).
    Test.assert(ScoreModel.pointsText(15, "AD").equals("15") && ScoreModel.pointsText(12, "AD").equals("12"));
    Test.assert(ScoreModel.pointsText(MatchState.POINTS_AD, "AV").equals("AV"));
    Test.assert(ScoreModel.pointsStyle(40) == STYLE_NUMBER && ScoreModel.pointsStyle(MatchState.POINTS_AD) == STYLE_BOLD);
    var model = ScoreModelTests.model(new MatchConfig(), "Me", "uuuttt u");
    Test.assertEqual(TestKit.screen(model), "US AD g0 oo | THEM 40 g0 oo | dot 365 259 | ME");
    Test.assert(model.banner == BANNER_DEUCE && model.bannerNumber == 1);
    model = ScoreModelTests.model(new MatchConfig(), "Me", "uuuttt t");
    Test.assertEqual(TestKit.screen(model), "US 40 g0 oo | THEM AD g0 oo | dot 365 259 | ME");
    Test.assertEqual(model.banner, BANNER_BREAK_POINT);
    return true;
}

(:test)
function scorePipsTest(logger as Logger) as Boolean {
    // One pip per set needed to win the match, filled when won: 1 set, best of 3, best of 5 (three a
    // team, two each in the fifth set), short sets (two, and the tie-break's plain points at 4-4).
    Test.assertEqual(TestKit.screen(ScoreModelTests.model(TestKit.preset(PRESET_ONE_SET), "", "UUU")), "US 0 g3 o | THEM 0 g0 o | dot - | -");
    Test.assertEqual(TestKit.screen(ScoreModelTests.model(new MatchConfig(), "", "TTTTTT UUUUUU U")),
        "US 0 g1 xo | THEM 0 g0 xo | dot - | -");
    Test.assertEqual(TestKit.screen(ScoreModelTests.model(TestKit.preset(PRESET_BEST_OF_5), "", "UUUUUU UUUUUU")),
        "US 0 g0 xxo | THEM 0 g0 ooo | dot - | -");
    Test.assertEqual(TestKit.screen(ScoreModelTests.model(TestKit.preset(PRESET_BEST_OF_5), "", "UUUUUU TTTTTT TTTTTT UUUUUU UTUTU ut")),
        "US 15 g3 xxo | THEM 15 g2 xxo | dot - | -");
    var model = ScoreModelTests.model(TestKit.preset(PRESET_SHORT_SETS), "", "UUUU UTUTUTUT uut");
    Test.assertEqual(TestKit.screen(model), "US 2 g4 xo | THEM 1 g4 oo | dot - | -");
    Test.assert(model.banner == BANNER_TIE_BREAK && model.caption == CAPTION_CHANGE_ENDS_AT && model.captionNumber == 6);
    return true;
}

(:test)
function scoreSuperTieBreakTest(logger as Logger) as Boolean {
    // The super tie-break: plain points, no games (0-0 tiles), TIE-BREAK and the change of ends. ME
    // served the first point, they the next two: PARTNER serves the 4th, from the left. A match point in
    // it, on their serve from their right.
    var engine = TestKit.matchOf(TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "Me", "UUUUUU TTTTTT uut");
    var model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assertEqual(TestKit.screen(model), "US 2 g0 xo | THEM 1 g0 xo | dot 365 259 | PARTNER");
    Test.assert(model.banner == BANNER_TIE_BREAK && model.caption == CAPTION_CHANGE_ENDS_AT && model.captionNumber == 6);
    TestKit.play(engine, "uuuuuuu");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assertEqual(TestKit.screen(model), "US 9 g0 xo | THEM 1 g0 xo | dot 365 221 | -");
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerMatchPoint, [Palette.BG, Palette.BALL, Palette.BALL]);
    return true;
}

(:test)
function scoreTieBreakOnlyTest(logger as Logger) as Boolean {
    // Tie-break only shows as the super tie-break does: plain points, the games tiles at
    // 0-0 (it counts no games), one pip a team (one set), TIE-BREAK and CHANGE ENDS AT n from its first
    // point, SET 1 in its place with the Change of ends alert off. ME serves the first point, from the
    // right; they the next two; at 2-1 PARTNER, from the left. A match point; won, the pip filled, no
    // ball, no banner.
    var engine = TestKit.matchOf(TestKit.preset(PRESET_TIE_BREAK_7), "Me", "");
    var model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assertEqual(TestKit.screen(model), "US 0 g0 o | THEM 0 g0 o | dot 391 259 | ME");
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerTieBreak, [Palette.BG, Palette.TEXT, Palette.TEXT]);
    Test.assert(model.caption == CAPTION_CHANGE_ENDS_AT && model.captionNumber == 6);
    TestKit.play(engine, "uut");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assertEqual(TestKit.screen(model), "US 2 g0 o | THEM 1 g0 o | dot 365 259 | PARTNER");
    model = new ScoreModel(engine.getConfig(), engine.getState(), false);
    Test.assert(model.caption == CAPTION_SET && model.captionNumber == 1 && model.banner == BANNER_TIE_BREAK);
    TestKit.play(engine, "uuuu");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assertEqual(TestKit.screen(model), "US 6 g0 o | THEM 1 g0 o | dot 365 259 | ME");
    ScoreModelTests.assertBanner(model, Rez.Strings.BannerMatchPoint, [Palette.BG, Palette.BALL, Palette.BALL]);
    Test.assert(model.caption == CAPTION_CHANGE_ENDS_AT && model.captionNumber == 12);
    TestKit.play(engine, "u");
    model = new ScoreModel(engine.getConfig(), engine.getState(), true);
    Test.assert(TestKit.screen(model).equals("US 0 g0 x | THEM 0 g0 o | dot - | -") && model.banner == BANNER_NONE);
    return true;
}

(:test)
function scoreServeIndicatorTest(logger as Logger) as Boolean {
    // The server unknown (serve tracking off, or BACK on the first serve question): no ball and no YOU
    // / PARTNER, until Fix serving team. Our players alternate over our service games; theirs show no
    // name. Singles: our only player is YOU. Once the match is over there is no next point: no ball,
    // banner or caption.
    var engine = TestKit.matchOf(new MatchConfig(), "", "U uu");
    Test.assertEqual(TestKit.screen(new ScoreModel(engine.getConfig(), engine.getState(), true)), "US 30 g1 oo | THEM 0 g0 oo | dot - | -");
    TestKit.add(engine, EVENT_FIX_SERVING_TEAM, TEAM_US);
    Test.assertEqual(TestKit.screen(new ScoreModel(engine.getConfig(), engine.getState(), true)), "US 30 g1 oo | THEM 0 g0 oo | dot 391 259 | ME");
    engine = TestKit.newMatch(new MatchConfig(), "Partner");
    var steps = [["", "US 0 g0 oo | THEM 0 g0 oo | dot 391 259 | PARTNER"], ["U u", "US 15 g1 oo | THEM 0 g0 oo | dot 391 221 | -"],
        ["U", "US 0 g2 oo | THEM 0 g0 oo | dot 391 259 | ME"], ["UU", "US 0 g4 oo | THEM 0 g0 oo | dot 391 259 | PARTNER"]];
    for (var i = 0; i < steps.size(); i++) {
        TestKit.play(engine, steps[i][0]);
        Test.assertEqual(TestKit.screen(new ScoreModel(engine.getConfig(), engine.getState(), true)), steps[i][1]);
    }
    var singles = new MatchConfig();
    singles.doubles = false;
    var model = ScoreModelTests.model(singles, "Me", "u");
    Test.assertEqual(TestKit.screen(model), "US 15 g0 oo | THEM 0 g0 oo | dot 365 259 | ME");
    Test.assert(ScoreModel.serverString(model.server) == Rez.Strings.ServerYou && ScoreModel.serverString(null) == null);
    model = ScoreModelTests.model(new MatchConfig(), "Me", "UUUUUU UUUUUU");
    Test.assertEqual(TestKit.screen(model), "US 0 g0 xx | THEM 0 g0 oo | dot - | -");
    Test.assert(model.banner == BANNER_NONE && model.caption == CAPTION_NONE);
    return true;
}

(:test)
function scoreChangeOfEndsCaptionTest(logger as Logger) as Boolean {
    // With the Change of ends alert off, CHANGE ENDS AT n goes from the tie-break's caption,
    // which shows the set instead: SET 1 in the first set's tie-break, SET 3 in the super tie-break. The
    // rest of the screen stays, and so do the other captions: SET n, RECEIVERS CHOOSE on a deciding
    // point.
    var cases = [
        [new MatchConfig(), TestKit.repeat("UT", 6) + " ututututt", CAPTION_CHANGE_ENDS_AT, 12, 1],
        [TestKit.preset(PRESET_BEST_OF_3_SUPER_TB), "UUUUUU TTTTTT uut", CAPTION_CHANGE_ENDS_AT, 6, 3],
        [new MatchConfig(), "UTTTTTT UTUTUTU ututu", CAPTION_SET, 2, 2],
        [new MatchConfig(), "UUUUUU UTUTUTTTT UUTUTUU uuuttt ut ut", CAPTION_RECEIVERS_CHOOSE, 0, 0]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var engine = TestKit.matchOf(c[0] as MatchConfig, "Me", c[1] as String);
        var on = new ScoreModel(engine.getConfig(), engine.getState(), true);
        var off = new ScoreModel(engine.getConfig(), engine.getState(), false);
        var message = "case " + i;
        Test.assertMessage(on.caption == c[2] && on.captionNumber == c[3], message + ": on");
        var caption = c[2] == CAPTION_CHANGE_ENDS_AT ? CAPTION_SET : c[2];
        Test.assertMessage(off.caption == caption && off.captionNumber == c[4], message + ": off " + off.captionNumber);
        Test.assertEqualMessage(TestKit.screen(off), TestKit.screen(on), message);
        Test.assertMessage(off.banner == on.banner && off.bannerStyle == on.bannerStyle, message + ": banner");
    }
    var engine = TestKit.matchOf(new MatchConfig(), "Me", TestKit.repeat("UT", 6));
    ScoreModelTests.assertCaption(new ScoreModel(engine.getConfig(), engine.getState(), false), CAPTION_SET,
        Rez.Strings.CaptionSet, Palette.MUTED);
    return true;
}

(:test)
function scoreTextKeysTest(logger as Logger) as Boolean {
    // Every banner and caption has its string; none for BANNER_NONE and CAPTION_NONE.
    var banners = [BANNER_STAR_POINT, BANNER_SILVER_POINT, BANNER_GOLDEN_POINT, BANNER_MATCH_POINT, BANNER_SET_POINT,
        BANNER_BREAK_POINT, BANNER_DEUCE, BANNER_TIE_BREAK];
    var strings = [Rez.Strings.BannerStarPoint, Rez.Strings.BannerSilverPoint, Rez.Strings.BannerGoldenPoint,
        Rez.Strings.BannerMatchPoint, Rez.Strings.BannerSetPoint, Rez.Strings.BannerBreakPoint, Rez.Strings.BannerDeuce,
        Rez.Strings.BannerTieBreak];
    for (var i = 0; i < banners.size(); i++) {
        Test.assertMessage(ScoreModel.bannerString(banners[i]) == strings[i], "banner " + banners[i]);
    }
    var captions = [CAPTION_SET, CAPTION_CHANGE_ENDS_AT, CAPTION_RECEIVERS_CHOOSE, CAPTION_SAME_SEX_RECEIVES];
    strings = [Rez.Strings.CaptionSet, Rez.Strings.CaptionChangeEndsAt, Rez.Strings.CaptionReceiversChoose,
        Rez.Strings.CaptionSameSexReceives];
    for (var i = 0; i < captions.size(); i++) {
        Test.assertMessage(ScoreModel.captionString(captions[i]) == strings[i], "caption " + captions[i]);
    }
    Test.assert(ScoreModel.bannerString(BANNER_NONE) == null && ScoreModel.captionString(CAPTION_NONE) == null);
    return true;
}

(:test)
function scoreBannerWidthTest(logger as Logger) as Boolean {
    // The pill is its text plus 30 on each side, as the mockups draw BREAK POINT (111 wide in the watch's
    // font: 171 for the mockup's 170) and TIE-BREAK (88: 148 for 150). A long text (French BALLE DE
    // MATCH, 144) keeps a clear gap before the mini court: the margin gets narrower, so the pill ends 10
    // before the court's left edge (352). Wider than BANNER_TEXT_MAX, the text gets a smaller font first.
    TestKit.assertNear(ScoreModel.bannerWidth(111), 171, 0.01);
    TestKit.assertNear(ScoreModel.bannerWidth(88), 148, 0.01);
    TestKit.assertNear(ScoreModel.bannerWidth(144), 184, 0.01);
    TestKit.assertNear(ScoreModel.BANNER_X + ScoreModel.bannerWidth(144) / 2, 342, 0.01);
    TestKit.assertNear(ScoreModel.bannerWidth(ScoreModel.BANNER_TEXT_MAX), 184, 0.01);
    Test.assertEqual(ScoreModel.BANNER_TEXT_MAX, 152);
    return true;
}

(:test)
function scoreFixturesTest(logger as Logger) as Boolean {
    // The debug fixtures (ScoreFixtures) give the mockup states and the edge cases the simulator
    // screenshots show. The three mockups show their time, heart rate, calories and game time; the
    // others the real ones. The fixtures' zones put each heart rate in the mockup's zone.
    var expected = [
        ["1-6 | 4-3 40-30", "THEM L", "BREAK POINT pressure | SET 2 | break U"],
        ["6-0 3-6 | 5-2 40-40", "PARTNER -", "STAR POINT deciding | RECEIVERS CHOOSE | break T, set U, match U, deciding"],
        ["| 6-6 tb 4-5", "THEM L", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["| 1-0 30-15", "?", "- | SET 1 | -"],
        ["6-0 0-6 | 0-0 stb 6-4", "THEM R", "TIE-BREAK info | CHANGE ENDS AT 12 | tie-break"],
        ["| 0-0 AD-40", "ME L", "DEUCE 1 info | SET 1 | -"],
        ["| 0-0 40-AD", "ME L", "BREAK POINT pressure | SET 1 | break T"],
        ["6-0 | 5-1 40-0", "ME L", "MATCH POINT pressure | SET 2 | set U, match U"],
        ["| 0-0 40-40", "ME R", "DEUCE 2 info | SET 1 | -"],
        ["6-0 3-6 | 5-2 40-40", "PARTNER -", "STAR POINT deciding | SAME SEX RECEIVES | break T, set U, match U, deciding"],
        ["| 0-0 15-0", "ME L", "- | SET 1 | -"],
        ["| 2-5 0-40", "THEM L", "SET POINT pressure | SET 1 | set T"],
        ["| 6-6 tb 6-5", "PARTNER L", "SET POINT pressure | CHANGE ENDS AT 12 | set U, tie-break"],
        ["6-0 0-6 | 0-0 stb 9-8", "THEM L", "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break"],
        ["6-4 3-6 | 0-0 stb 9-8", "ME L", "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break"],
        ["10-8 0-2 2-0 0-2 | 1-0 40-0", "THEM L", "MATCH POINT pressure | SET 5 | break U, set U, match U"],
        ["6-4 3-6 7-6(7-5) 4-6 | 5-4 40-15", "THEM R", "MATCH POINT pressure | SET 5 | break U, set U, match U"],
        ["4-2 | 4-4 tb 2-1", "ME L", "TIE-BREAK info | CHANGE ENDS AT 6 | tie-break"],
        ["| 0-0 stb 6-5", "PARTNER L", "MATCH POINT pressure | CHANGE ENDS AT 12 | set U, match U, tie-break"],
        ["| 0-0 stb 9-8", "ME L", "MATCH POINT pressure | CHANGE ENDS AT 18 | set U, match U, tie-break"],
        ["1-6 | 4-2 40-30", "ME L", "- | SET 2 | -"],
        ["6-0 0-6 6-0 6-4 | 2-1 30-15", "THEM L", "- | SET 5 | -"],
        ["| 4-3 30-15", "THEM L", "- | SET 1 | -"]
    ];
    var fixtures = ScoreFixtures.all();
    Test.assertEqual(fixtures.size(), expected.size());
    for (var i = 0; i < fixtures.size(); i++) {
        var engine = fixtures[i].engine(TestKit.T0);
        var state = engine.getState();
        var actual = TestKit.sets(state) + " / " + TestKit.serve(state) + " / " + TestKit.situation(engine.getConfig(), state);
        Test.assertEqualMessage(actual, expected[i][0] + " / " + expected[i][1] + " / " + expected[i][2], fixtures[i].name);
        TestKit.assertMatchesReplay(engine, fixtures[i].name);
    }
    Test.assertEqual(ScoreModelTests.numbers(fixtures[0].frozen), "2537 152 486 134");
    Test.assertEqual(ScoreModelTests.numbers(fixtures[1].frozen), "4865 171 905 288");
    Test.assertEqual(ScoreModelTests.numbers(fixtures[2].frozen), "3520 139 652 415");
    Test.assert(fixtures[3].frozen == null);
    // The summary mockup's: its duration, heart rate and calories, then its maximum heart rate.
    Test.assertEqual(ScoreModelTests.numbers(fixtures[14].frozen), "5050 148 905 0 171");
    Test.assert(HeartRateArc.zoneOf(152, ScoreFixtures.ZONES) == 4 && HeartRateArc.zoneOf(171, ScoreFixtures.ZONES) == 5
        && HeartRateArc.zoneOf(139, ScoreFixtures.ZONES) == 3);
    return true;
}

(:test)
module ScoreModelTests {

    function model(config as MatchConfig, answer as String, moves as String) as ScoreModel {
        var engine = TestKit.matchOf(config, answer, moves);
        return new ScoreModel(engine.getConfig(), engine.getState(), true);
    }

    function numbers(values as Array<Number>?) as String {
        if (values == null) {
            return "-";
        }
        var text = "";
        for (var i = 0; i < values.size(); i++) {
            text += (i == 0 ? "" : " ") + values[i];
        }
        return text;
    }

    // The banner's string and its fill, stroke and text colors.
    function assertBanner(model as ScoreModel, string as ResourceId, colors as Array<Number>) as Void {
        Test.assertEqual(ScoreModel.bannerString(model.banner) as ResourceId, string);
        Test.assertEqual(ScoreModel.bannerColors(model.bannerStyle).toString(), colors.toString());
    }

    function assertCaption(model as ScoreModel, caption as Caption, string as ResourceId, color as Number) as Void {
        Test.assert(model.caption == caption && ScoreModel.captionString(model.caption) == string);
        Test.assertEqual(ScoreModel.captionColor(model.caption), color);
    }
}

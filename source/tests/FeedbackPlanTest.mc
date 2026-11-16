import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Feedback: vibration by count and length (short 150 ms, medium 400, long 800, 250 ms gaps,
// a 600 ms pause before the game or set pulses), tones for the important events only. The Vibration
// setting (Every point / Important only / Off), Sounds (Off / On), the Change of ends alert (On / Off),
// and the watch's own vibration and tones settings, which always win. One vibrate call takes at most 8
// profiles, pulses and gaps both, and more crashes the app (tested on the FR265): a longer pattern is cut into
// several calls. A point that wrote its game's lap plays nothing of its own: the watch's own lap alert
// answers it, and a change of ends it brings waits until that alert is over. The other plans here are
// the points that wrote none (lap false).

(:test)
function feedbackEveryPointTest(logger as Logger) as Boolean {
    // The feedback table with the defaults (Every point, Sounds off) and the watch's settings on. Point US:
    // 1 short. Point THEM: 2 short. Undo: 1 medium. Game won: the point pulses, a pause, 1 long, in one
    // call. Set or match won by US: the point pulse, a pause, 3 long: 7 profiles, one call. By THEM it's
    // 9 profiles: cut at the pause, the 3 long pulses start when the pause ends (150 + 250 + 150 + 600 =
    // 1150 ms after the event). Sounds off: no tone at all.
    Test.assertEqual(FeedbackPlan.MAX_PROFILES, 8);
    var on = new FeedbackChannels(VIBRATION_EVERY_POINT, false, true, true, true);
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_US, WON_POINT, false, false, on), [[150]], [0], "point US");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_POINT, false, false, on), [[150, 250, 150]], [0], "point THEM");
    FeedbackTests.assertPlan(FeedbackPlan.undo(on), [[400]], [0], "undo");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_US, WON_GAME, false, false, on), [[150, 600, 800]], [0], "game US");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_GAME, false, false, on), [[150, 250, 150, 600, 800]], [0], "game THEM");
    var setUs = [[150, 600, 800, 250, 800, 250, 800]];
    var setThem = [[150, 250, 150], [800, 250, 800, 250, 800]];
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_US, WON_SET, false, false, on), setUs, [0], "set US");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_US, WON_MATCH, false, false, on), setUs, [0], "match US");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_SET, false, false, on), setThem, [0, 1150], "set THEM");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_MATCH, false, false, on), setThem, [0, 1150], "match THEM");
    for (var i = 0; i < FeedbackTests.EVENTS; i++) {
        Test.assertEqualMessage(FeedbackTests.plan(i, on).tones.size(), 0, FeedbackTests.name(i));
    }
    return true;
}

(:test)
function feedbackAfterLapTest(logger as Logger) as Boolean {
    // A point that wrote its game's lap (a game or a set won, the first time) and brings no
    // change of ends plays nothing in any setting, neither buzz nor tone: the watch's own lap alert, a
    // beep and a buzz, answers the press. With no lap written the point plays its pattern, as the other
    // events do: the match point, which writes none, and a game or a set won again after its winning
    // point was undone.
    var settings = [VIBRATION_EVERY_POINT, VIBRATION_IMPORTANT, VIBRATION_OFF];
    for (var s = 0; s < settings.size(); s++) {
        for (var flags = 0; flags < 16; flags++) {
            var channels = FeedbackTests.channels(settings[s], flags);
            for (var i = 0; i < 8; i++) {
                if (i % 4 == 1 || i % 4 == 2) {
                    var plan = FeedbackPlan.point(i < 4 ? TEAM_US : TEAM_THEM, FeedbackTests.WINS[i % 4], true, false, channels);
                    Test.assertMessage(plan.isEmpty(), FeedbackTests.name(i) + " with its lap, setting " + settings[s] + ", flags " + flags);
                }
            }
        }
    }
    var sounds = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    var match = FeedbackPlan.point(TEAM_THEM, WON_MATCH, false, false, sounds);
    FeedbackTests.assertPlan(match, [[150, 250, 150], [800, 250, 800, 250, 800]], [0, 1150], "match THEM");
    FeedbackTests.assertTones(match, [FeedbackPlan.setTones()], [0], "match THEM");
    var again = FeedbackPlan.point(TEAM_US, WON_GAME, false, false, sounds);
    FeedbackTests.assertPlan(again, [[150, 600, 800]], [0], "game won again");
    FeedbackTests.assertTones(again, [FeedbackPlan.gameTones()], [0], "game won again");
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_POINT, false, false, sounds), [[150, 250, 150]], [0], "point THEM");
    return true;
}

(:test)
function feedbackChangeOfEndsTest(logger as Logger) as Boolean {
    // The change of ends: 2 long pulses, and with Sounds on 2 tones, one at the start
    // of each long pulse. In a tie-break (a point that wins only the point) they follow the point
    // pulses after the pause; after a game or a set won again after an undo, that pattern's own
    // pulses, after the pause; after a point that wrote its game's lap they start LAP_ALERT_WAIT after
    // the press, once the watch's lap alert is over. Cut at the longest silence as any pattern: no call
    // over 8 profiles. Never at the match end, never with the alert off: the plan is then the point's
    // own.
    var on = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    var l = FeedbackPlan.LONG;
    var g = FeedbackPlan.GAP;
    var wait = FeedbackPlan.LAP_ALERT_WAIT;
    var tone = FeedbackPlan.endsTone();
    var plan = FeedbackPlan.point(TEAM_US, WON_POINT, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 600, 800, 250, 800]], [0], "tie-break US");
    FeedbackTests.assertTones(plan, [tone, tone], [750, 1800], "tie-break US");
    plan = FeedbackPlan.point(TEAM_THEM, WON_POINT, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 250, 150, 600, 800, 250, 800]], [0], "tie-break THEM");
    FeedbackTests.assertTones(plan, [tone, tone], [1150, 2200], "tie-break THEM");
    var teams = [TEAM_US, TEAM_THEM];
    var wins = [WON_GAME, WON_SET];
    for (var t = 0; t < teams.size(); t++) {
        for (var w = 0; w < wins.size(); w++) {
            plan = FeedbackPlan.point(teams[t], wins[w], true, true, on);
            FeedbackTests.assertPlan(plan, [[l, g, l]], [wait], "after the lap " + t + w);
            FeedbackTests.assertTones(plan, [tone, tone], [wait, wait + l + g], "after the lap " + t + w);
        }
    }
    plan = FeedbackPlan.point(TEAM_US, WON_GAME, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 600, 800, 600, 800, 250, 800]], [0], "game US won again");
    FeedbackTests.assertTones(plan, [FeedbackPlan.gameTones(), tone, tone], [0, 2150, 3200], "game US won again");
    plan = FeedbackPlan.point(TEAM_THEM, WON_GAME, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 250, 150, 600, 800], [800, 250, 800]], [0, 2550], "game THEM won again");
    FeedbackTests.assertTones(plan, [FeedbackPlan.gameTones(), tone, tone], [0, 2550, 3600], "game THEM won again");
    plan = FeedbackPlan.point(TEAM_US, WON_SET, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 600, 800, 250, 800, 250, 800], [800, 250, 800]], [0, 4250], "set US won again");
    FeedbackTests.assertTones(plan, [FeedbackPlan.setTones(), tone, tone], [0, 4250, 5300], "set US won again");
    plan = FeedbackPlan.point(TEAM_THEM, WON_SET, false, true, on);
    FeedbackTests.assertPlan(plan, [[150, 250, 150], [800, 250, 800, 250, 800], [800, 250, 800]], [0, 1150, 4650], "set THEM won again");
    FeedbackTests.assertTones(plan, [FeedbackPlan.setTones(), tone, tone], [0, 4650, 5700], "set THEM won again");
    // The match point: the engine never says the ends change then, and the plan keeps to the match's.
    var off = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, false);
    for (var t = 0; t < teams.size(); t++) {
        var match = FeedbackPlan.point(teams[t], WON_MATCH, false, false, on);
        FeedbackTests.assertSamePlan(FeedbackPlan.point(teams[t], WON_MATCH, false, true, on), match, "match " + t);
        // The alert off: each point plays its own plan, a lap's nothing.
        var all = [WON_POINT, WON_GAME, WON_SET, WON_MATCH];
        for (var w = 0; w < all.size(); w++) {
            for (var lap = 0; lap < 2; lap++) {
                if (lap == 0 || all[w] == WON_GAME || all[w] == WON_SET) {
                    FeedbackTests.assertSamePlan(FeedbackPlan.point(teams[t], all[w], lap == 1, true, off),
                        FeedbackPlan.point(teams[t], all[w], lap == 1, false, on), "alert off " + t + w + lap);
                }
            }
        }
    }
    // Important only keeps the whole pattern, the point pulses included; Vibration Off keeps the tones.
    var important = new FeedbackChannels(VIBRATION_IMPORTANT, true, true, true, true);
    FeedbackTests.assertSamePlan(FeedbackPlan.point(TEAM_THEM, WON_POINT, false, true, important),
        FeedbackPlan.point(TEAM_THEM, WON_POINT, false, true, on), "tie-break, important only");
    plan = FeedbackPlan.point(TEAM_US, WON_GAME, true, true, new FeedbackChannels(VIBRATION_OFF, true, true, true, true));
    Test.assert(plan.calls.size() == 0);
    FeedbackTests.assertTones(plan, [tone, tone], [wait, wait + l + g], "after the lap, vibration off");
    return true;
}

(:test)
function feedbackTonesTest(logger as Logger) as Boolean {
    // Sounds on: never for a point or an undo; 1 tone for a game; rising tones for a set or the match;
    // falling for the court time; for the change of ends, one note twice, lower than the game's, with
    // its 2 long pulses. The tones don't change the vibration.
    var sounds = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    for (var t = 0; t < 2; t++) {
        var team = t == 0 ? TEAM_US : TEAM_THEM;
        Test.assertEqual(FeedbackPlan.point(team, WON_POINT, false, false, sounds).tones.size(), 0);
        var game = FeedbackPlan.point(team, WON_GAME, false, false, sounds).tones;
        Test.assert(game.size() == 1 && game[0].size() == 2);
        FeedbackTests.assertAudible(game[0], "game");
        var wins = [WON_SET, WON_MATCH];
        for (var w = 0; w < wins.size(); w++) {
            var tones = FeedbackPlan.point(team, wins[w], false, false, sounds).tones;
            Test.assertEqual(tones.size(), 1);
            FeedbackTests.assertAudible(tones[0], "set or match");
            Test.assert(tones[0].size() >= 4);
            for (var i = 2; i < tones[0].size(); i += 2) {
                Test.assertMessage(tones[0][i] > tones[0][i - 2], "rising: " + tones);
            }
        }
    }
    Test.assertEqual(FeedbackPlan.undo(sounds).tones.size(), 0);
    var court = FeedbackPlan.court(sounds).tones;
    Test.assertEqual(court.size(), 1);
    FeedbackTests.assertAudible(court[0], "court time");
    Test.assertMessage(court[0].size() == 6 && court[0][2] < court[0][0] && court[0][4] < court[0][2], "falling: " + court);
    var ends = FeedbackPlan.endsTone();
    FeedbackTests.assertAudible(ends, "change of ends");
    Test.assert(ends.size() == 2 && ends[0] < FeedbackPlan.gameTones()[0] && ends[1] <= FeedbackPlan.LONG);
    FeedbackTests.assertPlan(FeedbackPlan.point(TEAM_THEM, WON_SET, false, false, sounds), [[150, 250, 150], [800, 250, 800, 250, 800]], [0, 1150],
        "set THEM, sounds on");
    return true;
}

(:test)
function feedbackImportantOnlyTest(logger as Logger) as Boolean {
    // Important only: no buzz for a point that wins nothing more, nor for an undo; a game, a set, the
    // match, a change of ends and the court time keep their whole pattern, the point pulses included,
    // and their tones.
    var important = new FeedbackChannels(VIBRATION_IMPORTANT, true, true, true, true);
    var every = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    Test.assert(FeedbackPlan.point(TEAM_US, WON_POINT, false, false, important).isEmpty()
        && FeedbackPlan.point(TEAM_THEM, WON_POINT, false, false, important).isEmpty());
    Test.assert(FeedbackPlan.undo(important).isEmpty());
    for (var i = 0; i < FeedbackTests.EVENTS; i++) {
        if (FeedbackTests.isImportant(i, true)) {
            FeedbackTests.assertSamePlan(FeedbackTests.plan(i, important), FeedbackTests.plan(i, every), FeedbackTests.name(i));
        }
    }
    return true;
}

(:test)
function feedbackEveryPlanTest(logger as Logger) as Boolean {
    // Every event, the change of ends included, with every combination of the settings and the watch's
    // (whose vibration and tones settings always win): the calls are the event's whole pattern when it
    // vibrates (put back together, with the silences where they were cut), from its start (later after
    // a lap), nothing otherwise; its tones, when they start, only for an important event with Sounds
    // and the watch's tones on, Vibration Off included; no call over 8 profiles. With the alert off, a
    // change of ends adds nothing.
    var settings = [VIBRATION_EVERY_POINT, VIBRATION_IMPORTANT, VIBRATION_OFF];
    for (var s = 0; s < settings.size(); s++) {
        for (var flags = 0; flags < 16; flags++) {
            var sounds = (flags & 1) != 0;
            var vibrateOn = (flags & 2) != 0;
            var tonesOn = (flags & 4) != 0;
            var alert = (flags & 8) != 0;
            var channels = FeedbackTests.channels(settings[s], flags);
            for (var i = 0; i < FeedbackTests.EVENTS; i++) {
                var name = FeedbackTests.name(i) + ", setting " + settings[s] + ", flags " + flags;
                var plan = FeedbackTests.plan(i, channels);
                var important = FeedbackTests.isImportant(i, alert);
                var pattern = FeedbackTests.pattern(i, alert);
                var vibrates = vibrateOn && pattern.size() > 0
                    && (settings[s] == VIBRATION_EVERY_POINT || (settings[s] == VIBRATION_IMPORTANT && important));
                var beeps = sounds && tonesOn && important;
                FeedbackTests.assertLimit(plan, name);
                Test.assertEqualMessage(FeedbackTests.joined(plan), vibrates ? pattern.toString() : "[]", name);
                if (vibrates) {
                    Test.assertEqualMessage(plan.starts[0], FeedbackTests.start(i), name);
                }
                Test.assertEqualMessage(plan.tones.toString() + plan.toneStarts, beeps ? FeedbackTests.tones(i, alert) : "[][]", name);
                Test.assertEqualMessage(plan.isEmpty(), !vibrates && plan.tones.size() == 0, name);
            }
        }
    }
    return true;
}

(:test)
function feedbackLongPatternsTest(logger as Logger) as Boolean {
    // Any pattern over 8 profiles (court time: 3 short, a pause, 3 short, 11 profiles; a game won again
    // with the change of ends after it) is cut at its longest silence, the last one on a tie, as often
    // as needed: no call over 8, each starts and ends with a pulse, and the timing is kept. Up to 8
    // profiles (7, as a pattern starts and ends with a pulse): one call, as given.
    var on = new FeedbackChannels(VIBRATION_EVERY_POINT, false, true, true, true);
    var s = FeedbackPlan.SHORT;
    var l = FeedbackPlan.LONG;
    var g = FeedbackPlan.GAP;
    var p = FeedbackPlan.PAUSE;
    FeedbackTests.assertPlan(FeedbackPlan.court(on), [[s, g, s, g, s], [s, g, s, g, s]], [0, 1550], "court time");
    FeedbackTests.assertPlan(new FeedbackPlan([s, g, s, p, l, p, l, g, l], true, [], on), [[s, g, s, p, l], [l, g, l]], [0, 2550],
        "game THEM, change of ends");
    var patterns = [
        [s, g, s, g, s, g, s, g, s],
        [s, g, s, p, l, g, l, g, l, p, l, g, l],
        [s, g, s, g, s, g, s, g, s, g, s, g, s, g, s, g, s, g, s, g, s],
        [l, 1, l, 2, l, 3, l, 4, l, 5, l, 6, l, 7, l, 8, l, 9, l, 10, l, 11, l]
    ];
    for (var i = 0; i < patterns.size(); i++) {
        var plan = new FeedbackPlan(patterns[i], false, [], on);
        Test.assertMessage(plan.calls.size() >= 2, "pattern " + i);
        FeedbackTests.assertLimit(plan, "pattern " + i);
        Test.assertEqualMessage(FeedbackTests.joined(plan), patterns[i].toString(), "pattern " + i);
    }
    FeedbackTests.assertPlan(new FeedbackPlan([s, g, s, g, s, g, s], false, [], on), [[s, g, s, g, s, g, s]], [0], "7 profiles");
    return true;
}

(:test)
function feedbackTimelineTest(logger as Logger) as Boolean {
    // What Feedback plays next, in the order of the plan's times: nextStart() gives when the next call
    // or tones not yet played start, the earlier of the two, then nothing once all are played. delay()
    // moves the whole plan later.
    var on = new FeedbackChannels(VIBRATION_EVERY_POINT, true, true, true, true);
    var plan = FeedbackPlan.point(TEAM_THEM, WON_GAME, false, true, on);
    Test.assert(plan.nextStart(0, 0) == 0 && plan.nextStart(1, 1) == 2550 && plan.nextStart(2, 1) == 2550);
    Test.assert(plan.nextStart(2, 2) == 3600 && plan.nextStart(2, 3) == null);
    Test.assert(FeedbackPlan.point(TEAM_US, WON_GAME, true, false, on).nextStart(0, 0) == null);
    var lap = FeedbackPlan.point(TEAM_US, WON_SET, true, true, on);
    var wait = FeedbackPlan.LAP_ALERT_WAIT;
    Test.assert(lap.nextStart(0, 0) == wait && lap.nextStart(1, 1) == wait + FeedbackPlan.LONG + FeedbackPlan.GAP);
    var later = FeedbackPlan.point(TEAM_US, WON_POINT, false, true, on).delay(100);
    Test.assertEqual(later.starts.toString() + later.toneStarts, [100].toString() + [850, 1900]);
    return true;
}

(:test)
function feedbackProfilesTest(logger as Logger) as Boolean {
    // What reaches Attention: pulses at full duty, silences at zero (a real pause on the FR265),
    // and never a call over 8 profiles; tones as frequency and duration. Read at each event: the
    // app's settings as stored, the watch's as they are now.
    var profiles = Feedback.vibeProfiles([150, 250, 150]) as Array<Attention.VibeProfile>;
    Test.assert(profiles.size() == 3 && profiles[0].dutyCycle == 100 && profiles[0].length == 150);
    Test.assert(profiles[1].dutyCycle == 0 && profiles[1].length == 250 && profiles[2].dutyCycle == 100);
    Test.assertEqual((Feedback.vibeProfiles([150, 250, 150, 250, 150, 250, 150, 250]) as Array).size(), 8);
    Test.assert(Feedback.vibeProfiles([150, 250, 150, 250, 150, 250, 150, 250, 150]) == null && Feedback.vibeProfiles([]) == null);
    var tones = Feedback.toneProfiles([2500, 200, 4000, 300]);
    Test.assert(tones.size() == 2 && tones[0].frequency == 2500 && tones[0].duration == 200 && tones[1].frequency == 4000);
    var channels = Feedback.channels();
    var device = System.getDeviceSettings();
    Test.assert(channels.vibration == Settings.getVibration() && channels.sounds == Settings.isSoundsOn());
    Test.assert(channels.vibrateOn == device.vibrateOn && channels.tonesOn == device.tonesOn);
    Test.assertEqual(channels.endsAlert, Settings.isChangeOfEndsAlert());
    return true;
}

(:test)
module FeedbackTests {

    // The events of the feedback table in scope: a point for each team that wins only the point, a game, a
    // set or the match (0 to 7), then the undo (8), the court time warning or end (9), then the
    // same 8 points bringing a change of ends (10 to 17: a tie-break's 6th point, a game or a set won
    // again after an undo, the match point, which never has one), then a game or a set won by each
    // team that wrote its lap and brings a change of ends (18 to 21: US game, US set, THEM game, THEM
    // set).
    const EVENTS = 22;
    const WINS = [WON_POINT, WON_GAME, WON_SET, WON_MATCH];

    // The settings, flags as bits: Sounds, the watch's vibration, the watch's tones, the alert.
    function channels(vibration as VibrationSetting, flags as Number) as FeedbackChannels {
        return new FeedbackChannels(vibration, (flags & 1) != 0, (flags & 2) != 0, (flags & 4) != 0, (flags & 8) != 0);
    }

    function plan(event as Number, channels as FeedbackChannels) as FeedbackPlan {
        if (event == 8) {
            return FeedbackPlan.undo(channels);
        } else if (event == 9) {
            return FeedbackPlan.court(channels);
        }
        return FeedbackPlan.point(team(event), won(event), event >= 18, event >= 10, channels);
    }

    function team(event as Number) as Team {
        if (event >= 18) {
            return event < 20 ? TEAM_US : TEAM_THEM;
        }
        return event % 10 < 4 ? TEAM_US : TEAM_THEM;
    }

    function won(event as Number) as PointWon {
        if (event >= 18) {
            return event % 2 == 0 ? WON_GAME : WON_SET;
        }
        return WINS[event % 10 % 4];
    }

    function name(event as Number) as String {
        if (event == 8 || event == 9) {
            return event == 8 ? "undo" : "court time";
        }
        return (team(event) == TEAM_US ? "US " : "THEM ") + ["point", "game", "set", "match"][won(event) as Number]
            + (event >= 18 ? ", lap, ends" : event >= 10 ? ", ends" : "");
    }

    // The ends change at this event, the alert on: not at the match point.
    function ends(event as Number, alert as Boolean) as Boolean {
        return alert && event >= 10 && won(event) != WON_MATCH;
    }

    // Game, set, match, court time and the change of ends: they play with Important only, and have
    // tones.
    function isImportant(event as Number, alert as Boolean) as Boolean {
        return event == 9 || (event != 8 && won(event) != WON_POINT) || ends(event, alert);
    }

    // The point's own pattern, from the feedback table, then a pause and the 2 long pulses of a change of
    // ends; after a lap, only those.
    function pattern(event as Number, alert as Boolean) as Array<Number> {
        if (event == 8) {
            return [400];
        } else if (event == 9) {
            return [150, 250, 150, 250, 150, 600, 150, 250, 150, 250, 150];
        }
        var steps = [] as Array<Number>;
        if (event < 18) {
            steps = team(event) == TEAM_US ? [150] : [150, 250, 150];
            var longs = [0, 1, 3, 3][won(event) as Number];
            for (var i = 0; i < longs; i++) {
                steps.addAll([i == 0 ? 600 : 250, 800]);
            }
        }
        if (ends(event, alert)) {
            if (steps.size() > 0) {
                steps.add(600);
            }
            steps.addAll([800, 250, 800]);
        }
        return steps;
    }

    // When the event's pulses start: at the event, or 2 s after it, once the watch's lap alert is over.
    function start(event as Number) as Number {
        return event >= 18 ? FeedbackPlan.LAP_ALERT_WAIT : 0;
    }

    // The event's tones, as plan.tones and plan.toneStarts print them: the point's own at the event
    // (none after a lap), then the change of ends' note at the start of each of its long pulses.
    function tones(event as Number, alert as Boolean) as String {
        var tones = [] as Array<Array<Number> >;
        var starts = [] as Array<Number>;
        if (event == 9) {
            tones.add(FeedbackPlan.courtTones());
            starts.add(0);
        } else if (event < 18 && won(event) != WON_POINT) {
            tones.add(won(event) == WON_GAME ? FeedbackPlan.gameTones() : FeedbackPlan.setTones());
            starts.add(0);
        }
        if (ends(event, alert)) {
            var steps = pattern(event, alert);
            var at = start(event);
            for (var i = 0; i < steps.size() - 3; i++) {
                at += steps[i];
            }
            tones.addAll([FeedbackPlan.endsTone(), FeedbackPlan.endsTone()]);
            starts.addAll([at, at + 1050]);
        }
        return tones.toString() + starts;
    }

    // The calls put back together, the silence at each cut being the time from the end of a call to the
    // start of the next.
    function joined(plan as FeedbackPlan) as String {
        var steps = [] as Array<Number>;
        for (var i = 0; i < plan.calls.size(); i++) {
            if (i > 0) {
                steps.add(plan.starts[i] - end(plan, i - 1));
            }
            steps.addAll(plan.calls[i]);
        }
        return steps.toString();
    }

    // When call i ends, in ms after the event.
    function end(plan as FeedbackPlan, i as Number) as Number {
        var time = plan.starts[i];
        for (var j = 0; j < plan.calls[i].size(); j++) {
            time += plan.calls[i][j];
        }
        return time;
    }

    // No call over 8 profiles; each starts and ends with a pulse (an odd count, as a pattern alternates
    // pulses and silences); the first at the event or later, each later one after the last ends. The
    // tones as many as their starts, in order.
    function assertLimit(plan as FeedbackPlan, name as String) as Void {
        Test.assertEqualMessage(plan.starts.size(), plan.calls.size(), name);
        for (var i = 0; i < plan.calls.size(); i++) {
            var size = plan.calls[i].size();
            Test.assertMessage(size >= 1 && size <= FeedbackPlan.MAX_PROFILES && size % 2 == 1, name + ": " + plan.calls[i]);
            Test.assertMessage(i == 0 ? plan.starts[i] >= 0 : plan.starts[i] > end(plan, i - 1), name);
        }
        Test.assertEqualMessage(plan.toneStarts.size(), plan.tones.size(), name);
        for (var i = 1; i < plan.toneStarts.size(); i++) {
            Test.assertMessage(plan.toneStarts[i] > plan.toneStarts[i - 1], name);
        }
    }

    function assertPlan(plan as FeedbackPlan, calls as Array<Array<Number> >, starts as Array<Number>, name as String) as Void {
        Test.assertEqualMessage(plan.calls.toString(), calls.toString(), name);
        Test.assertEqualMessage(plan.starts.toString(), starts.toString(), name);
        assertLimit(plan, name);
    }

    function assertTones(plan as FeedbackPlan, tones as Array<Array<Number> >, starts as Array<Number>, name as String) as Void {
        Test.assertEqualMessage(plan.tones.toString(), tones.toString(), name);
        Test.assertEqualMessage(plan.toneStarts.toString(), starts.toString(), name);
    }

    function assertSamePlan(actual as FeedbackPlan, expected as FeedbackPlan, name as String) as Void {
        Test.assertEqualMessage(actual.calls.toString() + actual.starts + actual.tones + actual.toneStarts,
            expected.calls.toString() + expected.starts + expected.tones + expected.toneStarts, name);
    }

    // Notes as [frequency, duration, ...]: a small beeper is loudest between 2 and 5 kHz, and a note
    // under 100 ms is hard to hear on a loud court.
    function assertAudible(tones as Array<Number>, name as String) as Void {
        Test.assertMessage(tones.size() >= 2 && tones.size() % 2 == 0, name + ": " + tones);
        for (var i = 0; i < tones.size(); i += 2) {
            Test.assertMessage(tones[i] >= 2000 && tones[i] <= 5000 && tones[i + 1] >= 100 && tones[i + 1] <= 1000, name + ": " + tones);
        }
    }
}

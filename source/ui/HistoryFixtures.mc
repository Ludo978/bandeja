import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Debug builds only: a full history for the history screens and the memory
// checks, from the sensor lock's debug menu ("History: 20 matches", "History: clear"). The records
// are written as they are, without the engine (20 matches through it in one callback would trip the
// watchdog): a win, a loss in a super tie-break, a best of 5, a draw after End match, a match saved
// mid-set from the pause menu, one set with serve tracking off and no heart rate, a pro set, a loss
// in three sets, a short sets match and a whitewash, then the same ten again a week earlier.
// Each starts a day before the one after it. The stats follow the games: four points per game won
// and two per game lost, a tie-break's or the super tie-break's points as scored. The first three have
// team names, as Settings.readTeamName() keeps them: two names, their name alone (cut at 12),
// and the widest 12 characters.
(:debug)
module HistoryFixtures {

    const NAMES = [["Hugo & Lena", "Las Panteras"], [null, "Los Galácticos"], ["Łukasz & Zoë", "MMMMMMMMMMMM"]];

    // Each match: its format (formatOf()), its result, its sets (our score,
    // theirs, the winner or -1 for the set the match ended in, 1 for a super tie-break), serve
    // tracking on (1) or off (0), the heart rate known (1) or not (0).
    const MATCHES = [
        ["best of 3", RESULT_WIN, [6, 4, 0, 0, 6, 3, 0, 0], 1, 1],
        ["super TB", RESULT_LOSS, [6, 4, 0, 0, 3, 6, 1, 0, 8, 10, 1, 1], 1, 1],
        ["best of 5", RESULT_WIN, [6, 4, 0, 0, 3, 6, 1, 0, 7, 6, 0, 0, 4, 6, 1, 0, 6, 2, 0, 0], 1, 1],
        ["best of 3", RESULT_DRAW, [6, 4, 0, 0, 4, 6, 1, 0, 2, 2, -1, 0], 1, 1],
        ["best of 3", RESULT_UNFINISHED, [6, 3, 0, 0, 2, 1, -1, 0], 1, 1],
        ["1 set", RESULT_LOSS, [4, 6, 1, 0], 0, 0],
        ["pro set", RESULT_WIN, [9, 7, 0, 0], 1, 1],
        ["best of 3", RESULT_LOSS, [7, 6, 0, 0, 3, 6, 1, 0, 4, 6, 1, 0], 1, 1],
        ["short sets", RESULT_WIN, [4, 2, 0, 0, 4, 1, 0, 0], 1, 1],
        ["best of 3", RESULT_WIN, [6, 0, 0, 0, 6, 0, 0, 0], 0, 1]
    ];

    // The 20 records, newest first, the newest starting an hour before now.
    function records(now as Number) as Array<HistoryRecord> {
        var list = [] as Array<HistoryRecord>;
        for (var i = 0; i < 2 * MATCHES.size(); i++) {
            var match = MATCHES[i % MATCHES.size()] as Array;
            list.add(record(now - 3600 - 86400 * i, match, i));
        }
        return list;
    }

    // The history holds the 20 records, whatever it held, and the glance shows the newest.
    function fill() as Void {
        var list = records(Time.now().value());
        var values = [] as Array<Application.Storage.ValueType>;
        for (var i = 0; i < list.size(); i++) {
            values.add(list[i].toValue());
        }
        if (HistoryStore.write(values)) {
            HistoryStore.writeLast(list[0]);
        }
    }

    // MATCHES' formats: the presets, Star point.
    function formatOf(name as String) as MatchConfig {
        var config = new MatchConfig();
        if (name.equals("super TB")) {
            config.applyPreset(PRESET_BEST_OF_3_SUPER_TB);
        } else if (name.equals("1 set")) {
            config.applyPreset(PRESET_ONE_SET);
        } else if (name.equals("pro set")) {
            config.applyPreset(PRESET_PRO_SET);
        } else if (name.equals("best of 5")) {
            config.applyPreset(PRESET_BEST_OF_5);
        } else if (name.equals("short sets")) {
            config.applyPreset(PRESET_SHORT_SETS);
        }
        return config;
    }

    function record(start as Number, match as Array, seed as Number) as HistoryRecord {
        var config = formatOf(match[0] as String);
        var sets = match[2] as Array<Number>;
        var rows = [] as Array<SummaryRow>;
        var m = new MatchStats();
        var tieBreakPoints = [0, 0];
        for (var i = 0; i < sets.size(); i += 4) {
            var us = sets[i];
            var them = sets[i + 1];
            var winner = sets[i + 2];
            var superTieBreak = sets[i + 3] == 1;
            rows.add(new SummaryRow(i / 4 + 1, superTieBreak, [us, them], winner < 0 ? null : winner as Team));
            if (winner == TEAM_US) {
                m.setsWon++;
            } else if (winner == TEAM_THEM) {
                m.setsLost++;
            }
            if (superTieBreak) {
                tieBreakPoints[TEAM_US] += us;
                tieBreakPoints[TEAM_THEM] += them;
                m.tieBreaksPlayed++;
                m.tieBreaksWon += winner == TEAM_US ? 1 : 0;
            } else {
                m.gamesWon += us;
                m.gamesLost += them;
                if (us + them == 13) {
                    tieBreakPoints[TEAM_US] += us > them ? 7 : 4;
                    tieBreakPoints[TEAM_THEM] += us > them ? 4 : 7;
                    m.tieBreaksPlayed++;
                    m.tieBreaksWon += us > them ? 1 : 0;
                }
            }
        }
        m.pointsWon = 4 * m.gamesWon + 2 * m.gamesLost + tieBreakPoints[TEAM_US];
        m.pointsLost = 4 * m.gamesLost + 2 * m.gamesWon + tieBreakPoints[TEAM_THEM];
        var games = m.gamesWon + m.gamesLost;
        m.gameDurations = [240 + 13 * (seed % 10)];
        m.longestGame = 0;
        m.decidingPointsPlayed = games / 4;
        m.decidingPointsWon = games / 8;
        var average = 36 + seed % 9;
        m.averagePointTime = average;
        m.longestStreak = 3 + seed % 6;
        if ((match[3] as Number) == 1) {
            var points = m.pointsWon + m.pointsLost;
            var served = points / 2;
            var servedWon = served * (m.pointsWon > m.pointsLost ? 64 : 48) / 100;
            var conceded = m.gamesLost / 4;
            var broke = m.gamesWon / 4;
            m.servePointsPlayed = served;
            m.servePointsWon = servedWon;
            m.returnPointsPlayed = points - served;
            m.returnPointsWon = m.pointsWon - servedWon;
            m.serviceGamesPlayed = games / 2;
            m.serviceGamesHeld = games / 2 - conceded;
            m.breaksConceded = conceded;
            m.returnGamesPlayed = games - games / 2;
            m.breaksWon = broke;
            m.breakPointsPlayed = 2 * broke + 1;
            m.breakPointsConverted = broke;
            m.breakPointsFaced = 2 * conceded + 1;
            m.breakPointsSaved = conceded + 1;
        }
        var timer = (m.pointsWon + m.pointsLost) * average;
        var heartRate = (match[4] as Number) == 1;
        var record = new HistoryRecord(start, config, match[1] as MatchResult, rows, m,
            [timer, heartRate ? 138 + seed % 12 : null, heartRate ? 168 + seed % 15 : null, timer / 7]);
        if (seed < NAMES.size()) {
            var names = NAMES[seed] as Array<String?>;
            record.names = [Settings.readTeamName(names[TEAM_US]), Settings.readTeamName(names[TEAM_THEM])];
        }
        return record;
    }
}

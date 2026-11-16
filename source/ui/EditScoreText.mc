import Toybox.Lang;
import Toybox.WatchUi;

// What the Edit score menu and its lists show: scores our side first ("6-4"); a regular
// game's points as the score screen shows them ("30-15", "AD-40", AD in the watch's language), with
// the deuce its net banner names ("Deuce 2", the deciding point) where the game's rule counts them; a
// tie-break's points as numbers. Item labels: "Set n", "Game" / "Tie-break" (Tie-break only's too) /
// "Super tie-break", "Add set", "Remove set n", "Apply"; under the items, their part of the draft.
module EditScoreText {

    // "6-4", our side first.
    function pair(values as Array<Number>) as String {
        return values[TEAM_US] + "-" + values[TEAM_THEM];
    }

    // A regular game's point counts as the screen shows them, "AD-40"; a tie-break's as numbers.
    function points(values as Array<Number>, type as GameType) as String {
        if (type != GAME_REGULAR) {
            return pair(values);
        }
        var ad = WatchUi.loadResource(Rez.Strings.PointsAd) as String;
        return ScoreModel.pointsText(MatchState.pointDisplay(values[TEAM_US], values[TEAM_THEM]), ad) + "-"
            + ScoreModel.pointsText(MatchState.pointDisplay(values[TEAM_THEM], values[TEAM_US]), ad);
    }

    // What the net banner calls a regular game's point counts under mode: the deciding
    // point by its mode's name ("Star point"), "Deuce n" before it with Star and Silver (n kept through
    // the advantage after it); null before 40-40, and with Advantage, which counts no deuces.
    function deuceName(values as Array<Number>, mode as DeuceMode) as String? {
        var us = values[TEAM_US];
        var them = values[TEAM_THEM];
        var low = us < them ? us : them;
        var deuce = low >= 3 ? low - 2 : 0;
        if (deuce == 0) {
            return null;
        } else if (us == them && deuce == MatchState.decidingDeuce(mode)) {
            return text(FormatText.deuceModeName(mode));
        } else if (mode == DEUCE_STAR || mode == DEUCE_SILVER) {
            return Lang.format(text(Rez.Strings.EditDeuce), [deuce]);
        }
        return null;
    }

    function label(rules as EditScoreRules, item as Number) as String {
        if (item == EditScoreRules.ITEM_GAMES) {
            return setLabel(rules.getSetNumber());
        } else if (item == EditScoreRules.ITEM_POINTS) {
            // Tie-break only's one set is a tie-break, not a super tie-break.
            var type = rules.getGameType();
            var tieBreak = type == GAME_TIE_BREAK || rules.match.engine.getConfig().isTieBreakOnly();
            return text(type == GAME_REGULAR ? Rez.Strings.EditGame
                : tieBreak ? Rez.Strings.MenuTieBreak : Rez.Strings.EditSuperTieBreak);
        } else if (item == EditScoreRules.ITEM_ADD_SET) {
            return text(Rez.Strings.EditAddSet);
        } else if (item == EditScoreRules.ITEM_REMOVE_SET) {
            return Lang.format(text(Rez.Strings.EditRemoveSet), [rules.sets.size()]);
        } else if (item == EditScoreRules.ITEM_APPLY) {
            return text(Rez.Strings.EditApply);
        }
        return setLabel(item - EditScoreRules.ITEM_SET + 1);
    }

    // Under an item, its part of the draft: a set's games, the current set's games, the game's points
    // and their deuce ("AD-40 · Deuce 1"). None under Add set, Remove set and Apply.
    function value(rules as EditScoreRules, item as Number) as String? {
        if (item == EditScoreRules.ITEM_GAMES) {
            return pair(rules.games);
        } else if (item == EditScoreRules.ITEM_POINTS) {
            var type = rules.getGameType();
            var name = type == GAME_REGULAR ? deuceName(rules.points, rules.getDeuceMode()) : null;
            return points(rules.points, type) + (name != null ? FormatText.SEPARATOR + name : "");
        } else if (item < EditScoreRules.ITEM_SET) {
            return null;
        }
        return pair(rules.sets[item - EditScoreRules.ITEM_SET].games);
    }

    // "Set 2".
    function setLabel(number as Number) as String {
        return Lang.format(text(Rez.Strings.EditSet), [number]);
    }

    function text(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }
}

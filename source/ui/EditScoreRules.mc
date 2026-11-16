import Toybox.Lang;

// Edit score without its native menus (EditScoreMenu), so it's unit-tested: a draft
// of the score, the match's own when the menu opens, whose parts are each picked from a list holding
// only the values the format allows with the rest of the draft (ScoreEdit's own rules), so the draft
// is always a score EDIT_SCORE accepts, or the match's own. apply() logs it as one event, through the
// match holder, and refuses the match's own score (an edit that changes nothing); leaving the menu
// drops the draft, so nothing is logged.
//
// The menu's items (getItems()): one per finished set, the current set's games (none in the super
// tie-break, which has no games), the game's points (a tie-break's or the super tie-break's), Add set
// while another finished set leaves both teams short of the sets that win the match (in Free play, up to
// ScoreEdit.MAX sets) and the edit it makes still fits the log (ScoringEngine.hasRoomFor()), Remove set
// (the last finished one) with a finished set, and Apply.
//  - A finished set (getSetChoices()): one list of the scores it can be won with, ours then theirs,
//    only the winners that leave both teams short of the match. 7-6 keeps the tie-break's points the
//    set had, or else L-(L-2), which no screen shows. A set End set now gave, and one the list doesn't
//    hold, is offered first, as it is.
//  - The set in progress's games and a tie-break's points (isByTeam()): two short lists, our count,
//    then theirs among those that go with ours.
//  - A regular game's points (getPointsChoices()): one list of point counts, in the order a game
//    reaches them, then the deuces the game's rule reaches.
// Adding or removing a set keeps the current set's games when the set in progress can have them
// (0-0 otherwise, always in the super tie-break), and the points unless the game becomes another kind
// (a regular game, a tie-break, the super tie-break), which starts at 0-0. Changing the games does the
// same to the points.
class EditScoreRules {

    // The menu's items, also their menu item IDs: a finished set is ITEM_SET + its index, after the others
    // (Free play has any number of sets).
    static const ITEM_SET = 100;
    static const ITEM_GAMES = 10;
    static const ITEM_POINTS = 11;
    static const ITEM_ADD_SET = 12;
    static const ITEM_REMOVE_SET = 13;
    static const ITEM_APPLY = 14;

    // How far past the format's length the lists of counts go where nothing caps them: a set without a
    // tie-break (to N + LONG games) and a tie-break's points (to its length + LONG). The draft's own
    // count is always in them.
    static const LONG = 5;

    var match as CurrentMatch;
    // The draft: the finished sets, the current set's games, the game's points (counts), per Team.
    var sets as Array<SetScore>;
    var games as Array<Number>;
    var points as Array<Number>;
    private var _config as MatchConfig;

    function initialize(match as CurrentMatch) {
        self.match = match;
        _config = match.engine.getConfig();
        var state = match.getState();
        sets = [] as Array<SetScore>;
        for (var i = 0; i < state.setScores.size(); i++) {
            sets.add(state.setScores[i].copy());
        }
        games = [state.games[TEAM_US], state.games[TEAM_THEM]];
        points = [state.gamePoints[TEAM_US], state.gamePoints[TEAM_THEM]];
    }

    function getItems() as Array<Number> {
        var items = [] as Array<Number>;
        for (var i = 0; i < sets.size(); i++) {
            items.add(ITEM_SET + i);
        }
        if (getGameType() != GAME_SUPER_TIE_BREAK) {
            items.add(ITEM_GAMES);
        }
        items.add(ITEM_POINTS);
        if (canAddSet()) {
            items.add(ITEM_ADD_SET);
        }
        if (sets.size() > 0) {
            items.add(ITEM_REMOVE_SET);
        }
        items.add(ITEM_APPLY);
        return items;
    }

    // The set in progress in the draft, from 1.
    function getSetNumber() as Number {
        return sets.size() + 1;
    }

    // The game in progress in the draft: the super tie-break, a tie-break, or a regular game.
    function getGameType() as GameType {
        return getEdit().getGameType(_config);
    }

    // The rule the draft's game is played with: the game in progress keeps its own, and at
    // 0-0 the mode chosen last applies.
    function getDeuceMode() as DeuceMode {
        return getEdit().getGameDeuceMode(match.getState());
    }

    // Another finished set fits before the set in progress: after it, a set is still to be played (Free
    // play: ScoreEdit.MAX sets at most), and the log has room for the edit.
    function canAddSet() as Boolean {
        var count = sets.size() + 1;
        return (_config.isFreePlay() ? count <= ScoreEdit.MAX : count + 1 <= _config.maxSets()) && fits(match.engine, count);
    }

    // The engine's log has room for an edit with count finished sets (the Edit score item shows when the
    // match's own count fits, MatchMenuRules).
    static function fits(engine as ScoringEngine, count as Number) as Boolean {
        return engine.hasRoomFor(ScoringEngine.LOG_NUMBERS_PER_EVENT + ScoreEdit.SET_NUMBERS * (count + 1));
    }

    // The scores finished set index can have (index sets.size(): the set Add set adds): those it can
    // be won with in the format, by games or in the tie-break, ours then theirs, each by the
    // loser's games, only for a winner that leaves both teams short of the sets that win the match with
    // the other sets. The set as it is comes first when the list wouldn't hold it (End set now gave it,
    // or it's longer than the list goes).
    function getSetChoices(index as Number) as Array<SetScore> {
        var current = index < sets.size() ? sets[index] : null;
        var won = [0, 0];
        for (var i = 0; i < sets.size(); i++) {
            if (i != index) {
                won[sets[i].winner] += 1;
            }
        }
        var c = _config;
        var most = c.hasTieBreak ? c.tieBreakAt + 1 : c.gamesToWin + LONG;
        var choices = [] as Array<SetScore>;
        for (var winner = 0; winner < 2; winner++) {
            if (c.winsMatch(won[winner] + 1)) {
                continue;
            }
            var team = winner as Team;
            for (var w = c.gamesToWin; w <= most; w++) {
                for (var l = 0; l < w; l++) {
                    var set = new SetScore(team == TEAM_US ? [w, l] : [l, w], null, false, team, false);
                    if (!ScoreEdit.isFinishedSet(c, set)) {
                        set.tieBreakPoints = tieBreakOf(current, set);
                        if (!ScoreEdit.isFinishedSet(c, set)) {
                            continue;
                        }
                    }
                    choices.add(set);
                }
            }
        }
        if (current != null && indexOf(choices, current) < 0) {
            var first = [current] as Array<SetScore>;
            first.addAll(choices);
            return first;
        }
        return choices;
    }

    // Where set is in choices, -1 when it isn't.
    static function indexOf(choices as Array<SetScore>, set as SetScore) as Number {
        for (var i = 0; i < choices.size(); i++) {
            if (choices[i].equals(set)) {
                return i;
            }
        }
        return -1;
    }

    // Finished set index takes the score; index sets.size() adds it (Add set).
    function setSet(index as Number, set as SetScore) as Void {
        if (index < sets.size()) {
            sets[index] = set;
            return;
        }
        var type = getGameType();
        sets.add(set);
        settle(type);
    }

    // Remove set: the last finished set goes.
    function removeSet() as Void {
        var type = getGameType();
        sets = sets.slice(0, sets.size() - 1);
        settle(type);
    }

    // Picked one team at a time: the set in progress's games, and a tie-break's or the super
    // tie-break's points. A regular game's points are one list.
    function isByTeam(item as Number) as Boolean {
        return item == ITEM_GAMES || getGameType() != GAME_REGULAR;
    }

    // Our counts for ITEM_GAMES or a tie-break's ITEM_POINTS, from 0: those some count of theirs goes
    // with, to T games with a tie-break, else to N + LONG games or the tie-break's length + LONG
    // points, and ours in the draft.
    function getOurChoices(item as Number) as Array<Number> {
        var isGames = item == ITEM_GAMES;
        var c = _config;
        var most = isGames ? (c.hasTieBreak ? c.tieBreakAt : c.gamesToWin + LONG) : getLength() + LONG;
        var mine = (isGames ? games : points)[TEAM_US];
        if (mine > most) {
            most = mine;
        }
        var choices = [] as Array<Number>;
        for (var us = 0; us <= most; us++) {
            if (getTheirChoices(item, us).size() > 0) {
                choices.add(us);
            }
        }
        return choices;
    }

    // Their counts that go with ours: the set in progress not won by either team, no more than T each
    // with a tie-break; the tie-break not won by either.
    function getTheirChoices(item as Number, us as Number) as Array<Number> {
        var choices = [] as Array<Number>;
        if (item == ITEM_GAMES) {
            for (var them = 0; them <= us + _config.gamesToWin; them++) {
                if (ScoreEdit.isSetInProgress(_config, us, them)) {
                    choices.add(them);
                }
            }
            return choices;
        }
        var type = getGameType();
        for (var them = 0; them <= us + getLength(); them++) {
            if (ScoreEdit.isGameInProgress(_config, type, DEUCE_ADVANTAGE, us, them)) {
                choices.add(them);
            }
        }
        return choices;
    }

    // ITEM_GAMES or ITEM_POINTS takes the counts. New games may make the game another kind, which
    // then starts at 0-0.
    function setPair(item as Number, us as Number, them as Number) as Void {
        if (item == ITEM_POINTS) {
            points = [us, them];
            return;
        }
        var type = getGameType();
        games = [us, them];
        if (getGameType() != type) {
            points = [0, 0];
        }
    }

    // A regular game's point counts, in the order a game reaches them (by points played, ours ahead
    // first): 0-0, 15-0, 0-15, 30-0 ... 30-40, then the deuces the game's rule reaches, each 40-40 and
    // the advantages after it: Advantage deuce 1 only (no deuce count shows), Golden 40-40, Silver up to
    // its deuce 2, Star up to its deuce 3 (deuce n is n + 2 points each). The game's rule is the one it
    // is played with. The entry that shows the draft's points holds its counts (an Advantage game
    // played past deuce 1).
    function getPointsChoices() as Array<Array<Number> > {
        var mode = match.getState().gameDeuceMode;
        var deciding = MatchState.decidingDeuce(mode);
        var deuces = deciding > 0 ? deciding : 1;
        var most = deuces + 3;
        var choices = [] as Array<Array<Number> >;
        var found = false;
        for (var total = 0; total <= 2 * most; total++) {
            for (var us = total; us >= 0; us--) {
                var them = total - us;
                var low = us < them ? us : them;
                if (us > most || them > most || low - 2 > deuces
                        || !ScoreEdit.isGameInProgress(_config, GAME_REGULAR, mode, us, them)) {
                    continue;
                }
                choices.add([us, them]);
                found = found || (us == points[TEAM_US] && them == points[TEAM_THEM]);
            }
        }
        if (!found) {
            for (var i = 0; i < choices.size(); i++) {
                if (sameDisplay(choices[i], points)) {
                    choices[i] = [points[TEAM_US], points[TEAM_THEM]];
                    break;
                }
            }
        }
        return choices;
    }

    // The draft as the edit it would log.
    function getEdit() as ScoreEdit {
        return new ScoreEdit(sets.slice(0, null), [games[TEAM_US], games[TEAM_THEM]], [points[TEAM_US], points[TEAM_THEM]]);
    }

    // Apply: the draft logged as one EDIT_SCORE event at time (MatchEvent.editScore()). False, logging
    // nothing, when it's the match's own score (or the match is over, when the menu isn't offered).
    function apply(time as Number) as Boolean {
        return match.add(MatchEvent.editScore(time, getEdit()));
    }

    // The tie-break or super tie-break's length in points (Tie-break only's, 7 or 10).
    private function getLength() as Number {
        return getGameType() == GAME_SUPER_TIE_BREAK ? _config.superTieBreakPoints() : _config.tieBreakPoints;
    }

    // After the set count changed (before: the game's kind then): the games the set in progress can't
    // have go back to 0-0, and so do the points when the game is another kind.
    private function settle(before as GameType) as Void {
        if (getGameType() == GAME_SUPER_TIE_BREAK || !ScoreEdit.isSetInProgress(_config, games[TEAM_US], games[TEAM_THEM])) {
            games = [0, 0];
        }
        if (getGameType() != before) {
            points = [0, 0];
        }
    }

    // The tie-break points of a set won 7-6: the current set's when it was that score, else L-(L-2) to
    // its winner.
    private function tieBreakOf(current as SetScore?, set as SetScore) as Array<Number> {
        var points = current != null ? current.tieBreakPoints : null;
        if (current != null && points != null && !current.endedEarly && current.winner == set.winner
                && current.games[TEAM_US] == set.games[TEAM_US] && current.games[TEAM_THEM] == set.games[TEAM_THEM]) {
            return [points[TEAM_US], points[TEAM_THEM]];
        }
        var length = _config.tieBreakPoints;
        return set.winner == TEAM_US ? [length, length - 2] : [length - 2, length];
    }

    private static function sameDisplay(mine as Array<Number>, others as Array<Number>) as Boolean {
        var us = TEAM_US;
        var them = TEAM_THEM;
        return MatchState.pointDisplay(mine[us], mine[them]) == MatchState.pointDisplay(others[us], others[them])
            && MatchState.pointDisplay(mine[them], mine[us]) == MatchState.pointDisplay(others[them], others[us]);
    }
}

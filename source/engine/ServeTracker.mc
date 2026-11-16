import Toybox.Lang;

// Who serves and when the players change ends: the rules ScoringEngine applies
// to the state. MatchState.getServingTeam(), getServingPlayer(), getServeSide() and
// getChangeOfEndsAt() read the result.
//
// The state only keeps the game's server: the team serving it and our player for our current or
// next service game. A tie-break is one game in the rotation, served by the team and player whose
// turn it is: they serve its first point, then the turns go on two points each, alternating the
// teams and each team's players. After it the rotation goes on as after any game, so the pair that
// didn't serve its first point serves next, opening the next set, and each pair's next player is
// the one after the player who served the tie-break for it. While the serving
// team is unknown (serve tracking off), nothing rotates.
module ServeTracker {

    // A point was just played: the 6th, 12th... point of a tie-break changes ends.
    function pointPlayed(state as MatchState) as Void {
        var played = state.gamePoints[TEAM_US] + state.gamePoints[TEAM_THEM];
        if (state.isTieBreak() && played % MatchState.CHANGE_OF_ENDS_POINTS == 0) {
            state.changeOfEnds = true;
        }
    }

    // The game in progress went to winner, already counted in the set's games: the game is kept
    // with its server and the set's score after it, the ends change after game 1, 3, 5... of the set
    // (so at the end of a set with an odd count), and the serve passes to the other team, to our other
    // player after a game we served.
    function gameWon(state as MatchState, winner as Team) as Void {
        var server = state.servingTeam;
        // The set's score: its games, the super tie-break's points (MatchState.getCurrentSetScore()).
        var score = state.gameType == GAME_SUPER_TIE_BREAK ? state.gamePoints : state.games;
        state.finishedGames.add(MatchState.finishedGameCode(state.setScores.size(), score[TEAM_US], score[TEAM_THEM],
            state.gameType, server, winner));
        if ((state.games[TEAM_US] + state.games[TEAM_THEM]) % 2 == 1) {
            state.changeOfEnds = true;
        }
        if (server != null) {
            if (server == TEAM_US && state.doubles) {
                swapOurServer(state);
            }
            state.servingTeam = MatchState.otherTeam(server);
        }
    }

    // FIX_SERVING_TEAM: team serves the current point. In a tie-break the turns around it shift
    // with it, so the team of its first turn is kept.
    function fixServingTeam(state as MatchState, team as Team) as Void {
        state.servingTeam = state.getServeTurn() % 2 == 0 ? team : MatchState.otherTeam(team);
    }

    // SWAP_OUR_SERVER: our two players swap their serving order.
    function swapOurServer(state as MatchState) as Void {
        state.ourServer = state.ourServer == PLAYER_ME ? PLAYER_PARTNER : PLAYER_ME;
    }
}

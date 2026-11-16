import Toybox.Lang;

// The banner on the net line of the score screen, one at a time. Listed by priority,
// highest first; not stored, so the values can change.
enum Banner {
    BANNER_NONE = 0,
    BANNER_STAR_POINT = 1,   // the deciding point, named by the game's deuce mode
    BANNER_SILVER_POINT = 2,
    BANNER_GOLDEN_POINT = 3,
    BANNER_MATCH_POINT = 4,
    BANNER_SET_POINT = 5,
    BANNER_BREAK_POINT = 6,
    BANNER_DEUCE = 7,        // DEUCE n, with n in MatchSituation.bannerNumber
    BANNER_TIE_BREAK = 8,    // a tie-break or the super tie-break
    // A timed match's court time (CourtBooking.getBanner()), when the score gives none of the above.
    BANNER_TIME_LEFT = 9,    // TIME LEFT m:ss, the last 5 minutes
    BANNER_TIME = 10         // TIME, once the end time has passed, until Finish or Keep playing
}

// How the banner is drawn (mockups). The UI picks the colors.
enum BannerStyle {
    BANNER_STYLE_INFO = 0,     // outlined, neutral: DEUCE n, TIE-BREAK
    BANNER_STYLE_PRESSURE = 1, // outlined in the ball's yellow: MATCH POINT, SET POINT, BREAK POINT, TIME LEFT
    BANNER_STYLE_DECIDING = 2  // solid ball yellow: STAR, SILVER, GOLDEN POINT, TIME
}

// The caption at the bottom of the score screen.
enum Caption {
    CAPTION_NONE = 0,             // the match is over
    CAPTION_SET = 1,              // SET n
    CAPTION_CHANGE_ENDS_AT = 2,   // CHANGE ENDS AT n, in a tie-break or the super tie-break
    CAPTION_RECEIVERS_CHOOSE = 3, // a deciding point: the receiving pair picks who receives
    CAPTION_SAME_SEX_RECEIVES = 4 // a deciding point in mixed doubles
}

// The situation of the point about to be played: who has a break, set or match point, whether it
// decides the game or is a tie-break point, and what the score screen shows for it on the net and
// in the bottom caption. Worked out from the format and the state on demand, so the
// state updated event by event, an undo and a replay all give the same. Nothing once the match is
// over. Read-only.
class MatchSituation {

    // The receivers, when the next point would win them the game: a regular game whose serving team
    // is known (serve tracking on), a deciding point included. Never in a tie-break.
    var breakPoint as Team? = null;
    // The team that would win the set with the next point, a tie-break's or the super tie-break's
    // included. Never both teams: one of them can't be two games ahead after the game.
    var setPoint as Team? = null;
    // The team that would win the match with the next point: a set point in the last set it needs.
    var matchPoint as Team? = null;
    // The next point decides the game, for both teams (MatchState.isDecidingPoint()).
    var decidingPoint as Boolean = false;
    // A tie-break or the super tie-break is in play.
    var tieBreak as Boolean = false;
    var banner as Banner = BANNER_NONE;
    // n for BANNER_DEUCE, 0 otherwise.
    var bannerNumber as Number = 0;
    var caption as Caption = CAPTION_NONE;
    // n for CAPTION_SET (the set's number, 1 for the first) and CAPTION_CHANGE_ENDS_AT (the
    // tie-break points played at the next change of ends), 0 otherwise.
    var captionNumber as Number = 0;

    function initialize(config as MatchConfig, state as MatchState) {
        if (state.matchOver) {
            return;
        }
        decidingPoint = state.isDecidingPoint();
        tieBreak = state.isTieBreak();
        addGamePoint(config, state, TEAM_US);
        addGamePoint(config, state, TEAM_THEM);
        setBanner(state);
        setCaption(config, state);
    }

    // How the banner is drawn: outlined for information, outlined in yellow for a match, set or
    // break point, solid yellow for a deciding point.
    function getBannerStyle() as BannerStyle {
        return styleOf(banner);
    }

    // A banner's style, the court time's included: TIME LEFT outlined in yellow, TIME solid yellow.
    static function styleOf(banner as Banner) as BannerStyle {
        if (banner == BANNER_STAR_POINT || banner == BANNER_SILVER_POINT || banner == BANNER_GOLDEN_POINT
                || banner == BANNER_TIME) {
            return BANNER_STYLE_DECIDING;
        } else if (banner == BANNER_MATCH_POINT || banner == BANNER_SET_POINT || banner == BANNER_BREAK_POINT
                || banner == BANNER_TIME_LEFT) {
            return BANNER_STYLE_PRESSURE;
        }
        return BANNER_STYLE_INFO;
    }

    // Whether the next point would win the team the game in progress: a deciding point, or the
    // game's length with a 2-point lead. The stats count break points with it too.
    static function isGamePoint(config as MatchConfig, state as MatchState, team as Team) as Boolean {
        return state.isDecidingPoint()
            || config.isGameWon(state.gameType, state.gamePoints[team] + 1, state.gamePoints[MatchState.otherTeam(team)]);
    }

    // The flags the team gets when the next point would win it the game in progress.
    private function addGamePoint(config as MatchConfig, state as MatchState, team as Team) as Void {
        if (!isGamePoint(config, state, team)) {
            return;
        }
        var other = MatchState.otherTeam(team);
        if (!tieBreak && state.getServingTeam() == other) {
            breakPoint = team;
        }
        // A tie-break or the super tie-break is the set's last game.
        if (tieBreak || config.isSetWon(state.games[team] + 1, state.games[other])) {
            setPoint = team;
            if (config.winsMatch(state.getSetsWon(team) + 1)) {
                matchPoint = team;
            }
        }
    }

    // The first banner in the order whose flag holds. The deciding point comes first:
    // it decides the game for both teams, whatever else rides on it.
    private function setBanner(state as MatchState) as Void {
        var mode = state.gameDeuceMode;
        if (decidingPoint) {
            if (mode == DEUCE_GOLDEN) {
                banner = BANNER_GOLDEN_POINT;
            } else if (mode == DEUCE_SILVER) {
                banner = BANNER_SILVER_POINT;
            } else {
                banner = BANNER_STAR_POINT;
            }
        } else if (matchPoint != null) {
            banner = BANNER_MATCH_POINT;
        } else if (setPoint != null) {
            banner = BANNER_SET_POINT;
        } else if (breakPoint != null) {
            banner = BANNER_BREAK_POINT;
        } else if ((mode == DEUCE_STAR || mode == DEUCE_SILVER) && state.getDeuceCount() > 0) {
            // The FIP counter before a Star or Silver point, through the advantage after each deuce.
            banner = BANNER_DEUCE;
            bannerNumber = state.getDeuceCount();
        } else if (tieBreak) {
            banner = BANNER_TIE_BREAK;
        }
    }

    private function setCaption(config as MatchConfig, state as MatchState) as Void {
        if (decidingPoint) {
            // Mixed only exists in doubles.
            caption = config.mixed && config.doubles ? CAPTION_SAME_SEX_RECEIVES : CAPTION_RECEIVERS_CHOOSE;
        } else if (tieBreak) {
            caption = CAPTION_CHANGE_ENDS_AT;
            captionNumber = state.getChangeOfEndsAt() as Number;
        } else {
            caption = CAPTION_SET;
            captionNumber = state.setScores.size() + 1;
        }
    }
}

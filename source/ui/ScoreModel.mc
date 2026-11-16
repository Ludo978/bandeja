import Toybox.Graphics;
import Toybox.Lang;

// What the score screen shows for the match as it stands, worked out once per change
// from the format, the state and the Change of ends alert setting: each team's points, games and set
// pips, the serve dot and our player serving, the net banner and the bottom caption (MatchSituation).
// Numbers, resource IDs and mockup positions only: ScoreView loads the strings, measures and draws,
// so this is unit-tested.
// A timed match's court time banner, the lowest, follows the clock: setCourt() at each tick.
class ScoreModel {

    // The points and the banner are centered on this mockup x, between the games tiles and the mini
    // court.
    static const BANNER_X = 250;
    // The banner pill (mockups): its text plus BANNER_MARGIN on each side, or less, down to
    // BANNER_MIN_MARGIN, so the pill ends at least 10 before the mini court (left edge 352).
    static const BANNER_MARGIN = 30;
    static const BANNER_MIN_MARGIN = 16;
    static const BANNER_MAX_WIDTH = 184;
    // The widest banner text at the mockup size; a wider one gets a smaller font (Layout.fitSize()).
    static const BANNER_TEXT_MAX = 152;

    // The serve dot's centers on the mini court (352 to 404 wide, 202 to 278 high, net at 240): each
    // column's middle and the center line, each half's middle.
    static const DOT_LEFT_X = 365;
    static const DOT_CENTER_X = 378;
    static const DOT_RIGHT_X = 391;
    static const DOT_THEM_Y = 221;
    static const DOT_US_Y = 259;

    // Per team (indexed by Team): MatchState.getPointDisplay() (POINTS_AD for the advantage, plain
    // numbers in a tie-break), the games of the current set, the sets won.
    var points as Array<Number>;
    var games as Array<Number>;
    var setsWon as Array<Number>;
    // One pip per set needed to win the match. None in Free play, which has no end: the sets
    // won show as a number in their place (setsAsNumber).
    var pips as Number;
    var setsAsNumber as Boolean;
    var banner as Banner;
    // n of DEUCE n; the seconds left of TIME LEFT.
    var bannerNumber as Number;
    var bannerStyle as BannerStyle;
    var caption as Caption;
    // n of SET n and CHANGE ENDS AT n.
    var captionNumber as Number;
    // The serve dot's mockup center, null when there's no ball: the server unknown, or the match over.
    var dot as Array<Number>? = null;
    // Our player serving the point (YOU / PARTNER under the court), null when they serve or the server
    // is unknown.
    var server as Player? = null;

    // The score's own banner (MatchSituation), which the court time's never replaces.
    private var _scoreBanner as Banner;
    private var _over as Boolean;

    // endsAlert: the Change of ends alert setting. Off, the tie-break's CHANGE ENDS AT n
    // goes too, and the caption shows the set there, as in a game.
    function initialize(config as MatchConfig, state as MatchState, endsAlert as Boolean) {
        points = [state.getPointDisplay(TEAM_US), state.getPointDisplay(TEAM_THEM)];
        games = [state.games[TEAM_US], state.games[TEAM_THEM]];
        setsWon = [state.getSetsWon(TEAM_US), state.getSetsWon(TEAM_THEM)];
        pips = config.setsToWin;
        setsAsNumber = config.isFreePlay();
        var situation = new MatchSituation(config, state);
        banner = situation.banner;
        _scoreBanner = banner;
        _over = state.matchOver;
        bannerNumber = situation.bannerNumber;
        bannerStyle = situation.getBannerStyle();
        caption = situation.caption;
        captionNumber = situation.captionNumber;
        if (caption == CAPTION_CHANGE_ENDS_AT && !endsAlert) {
            caption = CAPTION_SET;
            captionNumber = state.setScores.size() + 1;
        }
        // Once the match is over there's no next point to serve.
        if (!state.matchOver) {
            dot = dotPosition(state.getServingTeam(), state.getServeSide());
            server = state.getServingPlayer();
        }
    }

    // A timed match's court time banner at now (CourtBooking.getBanner(): TIME LEFT with its seconds
    // left, or TIME), when the score gives none: the lowest priority. None once the match
    // is over. True when the banner or its number changed.
    function setCourt(court as CourtBooking?, now as Number) as Boolean {
        if (_scoreBanner != BANNER_NONE || _over || court == null) {
            return false;
        }
        var courtBanner = court.getBanner(now);
        var number = courtBanner == BANNER_TIME_LEFT ? court.getLeft(now) : 0;
        if (courtBanner == banner && number == bannerNumber) {
            return false;
        }
        banner = courtBanner;
        bannerNumber = number;
        bannerStyle = MatchSituation.styleOf(courtBanner);
        return true;
    }

    // Whether the team's pip index (0 for the first) is filled: that many sets won.
    function isPipFilled(team as Team, index as Number) as Boolean {
        return index < setsWon[team];
    }

    // The serve dot's mockup center for the team serving and its side. The mini court
    // is seen from our end, like the screen: they serve in the top half, we serve in the bottom one;
    // our right is the screen's right, theirs the screen's left. No side is a deciding point (the
    // receivers choose): the dot sits on the center line. No team, no ball.
    static function dotPosition(team as Team?, side as Side?) as Array<Number>? {
        if (team == null) {
            return null;
        }
        var y = team == TEAM_US ? DOT_US_Y : DOT_THEM_Y;
        if (side == null) {
            return [DOT_CENTER_X, y];
        }
        var screenRight = (side == SIDE_RIGHT) == (team == TEAM_US);
        return [screenRight ? DOT_RIGHT_X : DOT_LEFT_X, y];
    }

    // A team's points as shown: the number, or ad (the translated AD) for the advantage.
    static function pointsText(display as Number, ad as String) as String {
        return display == MatchState.POINTS_AD ? ad : display.toString();
    }

    // AD has letters, which the number fonts' fallbacks don't.
    static function pointsStyle(display as Number) as FontStyle {
        return display == MatchState.POINTS_AD ? STYLE_BOLD : STYLE_NUMBER;
    }

    // The banner's string, null for none. DEUCE n takes its number ($1$), TIME LEFT the time left.
    static function bannerString(banner as Banner) as ResourceId? {
        if (banner == BANNER_STAR_POINT) {
            return Rez.Strings.BannerStarPoint;
        } else if (banner == BANNER_SILVER_POINT) {
            return Rez.Strings.BannerSilverPoint;
        } else if (banner == BANNER_GOLDEN_POINT) {
            return Rez.Strings.BannerGoldenPoint;
        } else if (banner == BANNER_MATCH_POINT) {
            return Rez.Strings.BannerMatchPoint;
        } else if (banner == BANNER_SET_POINT) {
            return Rez.Strings.BannerSetPoint;
        } else if (banner == BANNER_BREAK_POINT) {
            return Rez.Strings.BannerBreakPoint;
        } else if (banner == BANNER_DEUCE) {
            return Rez.Strings.BannerDeuce;
        } else if (banner == BANNER_TIE_BREAK) {
            return Rez.Strings.BannerTieBreak;
        } else if (banner == BANNER_TIME_LEFT) {
            return Rez.Strings.BannerTimeLeft;
        } else if (banner == BANNER_TIME) {
            return Rez.Strings.BannerTime;
        }
        return null;
    }

    // The toast a court time alert brings, here and on the warm-up screen; null for none.
    static function courtAlertString(alert as CourtAlert) as ResourceId? {
        if (alert == COURT_TEN) {
            return Rez.Strings.CourtTen;
        } else if (alert == COURT_FIVE) {
            return Rez.Strings.CourtFive;
        } else if (alert == COURT_TIME) {
            return Rez.Strings.CourtTime;
        }
        return null;
    }

    // The caption's string, null for none. SET n and CHANGE ENDS AT n take their number ($1$).
    static function captionString(caption as Caption) as ResourceId? {
        if (caption == CAPTION_SET) {
            return Rez.Strings.CaptionSet;
        } else if (caption == CAPTION_CHANGE_ENDS_AT) {
            return Rez.Strings.CaptionChangeEndsAt;
        } else if (caption == CAPTION_RECEIVERS_CHOOSE) {
            return Rez.Strings.CaptionReceiversChoose;
        } else if (caption == CAPTION_SAME_SEX_RECEIVES) {
            return Rez.Strings.CaptionSameSexReceives;
        }
        return null;
    }

    // YOU or PARTNER, null when none shows.
    static function serverString(player as Player?) as ResourceId? {
        if (player == PLAYER_ME) {
            return Rez.Strings.ServerYou;
        } else if (player == PLAYER_PARTNER) {
            return Rez.Strings.ServerPartner;
        }
        return null;
    }

    // The banner's fill, outline and text colors: outlined white for information,
    // outlined yellow for a match, set or break point, solid yellow for a deciding point.
    static function bannerColors(style as BannerStyle) as Array<Number> {
        if (style == BANNER_STYLE_DECIDING) {
            return [Palette.BALL, Palette.BALL, Palette.BG];
        } else if (style == BANNER_STYLE_PRESSURE) {
            return [Palette.BG, Palette.BALL, Palette.BALL];
        }
        return [Palette.BG, Palette.TEXT, Palette.TEXT];
    }

    // The receivers' choice on a deciding point is yellow, the set and the change of ends grey.
    static function captionColor(caption as Caption) as Number {
        return caption == CAPTION_RECEIVERS_CHOOSE || caption == CAPTION_SAME_SEX_RECEIVES ? Palette.BALL : Palette.MUTED;
    }

    // The pill's width for its text's (mockup pixels, at most BANNER_TEXT_MAX).
    static function bannerWidth(textWidth as Numeric) as Float {
        var width = textWidth + 2 * BANNER_MARGIN;
        return (width < BANNER_MAX_WIDTH ? width : BANNER_MAX_WIDTH).toFloat();
    }
}

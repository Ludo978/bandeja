import Toybox.Lang;

// The question showing (ServeQuestions).
enum ServeQuestion {
    QUESTION_NONE,   // nothing (more) to ask: the match screen
    QUESTION_FIRST,  // "Who serves first?"
    QUESTION_SECOND  // "Our first server?", after Opponents in doubles
}

// An answer, also its menu item's ID.
enum ServeAnswer {
    ANSWER_ME,
    ANSWER_PARTNER,
    ANSWER_OPPONENTS
}

// "Who serves first? Me / Partner / Opponents" and, after Opponents, "Our first server?
// Me / Partner"; in singles one question, Me / Opponent. Asked once the match has
// started, before the first point, only with serve tracking on. The rules without the menus
// (ServeMenu), so they're unit-tested.
//
// The last answer logs the events through the match holder: FIX_SERVING_TEAM for the team,
// then SWAP_OUR_SERVER when our first server is Partner, so they're saved like any event. BACK on
// the score screen leaves them (ScoreInput): Fix serving team and Swap our server order change
// them. Nothing is logged before the last answer: BACK on the second question goes back to the first, and BACK
// on the first does nothing, so the question can't be skipped. BACK never leaves the match.
class ServeQuestions {

    private var _match as CurrentMatch;
    private var _question as ServeQuestion;
    // The answer the first question opens on: Opponents when BACK brings it back.
    private var _focus as ServeAnswer = ANSWER_ME;

    function initialize(match as CurrentMatch, serveTracking as Boolean) {
        _match = match;
        _question = serveTracking ? QUESTION_FIRST : QUESTION_NONE;
    }

    function getQuestion() as ServeQuestion {
        return _question;
    }

    function getTitle() as ResourceId {
        return _question == QUESTION_SECOND ? Rez.Strings.ServeFirstUs : Rez.Strings.ServeFirst;
    }

    // The current question's answers, in menu order.
    function getAnswers() as Array<ServeAnswer> {
        if (_question == QUESTION_SECOND) {
            return [ANSWER_ME, ANSWER_PARTNER];
        }
        return isDoubles() ? [ANSWER_ME, ANSWER_PARTNER, ANSWER_OPPONENTS] : [ANSWER_ME, ANSWER_OPPONENTS];
    }

    // The answer the menu opens on.
    function getFocus() as ServeAnswer {
        return _question == QUESTION_FIRST ? _focus : ANSWER_ME;
    }

    function getLabel(answer as ServeAnswer) as ResourceId {
        if (answer == ANSWER_PARTNER) {
            return Rez.Strings.ServePartner;
        } else if (answer == ANSWER_OPPONENTS) {
            return isDoubles() ? Rez.Strings.ServeOpponents : Rez.Strings.ServeOpponent;
        }
        return Rez.Strings.ServeMe;
    }

    // START on an answer, at time (Time.now().value()). Returns the question that follows.
    function pick(answer as ServeAnswer, time as Number) as ServeQuestion {
        if (_question == QUESTION_FIRST && answer == ANSWER_OPPONENTS && isDoubles()) {
            _question = QUESTION_SECOND;
        } else if (_question != QUESTION_NONE) {
            var team = _question == QUESTION_SECOND || answer == ANSWER_OPPONENTS ? TEAM_THEM : TEAM_US;
            setServer(team, answer == ANSWER_PARTNER ? PLAYER_PARTNER : PLAYER_ME, time);
            _question = QUESTION_NONE;
        }
        return _question;
    }

    // BACK, or a swipe right: true when it goes back to the first question. On the first it does
    // nothing (false): with serve tracking on the question is always answered, since a server left
    // unknown would stay so all match, with no tracker and nothing saying how to set it.
    function back() as Boolean {
        if (_question != QUESTION_SECOND) {
            return false;
        }
        _question = QUESTION_FIRST;
        _focus = ANSWER_OPPONENTS;
        return true;
    }

    // Logs what the state needs to say team serves now and player serves our first game: at the
    // match start, FIX_SERVING_TEAM, then SWAP_OUR_SERVER for Partner. Asked again with some
    // answers still logged, only what changes.
    private function setServer(team as Team, player as Player, time as Number) as Void {
        if (_match.getState().getServingTeam() != team) {
            _match.add(new MatchEvent(EVENT_FIX_SERVING_TEAM, time, team));
        }
        if (_match.getState().ourServer != player) {
            _match.add(new MatchEvent(EVENT_SWAP_OUR_SERVER, time, null));
        }
    }

    private function isDoubles() as Boolean {
        return _match.engine.getConfig().doubles;
    }
}

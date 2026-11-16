import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;

// The 18 developer fields of the Padel session: 13 session fields, 4 lap fields, 1
// record field. Their numbers are the ids in resources/fitcontributions/fitcontributions.xml,
// where Connect finds their labels and units: never renumber or reuse one once released. The units
// here are the English unit labels, for the FIT file's own field descriptions.
class FitFields {

    // Session fields 0 to 12, in SessionValues' order.
    private var _session as Array<FitContributor.Field>;
    // Lap fields 13 to 16: the set, its score right after the game (games, or the super tie-break's
    // points), the outcome.
    private var _lap as Array<FitContributor.Field>;
    // Record field 17: our points minus theirs.
    private var _pointDifferential as FitContributor.Field;

    // Creates the fields, before the session starts. Lap fields get no value here: a value stays set
    // for the laps after it, and the warm-up lap must get none.
    function initialize(session as ActivityRecording.Session) {
        var sessionType = FitContributor.MESG_TYPE_SESSION;
        var uint8 = FitContributor.DATA_TYPE_UINT8;
        var uint16 = FitContributor.DATA_TYPE_UINT16;
        _session = [
            session.createField("score", 0, FitContributor.DATA_TYPE_STRING,
                {:mesgType => sessionType, :count => SessionValues.SCORE_BYTES, :units => "sets"}),
            field(session, "sets_won", 1, uint8, sessionType, "sets"),
            field(session, "sets_lost", 2, uint8, sessionType, "sets"),
            field(session, "games_won", 3, uint8, sessionType, "games"),
            field(session, "games_lost", 4, uint8, sessionType, "games"),
            field(session, "points_won", 5, uint16, sessionType, "pts"),
            field(session, "points_lost", 6, uint16, sessionType, "pts"),
            field(session, "serve_points_won", 7, uint8, sessionType, "%"),
            field(session, "return_points_won", 8, uint8, sessionType, "%"),
            field(session, "breaks_won", 9, uint8, sessionType, "games"),
            field(session, "result", 10, uint8, sessionType, "#"),
            field(session, "deciding_won", 11, uint8, sessionType, "pts"),
            field(session, "deciding_played", 12, uint8, sessionType, "pts")
        ];
        var lapType = FitContributor.MESG_TYPE_LAP;
        _lap = [
            field(session, "lap_set", 13, uint8, lapType, "#"),
            field(session, "lap_score_us", 14, uint8, lapType, "#"),
            field(session, "lap_score_them", 15, uint8, lapType, "#"),
            field(session, "lap_outcome", 16, uint8, lapType, "#")
        ];
        _pointDifferential = field(session, "point_differential", 17, FitContributor.DATA_TYPE_SINT16,
            FitContributor.MESG_TYPE_RECORD, "pts");
        // The chart starts level, warm-up included.
        _pointDifferential.setData(0);
    }

    // Written at save. Set them while recording, before the timer stops.
    function setSessionValues(values as SessionValues) as Void {
        var data = [
            values.score,
            values.sets[TEAM_US], values.sets[TEAM_THEM],
            values.games[TEAM_US], values.games[TEAM_THEM],
            values.points[TEAM_US], values.points[TEAM_THEM],
            values.servePointsWonPercent, values.returnPointsWonPercent, values.breaksWon,
            values.result,
            values.decidingPointsWon, values.decidingPointsPlayed
        ] as Array<String or Number>;
        for (var i = 0; i < _session.size(); i++) {
            _session[i].setData(data[i]);
        }
    }

    // Written when the lap closes, and kept for the laps after it until set again.
    function setLapValues(values as LapValues) as Void {
        _lap[0].setData(values.setNumber);
        _lap[1].setData(values.games[TEAM_US]);
        _lap[2].setData(values.games[TEAM_THEM]);
        _lap[3].setData(values.getOutcomeCode());
    }

    // Written with every record until set again.
    function setPointDifferential(value as Number) as Void {
        _pointDifferential.setData(value);
    }

    private static function field(session as ActivityRecording.Session, name as String, id as Number,
            type as FitContributor.DataType, mesgType as Number, units as String) as FitContributor.Field {
        return session.createField(name, id, type, {:mesgType => mesgType, :units => units});
    }
}

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// The data page (mockup "Data page"), which the score screen shows in place of the score
// page with the same input (ScoreView, ScoreMotion.page): the heart rate in large type under a
// 240° ring of the five zones, each dimmed but the current one, a marker at the heart rate's place
// on it and ZONE n in the zone's color; under the divider a 2 x 2 grid: the elapsed time (the
// activity timer, as on the score page), the calories, this game's duration and the time of day, or
// in a timed match the court time left, in yellow (COURT LEFT); the page dots at the bottom, this
// page second of three (the stats page after it).
//
// The grid's texts are kept: the score screen sets them at its 1 Hz tick (set()), which is true
// only when one changed, so it redraws only then. The heart rate and its zone are the score
// screen's (HeartRateArc), read on the same tick.
class DataPage {

    // The zone ring (mockup): radius, stroke, from 210° (zone 1, bottom left) to -30° (zone 5,
    // bottom right), 3° between zones.
    static const RING_RADIUS = 198;
    static const RING_STROKE = 10;
    static const RING_FROM = 210;
    static const RING_TO = -30;
    static const RING_GAP = 3;
    // A value the watch doesn't give.
    static const NONE = "--";
    // The grid's labels: size and letter spacing (mockup), and the widest a label gets in its cell
    // (the cells are 144 apart) before a smaller font.
    private const LABEL_SIZE = 13;
    private const LABEL_SPACING = 2;
    private const LABEL_WIDTH = 136;

    // The grid's texts, NONE for a value the watch doesn't give. The fourth is the time of day, or a
    // timed match's court time left (court).
    var elapsed as String = NONE;
    var calories as String = NONE;
    var game as String = NONE;
    var clock as String = NONE;
    var court as Boolean = false;

    // Loaded once (load()): the labels in grid order (elapsed, calories, this game, time of day), their
    // fitted sizes, and "ZONE $1$".
    private var _labels as Array<String> = ["", "", "", ""];
    private var _labelSizes as Array<Number> = [LABEL_SIZE, LABEL_SIZE, LABEL_SIZE, LABEL_SIZE];
    private var _zoneFormat as String = "";
    // The zone whose label is worked out, and the label.
    private var _zone as Number = 0;
    private var _zoneText as String = "";

    function initialize() {
    }

    // The strings and their sizes, with the screen (ScoreView.onLayout()); timed, the court time left
    // in place of the time of day.
    function load(dc as Graphics.Dc, l as Layout, timed as Boolean) as Void {
        court = timed;
        var ids = [Rez.Strings.DataElapsed, Rez.Strings.DataCalories, Rez.Strings.DataGame,
            timed ? Rez.Strings.CourtLeft : Rez.Strings.DataClock];
        for (var i = 0; i < ids.size(); i++) {
            _labels[i] = WatchUi.loadResource(ids[i]) as String;
            _labelSizes[i] = l.fitSize(dc, STYLE_BOLD, LABEL_SIZE, _labels[i], LABEL_SPACING, LABEL_WIDTH);
        }
        _zoneFormat = WatchUi.loadResource(Rez.Strings.DataZone) as String;
        _zone = 0;
    }

    // Sets the grid from the activity timer (ms) and calories (kcal), this game's seconds
    // (gameSeconds()), each null when there's none, and the time of day (TimeText.clock()) or the
    // court time left (TimeText.countdown()). True when a text shown changed.
    function set(timerTime as Number?, kcal as Number?, gameSeconds as Number?, time as String) as Boolean {
        var newElapsed = timerTime != null ? TimeText.duration(timerTime / 1000, true) : NONE;
        var newCalories = kcal != null ? kcal.toString() : NONE;
        var newGame = gameSeconds != null ? TimeText.duration(gameSeconds, false) : NONE;
        var changed = !newElapsed.equals(elapsed) || !newCalories.equals(calories) || !newGame.equals(game)
            || !time.equals(clock);
        elapsed = newElapsed;
        calories = newCalories;
        game = newGame;
        clock = time;
        return changed;
    }

    // This game's duration at now, in seconds (wall clock, like the match start and the events, so
    // a pause doesn't stop it): from the end of the game before it, the first game from the match
    // start. Null once the match is over: no game is being played.
    static function gameSeconds(state as MatchState, matchStart as Number, now as Number) as Number? {
        return state.matchOver ? null : now - state.getGameStartTime(matchStart);
    }

    // The whole screen, with the heart rate and its zone as heartRate shows them.
    function draw(dc as Graphics.Dc, l as Layout, heartRate as HeartRateArc) as Void {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        var zone = heartRate.zone;
        HeartRateArc.drawZones(dc, l, zone, RING_RADIUS, RING_STROKE, RING_FROM, RING_TO, RING_GAP, true);
        var marker = heartRate.getMarkerAngle(RING_FROM, RING_TO, RING_GAP);
        if (marker != null) {
            var angle = Math.toRadians(marker);
            l.fillStrokedCircle(dc, 240 + RING_RADIUS * Math.cos(angle), 240 - RING_RADIUS * Math.sin(angle), 8,
                Palette.BG, Palette.TEXT, 3);
        }
        // The mockup's heart is the score screen's at 1.1 times its size.
        HeartRateArc.drawHeart(dc, l, 240, 104, 1.1);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 192, STYLE_NUMBER, 96, HeartRateArc.text(heartRate.heartRate), Graphics.TEXT_JUSTIFY_CENTER);
        // No label below zone 1 or without zones, where nothing is lit.
        if (zone > 0) {
            if (zone != _zone) {
                _zone = zone;
                _zoneText = Lang.format(_zoneFormat, [zone]);
            }
            dc.setColor(Palette.hrZoneColor(zone), Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, 240, 222, STYLE_BOLD, 16, 3, _zoneText, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 96, 245.25, 288, 1.5);
        // Values at 290 and 354, labels 20 under them (a smaller font keeps its capitals' middle).
        var values = [elapsed, calories, game, clock];
        for (var i = 0; i < values.size(); i++) {
            var x = i % 2 == 0 ? 168 : 312;
            var y = 290 + i / 2 * 64;
            dc.setColor(i == 3 && court ? Palette.BALL : Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            l.drawText(dc, x, y, STYLE_NUMBER, 32, values[i], Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, x, y + 20 - Fonts.CAP_MIDDLE * (LABEL_SIZE - _labelSizes[i]), STYLE_BOLD,
                _labelSizes[i], LABEL_SPACING, _labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawDots(dc, l, PAGE_DATA);
    }

    // The page dots at the bottom of the data page and the stats page (mockup "Stats page"): one per
    // page of the score screen, left to right, 16 apart and centered, the page showing lit.
    static function drawDots(dc as Graphics.Dc, l as Layout, page as ScorePage) as Void {
        var pages = PAGE_STATS + 1;
        for (var i = 0; i < pages; i++) {
            dc.setColor(i == (page as Number) ? Palette.TEXT : Palette.INACTIVE, Graphics.COLOR_TRANSPARENT);
            l.fillCircle(dc, 240 + (2 * i - pages + 1) * 8, 416, 4);
        }
    }
}

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The stats page (mockup "Stats page"), the score screen's third page, after the data
// page, with the same input (ScoreView, ScoreMotion.page): the points won % in large type under the
// data page's 240° ring, split between our points won, in our color from its left end, and theirs in
// their color (the theme's); POINTS WON under it in our color; under the divider the serve points won %, the average
// time per point (m:ss, as the data page writes a duration) and our best streak; the page dots, this
// page third. "--" for what serve tracking off or an empty match doesn't give: the serve points with
// tracking off or before we serve, the points won % and the average before the first point. The
// streak is a count: 0 until we win a point.
//
// Its texts come from the match's stats (MatchState.getStats(): the tally, no replay), worked out again
// only when the state shown changed (show()). A point or an undo brings the score page back, but a
// menu's event (Fix serving team) changes the state under it. Nothing on it changes with time, so the
// screen's 1 Hz tick doesn't redraw it.
class StatsPage {

    static const NONE = "--";
    // The gap between our part of the ring and theirs, as between the data page's zones.
    static const RING_GAP = 3;
    // The shortest part of the ring drawn, in degrees.
    static const RING_MIN = 1;
    // The points won %: the number, then the % sign at half its size (mockup), on one baseline.
    private const POINTS_Y = 192;
    private const POINTS_SIZE = 96;
    private const SIGN_SIZE = 48;
    private const SIGN = "%";
    // POINTS WON under it, in our color: baseline, size, letter spacing, and the widest it gets (the
    // divider's width) before a smaller font.
    private const TITLE_Y = 222;
    private const TITLE_SIZE = 16;
    private const TITLE_SPACING = 3;
    private const TITLE_WIDTH = 288;
    // The grid: the data page's values and labels. The third stat alone in the middle of the second
    // row, as the summary's odd last stat.
    private const VALUE_SIZE = 32;
    private const LABEL_SIZE = 13;
    private const LABEL_SPACING = 2;
    private const LABEL_WIDTH = 136;
    private const CELLS = [[168, 290], [312, 290], [240, 354]] as Array<Array<Number>>;

    // The points won % without its sign, the serve points won % with it, the average time per point
    // and the best streak, NONE for what the match doesn't give.
    var points as String = NONE;
    var serve as String = NONE;
    var average as String = NONE;
    var streak as String = "0";
    // The points each team won, for the ring.
    var won as Number = 0;
    var lost as Number = 0;

    // Loaded once (load()): POINTS WON and the grid's labels (serve points, per point, best streak), with
    // their fitted sizes.
    private var _title as String = "";
    private var _titleSize as Number = TITLE_SIZE;
    private var _labels as Array<String> = ["", "", ""];
    private var _labelSizes as Array<Number> = [LABEL_SIZE, LABEL_SIZE, LABEL_SIZE];
    // The state the texts were worked out for, weakly held (an undo replaces the state, and the page
    // may not show again for long), and its event count (an event changes it in place).
    private var _state as WeakReference? = null;
    private var _eventCount as Number = -1;

    function initialize() {
    }

    // The strings and their sizes, with the screen (ScoreView.onLayout()).
    function load(dc as Graphics.Dc, l as Layout) as Void {
        _title = WatchUi.loadResource(Rez.Strings.StatPointsWon) as String;
        _titleSize = l.fitSize(dc, STYLE_BOLD, TITLE_SIZE, _title, TITLE_SPACING, TITLE_WIDTH);
        var ids = [Rez.Strings.StatServe, Rez.Strings.StatPerPoint, Rez.Strings.StatStreak];
        for (var i = 0; i < ids.size(); i++) {
            _labels[i] = WatchUi.loadResource(ids[i]) as String;
            _labelSizes[i] = l.fitSize(dc, STYLE_BOLD, LABEL_SIZE, _labels[i], LABEL_SPACING, LABEL_WIDTH);
        }
        // The sign's font loads now rather than at the page's first redraw.
        l.font(STYLE_NUMBER, SIGN_SIZE);
    }

    // The texts for the state at its redraw, from its stats (matchStart for the average), worked out
    // again only when the state changed since the last call. True when they were.
    function show(state as MatchState, matchStart as Number) as Boolean {
        var shown = _state;
        if (shown != null && shown.get() == state && state.eventCount == _eventCount) {
            return false;
        }
        set(state.getStats(matchStart));
        _state = state.weak();
        _eventCount = state.eventCount;
        return true;
    }

    // The texts from a match's stats.
    function set(stats as MatchStats) as Void {
        won = stats.pointsWon;
        lost = stats.pointsLost;
        var percent = stats.getPointsWonPercent();
        points = percent != null ? percent.toString() : NONE;
        var servePercent = stats.getServePointsWonPercent();
        serve = servePercent != null ? servePercent + SIGN : NONE;
        var time = stats.averagePointTime;
        average = time != null ? TimeText.duration(time, false) : NONE;
        streak = stats.longestStreak.toString();
    }

    // The ring's parts for the points won and lost, each [color, start, end] (Connect IQ degrees,
    // counterclockwise from start to end, as Layout.drawArc() takes them): ours from the ring's left end
    // (210°) in our color, theirs to its right end (-30°) in their color, the theme's, RING_GAP apart,
    // split as the points are. One team only: the whole ring in its color; no point: the whole ring
    // INACTIVE. A part shorter than RING_MIN isn't there.
    static function ringArcs(won as Number, lost as Number, theme as ThemeSetting) as Array<[Number, Float, Float]> {
        var from = DataPage.RING_FROM.toFloat();
        var to = DataPage.RING_TO.toFloat();
        var us = Palette.teamColor(theme, TEAM_US);
        var them = Palette.teamColor(theme, TEAM_THEM);
        if (won == 0 || lost == 0) {
            var color = won > 0 ? us : lost > 0 ? them : Palette.INACTIVE;
            return [[color, to, from]] as Array<[Number, Float, Float]>;
        }
        var split = from - (from - to) * won / (won + lost);
        var arcs = [] as Array<[Number, Float, Float]>;
        var ours = split + RING_GAP / 2.0;
        if (from - ours >= RING_MIN) {
            arcs.add([us, ours, from] as [Number, Float, Float]);
        }
        var theirs = split - RING_GAP / 2.0;
        if (theirs - to >= RING_MIN) {
            arcs.add([them, to, theirs] as [Number, Float, Float]);
        }
        return arcs;
    }

    // The whole screen, its team colors the theme's.
    function draw(dc as Graphics.Dc, l as Layout, theme as ThemeSetting) as Void {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        var arcs = ringArcs(won, lost, theme);
        for (var i = 0; i < arcs.size(); i++) {
            var arc = arcs[i];
            dc.setColor(arc[0], Graphics.COLOR_TRANSPARENT);
            l.drawArc(dc, DataPage.RING_RADIUS, DataPage.RING_STROKE, arc[1], arc[2]);
        }

        // The number and its sign centered together, as the mockup's one text.
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        if (points.equals(NONE)) {
            l.drawText(dc, 240, POINTS_Y, STYLE_NUMBER, POINTS_SIZE, points, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var number = l.textWidth(dc, STYLE_NUMBER, POINTS_SIZE, points, 0);
            var left = 240 - (number + l.textWidth(dc, STYLE_NUMBER, SIGN_SIZE, SIGN, 0)) / 2;
            l.drawText(dc, left, POINTS_Y, STYLE_NUMBER, POINTS_SIZE, points, Graphics.TEXT_JUSTIFY_LEFT);
            l.drawText(dc, left + number, POINTS_Y, STYLE_NUMBER, SIGN_SIZE, SIGN, Graphics.TEXT_JUSTIFY_LEFT);
        }
        // A smaller font keeps its capitals' middle.
        dc.setColor(Palette.teamColor(theme, TEAM_US), Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, TITLE_Y - Fonts.CAP_MIDDLE * (TITLE_SIZE - _titleSize), STYLE_BOLD, _titleSize,
            TITLE_SPACING, _title, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 96, 245.25, 288, 1.5);
        // Values on the cells' baselines, labels 20 under them.
        var values = [serve, average, streak];
        for (var i = 0; i < values.size(); i++) {
            var x = CELLS[i][0];
            var y = CELLS[i][1];
            dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
            l.drawText(dc, x, y, STYLE_NUMBER, VALUE_SIZE, values[i], Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, x, y + 20 - Fonts.CAP_MIDDLE * (LABEL_SIZE - _labelSizes[i]), STYLE_BOLD,
                _labelSizes[i], LABEL_SPACING, _labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        DataPage.drawDots(dc, l, PAGE_STATS);
    }
}

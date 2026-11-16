import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The match summary (mockup "Match summary"), drawn from the mockup's numbers through
// Layout: WON / LOST (or DRAW) in the winner's color, the sets score large, the set table with US /
// THEM columns (each set's winner in its color, the loser in grey, the set the match ended in
// starred), the divider and the 2 x 2 stat grid; the START hint arc with its check mark, and the
// chevron when there's more below. The pages below hold the other stats (SummaryModel), two columns
// in the grid's style, a chevron above them too. Worked out once when it opens (SummaryModel): no
// timer, it only redraws on a page turn and for the toast ("Not saved", the Toast's own timer).
// A stored match's summary, opened from the history, is the same screen without the START
// hint: START saves nothing there. The team colors are the theme's, read when it shows. The
// team names over the table are the record's (SummaryModel), shrunk down to three quarters
// when the circle needs it; the match's own summary takes them from the settings when it shows, as
// its Save does, and both take a change made in the Garmin Connect app at once (applySettings()).
class SummaryView extends WatchUi.View {

    // The header, the sets score, the team names over the table.
    private const HEADER_Y = 104;
    private const HEADER_SIZE = 22;
    private const HEADER_SPACING = 5;
    private const SETS_Y = 170;
    private const SETS_SIZE = 64;
    static const TEAMS_Y = 202;
    // The set table: labels right-aligned on LABEL_X, each team's number centered on its column
    // (SummaryModel.COLUMNS), rows ROW_PITCH apart, the numbers 2 below their label's baseline.
    private const LABEL_X = 196;
    private const ROW_Y = 228;
    private const ROW_PITCH = 30;
    private const ROW_LABEL_SIZE = 14;
    private const ROW_LABEL_SPACING = 1.5;
    private const ROW_SCORE_SIZE = 26;
    // The grid under the divider: two columns, values over their labels.
    private const DIVIDER_Y = 310;
    private const GRID_X = [186, 294];
    private const GRID_Y = 344;
    private const GRID_PITCH = 52;
    // The later pages: two wider columns, rows centered on the screen.
    private const PAGE_X = [168, 312];
    private const PAGE_PITCH = 64;
    // Every value, and its label LABEL_GAP under it.
    private const VALUE_SIZE = 26;
    static const LABEL_SIZE = 12;
    static const LABEL_SPACING = 2;
    private const LABEL_GAP = 18;
    // The widest label in a grid cell and in a later page's cell, before a smaller font.
    private const GRID_LABEL_WIDTH = 100;
    private const PAGE_LABEL_WIDTH = 136;
    // The header keeps this far inside the circle at the top of its capitals.
    static const MARGIN = 10;
    // The toast's center line.
    private const TOAST_Y = 240;

    // "Not saved" when the watch refuses the save.
    var toast as Toast = new Toast();
    // The page showing, from 0 (SummaryInput.page).
    var page as Number = 0;

    private var _model as SummaryModel;
    // The match's own summary, where START saves: the START hint shows. False for a stored match's.
    private var _live as Boolean;
    private var _layout as Layout = new Layout(416);
    // The Theme setting, read when the screen shows.
    private var _theme as ThemeSetting = Settings.DEFAULT_THEME;
    // The team names as drawn, their size and centers, worked out at the first redraw after the names
    // or the layout changed (loadNames()).
    private var _names as Array<String> = ["", ""];
    private var _namesSize as Number = LABEL_SIZE;
    private var _namesX as Array<Float> = [0.0, 0.0];
    private var _namesStale as Boolean = true;
    // Loaded once (onLayout): the header and its size, each row's label, each stat's label and its
    // size.
    private var _header as String? = null;
    private var _headerSize as Number = HEADER_SIZE;
    private var _rowLabels as Array<String> = [] as Array<String>;
    private var _statLabels as Array<String> = [] as Array<String>;
    private var _statSizes as Array<Number> = [] as Array<Number>;

    function initialize(model as SummaryModel, live as Boolean) {
        View.initialize();
        _model = model;
        _live = live;
    }

    function onLayout(dc as Dc) as Void {
        var l = new Layout(dc.getWidth());
        _layout = l;
        var model = _model;
        var header = SummaryModel.headerString(model.result);
        _header = header != null ? WatchUi.loadResource(header) as String : null;
        if (_header != null) {
            _headerSize = l.fitSize(dc, STYLE_BOLD, HEADER_SIZE, _header as String, HEADER_SPACING,
                Layout.chord(HEADER_Y - 2 * Fonts.CAP_MIDDLE * HEADER_SIZE) - 2 * MARGIN);
        }
        _namesStale = true;

        _rowLabels = [] as Array<String>;
        for (var i = 0; i < model.rows.size(); i++) {
            var row = model.rows[i];
            var label = WatchUi.loadResource(model.rowLabel(row)) as String;
            if (!row.superTieBreak) {
                label = Lang.format(label, [row.setNumber]);
            }
            _rowLabels.add(row.winner == null ? label + SummaryRow.STAR : label);
        }

        // The first page's stats sit in the grid's narrower cells.
        var inGrid = model.getStats(0).size();
        _statLabels = [] as Array<String>;
        _statSizes = [] as Array<Number>;
        for (var i = 0; i < model.stats.size(); i++) {
            var label = WatchUi.loadResource(model.stats[i].label) as String;
            _statLabels.add(label);
            _statSizes.add(l.fitSize(dc, STYLE_BOLD, LABEL_SIZE, label, LABEL_SPACING,
                i < inGrid ? GRID_LABEL_WIDTH : PAGE_LABEL_WIDTH));
        }
    }

    function onShow() as Void {
        readSettings();
    }

    // A change made in the Garmin Connect app (BandejaApp.onSettingsChanged()) while this screen shows:
    // the theme, and the match's own summary's team names, as when it shows; redrawn at once.
    function applySettings() as Void {
        readSettings();
        WatchUi.requestUpdate();
    }

    // The theme, and for the match's own summary the team names, which its Save takes too
    // (MatchFlow.historyRecord()). A stored match keeps the names it was saved with.
    private function readSettings() as Void {
        _theme = Settings.getTheme();
        if (_live) {
            var names = Settings.getTeamNames();
            if (!equalNames(names, _model.names)) {
                _model.names = names;
                _namesStale = true;
            }
        }
    }

    private static function equalNames(a as Array<String?>, b as Array<String?>) as Boolean {
        for (var team = 0; team < 2; team++) {
            var x = a[team];
            var y = b[team];
            if (x == null || y == null) {
                if (x != y) {
                    return false;
                }
            } else if (!x.equals(y)) {
                return false;
            }
        }
        return true;
    }

    // The names as drawn (US / THEM for none), their size and centers (fitNames()).
    private function loadNames(dc as Dc) as Void {
        var defaults = [Rez.Strings.Us, Rez.Strings.Them];
        for (var team = 0; team < 2; team++) {
            var name = _model.names[team];
            _names[team] = name != null ? SummaryModel.nameText(name) : WatchUi.loadResource(defaults[team]) as String;
        }
        var fit = fitNames(dc, _layout, _names);
        _namesSize = fit[0] as Number;
        _namesX = [fit[1] as Float, fit[2] as Float];
        _namesStale = false;
    }

    // The team names as drawn over the table: [size, our center, their center] (mockup numbers), at the
    // label size or smaller, down to three quarters of it, until both keep MARGIN inside the circle at
    // the top of their capitals, each where SummaryModel.nameCenters() puts it.
    static function fitNames(dc as Dc, l as Layout, names as Array<String>) as Array<Numeric> {
        var size = LABEL_SIZE;
        var smallest = size * 3 / 4;
        var centers = [0.0, 0.0] as Array<Float>;
        for (; size >= smallest; size--) {
            var widths = [l.textWidth(dc, STYLE_BOLD, size, names[TEAM_US], LABEL_SPACING),
                l.textWidth(dc, STYLE_BOLD, size, names[TEAM_THEM], LABEL_SPACING)];
            centers = SummaryModel.nameCenters(widths);
            var half = Layout.chord(TEAMS_Y - 2 * Fonts.CAP_MIDDLE * size) / 2 - MARGIN;
            if (centers[TEAM_US] - widths[TEAM_US] / 2 >= 240 - half && centers[TEAM_THEM] + widths[TEAM_THEM] / 2 <= 240 + half) {
                break;
            }
        }
        return [size < smallest ? smallest : size, centers[TEAM_US], centers[TEAM_THEM]];
    }

    // A menu on top (hold UP): the toast is gone.
    function onHide() as Void {
        toast.hide();
    }

    function onUpdate(dc as Dc) as Void {
        var l = _layout;
        dc.setAntiAlias(true);
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        if (_live) {
            drawStartHint(dc, l);
        }
        var pages = _model.getPageCount();
        if (page == 0) {
            drawResult(dc, l);
        } else {
            drawStatsPage(dc, l);
        }
        // The chevrons: more below, more above.
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(l.pen(2));
        if (page < pages - 1) {
            drawChevron(dc, l, 428, 435);
        }
        if (page > 0) {
            drawChevron(dc, l, 52, 45);
        }
        toast.draw(dc, l, TOAST_Y);
    }

    // The header, the sets score and the table, then the grid when it fits under the table.
    private function drawResult(dc as Dc, l as Layout) as Void {
        var model = _model;
        var header = _header;
        if (header != null) {
            dc.setColor(SummaryModel.headerColor(model.result, _theme), Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, 240, HEADER_Y - Fonts.CAP_MIDDLE * (HEADER_SIZE - _headerSize), STYLE_BOLD,
                _headerSize, HEADER_SPACING, header, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, SETS_Y, STYLE_NUMBER, SETS_SIZE, model.getSetsText(), Graphics.TEXT_JUSTIFY_CENTER);

        if (_namesStale) {
            loadNames(dc);
        }
        var columns = SummaryModel.COLUMNS;
        for (var team = 0; team < 2; team++) {
            dc.setColor(Palette.teamColor(_theme, team as Team), Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, _namesX[team], TEAMS_Y - Fonts.CAP_MIDDLE * (LABEL_SIZE - _namesSize), STYLE_BOLD,
                _namesSize, LABEL_SPACING, _names[team], Graphics.TEXT_JUSTIFY_CENTER);
        }
        for (var i = 0; i < model.rows.size(); i++) {
            var row = model.rows[i];
            var y = ROW_Y + i * ROW_PITCH;
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, LABEL_X, y, STYLE_BOLD, ROW_LABEL_SIZE, ROW_LABEL_SPACING, _rowLabels[i],
                Graphics.TEXT_JUSTIFY_RIGHT);
            // The set's winner in bold and in color, the loser regular and grey (mockup).
            for (var team = 0; team < 2; team++) {
                dc.setColor(SummaryModel.scoreColor(row, team as Team, _theme), Graphics.COLOR_TRANSPARENT);
                l.drawText(dc, columns[team], y + 2, row.winner == team ? STYLE_NUMBER : STYLE_REGULAR, ROW_SCORE_SIZE,
                    row.score[team].toString(), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var stats = model.getStats(0);
        if (stats.size() == 0) {
            return;
        }
        dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 120, DIVIDER_Y - 0.75, 240, 1.5);
        for (var i = 0; i < stats.size(); i++) {
            drawStat(dc, l, i, GRID_X[i % 2], GRID_Y + i / 2 * GRID_PITCH);
        }
    }

    // A later page's stats: two columns, the rows centered on the screen, an odd last stat in the
    // middle.
    private function drawStatsPage(dc as Dc, l as Layout) as Void {
        var stats = _model.getStats(page);
        var first = _model.firstStat(page);
        var rows = (stats.size() + 1) / 2;
        var top = 240 - (rows - 1) * PAGE_PITCH / 2;
        for (var i = 0; i < stats.size(); i++) {
            var alone = i == stats.size() - 1 && i % 2 == 0;
            drawStat(dc, l, first + i, alone ? 240 : PAGE_X[i % 2], top + i / 2 * PAGE_PITCH);
        }
    }

    // A stat's value with its baseline at y, its label under it.
    private function drawStat(dc as Dc, l as Layout, index as Number, x as Number, y as Number) as Void {
        var size = _statSizes[index];
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, x, y, STYLE_BOLD, VALUE_SIZE, _model.stats[index].value, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, x, y + LABEL_GAP - Fonts.CAP_MIDDLE * (LABEL_SIZE - size), STYLE_BOLD, size,
            LABEL_SPACING, _statLabels[index], Graphics.TEXT_JUSTIFY_CENTER);
    }

    // START saves: the yellow arc by the button and the mockup's check mark,
    // its ends and corner rounded.
    private function drawStartHint(dc as Dc, l as Layout) as Void {
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.drawStartArc(dc);
        var points = [[384, 140], [390, 146], [402, 133]];
        dc.setPenWidth(l.pen(3));
        for (var i = 0; i < points.size(); i++) {
            var point = points[i];
            if (i > 0) {
                var from = points[i - 1];
                dc.drawLine(l.x(from[0]), l.y(from[1]), l.x(point[0]), l.y(point[1]));
            }
            l.fillCircle(dc, point[0], point[1], 1.5);
        }
    }

    // The mockup's chevron, from (232, y) to its tip at (240, tipY) and back to (248, y).
    private function drawChevron(dc as Dc, l as Layout, y as Number, tipY as Number) as Void {
        dc.drawLine(l.x(232), l.y(y), l.x(240), l.y(tipY));
        dc.drawLine(l.x(240), l.y(tipY), l.x(248), l.y(y));
    }
}

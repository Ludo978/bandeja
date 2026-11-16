import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Debug builds only: a rendering check of the design foundation, a static slice of the
// "Score, in play" mockup drawn from its own numbers through Layout, Palette and Fonts. Not the
// score screen (ScoreView draws real state). UP shows the top half at the point flash tint, DOWN the
// bottom half, START switches to the system font fallback and back, BACK leaves. Opened with a tap
// on the sensor lock screen (PLAY on the home screen), before recording.
(:debug)
class DesignTestView extends WatchUi.View {

    // The team whose half shows the point flash tint, if any.
    var flash as Team? = null;
    // false shows the fonts used without vector fonts.
    var vector as Boolean = true;
    // The Theme setting's team colors, read when the screen shows.
    private var _theme as ThemeSetting = Settings.DEFAULT_THEME;

    private var _layout as Layout = new Layout(416);
    private var _them as String = "";
    private var _us as String = "";
    private var _banner as String = "";
    private var _caption as String = "";
    // The mockup's other opacities over black: the net line, the mini court's net.
    private var _netColor as Number = Palette.onBlack(Palette.TEXT, 55);
    private var _courtNetColor as Number = Palette.onBlack(Palette.TEXT, 80);

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layout = new Layout(dc.getWidth());
        _them = WatchUi.loadResource(Rez.Strings.Them) as String;
        _us = WatchUi.loadResource(Rez.Strings.Us) as String;
        _banner = WatchUi.loadResource(Rez.Strings.BannerBreakPoint) as String;
        _caption = Lang.format(WatchUi.loadResource(Rez.Strings.CaptionSet) as String, [2]);
    }

    function onShow() as Void {
        Fonts.setVectorEnabled(vector);
        _theme = Settings.getTheme();
    }

    // The rest of the app always gets vector fonts.
    function onHide() as Void {
        Fonts.setVectorEnabled(true);
    }

    function onUpdate(dc as Dc) as Void {
        var l = _layout;
        dc.setAntiAlias(true);
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        // The halves: a rectangle is enough, the screen itself is round.
        dc.setColor(flash == TEAM_THEM ? Palette.teamFlash(_theme, TEAM_THEM) : Palette.teamTint(_theme, TEAM_THEM),
            Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 32, 32, 416, 208);
        dc.setColor(flash == TEAM_US ? Palette.teamFlash(_theme, TEAM_US) : Palette.teamTint(_theme, TEAM_US),
            Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 32, 240, 416, 208);
        dc.setColor(_netColor, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 20, 239, 440, 2);

        // The HR zone arc, zone 4 lit (the score screen's component).
        HeartRateArc.drawArc(dc, l, 4, "152");

        // THEM: label and set pips, games tile, points.
        drawTeamLabel(dc, l, _them, 131, 126, TEAM_THEM, 1);
        dc.setColor(Palette.teamColor(_theme, TEAM_THEM), Graphics.COLOR_TRANSPARENT);
        l.fillRoundedRect(dc, 80, 138, 60, 60, 14);
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 110, 184, STYLE_NUMBER, 46, "3", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 250, 210, STYLE_NUMBER, 120, "30", Graphics.TEXT_JUSTIFY_CENTER);

        drawBanner(dc, l);
        drawMiniCourt(dc, l);

        // US: games tile, points, label and set pips.
        dc.setColor(Palette.teamColor(_theme, TEAM_US), Graphics.COLOR_TRANSPARENT);
        l.fillRoundedRect(dc, 80, 282, 60, 60, 14);
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 110, 328, STYLE_NUMBER, 46, "4", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 250, 355, STYLE_NUMBER, 120, "40", Graphics.TEXT_JUSTIFY_CENTER);
        drawTeamLabel(dc, l, _us, 360, 355, TEAM_US, 0);

        // Elapsed time and the bottom caption.
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 402, STYLE_NUMBER, 24, "0:42:17", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, 427, STYLE_BOLD, 14, 2, _caption, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // A team name and its set pips (won ones filled), the pips right after the name, whatever its
    // length in the language.
    private function drawTeamLabel(dc as Dc, l as Layout, name as String, baseline as Number, pipY as Number,
            team as Team, setsWon as Number) as Void {
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 80, baseline, STYLE_BOLD, 15, 2, name, Graphics.TEXT_JUSTIFY_LEFT);
        // The first pip's center sits 14 after the name (12 after its letter spacing, as SVG counts it).
        var pipX = 80 + l.textWidth(dc, STYLE_BOLD, 15, name, 2) + 14;
        var tint = Palette.teamTint(_theme, team);
        var color = Palette.teamColor(_theme, team);
        for (var i = 0; i < 2; i++) {
            if (i < setsWon) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                l.fillCircle(dc, pipX + i * 18, pipY, 6);
            } else {
                l.fillStrokedCircle(dc, pipX + i * 18, pipY, 5.5, tint, color, 1.5);
            }
        }
    }

    // The BREAK POINT pill on the net, as wide as its text plus a margin, centered on x = 250.
    private function drawBanner(dc as Dc, l as Layout) as Void {
        var width = l.textWidth(dc, STYLE_BOLD, 16, _banner, 2) + 2 * 30;
        l.fillStrokedRoundedRect(dc, 250 - width / 2, 225, width, 30, 15, Palette.BG, Palette.BALL, 2);
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 250, 246, STYLE_BOLD, 16, 2, _banner, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The serve indicator: court, center line, net, the server's dot. The mockup fills the court
    // with black at 60 % over the tints: plain black, the tints being 31 at most per channel.
    private function drawMiniCourt(dc as Dc, l as Layout) as Void {
        l.fillStrokedRoundedRect(dc, 352, 202, 52, 76, 6, Palette.BG, Palette.MUTED, 1.5);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 377.5, 202, 1, 76);
        dc.setColor(_courtNetColor, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 352, 239, 52, 2);
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.fillCircle(dc, 391, 221, 8);
    }
}

(:debug)
class DesignTestDelegate extends WatchUi.BehaviorDelegate {

    private var _view as DesignTestView;

    function initialize(view as DesignTestView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            var team = key == WatchUi.KEY_UP ? TEAM_THEM : TEAM_US;
            _view.flash = _view.flash == team ? null : team;
        } else if (key == WatchUi.KEY_ENTER) {
            _view.vector = !_view.vector;
            Fonts.setVectorEnabled(_view.vector);
        } else {
            return false;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

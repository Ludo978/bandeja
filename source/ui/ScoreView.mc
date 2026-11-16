import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The score screen (mockups "Score, in play", "Star point", "Tie-break"), drawn from the
// mockups' numbers through Layout: the court seen from above, THEM on the top half and US on the
// bottom one, each tinted with its team color, split by the net line. Each half has its team name
// and set pips, its games tile and its points; the mini court sits on the net with the serve dot and
// YOU / PARTNER, the banner on the net, the elapsed time and the caption at the bottom, the HR arc at
// the top. The team colors, here, on the overlay and on the stats page, are the Theme setting's
// (Palette), read when the screen shows: a change in the pause menu's Settings applies when it
// comes back.
//
// What shows comes from the match the app holds (CurrentMatch): ScoreModel works it out once per
// change, at the first redraw where the state the match gives isn't the one shown (an event added
// changes its event count, an undo replays a new state), and the strings and sizes with it. So after
// adding or undoing an event, WatchUi.requestUpdate() is all it needs. The timer and the heart rate
// are read at 1 Hz, with a redraw only when they change.
//
// The motion comes from ScoreMotion, after each input (input()): a point flashes its
// team's half for 200 ms, a point that won a game, a set or the match shows the team-color overlay
// for 1.5 s instead, and any input that does something ends the overlay. A point after which the
// players change ends puts the CHANGE ENDS pill on that overlay, or in a tie-break, where
// no overlay shows, the change of ends toast on the net. With the Change of ends alert off (read when
// the screen shows) neither shows, and the caption has no CHANGE ENDS AT n. One Timer serves the
// screen: the 1 Hz tick and the end of the flash, the overlay and the toast, each wake-up setting the
// next (ScoreMotion.nextWake()), so the toast has no timer of its own here. With Feedback's, 2 Timers
// run at once at most (Connect IQ starts 3 by default). At the match end the summary takes over
// (ScoreMotion, MatchFlow.showSummary()), and replaces this screen.
//
// The match is written to storage after every event, here once the change is on screen:
// a write takes about 35 ms on the watch, and requestUpdate() only queues the redraw, so a write in
// the input handler would hold the score back. A change sets the timer's next wake-up SAVE_WAIT
// later at most, and that wake-up writes the match if the screen has drawn its state since; a menu
// covering the screen writes it at once (onHide()), and a change still not drawn a second later is
// written anyway. The same tick checks the battery: at 3 % the session is saved and the app exits
// (MatchFlow.checkBattery()).
//
// The data page (DataPage) is this screen's second page and the stats page (StatsPage)
// its third, drawn in place of the score page when ScoreMotion says so: a swipe left turns to the
// next one, a swipe right to the one before, the match menu's Data page and Stats page show theirs
// (MatchFlow.showPage()). They take the same input, through the same ScoreInput (one debounce),
// and the data page is read on the same tick, so they add no Timer; UP, DOWN and BACK bring the score
// page back, where they're answered. The stats page shows the match's stats, worked out at a redraw
// when the state changed; nothing on it ticks, so the tick doesn't redraw it.
//
// A timed match runs on the same tick too: the court time left on the data page, the TIME
// LEFT and TIME banners when the score gives none (ScoreModel.setCourt()), and the warnings at T-10
// and T-5 and the TIME alert, each once (CurrentMatch.takeCourtAlert()): the court time's vibration
// and tones, and a toast on the net. Nothing there takes a press: points keep counting, and Finish and
// Keep playing wait in the pause menu (MatchMenuRules).
class ScoreView extends WatchUi.View {

    // The toast's center line: the net, where it covers the banner (the undo toast).
    static const TOAST_Y = 240;
    // The longest wait from a change to the wake-up that writes it, once it's drawn.
    private const SAVE_WAIT = ScoreMotion.MIN_WAIT;
    // The bottom caption keeps this far inside the circle at its baseline.
    private const CAPTION_MARGIN = 10;
    private const CAPTION_Y = 427;
    // The overlay's lines (mockup "Game won + change ends"): baselines, sizes, letter spacing, and
    // the space kept inside the circle at the top of their capitals, as the caption's.
    private const OVERLAY_CONTEXT_Y = 128;
    private const OVERLAY_CONTEXT_SIZE = 16;
    private const OVERLAY_CONTEXT_SPACING = 3;
    private const OVERLAY_WORD_Y = 236;
    private const OVERLAY_WORD_SIZE = 104;
    private const OVERLAY_WORD_SPACING = 2;
    private const OVERLAY_SCORE_Y = 306;
    private const OVERLAY_SCORE_SIZE = 56;
    private const OVERLAY_MARGIN = 10;
    // The overlay's CHANGE ENDS pill (the same mockup): black, from 334 to 374, never narrower than
    // the mockup's 200; inside it, 22 from its left end, the yellow swap arrows (20 wide, 2 thick, at
    // 348 and 360), then 12 further the text (baseline 360, Bold 17, spacing 2, white), and 22 at least
    // after it.
    private const ENDS_TOP = 334;
    private const ENDS_HEIGHT = 40;
    private const ENDS_MIN_WIDTH = 200;
    private const ENDS_PADDING = 22;
    private const ENDS_ICON = 20;
    private const ENDS_GAP = 12;
    private const ENDS_TEXT_Y = 360;
    private const ENDS_TEXT_SIZE = 17;
    private const ENDS_SPACING = 2;

    // The app's toast ("Undone: point US"), drawn last, on the net. Shown with showToast(),
    // on the screen's timer.
    var toast as Toast = new Toast();

    private var _match as CurrentMatch;
    private var _motion as ScoreMotion = new ScoreMotion();
    // System.getTimer() at the last redraw.
    private var _drawnAt as Number = 0;
    // When the wake-ups first found the match unsaved, null while it's written.
    private var _unsavedAt as Number? = null;
    private var _layout as Layout = new Layout(416);
    private var _timer as Timer.Timer = new Timer.Timer();
    // A quick BACK waiting for the edge swipe's drags (BackGuard): when to call the delegate back.
    private var _backAt as Number? = null;
    private var _backDue as (Method() as Void)? = null;
    private var _heartRate as HeartRateArc = new HeartRateArc(null);
    private var _data as DataPage = new DataPage();
    private var _stats as StatsPage = new StatsPage();
    // Loaded once (onLayout). Banners and captions indexed by Banner and Caption.
    private var _names as Array<String> = ["", ""];
    private var _ad as String = "";
    private var _banners as Array<String?> = [] as Array<String?>;
    private var _captions as Array<String?> = [] as Array<String?>;
    private var _pausedText as String = "";
    private var _you as String = "";
    private var _partner as String = "";
    // The first set pip's mockup x for each team, right after its name.
    private var _pipX as Array<Float> = [0.0, 0.0];
    // Free play's sets won in the pips' place: from the first pip's left edge, Bold SETS_SIZE
    // in the team's color, the middle of its digits on the pips' line.
    private const SETS_SIZE = 18;
    // The state shown (and its event count, as an event changes it in place), and what it shows.
    private var _state as MatchState? = null;
    private var _eventCount as Number = -1;
    private var _model as ScoreModel? = null;
    private var _points as Array<String> = ["", ""];
    private var _games as Array<String> = ["", ""];
    private var _bannerText as String? = null;
    private var _bannerSize as Number = 16;
    private var _bannerWidth as Float = 0.0;
    // The court time banner changed since its text was measured (refresh()): measured at the redraw.
    private var _bannerStale as Boolean = false;
    private var _captionText as String? = null;
    private var _captionSize as Number = 14;
    private var _serverText as String? = null;
    // The elapsed time shown, in seconds and as text.
    private var _seconds as Number = -1;
    private var _time as String = "";
    // The mockups' other opacities over black: the net line, the mini court's net.
    private var _netColor as Number = Palette.onBlack(Palette.TEXT, 55);
    private var _courtNetColor as Number = Palette.onBlack(Palette.TEXT, 80);
    // The Theme setting (onShow()).
    private var _theme as ThemeSetting = Settings.DEFAULT_THEME;
    // The overlay: its words and fitted sizes indexed by PointWon (WON_POINT unused), its contexts
    // (SET $1$, TIE-BREAK), its context line's color per team in the theme (black at 60 % over the team
    // color).
    private var _overlayWords as Array<String> = ["", "", "", ""];
    private var _overlayWordSizes as Array<Number> = [0, 0, 0, 0];
    private var _overlayContexts as Array<String> = ["", ""];
    private var _overlayDim as Array<Number> = [0, 0];
    // The CHANGE ENDS pill's text, its fitted size and its width at that size; the change of ends toast.
    private var _endsText as String = "";
    private var _endsSize as Number = 17;
    private var _endsWidth as Float = 0.0;
    private var _endsToast as String = "";
    // The overlay whose texts are worked out, and them.
    private var _overlay as ScoreOverlay? = null;
    private var _overlayContext as String = "";
    private var _overlayContextSize as Number = 16;
    private var _overlayScore as String = "";
    // Debug fixtures only: [elapsed seconds, heart rate, calories, this game's seconds] and the heart
    // rate zones, shown instead of the real ones.
    private var _fixed as Array<Number>? = null;
    private var _fixedZones as Array<Number>? = null;

    function initialize(match as CurrentMatch) {
        View.initialize();
        _match = match;
    }

    function onLayout(dc as Dc) as Void {
        var l = new Layout(dc.getWidth());
        _layout = l;
        _names = [WatchUi.loadResource(Rez.Strings.Us) as String, WatchUi.loadResource(Rez.Strings.Them) as String];
        _ad = WatchUi.loadResource(Rez.Strings.PointsAd) as String;
        _you = WatchUi.loadResource(Rez.Strings.ServerYou) as String;
        _partner = WatchUi.loadResource(Rez.Strings.ServerPartner) as String;
        _banners = new Array<String?>[BANNER_TIME + 1];
        for (var i = 0; i < _banners.size(); i++) {
            var id = ScoreModel.bannerString(i as Banner);
            _banners[i] = id != null ? WatchUi.loadResource(id) as String : null;
        }
        _pausedText = WatchUi.loadResource(Rez.Strings.ToastPaused) as String;
        _captions = new Array<String?>[CAPTION_SAME_SEX_RECEIVES + 1];
        for (var i = 0; i < _captions.size(); i++) {
            var id = ScoreModel.captionString(i as Caption);
            _captions[i] = id != null ? WatchUi.loadResource(id) as String : null;
        }
        // The first pip's center 14 after the name (12 after its letter spacing, as SVG counts it).
        for (var team = 0; team < 2; team++) {
            _pipX[team] = 80 + l.textWidth(dc, STYLE_BOLD, 15, _names[team], 2) + 14;
        }
        var won = [WON_GAME, WON_SET, WON_MATCH] as Array<PointWon>;
        for (var i = 0; i < won.size(); i++) {
            var word = WatchUi.loadResource(ScoreOverlay.wordString(won[i])) as String;
            _overlayWords[won[i]] = word;
            _overlayWordSizes[won[i]] = fitOverlay(dc, OVERLAY_WORD_SIZE, word, OVERLAY_WORD_SPACING, OVERLAY_WORD_Y);
        }
        _overlayContexts = [WatchUi.loadResource(ScoreOverlay.contextString(false)) as String,
            WatchUi.loadResource(ScoreOverlay.contextString(true)) as String];
        // The pill's text keeps OVERLAY_MARGIN inside the circle at the pill's bottom, the arrows and the
        // padding beside it.
        _endsText = WatchUi.loadResource(Rez.Strings.OverlayChangeEnds) as String;
        var around = 2 * ENDS_PADDING + ENDS_ICON + ENDS_GAP;
        _endsSize = l.fitSize(dc, STYLE_BOLD, ENDS_TEXT_SIZE, _endsText, ENDS_SPACING,
            Layout.chord(ENDS_TOP + ENDS_HEIGHT) - 2 * OVERLAY_MARGIN - around);
        _endsWidth = l.textWidth(dc, STYLE_BOLD, _endsSize, _endsText, ENDS_SPACING);
        _endsToast = WatchUi.loadResource(Rez.Strings.ToastChangeEnds) as String;
        // The score's font loads now rather than at the first overlay, right after a press.
        l.font(STYLE_NUMBER, OVERLAY_SCORE_SIZE);
        _data.load(dc, l, _match.court != null);
        _stats.load(dc, l);
        // The strings and sizes go with the screen.
        _state = null;
        _overlay = null;
    }

    function onShow() as Void {
        readSettings();
        var fixed = _fixed;
        _heartRate = new HeartRateArc(fixed != null ? _fixedZones : HeartRateArc.readZones());
        if (fixed != null) {
            _heartRate.setHeartRate(fixed[1]);
            setSeconds(fixed[0]);
            _data.set(fixed[0] * 1000, fixed[2], fixed[3], fourthText(Time.now().value()));
        }
        refresh();
        var now = System.getTimer();
        _motion.startTicks(now);
        _motion.shown(_match.getState(), now);
        schedule(now);
    }

    // A change made in the Garmin Connect app (BandejaApp.onSettingsChanged()) while this screen shows:
    // what it reads when it shows, read again, and redrawn at once. Touch scoring and the press delay are
    // read at each press (ScoreDelegate), Vibration and Sounds at each event (Feedback).
    function applySettings() as Void {
        readSettings();
        WatchUi.requestUpdate();
    }

    // The Change of ends alert and the theme, which a menu over the screen (the pause menu's Settings)
    // or the Garmin Connect app can change: the caption follows the alert, worked out again at the next
    // redraw; the colors are the theme's from the next redraw.
    private function readSettings() as Void {
        var alert = Settings.isChangeOfEndsAlert();
        if (alert != _motion.endsAlert) {
            _motion.endsAlert = alert;
            _state = null;
        }
        setTheme(Settings.getTheme());
    }

    // The team colors' theme, and the overlay's context line colors in it.
    private function setTheme(theme as ThemeSetting) as Void {
        _theme = theme;
        for (var team = 0; team < 2; team++) {
            _overlayDim[team] = Palette.onBlack(Palette.teamColor(theme, team as Team), Palette.OVERLAY_DIM_PERCENT);
        }
    }

    // A menu on top (the serve questions, the pause menu) or the next screen: no ticks, and the toast
    // is gone. The flash and the overlay end on time, so one still due when the screen shows again
    // comes back. The page showing stays. A change not written yet is written now, the score having
    // left the screen.
    function onHide() as Void {
        _backAt = null;
        _backDue = null;
        _timer.stop();
        toast.hide();
        _match.save();
    }

    // After an input (ScoreDelegate, with ScoreInput's action, team, what the point won and whether
    // the players change ends after it): the flash or the overlay a point brings, the overlay the
    // input ends, or the other page, redrawn at once. An overlay and a page turn end the toast, which
    // spoke of an earlier press; a tie-break point that changes ends shows the change of ends toast.
    function input(action as ScoreAction, team as Team?, won as PointWon, ends as Boolean) as Void {
        if (_motion.isIdle(action)) {
            return;
        }
        var now = System.getTimer();
        var page = _motion.page;
        var ended = _motion.input(action, team, won, ends, _match.getState(), now);
        var turned = _motion.page != page;
        if (turned || _motion.getOverlayAt(now) != null) {
            toast.hide();
        }
        if (_motion.endsToast) {
            toast.showAt(_endsToast, now);
        }
        if (turned && _motion.page == PAGE_DATA) {
            refresh();
        }
        if (ended != null || turned || action == INPUT_POINT) {
            WatchUi.requestUpdate();
        }
        schedule(now);
    }

    // The page showing (ScoreInput.tap(): touch scoring scores on the score page only).
    function getPage() as ScorePage {
        return _motion.page;
    }

    // The match menu's Data page or Stats page, the menu closed (MatchFlow.showPage()): that page,
    // target, if another page shows; the data page with its values read now.
    function showPage(target as ScorePage) as Void {
        if (!_motion.showPage(target)) {
            return;
        }
        toast.hide();
        if (target == PAGE_DATA) {
            refresh();
        }
        WatchUi.requestUpdate();
    }

    // Shows the toast for Toast.DURATION, timed by the screen's timer.
    function showToast(text as String) as Void {
        var now = System.getTimer();
        toast.showAt(text, now);
        WatchUi.requestUpdate();
        schedule(now);
    }

    // The screen's timer: first the write of a change the screen shows; then the summary's hand-over
    // at the match end (ScoreMotion), which replaces this screen, its timer stopped; else the tick
    // (the battery, a redraw only when the time, the heart rate or the court time shown changed, and
    // a court time alert due), and a redraw when the flash, the overlay or the toast ended since the
    // last one.
    function onWake() as Void {
        var now = System.getTimer();
        var backAt = _backAt;
        if (backAt != null && now - backAt >= 0) {
            var due = _backDue;
            _backAt = null;
            _backDue = null;
            if (due != null) {
                due.invoke();
                now = System.getTimer();
            }
        }
        var state = _match.getState();
        var since = _unsavedAt;
        if (_match.isUnsaved() && ((state == _state && state.eventCount == _eventCount)
                || (since != null && now - since >= ScoreMotion.TICK))) {
            _match.save();
            now = System.getTimer();
        }
        if (_motion.takeSummary(now) && state.matchOver) {
            _timer.stop();
            MatchFlow.showSummary(_match);
            return;
        }
        var redraw = _motion.changed(_drawnAt, now)
            || (toast.getTextAt(_drawnAt) == null) != (toast.getTextAt(now) == null);
        if (_motion.tick(now)) {
            if (MatchFlow.checkBattery()) {
                _timer.stop();
                return;
            }
            redraw = refresh() || redraw;
            courtAlert(now);
        }
        if (redraw) {
            WatchUi.requestUpdate();
        }
        schedule(now);
    }

    // The next wake-up: ScoreMotion's, or SAVE_WAIT from now while a change isn't written.
    // Calls due at the timer's wake-up at `at` (ScoreDelegate's quick BACK).
    function deferBack(at as Number, due as Method() as Void) as Void {
        _backAt = at;
        _backDue = due;
        schedule(System.getTimer());
    }

    private function schedule(now as Number) as Void {
        var wait = _motion.nextWake(now, toast.getEndAt(now));
        var backAt = _backAt;
        if (backAt != null) {
            var untilBack = backAt - now;
            if (untilBack < wait) {
                wait = untilBack < 50 ? 50 : untilBack;
            }
        }
        if (!_match.isUnsaved()) {
            _unsavedAt = null;
        } else {
            if (_unsavedAt == null) {
                _unsavedAt = now;
            }
            if (wait > SAVE_WAIT) {
                wait = SAVE_WAIT;
            }
        }
        _timer.stop();
        _timer.start(method(:onWake), wait, false);
    }

    // Reads the heart rate and the timer, a timed match's court time banner, and the data page's
    // values while it shows; true when what shows changed, never on the stats page, which shows none
    // of them. The fixtures keep their values but the court time and the time of day.
    function refresh() as Boolean {
        var now = Time.now().value();
        var changed = false;
        var model = _model;
        if (model != null && model.setCourt(_match.court, now)) {
            _bannerStale = true;
            changed = true;
        }
        var page = _motion.page;
        var fixed = _fixed;
        if (fixed != null) {
            if (page == PAGE_DATA) {
                changed = _data.set(fixed[0] * 1000, fixed[2], fixed[3], fourthText(now)) || changed;
            }
            return changed && page != PAGE_STATS;
        }
        changed = _heartRate.update() || changed;
        var info = Activity.getActivityInfo();
        var timerTime = info != null ? info.timerTime : null;
        changed = setSeconds(timerTime != null ? timerTime / 1000 : 0) || changed;
        if (page == PAGE_DATA) {
            var seconds = DataPage.gameSeconds(_match.getState(), _match.start, now);
            changed = _data.set(timerTime, info != null ? info.calories : null, seconds, fourthText(now)) || changed;
        }
        return changed && page != PAGE_STATS;
    }

    // A timed match's warning at T-10 or T-5, or its TIME alert, when due (each once): the
    // court time's vibration and tones, and its toast on the net, over either page. Not during the
    // game / set overlay, which the toast would cover: it comes at the first tick after it.
    private function courtAlert(now as Number) as Void {
        if (_motion.getOverlayAt(now) != null) {
            return;
        }
        var text = ScoreModel.courtAlertString(_match.takeCourtAlert(Time.now().value()));
        if (text == null) {
            return;
        }
        getFeedback().court();
        toast.showAt(WatchUi.loadResource(text) as String, now);
        WatchUi.requestUpdate();
    }

    // The data page's fourth cell: a timed match's court time left, else the time of day.
    private function fourthText(now as Number) as String {
        var court = _match.court;
        return court != null ? TimeText.countdown(court.getLeft(now)) : clockText();
    }

    // The time of day as the watch's clock setting has it (12 h or 24 h), both read at each tick.
    private static function clockText() as String {
        var time = System.getClockTime();
        return TimeText.clock(time.hour, time.min, System.getDeviceSettings().is24Hour);
    }

    // Debug builds: the fixtures (ScoreFixtures) show the mockups' values: values is [elapsed seconds,
    // heart rate, calories, this game's seconds], its zone from zones, and the summary's maximum
    // heart rate after them when the fixture has one.
    (:debug)
    function fix(values as Array<Number>, zones as Array<Number>) as Void {
        _fixed = values;
        _fixedZones = zones;
    }

    // The fixture's values (fix()), which the summary shows in place of the activity's; null outside
    // the fixtures, and always in release builds.
    function getFixed() as Array<Number>? {
        return _fixed;
    }

    function onUpdate(dc as Dc) as Void {
        var now = System.getTimer();
        _drawnAt = now;
        var state = _match.getState();
        if (state != _state || state.eventCount != _eventCount) {
            update(dc, state);
        } else if (_bannerStale) {
            measureBanner(dc, _model as ScoreModel);
        }
        dc.setAntiAlias(true);
        // The overlay covers the whole screen: the score isn't drawn under it.
        var overlay = _motion.getOverlayAt(now);
        if (overlay != null) {
            drawOverlay(dc, _layout, overlay);
        } else if (_motion.page == PAGE_DATA) {
            _data.draw(dc, _layout, _heartRate);
        } else if (_motion.page == PAGE_STATS) {
            _stats.show(state, _match.start);
            _stats.draw(dc, _layout, _theme);
        } else {
            // A pill on the net (a toast, or "Paused") takes the net: no banner around it.
            drawScore(dc, _layout, _motion.getFlashAt(now), toast.getTextAt(now) == null && !getSessionManager().isPaused());
        }
        // While the timer is stopped (the pause menu closed with BACK, or after one of its events)
        // the "Paused" toast stays on the net, so the pause shows without a press.
        if (toast.getTextAt(now) == null && getSessionManager().isPaused()) {
            toast.drawText(dc, _layout, TOAST_Y, _pausedText);
        } else {
            toast.draw(dc, _layout, TOAST_Y);
        }
    }

    // The score, the flash (null for none) on its team's half, the banner unless the net has a pill.
    private function drawScore(dc as Dc, l as Layout, flash as Team?, banner as Boolean) as Void {
        var model = _model as ScoreModel;
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        // The halves: rectangles are enough, the screen itself is round.
        var halves = [halfColor(TEAM_US, flash), halfColor(TEAM_THEM, flash)];
        dc.setColor(halves[TEAM_THEM], Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 32, 32, 416, 208);
        dc.setColor(halves[TEAM_US], Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 32, 240, 416, 208);
        dc.setColor(_netColor, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 20, 239, 440, 2);

        _heartRate.draw(dc, l);
        // THEM: name and pips at 131 / 126, tile at 138, points at 210. US: tile at 282, points at
        // 355, name and pips at 360 / 355.
        drawTeam(dc, l, model, TEAM_THEM, halves[TEAM_THEM], 131, 126, 138, 210);
        drawTeam(dc, l, model, TEAM_US, halves[TEAM_US], 360, 355, 282, 355);
        drawCourt(dc, l, model);
        if (banner) {
            drawBanner(dc, l, model);
        }

        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 402, STYLE_NUMBER, 24, _time, Graphics.TEXT_JUSTIFY_CENTER);
        var caption = _captionText;
        if (caption != null) {
            // A smaller font keeps the middle of the capitals where the mockup has it.
            dc.setColor(ScoreModel.captionColor(model.caption), Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, 240, CAPTION_Y - Fonts.CAP_MIDDLE * (14 - _captionSize), STYLE_BOLD, _captionSize, 2,
                caption, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // The game, set or match overlay (mockup "Game won + change ends"): the screen in the team's
    // color, the context line (SET 2 · US, TIE-BREAK · US) in black at 60 %, the word and the set's
    // score in black, and the CHANGE ENDS pill when the players change ends. A smaller font keeps
    // the middle of the capitals in place.
    private function drawOverlay(dc as Dc, l as Layout, overlay as ScoreOverlay) as Void {
        if (overlay != _overlay) {
            prepareOverlay(dc, overlay);
        }
        var color = Palette.teamColor(_theme, overlay.team);
        dc.setColor(color, color);
        dc.clear();
        dc.setColor(_overlayDim[overlay.team], Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, OVERLAY_CONTEXT_Y - Fonts.CAP_MIDDLE * (OVERLAY_CONTEXT_SIZE - _overlayContextSize),
            STYLE_BOLD, _overlayContextSize, OVERLAY_CONTEXT_SPACING, _overlayContext, Graphics.TEXT_JUSTIFY_CENTER);
        var size = _overlayWordSizes[overlay.won];
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, OVERLAY_WORD_Y - Fonts.CAP_MIDDLE * (OVERLAY_WORD_SIZE - size), STYLE_BOLD, size,
            OVERLAY_WORD_SPACING, _overlayWords[overlay.won], Graphics.TEXT_JUSTIFY_CENTER);
        l.drawText(dc, 240, OVERLAY_SCORE_Y, STYLE_NUMBER, OVERLAY_SCORE_SIZE, _overlayScore,
            Graphics.TEXT_JUSTIFY_CENTER);
        if (overlay.changeEnds) {
            drawEndsPill(dc, l);
        }
    }

    // The CHANGE ENDS pill, centered under the score: the arrows and the text from 22 inside its left
    // end, so the English one is the mockup's, and a longer text (French CHANGEZ DE CÔTÉ) widens it
    // with 22 after it too.
    private function drawEndsPill(dc as Dc, l as Layout) as Void {
        var width = _endsWidth + 2 * ENDS_PADDING + ENDS_ICON + ENDS_GAP;
        if (width < ENDS_MIN_WIDTH) {
            width = ENDS_MIN_WIDTH.toFloat();
        }
        var left = 240 - width / 2;
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.fillRoundedRect(dc, left, ENDS_TOP, width, ENDS_HEIGHT, ENDS_HEIGHT / 2);
        var x = left + ENDS_PADDING;
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(l.pen(2));
        drawArrow(dc, l, x, x + ENDS_ICON, 348);
        drawArrow(dc, l, x + ENDS_ICON, x, 360);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, x + ENDS_ICON + ENDS_GAP, ENDS_TEXT_Y - Fonts.CAP_MIDDLE * (ENDS_TEXT_SIZE - _endsSize),
            STYLE_BOLD, _endsSize, ENDS_SPACING, _endsText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The mockup's arrow on the line y, from `from` to its tip at `to`, its head 5 back and 5 to each
    // side, in the current color and pen.
    private function drawArrow(dc as Dc, l as Layout, from as Float, to as Float, y as Number) as Void {
        var back = to > from ? to - 5 : to + 5;
        dc.drawLine(l.x(from), l.y(y), l.x(to), l.y(y));
        dc.drawLine(l.x(back), l.y(y - 5), l.x(to), l.y(y));
        dc.drawLine(l.x(back), l.y(y + 5), l.x(to), l.y(y));
    }

    // The overlay's context line and score, and the context's fitted size.
    private function prepareOverlay(dc as Dc, overlay as ScoreOverlay) as Void {
        var context = overlay.tieBreak ? _overlayContexts[1] : Lang.format(_overlayContexts[0], [overlay.setNumber]);
        _overlayContext = context + FormatText.SEPARATOR + _names[overlay.team];
        _overlayContextSize = fitOverlay(dc, OVERLAY_CONTEXT_SIZE, _overlayContext, OVERLAY_CONTEXT_SPACING,
            OVERLAY_CONTEXT_Y);
        _overlayScore = Lang.format("$1$ - $2$", [overlay.score[TEAM_US], overlay.score[TEAM_THEM]]);
        _overlay = overlay;
    }

    // The overlay's mockup size for a line, or a smaller one down to three quarters, so it keeps
    // OVERLAY_MARGIN inside the circle at the top of its capitals.
    private function fitOverlay(dc as Dc, size as Number, text as String, spacing as Number,
            baseline as Number) as Number {
        var top = baseline - 2 * Fonts.CAP_MIDDLE * size;
        return _layout.fitSize(dc, STYLE_BOLD, size, text, spacing, Layout.chord(top) - 2 * OVERLAY_MARGIN);
    }

    // Works out what the state shows: the model, its texts and their sizes.
    private function update(dc as Dc, state as MatchState) as Void {
        var model = new ScoreModel(_match.engine.getConfig(), state, _motion.endsAlert);
        model.setCourt(_match.court, Time.now().value());
        var l = _layout;
        for (var team = 0; team < 2; team++) {
            _points[team] = ScoreModel.pointsText(model.points[team], _ad);
            _games[team] = model.games[team].toString();
        }
        measureBanner(dc, model);

        var caption = _captions[model.caption];
        if (caption != null && (model.caption == CAPTION_SET || model.caption == CAPTION_CHANGE_ENDS_AT)) {
            caption = Lang.format(caption, [model.captionNumber]);
        }
        _captionText = caption;
        if (caption != null) {
            _captionSize = l.fitSize(dc, STYLE_BOLD, 14, caption, 2, Layout.chord(CAPTION_Y) - 2 * CAPTION_MARGIN);
        }

        var server = model.server;
        _serverText = server == PLAYER_ME ? _you : server == PLAYER_PARTNER ? _partner : null;
        _model = model;
        _state = state;
        _eventCount = state.eventCount;
    }

    // The banner's text, its size and its pill's width: DEUCE n takes its count, TIME LEFT the time
    // left.
    private function measureBanner(dc as Dc, model as ScoreModel) as Void {
        var l = _layout;
        var banner = _banners[model.banner];
        if (banner != null && model.banner == BANNER_DEUCE) {
            banner = Lang.format(banner, [model.bannerNumber]);
        } else if (banner != null && model.banner == BANNER_TIME_LEFT) {
            banner = Lang.format(banner, [TimeText.countdown(model.bannerNumber)]);
        }
        _bannerText = banner;
        if (banner != null) {
            _bannerSize = l.fitSize(dc, STYLE_BOLD, 16, banner, 2, ScoreModel.BANNER_TEXT_MAX);
            _bannerWidth = ScoreModel.bannerWidth(l.textWidth(dc, STYLE_BOLD, _bannerSize, banner, 2));
        }
        _bannerStale = false;
    }

    private function halfColor(team as Team, flash as Team?) as Number {
        return flash == team ? Palette.teamFlash(_theme, team) : Palette.teamTint(_theme, team);
    }

    // A team's name and set pips, games tile and points, at the mockup's places for its half.
    private function drawTeam(dc as Dc, l as Layout, model as ScoreModel, team as Team, half as Number,
            nameY as Number, pipY as Number, tileY as Number, pointsY as Number) as Void {
        var color = Palette.teamColor(_theme, team);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 80, nameY, STYLE_BOLD, 15, 2, _names[team], Graphics.TEXT_JUSTIFY_LEFT);
        if (model.setsAsNumber) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            l.drawText(dc, _pipX[team] - 6, pipY + Fonts.CAP_MIDDLE * SETS_SIZE, STYLE_NUMBER, SETS_SIZE,
                model.setsWon[team].toString(), Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Won sets are filled pips; the others are outlines over the half's color.
        for (var i = 0; i < model.pips; i++) {
            var x = _pipX[team] + i * 18;
            if (model.isPipFilled(team, i)) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                l.fillCircle(dc, x, pipY, 6);
            } else {
                l.fillStrokedCircle(dc, x, pipY, 5.5, half, color, 1.5);
            }
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        l.fillRoundedRect(dc, 80, tileY, 60, 60, 14);
        dc.setColor(Palette.BG, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 110, tileY + 46, STYLE_NUMBER, 46, _games[team], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, ScoreModel.BANNER_X, pointsY, ScoreModel.pointsStyle(model.points[team]), 120, _points[team],
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The serve indicator on the net: court, center line, net, the ball in the server's quadrant (on
    // the center line on a deciding point), and YOU / PARTNER under it when we serve. The mockup
    // fills the court with black at 60 % over the tints: plain black, the tints being 31 at most per
    // channel.
    private function drawCourt(dc as Dc, l as Layout, model as ScoreModel) as Void {
        l.fillStrokedRoundedRect(dc, 352, 202, 52, 76, 6, Palette.BG, Palette.MUTED, 1.5);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 377.5, 202, 1, 76);
        dc.setColor(_courtNetColor, Graphics.COLOR_TRANSPARENT);
        l.fillRect(dc, 352, 239, 52, 2);
        var dot = model.dot;
        if (dot != null) {
            dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
            l.fillCircle(dc, dot[0], dot[1], 8);
        }
        var server = _serverText;
        if (server != null) {
            dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, ScoreModel.DOT_CENTER_X, 298, STYLE_BOLD, 13, 1, server, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // The banner's pill on the net, centered with the points, in its style's colors.
    private function drawBanner(dc as Dc, l as Layout, model as ScoreModel) as Void {
        var text = _bannerText;
        if (text == null) {
            return;
        }
        var colors = ScoreModel.bannerColors(model.bannerStyle);
        l.fillStrokedRoundedRect(dc, ScoreModel.BANNER_X - _bannerWidth / 2, 225, _bannerWidth, 30, 15, colors[0],
            colors[1], 2);
        dc.setColor(colors[2], Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, ScoreModel.BANNER_X, 246 - Fonts.CAP_MIDDLE * (16 - _bannerSize), STYLE_BOLD, _bannerSize,
            2, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The elapsed time as h:mm:ss; true when it changed.
    private function setSeconds(seconds as Number) as Boolean {
        if (seconds == _seconds) {
            return false;
        }
        _seconds = seconds;
        _time = TimeText.duration(seconds, true);
        return true;
    }
}

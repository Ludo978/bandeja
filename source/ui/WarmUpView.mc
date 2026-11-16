import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The sensor lock, then the warm-up (mockup "Warm-up"): one screen, drawn from
// the mockup's numbers through Layout. Before recording (the lock) the label says READY, or
// SEARCHING GPS outdoors until the position is usable, the time shows 0:00 in grey, and the hint
// says what START begins (the warm-up, or the match when the Warm-up phase is off). Recording, it is
// the warm-up: the HR arc and HR, WARM-UP in yellow, the timer running in white, a timed match's court
// time left in yellow under a divider (from the lock on: the booking is picked before it), the format
// line, and START · BEGIN MATCH. No team colors and no score. Without the court time (an untimed
// match) the content above keeps the mockup's places, the format line moves up into the middle of
// the space left. Redrawn at 1 Hz only when what shows changes, and when the toast comes or goes.
// The same tick gives a timed match's warnings and TIME alert, each once: the court
// time's vibration and tones, and the toast.
class WarmUpView extends WatchUi.View {

    private const SEPARATOR = " · ";
    // The format line's baseline, in mockup pixels: under the court time in a timed match (the
    // mockup's), else in the middle of the space between the time and the hint. The toast's center
    // line stays at the middle of that space, over the format line or over the court time.
    private const FORMAT_Y = 347;
    private const FORMAT_TIMED_Y = 391;
    private const TOAST_Y = 341;

    var flow as WarmUpFlow;
    // "Press START to begin the match", over the format line.
    var toast as Toast = new Toast();
    var toastText as String = "";

    private var _layout as Layout = new Layout(416);
    private var _timer as Timer.Timer = new Timer.Timer();
    private var _heartRate as HeartRateArc = new HeartRateArc(null);
    private var _warmUp as String = "";
    private var _ready as String = "";
    private var _searchingGps as String = "";
    private var _beginMatch as String = "";
    private var _start as String = "";
    private var _formatLine as String = "";
    private var _courtLeft as String = "";
    // A timed match's court time left, as shown.
    private var _court as String = "";
    // What shows: the timer in seconds and as text, and whether GPS is ready (always indoors).
    private var _seconds as Number = 0;
    private var _time as String = "0:00";
    private var _gpsReady as Boolean = true;
    // Font sizes by text, smaller where a translation doesn't fit: worked out at the first draw.
    private var _sizes as Dictionary<String, Number> = {};

    function initialize(flow as WarmUpFlow) {
        View.initialize();
        self.flow = flow;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new Layout(dc.getWidth());
        _warmUp = WatchUi.loadResource(Rez.Strings.WarmUp) as String;
        _ready = WatchUi.loadResource(Rez.Strings.LockReady) as String;
        _searchingGps = WatchUi.loadResource(Rez.Strings.LockGps) as String;
        _beginMatch = WatchUi.loadResource(Rez.Strings.HintBeginMatch) as String;
        _start = WatchUi.loadResource(Rez.Strings.ButtonStart) as String;
        toastText = WatchUi.loadResource(Rez.Strings.ToastPressStart) as String;
        _courtLeft = WatchUi.loadResource(Rez.Strings.CourtLeft) as String;
        _formatLine = FormatText.line(flow.config);
        _sizes = {};
    }

    function onShow() as Void {
        flow.lock();
        _heartRate = new HeartRateArc(HeartRateArc.readZones());
        refresh();
        _timer.stop();
        _timer.start(method(:onTick), 1000, true);
    }

    // A menu on top: no ticks, and the toast is gone.
    function onHide() as Void {
        _timer.stop();
        toast.hide();
    }

    // At 3 % battery while recording, the session is saved and the app exits.
    function onTick() as Void {
        if (flow.isRecording() && MatchFlow.checkBattery()) {
            _timer.stop();
            return;
        }
        if (refresh()) {
            WatchUi.requestUpdate();
        }
        courtAlert();
    }

    // A timed match's warning at T-10 or T-5, or its TIME alert, when due (each once): the court time's
    // vibration and tones, and its toast. The match takes the alerts given with the booking.
    private function courtAlert() as Void {
        var court = flow.court;
        if (court == null) {
            return;
        }
        var text = ScoreModel.courtAlertString(court.take(Time.now().value()));
        if (text != null) {
            getFeedback().court();
            toast.show(WatchUi.loadResource(text) as String);
        }
    }

    // Reads the heart rate, the timer, the GPS and the court time left; true when what shows changed.
    function refresh() as Boolean {
        var changed = _heartRate.update();
        var court = flow.court;
        if (court != null) {
            var left = TimeText.countdown(court.getLeft(Time.now().value()));
            if (!left.equals(_court)) {
                _court = left;
                changed = true;
            }
        }
        var seconds = 0;
        if (flow.isRecording()) {
            var info = Activity.getActivityInfo();
            var timerTime = info != null ? info.timerTime : null;
            seconds = timerTime != null ? timerTime / 1000 : 0;
        }
        if (seconds != _seconds) {
            _seconds = seconds;
            _time = TimeText.duration(seconds, false);
            changed = true;
        }
        var gpsReady = !flow.outdoor || isGpsReady();
        if (gpsReady != _gpsReady) {
            _gpsReady = gpsReady;
            changed = true;
        }
        return changed;
    }

    function onUpdate(dc as Dc) as Void {
        var l = _layout;
        var recording = flow.isRecording();
        dc.setAntiAlias(true);
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();

        _heartRate.draw(dc, l);
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.drawStartArc(dc);

        var label = _warmUp;
        var labelColor = Palette.BALL;
        if (!recording) {
            label = _gpsReady ? _ready : _searchingGps;
            labelColor = _gpsReady ? Palette.TEXT : Palette.MUTED;
        }
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, 240, 156, STYLE_BOLD, size(dc, STYLE_BOLD, 20, label, 6, 340), 6, label,
            Graphics.TEXT_JUSTIFY_CENTER);

        // The time's digits stand between y 185 and 270, where the circle is 401 wide.
        dc.setColor(recording ? Palette.TEXT : Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, 270, STYLE_NUMBER, size(dc, STYLE_NUMBER, 120, _time, 0, 360), _time,
            Graphics.TEXT_JUSTIFY_CENTER);

        var formatY = FORMAT_Y;
        if (flow.court != null) {
            formatY = FORMAT_TIMED_Y;
            dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
            l.fillRect(dc, 170, 297.25, 140, 1.5);
            dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
            l.drawText(dc, 240, 336, STYLE_NUMBER, 30, _court, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            l.drawSpacedText(dc, 240, 356, STYLE_BOLD, size(dc, STYLE_BOLD, 12, _courtLeft, 2, 300), 2, _courtLeft,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // The mockup's weight 500 is Bold (no Medium face). Fitted to the circle at its
        // baseline, less a margin.
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 240, formatY, STYLE_BOLD, size(dc, STYLE_BOLD, 16, _formatLine, 0, Layout.chord(formatY) - 36),
            _formatLine, Graphics.TEXT_JUSTIFY_CENTER);

        drawHint(dc, l, recording || !flow.warmUp ? _beginMatch : _warmUp);
        toast.draw(dc, l, TOAST_Y);
    }

    // "START · BEGIN MATCH", START in yellow, at the bottom.
    private function drawHint(dc as Dc, l as Layout, action as String) as Void {
        var rest = SEPARATOR + action;
        var hintSize = size(dc, STYLE_BOLD, 13, _start + rest, 1.5, 190);
        var left = 240 - l.textWidth(dc, STYLE_BOLD, hintSize, _start + rest, 1.5) / 2;
        dc.setColor(Palette.BALL, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, left, 422, STYLE_BOLD, hintSize, 1.5, _start, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
        l.drawSpacedText(dc, left + l.textWidth(dc, STYLE_BOLD, hintSize, _start, 1.5) + 1.5, 422, STYLE_BOLD,
            hintSize, 1.5, rest, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The mockup size for text, or smaller so it fits maxWidth (Layout.fitSize()), kept per text.
    // The time is kept by its length: digits all have the same width.
    private function size(dc as Dc, style as FontStyle, mockupSize as Number, text as String, spacing as Numeric,
            maxWidth as Numeric) as Number {
        var key = style == STYLE_NUMBER ? "time " + text.length() : text;
        var fitted = _sizes[key];
        if (fitted == null) {
            fitted = _layout.fitSize(dc, style, mockupSize, text, spacing, maxWidth);
            _sizes[key] = fitted;
        }
        return fitted;
    }

    // A position good enough to record: usable or good.
    private function isGpsReady() as Boolean {
        var accuracy = Position.getInfo().accuracy;
        return accuracy == Position.QUALITY_USABLE || accuracy == Position.QUALITY_GOOD;
    }
}

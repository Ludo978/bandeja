import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Work too long for one callback (the watchdog), cut into steps that LoadView runs one per
// wake-up: the launch replay of a long stored match (ResumeLoad), a long debug fixture.
class LoadJob {

    function initialize() {
    }

    // Does the next step; true once the work is done.
    function step() as Boolean {
        return true;
    }

    // How much is done, 0 to 1.
    function getProgress() as Float {
        return 1.0;
    }

    // Once done, from LoadView: the screen that follows takes its place.
    function done() as Void {
    }

    // BACK while it runs.
    function back() as Void {
    }
}

// The screen while a LoadJob runs: black, with a thin ring around the edge that fills as it goes,
// clockwise from the top. A step every WAIT ms on its one Timer; no text, so nothing to translate.
class LoadView extends WatchUi.View {

    private const WAIT = 50;

    private var _job as LoadJob;
    private var _timer as Timer.Timer = new Timer.Timer();

    function initialize(job as LoadJob) {
        View.initialize();
        _job = job;
    }

    function onShow() as Void {
        _timer.start(method(:onWake), WAIT, true);
    }

    function onHide() as Void {
        _timer.stop();
    }

    function onWake() as Void {
        if (_job.step()) {
            _timer.stop();
            _job.done();
        } else {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var l = new Layout(dc.getWidth());
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
        l.drawArc(dc, 202, 4, 0, 360);
        var turned = 360 * _job.getProgress();
        if (turned >= 1) {
            dc.setColor(Palette.MUTED, Graphics.COLOR_TRANSPARENT);
            l.drawArc(dc, 202, 4, 90 - turned, 90);
        }
    }
}

// Only BACK does something: what the job says. The other inputs have nothing to act on.
class LoadDelegate extends WatchUi.BehaviorDelegate {

    private var _job as LoadJob;

    function initialize(job as LoadJob) {
        BehaviorDelegate.initialize();
        _job = job;
    }

    function onBack() as Boolean {
        _job.back();
        return true;
    }
}

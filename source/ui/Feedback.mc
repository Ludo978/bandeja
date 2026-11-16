import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// Plays the vibration and tone feedback with Attention: FeedbackPlan works out what, for the event and
// the settings read now. What starts at the event plays at once, each later call or tones on a
// one-shot Timer when its time comes, timed from the event. A new event's feedback replaces what is
// left of the last one: its later calls and tones are dropped, so a buzz always answers the press
// just made and nothing piles up behind a long set pattern. The app holds the one instance
// (getFeedback()), so a pattern goes on when the screen changes (the summary after the match point).
// A point that wrote a game's lap plays nothing of its own (FeedbackPlan.point()), but still drops
// what is left of the last pattern; a change of ends it brings starts once the watch's lap alert is
// over.
//
// The firmware also mutes vibrate() and playTone() when the watch's settings are off (tested on the FR265); the
// plan leaves them out itself, so the app stays silent on that channel whatever its own settings.
class Feedback {

    // The shortest Timer wait (Timer docs: 50 ms on most devices).
    private const MIN_WAIT = 50;

    private var _timer as Timer.Timer? = null;
    // The plan playing, while a call or tones are still to come.
    private var _plan as FeedbackPlan? = null;
    // Its next call and tones, the time they're due at (ms after the event), and System.getTimer() at
    // the event.
    private var _call as Number = 0;
    private var _tone as Number = 0;
    private var _due as Number = 0;
    private var _startedAt as Number = 0;

    function initialize() {
    }

    // After a point that counted (ScoreInput.team, ScoreInput.won, ScoreInput.lap, ScoreInput.ends).
    function point(team as Team, won as PointWon, lap as Boolean, ends as Boolean) as Void {
        play(FeedbackPlan.point(team, won, lap, ends, channels()));
    }

    // After an undo.
    function undo() as Void {
        play(FeedbackPlan.undo(channels()));
    }

    // A timed match's warning at T-10 or T-5, or its TIME alert.
    function court() as Void {
        play(FeedbackPlan.court(channels()));
    }

    // The settings and the watch's own, as they are now.
    static function channels() as FeedbackChannels {
        var device = System.getDeviceSettings();
        return new FeedbackChannels(Settings.getVibration(), Settings.isSoundsOn(), device.vibrateOn, device.tonesOn,
            Settings.isChangeOfEndsAlert());
    }

    // Plays a plan now, in place of what is left of the last one.
    function play(plan as FeedbackPlan) as Void {
        stop();
        _plan = plan;
        _call = 0;
        _tone = 0;
        _due = 0;
        _startedAt = System.getTimer();
        playDue();
    }

    // Drops the calls and tones still to come (the ones playing end by themselves).
    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
        }
        _plan = null;
    }

    // Plays the tones and the call due now, then waits for what comes next, timed from the event.
    function playDue() as Void {
        var plan = _plan;
        if (plan == null) {
            return;
        }
        while (_tone < plan.tones.size() && plan.toneStarts[_tone] <= _due) {
            beep(plan.tones[_tone]);
            _tone++;
        }
        while (_call < plan.calls.size() && plan.starts[_call] <= _due) {
            buzz(plan.calls[_call]);
            _call++;
        }
        var next = plan.nextStart(_call, _tone);
        if (next == null) {
            _plan = null;
            return;
        }
        _due = next;
        var wait = next - (System.getTimer() - _startedAt);
        var timer = _timer;
        if (timer == null) {
            timer = new Timer.Timer();
            _timer = timer;
        }
        timer.start(method(:playDue), wait > MIN_WAIT ? wait : MIN_WAIT, false);
    }

    // One call's profiles: pulses at full duty, silences at zero. Null for an empty call or one over
    // FeedbackPlan.MAX_PROFILES, which vibrate() would crash on: the plan never makes one, and this
    // makes sure.
    static function vibeProfiles(pattern as Array<Number>) as Array<Attention.VibeProfile>? {
        if (pattern.size() == 0 || pattern.size() > FeedbackPlan.MAX_PROFILES) {
            return null;
        }
        var profiles = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < pattern.size(); i++) {
            profiles.add(new Attention.VibeProfile(i % 2 == 0 ? 100 : 0, pattern[i]));
        }
        return profiles;
    }

    // Custom tones: the FR265 plays no sound for the predefined TONE_* values (tested on the FR265).
    static function toneProfiles(tones as Array<Number>) as Array<Attention.ToneProfile> {
        var profiles = [] as Array<Attention.ToneProfile>;
        for (var i = 0; i + 1 < tones.size(); i += 2) {
            profiles.add(new Attention.ToneProfile(tones[i], tones[i + 1]));
        }
        return profiles;
    }

    private function buzz(pattern as Array<Number>) as Void {
        var profiles = vibeProfiles(pattern);
        if (profiles != null && Attention has :vibrate) {
            Attention.vibrate(profiles);
        }
    }

    private function beep(tones as Array<Number>) as Void {
        if (tones.size() < 2 || !(Attention has :playTone) || !(Attention has :ToneProfile)) {
            return;
        }
        // Feedback never stops the match: a tone the watch refuses is dropped.
        try {
            Attention.playTone({:toneProfile => toneProfiles(tones)});
        } catch (e) {
        }
    }
}

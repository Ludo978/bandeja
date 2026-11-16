import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// A timed match's court booking end, asked at PLAY before the sensor lock (MatchFlow):
// a native list titled "Court ends at", of the clock times every 5 minutes up to 4 hours ahead, as
// the watch shows the time (12 h or 24 h), opening on the pre-fill, now + 90 minutes to the nearest
// half hour (CourtBooking). START picks one and the sensor lock takes the list's place, its countdown
// running; BACK returns home with nothing picked. Every time offered is a valid end, so the list
// needs no error message.
module CourtMenu {

    function open() as Void {
        var local = localSeconds();
        var choices = CourtBooking.choices(local);
        var texts = labels(choices, System.getDeviceSettings().is24Hour) as Array<String or ResourceId>;
        ChoiceMenu.push(Rez.Strings.CourtEndsAt, texts, choices, CourtBooking.prefill(local),
            new CourtChoice().method(:onChoice));
    }

    // The clock times (minutes since midnight) as the watch shows the time.
    function labels(choices as Array<Number>, is24Hour as Boolean) as Array<String> {
        var labels = [] as Array<String>;
        for (var i = 0; i < choices.size(); i++) {
            labels.add(TimeText.clock(choices[i] / 60, choices[i] % 60, is24Hour));
        }
        return labels;
    }

    // The watch's clock time, in seconds since midnight.
    function localSeconds() as Number {
        var time = System.getClockTime();
        return time.hour * 3600 + time.min * 60 + time.sec;
    }
}

// The clock time picked (CourtMenu): its next occurrence, worked out now, is the booking's end, and
// the sensor lock opens with it (the list has popped itself).
class CourtChoice {

    function initialize() {
    }

    function onChoice(value as Number) as Void {
        var end = CourtBooking.endFor(value, Time.now().value(), CourtMenu.localSeconds());
        MatchFlow.openLock(new CourtBooking(end, COURT_NONE));
    }
}

import Toybox.Lang;

// Durations as the screens write them: the warm-up's "4:32", the score screen's and
// the data page's "0:42:17", the stats page's average time per point "0:42"; a
// timed match's court time left, "85:28"; and the data page's time of day.
module TimeText {

    // seconds as m:ss under an hour and h:mm:ss from an hour on, or always h:mm:ss withHours.
    // A negative duration (a clock that went back) reads as 0.
    function duration(seconds as Number, withHours as Boolean) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        var hours = seconds / 3600;
        var minutes = seconds / 60 % 60;
        var rest = ":" + (seconds % 60).format("%02d");
        if (withHours || hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + rest;
        }
        return minutes.format("%d") + rest;
    }

    // The court time left (mockups "Warm-up" and "Data page"): minutes and seconds, the minutes
    // going past 60 rather than into hours ("85:28", up to "240:00", 4 hours ahead at most), "0:00"
    // once the time is up.
    function countdown(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }

    // The time of day (hour 0 to 23) as the watch's clock setting has it (DeviceSettings.is24Hour):
    // "09:42" and "00:05" in 24 h, two-digit hours so it never reads like a duration; "9:42" and
    // "12:05" in 12 h, without AM / PM.
    function clock(hour as Number, minute as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var twelve = hour % 12;
        return (twelve == 0 ? 12 : twelve).format("%d") + ":" + minute.format("%02d");
    }
}

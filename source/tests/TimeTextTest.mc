import Toybox.Lang;
import Toybox.Test;

// Times as the screens write them (mockups "Warm-up", "Score, in play" and
// "Data page"): "4:32" on the warm-up screen, "0:42:17" on the score screen and the data page, the data
// page's time of day in 12 h and 24 h, and the court time countdown; and the app's own toast.

(:test)
function timeTextDurationTest(logger as Logger) as Boolean {
    // Minutes and seconds under an hour, hours from an hour on, or always with hours. A clock that went
    // backwards never shows a negative time.
    var short = [[0, "0:00"], [9, "0:09"], [60, "1:00"], [272, "4:32"], [3599, "59:59"], [3600, "1:00:00"], [36000, "10:00:00"],
        [-5, "0:00"]];
    for (var i = 0; i < short.size(); i++) {
        Test.assertEqual(TimeText.duration(short[i][0] as Number, false), short[i][1]);
    }
    Test.assert(TimeText.duration(0, true).equals("0:00:00") && TimeText.duration(2537, true).equals("0:42:17"));
    Test.assert(TimeText.duration(3723, true).equals("1:02:03") && TimeText.duration(-5, true).equals("0:00:00"));
    // The court time left: minutes and seconds, as the mockups' 85:28, the minutes going past 60 rather
    // than into hours (4 hours ahead at most: 240:00), never below 0.
    var countdown = [[85 * 60 + 28, "85:28"], [CourtBooking.WINDOW, "240:00"], [300, "5:00"], [59, "0:59"], [0, "0:00"], [-30, "0:00"]];
    for (var i = 0; i < countdown.size(); i++) {
        Test.assertEqual(TimeText.countdown(countdown[i][0] as Number), countdown[i][1]);
    }
    return true;
}

(:test)
function timeTextClockTest(logger as Logger) as Boolean {
    // The data page's time of day. In 24 h, two-digit hours, so it never reads like the durations next
    // to it ("00:05", not "0:05"). In 12 h, 12 for the hour after midnight and after noon, no leading
    // zero, no AM / PM.
    var cases = [[0, 5, "00:05", "12:05"], [9, 42, "09:42", "9:42"], [12, 0, "12:00", "12:00"], [13, 5, "13:05", "1:05"],
        [23, 59, "23:59", "11:59"]];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        Test.assertEqual(TimeText.clock(c[0] as Number, c[1] as Number, true), c[2]);
        Test.assertEqual(TimeText.clock(c[0] as Number, c[1] as Number, false), c[3]);
    }
    return true;
}

(:test)
function toastTest(logger as Logger) as Boolean {
    // Shown for Toast.DURATION, restarted with the new text by a new show, gone at hide (a menu on top)
    // and not back when the screen shows again. System.getTimer() wraps around after about 24.8 days;
    // before it was shown (a clock read earlier): not shown.
    var toast = new Toast();
    Test.assert(toast.getTextAt(0) == null);
    toast.showAt("Press START", 1000);
    Test.assert("Press START".equals(toast.getTextAt(1000)) && "Press START".equals(toast.getTextAt(1000 + Toast.DURATION - 1)));
    Test.assert(toast.getTextAt(1000 + Toast.DURATION) == null);
    toast.showAt("Press START", 1000);
    toast.showAt("Undone: point US", 2500);
    Test.assert("Undone: point US".equals(toast.getTextAt(1000 + Toast.DURATION)) && toast.getTextAt(2500 + Toast.DURATION) == null);
    toast.hide();
    Test.assert(toast.getTextAt(2600) == null);
    var shown = 0x7FFFFFFF - 500;
    toast.showAt("Press START", shown);
    Test.assert("Press START".equals(toast.getTextAt(shown + 1000)) && toast.getTextAt(shown + Toast.DURATION) == null);
    Test.assert(toast.getTextAt(shown - 1) == null);
    return true;
}

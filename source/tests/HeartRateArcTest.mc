import Toybox.Lang;
import Toybox.Test;

// The heart rate and its zone: the zone of a heart rate from the user's zones
// as UserProfile.getHeartRateZones() gives them (the lowest heart rate of zone 1, then the highest of
// each zone), the text, the zone segments of the score screen and the data page as the mockups draw
// them, and the data page's marker.

(:test)
function heartRateZoneTest(logger as Logger) as Boolean {
    // Each zone holds its highest heart rate; below zone 1 no zone, nothing lit; above the maximum
    // still zone 5. No heart rate yet, or no usable zones: nothing lit, "--".
    var zones = [98, 117, 137, 156, 176, 195];
    var cases = [[97, 0], [98, 1], [117, 1], [118, 2], [156, 3], [157, 4], [195, 5], [210, 5]];
    for (var i = 0; i < cases.size(); i++) {
        Test.assertEqual(HeartRateArc.zoneOf(cases[i][0], zones), cases[i][1]);
    }
    Test.assert(HeartRateArc.zoneOf(null, zones) == 0 && HeartRateArc.zoneOf(150, null) == 0 && HeartRateArc.zoneOf(150, [98, 117, 137]) == 0);
    Test.assert(HeartRateArc.text(null).equals("--") && HeartRateArc.text(118).equals("118"));
    return true;
}

(:test)
function heartRateUpdateTest(logger as Logger) as Boolean {
    // A new reading asks for a redraw only when the number or the zone shown changes; without zones the
    // number still shows.
    var arc = new HeartRateArc([98, 117, 137, 156, 176, 195]);
    Test.assert(arc.heartRate == null && arc.zone == 0 && !arc.setHeartRate(null));
    Test.assert(arc.setHeartRate(118) && arc.zone == 2 && !arc.setHeartRate(118) && arc.setHeartRate(119) && arc.zone == 2);
    Test.assert(arc.setHeartRate(null) && arc.zone == 0);
    arc = new HeartRateArc(null);
    Test.assert(arc.setHeartRate(150) && arc.heartRate == 150 && arc.zone == 0);
    return true;
}

(:test)
function heartRateSegmentsTest(logger as Logger) as Boolean {
    // Score screen and warm-up (mockup paths): 13.2° segments 2.5° apart, from 128° down to 52°. Data
    // page ring: 45.6° segments 3° apart, from 210° down to -30°.
    HeartRateTests.assertSegment(HeartRateArc.segment(1, 128, 52, 2.5), 114.8, 128.0, "score zone 1");
    HeartRateTests.assertSegment(HeartRateArc.segment(2, 128, 52, 2.5), 99.1, 112.3, "score zone 2");
    HeartRateTests.assertSegment(HeartRateArc.segment(5, 128, 52, 2.5), 52.0, 65.2, "score zone 5");
    HeartRateTests.assertSegment(HeartRateArc.segment(1, 210, -30, 3), 164.4, 210.0, "data zone 1");
    HeartRateTests.assertSegment(HeartRateArc.segment(5, 210, -30, 3), -30.0, 15.6, "data zone 5");
    return true;
}

(:test)
function heartRateMarkerTest(logger as Logger) as Boolean {
    // The data page's marker: in the current zone's segment of the ring (210° to -30°, 3° gaps), as far
    // along it as the heart rate is in the zone. The mockup's 152 bpm in zone 4 (144 to 159 here) sits
    // 8/15 of the way along zone 4's segment, 64.2° to 18.6°: at 39.9° (the mockup's marker circle).
    // Zone 1 runs from its lowest heart rate to its highest, each next zone from just above the zone
    // before it; past the ends, at the ring's start or end. No heart rate yet, or no usable zones: no
    // marker.
    var zones = [100, 120, 132, 144, 159, 175];
    var cases = [[152, 39.9], [100, 210.0], [110, 187.2], [120, 164.4], [121, 157.6], [132, 115.8], [175, -30.0], [99, 210.0],
        [200, -30.0]];
    for (var i = 0; i < cases.size(); i++) {
        var marker = HeartRateArc.markerAngle(cases[i][0] as Number, zones, DataPage.RING_FROM, DataPage.RING_TO, DataPage.RING_GAP);
        Test.assertMessage(marker != null && ((marker as Float) - (cases[i][1] as Float)).abs() < 0.05, cases[i][0] + ": " + marker);
    }
    Test.assert(HeartRateArc.markerAngle(null, zones, 210, -30, 3) == null && HeartRateArc.markerAngle(150, null, 210, -30, 3) == null);
    var arc = new HeartRateArc(zones);
    Test.assert(arc.getMarkerAngle(210, -30, 3) == null);
    arc.setHeartRate(152);
    Test.assert(((arc.getMarkerAngle(210, -30, 3) as Float) - 39.9).abs() < 0.05);
    return true;
}

(:test)
module HeartRateTests {

    // The segment's start and end, in degrees, to a tenth.
    function assertSegment(segment as [Float, Float], start as Float, end as Float, message as String) as Void {
        Test.assertMessage((segment[0] - start).abs() < 0.05 && (segment[1] - end).abs() < 0.05, message + ": " + segment[0] + " to " + segment[1]);
    }
}

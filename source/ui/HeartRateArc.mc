import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.UserProfile;

// The heart rate and its zone, as the score screen, the warm-up screen and the
// data page show them. An instance keeps the heart rate shown and its zone: the view calls
// update() at 1 Hz and redraws when it returns true, then draw() draws the score screen's arc (five
// zone segments across the top, the current zone lit in its color, the others INACTIVE) with the
// heart and the number. The data page draws its own ring with drawZones() and the same zone, and
// the heart rate's place on it (getMarkerAngle()).
class HeartRateArc {

    // The heart rate shown, null until the sensor has one, and its zone: 1 to 5, 0 below zone 1 or
    // without zones (nothing lit).
    var heartRate as Number? = null;
    var zone as Number = 0;
    // As UserProfile.getHeartRateZones() gives them, or null.
    private var _zones as Array<Number>?;

    // zones: readZones(), read once per screen (they don't change during a match).
    function initialize(zones as Array<Number>?) {
        _zones = zones;
    }

    // Reads the heart rate; true when the number or the zone shown changed.
    function update() as Boolean {
        return setHeartRate(read());
    }

    // The same with a given heart rate.
    function setHeartRate(value as Number?) as Boolean {
        var newZone = zoneOf(value, _zones);
        if (value == heartRate && newZone == zone) {
            return false;
        }
        heartRate = value;
        zone = newZone;
        return true;
    }

    // The marker's angle for the heart rate shown on a ring of drawZones(), or null (markerAngle()).
    function getMarkerAngle(from as Numeric, to as Numeric, gap as Numeric) as Float? {
        return markerAngle(heartRate, _zones, from, to, gap);
    }

    function draw(dc as Graphics.Dc, l as Layout) as Void {
        drawArc(dc, l, zone, text(heartRate));
    }

    // The score screen's arc with zone lit, the heart and the value, at the mockups' positions.
    static function drawArc(dc as Graphics.Dc, l as Layout, zone as Number, value as String) as Void {
        drawZones(dc, l, zone, 196, 8, 128, 52, 2.5, false);
        drawHeart(dc, l, 220, 91, 1.0);
        dc.setColor(Palette.TEXT, Graphics.COLOR_TRANSPARENT);
        l.drawText(dc, 234, 92, STYLE_NUMBER, 24, value, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Five zone segments on a circle around the screen center (mockup radius and stroke), zone 1 at
    // from and zone 5 at to (Connect IQ degrees, from > to: left to right), gap degrees apart. The
    // current zone is in its color; the others are INACTIVE, or their own color at 30 % when dimmed
    // (the data page's ring).
    static function drawZones(dc as Graphics.Dc, l as Layout, zone as Number, radius as Numeric, stroke as Numeric,
            from as Numeric, to as Numeric, gap as Numeric, dimmed as Boolean) as Void {
        for (var i = 1; i <= 5; i++) {
            var color = Palette.hrZoneColor(i);
            if (i != zone) {
                color = dimmed ? Palette.onBlack(color, 30) : Palette.INACTIVE;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var arc = segment(i, from, to, gap);
            l.drawArc(dc, radius, stroke, arc[0], arc[1]);
        }
    }

    // The start and end, in degrees, of zone's segment (1 to 5) in drawZones().
    static function segment(zone as Number, from as Numeric, to as Numeric, gap as Numeric) as [Float, Float] {
        var span = (from - to - 4 * gap) / 5.0;
        var end = from - (zone - 1) * (span + gap);
        return [(end - span).toFloat(), end.toFloat()];
    }

    // Where a heart rate sits on a ring of drawZones() segments (from, to and gap as there), in
    // degrees: in its zone's segment, as far along it as the heart rate is in the zone, zone 1 from
    // its lowest heart rate and each next zone from the highest of the zone before it. Below zone 1
    // at the ring's start, above zone 5's highest at its end. Null without a heart rate or usable
    // zones.
    static function markerAngle(value as Number?, zones as Array<Number>?, from as Numeric, to as Numeric,
            gap as Numeric) as Float? {
        if (value == null || zones == null || zones.size() < 6) {
            return null;
        }
        var zone = zoneOf(value, zones);
        if (zone == 0) {
            return from.toFloat();
        }
        var low = zones[zone - 1];
        var high = zones[zone];
        var part = high > low ? (value - low).toFloat() / (high - low) : 1.0;
        if (part > 1.0) {
            part = 1.0;
        }
        var arc = segment(zone, from, to, gap);
        return arc[1] - part * (arc[1] - arc[0]);
    }

    // The red heart of the mockups, its point at (tipX, tipY), scale times the score screen's.
    static function drawHeart(dc as Graphics.Dc, l as Layout, tipX as Numeric, tipY as Numeric,
            scale as Numeric) as Void {
        dc.setColor(Palette.HR_ZONE_5, Graphics.COLOR_TRANSPARENT);
        l.fillCircle(dc, tipX - 3.8 * scale, tipY - 10.9 * scale, 4.9 * scale);
        l.fillCircle(dc, tipX + 3.8 * scale, tipY - 10.9 * scale, 4.9 * scale);
        dc.fillPolygon([[l.x(tipX - 8.6 * scale), l.y(tipY - 9.5 * scale)],
            [l.x(tipX + 8.6 * scale), l.y(tipY - 9.5 * scale)], [l.x(tipX), l.y(tipY)]]);
    }

    // The zone of a heart rate: zones holds the lowest heart rate of zone 1, then the highest of
    // zones 1 to 5. 0 below zone 1, with no heart rate, or without usable zones; 5 above zone 5.
    static function zoneOf(value as Number?, zones as Array<Number>?) as Number {
        if (value == null || zones == null || zones.size() < 6 || value < zones[0]) {
            return 0;
        }
        for (var i = 1; i < 5; i++) {
            if (value <= zones[i]) {
                return i;
            }
        }
        return 5;
    }

    // "118", or "--" without a heart rate.
    static function text(value as Number?) as String {
        return value == null ? "--" : value.toString();
    }

    // The current heart rate: the activity's while recording (a paired strap included), else the
    // sensor's (the sensor lock, before recording). Null until there's one.
    static function read() as Number? {
        var info = Activity.getActivityInfo();
        var value = info != null ? info.currentHeartRate : null;
        if (value == null) {
            value = Sensor.getInfo().heartRate;
        }
        return value;
    }

    // The user's heart rate zones (Garmin's default zones, the ones not tied to running, cycling
    // or swimming), or null if the watch has none.
    static function readZones() as Array<Number>? {
        try {
            return UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        } catch (e) {
            return null;
        }
    }
}

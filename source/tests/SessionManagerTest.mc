import Toybox.Lang;
import Toybox.Test;

// The session manager, driven with a fake recorder: one Padel session per app
// run, heart rate always and GPS only outdoors (criterion 7), the warm-up as lap 1 closed when the
// match starts, pause and resume, save and discard, and the error state when the watch refuses the
// session (never a generic activity). Calls to the recorder are written as TestKit.FakeRecorder notes
// them.

(:test)
function sessionStartIndoorTest(logger as Logger) as Boolean {
    // Nothing before START; then one session, a second START never creates another.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    Test.assert(manager.getPhase() == SESSION_IDLE && !manager.isRecording());
    Test.assert(!manager.startMatch() && !manager.addLap(new LapValues(1, [1, 0], LAP_WE_HELD)) && !manager.pause());
    Test.assert(!manager.resume() && !manager.save() && !manager.discard());
    TestKit.assertCalls(recorder, [], "before start");
    Test.assert(manager.start(false, true));
    Test.assert(!manager.start(false, true) && !manager.start(true, false));
    TestKit.assertCalls(recorder, ["create", "sensors", "start"], "start");
    Test.assert(manager.getPhase() == SESSION_WARM_UP && manager.isRecording() && !manager.isPaused());
    Test.assert(manager.getError() == null && !recorder.gpsEverOn);
    return true;
}

(:test)
function sessionStartOutdoorTest(logger as Logger) as Boolean {
    // GPS on for the whole recording, off once it's saved.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    Test.assert(manager.start(true, true) && recorder.gps);
    manager.startMatch();
    Test.assert(manager.save());
    TestKit.assertCalls(recorder, ["create", "sensors+gps", "start", "lap", "stop", "save", "sensors off"], "save");
    Test.assert(!recorder.gps);
    return true;
}

(:test)
function sessionIndoorNeverGpsTest(logger as Logger) as Boolean {
    // Criterion 7: an indoor match never turns GPS on, from the sensor lock to the save.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.enableSensors(false);
    manager.start(false, true);
    manager.startMatch();
    manager.addLap(new LapValues(1, [1, 0], LAP_WE_HELD));
    manager.pause();
    manager.resume();
    manager.save();
    Test.assert(!recorder.gpsEverOn && manager.getPhase() == SESSION_ENDED);
    return true;
}

(:test)
function sessionSensorLockTest(logger as Logger) as Boolean {
    // The sensors can be turned on before START (sensor lock), once; start() keeps them, or
    // turns GPS off when the match is indoors after all. BACK from the lock turns them off (nothing was
    // recorded), PLAY again on. While recording they stay as they are.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.disableSensors();
    manager.enableSensors(true);
    manager.enableSensors(true);
    manager.disableSensors();
    manager.disableSensors();
    manager.enableSensors(true);
    manager.start(true, true);
    TestKit.assertCalls(recorder, ["sensors+gps", "sensors off", "sensors+gps", "create", "start"], "lock outdoors");
    recorder.clear();
    manager.enableSensors(false);
    manager.disableSensors();
    TestKit.assertCalls(recorder, [], "while recording");
    Test.assert(manager.isRecording() && recorder.gps);
    recorder = new TestKit.FakeRecorder();
    manager = new SessionManager(recorder);
    manager.enableSensors(true);
    manager.start(false, true);
    TestKit.assertCalls(recorder, ["sensors+gps", "create", "sensors", "start"], "start indoors");
    Test.assert(!recorder.gps);
    return true;
}

(:test)
function sessionWarmUpLapTest(logger as Logger) as Boolean {
    // Lap 1 is the warm-up, closed when the match starts, once. With the Warm-up phase
    // setting off the match starts with the recording: no warm-up lap.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.start(false, true);
    recorder.clear();
    Test.assert(manager.startMatch() && !manager.startMatch());
    TestKit.assertCalls(recorder, ["lap"], "match start");
    Test.assert(manager.getPhase() == SESSION_MATCH && manager.isRecording());
    recorder = new TestKit.FakeRecorder();
    manager = new SessionManager(recorder);
    Test.assert(manager.start(false, false) && manager.getPhase() == SESSION_MATCH && !manager.startMatch());
    Test.assert(manager.save());
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "stop", "save", "sensors off"], "no warm-up");
    return true;
}

(:test)
function sessionAddLapTest(logger as Logger) as Boolean {
    // Game laps only once the match has started, paused or not, and never after the end. Each
    // gets its lap values right before it closes. The values of the lap in progress reach the recorder
    // where the timer stops, so the last lap, which the save closes, has them; the warm-up lap none.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    var first = new LapValues(1, [1, 0], LAP_WE_HELD);
    manager.start(false, true);
    Test.assert(!manager.addLap(first));
    manager.pause();
    manager.resume();
    manager.startMatch();
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "stop", "start", "lap"], "warm-up");
    recorder.clear();
    Test.assert(manager.addLap(first));
    manager.pause();
    Test.assert(manager.addLap(new LapValues(1, [1, 1], LAP_THEY_HELD)));
    manager.resume();
    manager.setLapValues(new LapValues(1, [2, 1], LAP_WE_BROKE));
    TestKit.assertCalls(recorder, ["values 1 1-0 0", "lap", "stop", "values 1 1-1 2", "lap", "start"], "laps");
    manager.setLapValues(new LapValues(1, [2, 2], LAP_NO_SERVE));
    Test.assert(manager.save());
    TestKit.assertCalls(recorder, ["values 1 1-0 0", "lap", "stop", "values 1 1-1 2", "lap", "start", "values 1 2-2 5", "stop",
        "save", "sensors off"], "save");
    Test.assertEqual(recorder.laps.toString(), ["none", "1 1-0 0", "1 1-1 2", "1 2-2 5"].toString());
    Test.assert(!manager.addLap(first));
    return true;
}

(:test)
function sessionPauseResumeTest(logger as Logger) as Boolean {
    // A timer the watch doesn't restart stays paused.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.start(false, true);
    manager.startMatch();
    recorder.clear();
    Test.assert(manager.pause() && manager.isPaused() && manager.isRecording() && !manager.pause());
    Test.assert(manager.resume() && !manager.isPaused() && !manager.resume());
    TestKit.assertCalls(recorder, ["stop", "start"], "pause, resume");
    manager.pause();
    recorder.startResult = false;
    Test.assert(!manager.resume() && manager.isPaused());
    return true;
}

(:test)
function sessionSaveTest(logger as Logger) as Boolean {
    // Saved, nothing more. A save the watch refuses keeps the session, paused: Save again (the timer
    // stopped once) or Discard.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.start(false, true);
    manager.startMatch();
    recorder.clear();
    Test.assert(manager.save());
    Test.assert(manager.getPhase() == SESSION_ENDED && !manager.isRecording() && !manager.isPaused());
    Test.assert(!manager.save() && !manager.discard() && !manager.pause() && !manager.start(false, true));
    TestKit.assertCalls(recorder, ["stop", "save", "sensors off"], "save, then nothing");
    recorder = new TestKit.FakeRecorder();
    manager = new SessionManager(recorder);
    manager.start(true, false);
    recorder.saveResult = false;
    recorder.clear();
    Test.assert(!manager.save());
    Test.assert(manager.getPhase() == SESSION_MATCH && manager.isRecording() && manager.isPaused() && recorder.gps);
    recorder.saveResult = true;
    Test.assert(manager.save() && manager.getPhase() == SESSION_ENDED);
    TestKit.assertCalls(recorder, ["stop", "save", "save", "sensors off"], "refused, then saved");
    return true;
}

(:test)
function sessionDiscardTest(logger as Logger) as Boolean {
    // Discard from the warm-up (its menu) or the match: nothing is saved.
    var recorder = new TestKit.FakeRecorder();
    var manager = new SessionManager(recorder);
    manager.start(true, true);
    recorder.clear();
    Test.assert(manager.discard() && !manager.discard());
    TestKit.assertCalls(recorder, ["stop", "discard", "sensors off"], "discard");
    Test.assert(manager.getPhase() == SESSION_ENDED && !manager.isRecording() && !recorder.gps);
    return true;
}

(:test)
function sessionCreateFailsTest(logger as Logger) as Boolean {
    // The watch refuses the Padel session: the error state, nothing records, the sensors turned on for
    // the lock go off, and no other session is tried (G3). A session whose timer doesn't start is
    // dropped and shown as an error too.
    var recorder = new TestKit.FakeRecorder();
    recorder.createFails = true;
    var manager = new SessionManager(recorder);
    manager.enableSensors(true);
    Test.assert(!manager.start(true, true));
    TestKit.assertCalls(recorder, ["sensors+gps", "create", "sensors off"], "refused");
    Test.assert(manager.getPhase() == SESSION_FAILED && "no Padel".equals(manager.getError()) && !manager.isRecording());
    recorder.clear();
    recorder.createFails = false;
    Test.assert(!manager.start(true, true) && !manager.startMatch() && !manager.pause() && !manager.save() && !manager.discard());
    manager.enableSensors(true);
    TestKit.assertCalls(recorder, [], "after the failure");
    recorder = new TestKit.FakeRecorder();
    recorder.startResult = false;
    manager = new SessionManager(recorder);
    Test.assert(!manager.start(false, true));
    TestKit.assertCalls(recorder, ["create", "sensors", "start", "discard", "sensors off"], "refused start");
    Test.assert(manager.getPhase() == SESSION_FAILED && manager.getError() == null && !manager.isRecording());
    return true;
}

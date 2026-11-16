import Toybox.Application;
import Toybox.Lang;

// The history: the last MAX_RECORDS saved matches, newest first, in Application.Storage as
// one value under one key, an array of HistoryRecord.toValue()'s form. A match goes in when it's saved
// and its stored match cleared (MatchFlow.saved(): Save on the summary or in the pause menu, the low
// battery save; and the app stopped on a finished match, MatchRecovery.stop()), never at a Discard nor
// at a stop that keeps the match for a resume. A match saved before its first point isn't kept. A record
// that can't be read is skipped, never a crash, and dropped at the next save. 20 records take at most
// about 8 KB of the 32 KB a value holds (a value over it ends the app). With the
// record goes the glance's value (LastMatch): the newest match in a few bytes, so the glance
// never reads the history.
module HistoryStore {

    // Storage key: never rename.
    const KEY = "history";
    const MAX_RECORDS = 20;

    // The match just saved goes first; the oldest past MAX_RECORDS goes, and so does a record that
    // can't be read. Nothing for a match with no point played. The stored records are checked one at a
    // time and kept in their stored form, so only one is read into objects at once. The glance's value
    // follows the history: it's the match just saved once the history holds it.
    function add(record as HistoryRecord) as Void {
        if (!record.hasPoint()) {
            return;
        }
        var list = [record.toValue()] as Array<Application.Storage.ValueType>;
        var stored = read();
        if (stored instanceof Array) {
            for (var i = 0; i < stored.size() && list.size() < MAX_RECORDS; i++) {
                var value = stored[i] as Application.Storage.ValueType;
                if (HistoryRecord.fromValue(value) != null) {
                    list.add(value);
                }
            }
        }
        if (write(list)) {
            writeLast(record);
        }
    }

    // The glance's value for record, the history's newest (LastMatch).
    function writeLast(record as HistoryRecord) as Void {
        try {
            Application.Storage.setValue(LastMatch.KEY, HistoryText.glanceValue(record));
        } catch (e) {
        }
    }

    // At the app's start: a history saved by a version before the glance has no glance value, which its
    // newest record that can be read gives, once. Only the glance value is read when it's there.
    function restoreLast() as Void {
        if (LastMatch.read() != null) {
            return;
        }
        var stored = read();
        if (stored instanceof Array) {
            for (var i = 0; i < stored.size(); i++) {
                var record = HistoryRecord.fromValue(stored[i] as Object?);
                if (record != null) {
                    writeLast(record);
                    return;
                }
            }
        }
    }

    // The records that can be read, newest first.
    function load() as Array<HistoryRecord> {
        var records = [] as Array<HistoryRecord>;
        var stored = read();
        if (stored instanceof Array) {
            for (var i = 0; i < stored.size(); i++) {
                var record = HistoryRecord.fromValue(stored[i] as Object?);
                if (record != null) {
                    records.add(record);
                }
            }
        }
        return records;
    }

    function read() as Object? {
        try {
            return Application.Storage.getValue(KEY);
        } catch (e) {
            return null;
        }
    }

    // A write the store refuses is dropped, never a crash: the history keeps its last value. True when
    // written.
    function write(list as Array<Application.Storage.ValueType>) as Boolean {
        try {
            Application.Storage.setValue(KEY, list);
            return true;
        } catch (e) {
            return false;
        }
    }

    // Debug builds only: no match in the history, nor in the glance.
    (:debug)
    function clear() as Void {
        try {
            Application.Storage.deleteValue(KEY);
            Application.Storage.deleteValue(LastMatch.KEY);
        } catch (e) {
        }
    }
}

import Toybox.Application;
import Toybox.Lang;

// The format for the next match: the last one picked in the Format menu, and the
// last Custom set structure, kept apart so that picking a preset doesn't lose it. Both are in
// Application.Storage in MatchConfig.toDictionary()'s form (Application.Properties can't hold a
// dictionary). Missing, stale or invalid data reads as the first-launch default.
module FormatStore {

    // Storage keys: never rename.
    const FORMAT_KEY = "format";
    const CUSTOM_KEY = "customFormat";

    // The last format picked; first launch: Best of 3, Star point, doubles, not mixed.
    function load() as MatchConfig {
        var config = MatchConfig.fromDictionary(read(FORMAT_KEY));
        return config != null ? config : new MatchConfig();
    }

    function save(config as MatchConfig) as Void {
        write(FORMAT_KEY, config.toDictionary());
    }

    // The last Custom format (only its set structure is used), or null when there's none yet.
    function loadCustom() as MatchConfig? {
        return MatchConfig.fromDictionary(read(CUSTOM_KEY));
    }

    function saveCustom(config as MatchConfig) as Void {
        write(CUSTOM_KEY, config.toDictionary());
    }

    function read(key as String) as Object? {
        try {
            return Application.Storage.getValue(key);
        } catch (e) {
            return null;
        }
    }

    // A write the store refuses is dropped (the format keeps its previous value), never a crash.
    function write(key as String, value as Application.Storage.ValueType) as Void {
        try {
            Application.Storage.setValue(key, value);
        } catch (e) {
        }
    }
}

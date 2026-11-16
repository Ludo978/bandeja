import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The launch prompt, the app's first view when a match is stored: a native menu
// titled "Resume match?", with Resume (the score under it) and Discard, or "Can't
// resume" with Discard only when the stored match can't be read or replayed (ResumePrompt). Resume
// starts a new session and opens the match (MatchFlow.resume()); Discard, confirmed with the watch's
// own confirmation, clears it and opens the home screen. BACK leaves the app with the match still
// stored, so the next launch asks again: no screen traps the player, and nothing is lost by a press.
module ResumeMenu {

    // The app's first view when a match is stored: the stored match is replayed a step at a time
    // (MatchStore.startLoad()), the first step here, so the prompt shows at once for a usual match;
    // a longer one goes on behind LoadView, then the prompt takes its place.
    function launchView() as [WatchUi.Views, WatchUi.InputDelegates] {
        var load = MatchStore.startLoad();
        if (load.step()) {
            return initialView(load.getStored());
        }
        var job = new ResumeLoad(load);
        return [new LoadView(job), new LoadDelegate(job)];
    }

    function initialView(stored as StoredMatch?) as [WatchUi.Views, WatchUi.InputDelegates] {
        var canResume = stored != null;
        var menu = new ResumeMenuView({:title => ResumePrompt.title(canResume)});
        var items = ResumePrompt.items(canResume);
        for (var i = 0; i < items.size(); i++) {
            if (items[i] == RESUME_ITEM_RESUME) {
                var score = ResumePrompt.scoreText((stored as StoredMatch).engine.getState());
                menu.addItem(new WatchUi.MenuItem(Rez.Strings.Resume, score, items[i], null));
            } else {
                menu.addItem(new WatchUi.MenuItem(Rez.Strings.Discard, null, items[i], null));
            }
        }
        return [menu, new ResumeMenuDelegate(stored)];
    }
}

// The prompt's menu. The watch's confirmation pops itself once answered, so Discard can't replace
// the prompt from there: when the prompt shows again with nothing stored, the home screen takes its
// place.
class ResumeMenuView extends WatchUi.Menu2 {

    function initialize(options as {:title as Lang.ResourceId}) {
        Menu2.initialize(options);
    }

    function onShow() as Void {
        Menu2.onShow();
        if (!MatchStore.isStored()) {
            MatchFlow.home();
        }
    }
}

class ResumeMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _stored as StoredMatch?;

    function initialize(stored as StoredMatch?) {
        Menu2InputDelegate.initialize();
        _stored = stored;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var stored = _stored;
        if (item.getId() == RESUME_ITEM_RESUME && stored != null) {
            MatchFlow.resume(stored);
        } else {
            WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.DiscardConfirm) as String),
                new ResumeDiscardDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        System.exit();
    }
}

class ResumeDiscardDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            MatchStore.clear();
        }
        return true;
    }
}

// The rest of a long launch replay (ResumeMenu.launchView()). BACK leaves the app with the match
// still stored, as on the prompt, and the replay mark removed: the replay didn't fail.
class ResumeLoad extends LoadJob {

    private var _load as MatchLoad;

    function initialize(load as MatchLoad) {
        LoadJob.initialize();
        _load = load;
    }

    function step() as Boolean {
        return _load.step();
    }

    function getProgress() as Float {
        return _load.getProgress();
    }

    function done() as Void {
        var prompt = ResumeMenu.initialView(_load.getStored());
        WatchUi.switchToView(prompt[0], prompt[1], WatchUi.SLIDE_IMMEDIATE);
    }

    function back() as Void {
        MatchStore.endLoad();
        System.exit();
    }
}

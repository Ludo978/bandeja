import Toybox.Lang;

// The launch prompt's items (ResumeMenu).
enum ResumeItem {
    RESUME_ITEM_RESUME,
    RESUME_ITEM_DISCARD
}

// What the launch prompt shows when a match is stored, without the menu, so it's
// unit-tested: "Resume match?" with Resume, the score under it, then Discard; when the stored match
// can't be read or replayed, "Can't resume" with Discard only.
module ResumePrompt {

    function title(canResume as Boolean) as ResourceId {
        return canResume ? Rez.Strings.ResumeTitle : Rez.Strings.ResumeFailedTitle;
    }

    function items(canResume as Boolean) as Array<ResumeItem> {
        return canResume ? [RESUME_ITEM_RESUME, RESUME_ITEM_DISCARD] : [RESUME_ITEM_DISCARD];
    }

    // The compact score (MatchState.getScoreText()) without the star of the unfinished set: "6-4 2-3".
    // At most a history line's score (HistoryText.LABEL_MAX characters), so it fits the item: a long
    // Free play's latest sets, ".. 7-6 2-6 7-5 2-3".
    function scoreText(state as MatchState) as String {
        var text = state.getScoreTextIn(HistoryText.LABEL_MAX);
        var star = text.find("*");
        return star != null ? text.substring(0, star) as String : text;
    }
}

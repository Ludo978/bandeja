import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The serve questions (ServeQuestions) as native menus: UP and DOWN
// move, START picks. They open over the match screen when the match starts. The second question
// takes the first one's place and BACK there brings the first back, so only one is ever open; the
// last answer closes it on the match screen, and BACK on the first question does nothing. While they
// show the recording goes on, and no point can be scored.
module ServeMenu {

    // Opens the current question, if there is one to ask.
    function open(questions as ServeQuestions) as Void {
        if (questions.getQuestion() != QUESTION_NONE) {
            WatchUi.pushView(build(questions), new ServeMenuDelegate(questions), WatchUi.SLIDE_LEFT);
        }
    }

    function build(questions as ServeQuestions) as WatchUi.Menu2 {
        var answers = questions.getAnswers();
        var focus = answers.indexOf(questions.getFocus());
        var menu = new WatchUi.Menu2({:title => questions.getTitle(), :focus => focus < 0 ? 0 : focus});
        for (var i = 0; i < answers.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(questions.getLabel(answers[i]), null, answers[i] as Number, null));
        }
        return menu;
    }
}

class ServeMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _questions as ServeQuestions;

    function initialize(questions as ServeQuestions) {
        Menu2InputDelegate.initialize();
        _questions = questions;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        show(_questions.pick(item.getId() as Number as ServeAnswer, Time.now().value()), WatchUi.SLIDE_LEFT);
    }

    // Back to the first question from the second; nothing on the first, which must be answered. Never
    // leaves the match (a swipe right too).
    function onBack() as Void {
        if (_questions.back()) {
            show(QUESTION_FIRST, WatchUi.SLIDE_RIGHT);
        }
    }

    // The next question in this one's place, or the match screen.
    private function show(question as ServeQuestion, transition as WatchUi.SlideType) as Void {
        if (question == QUESTION_NONE) {
            WatchUi.popView(transition);
        } else {
            WatchUi.switchToView(ServeMenu.build(_questions), self, transition);
        }
    }
}

// Serialize display commands: an older wake must finish before a newer blank.
function createState() {
    return { blanked: false, wakeRunning: false, blankRunning: false,
        blankPending: false, wakePending: false, ignoreMotionUntil: 0 };
}
function transition(state, event) {
    var next = Object.assign({}, state);
    var effects = [];
    function wake() {
        next.blanked = false;
        next.wakePending = false;
        if (!next.wakeRunning) { next.wakeRunning = true; effects.push("WAKE"); }
    }
    function blank() {
        next.blankPending = false;
        next.blankRunning = true;
        effects.push("BLANK");
    }
    switch (event.type) {
    case "WAKE":
        if (next.blankPending || next.blankRunning) {
            if (event.deliberate) next.wakePending = true;
            break;
        }
        if (!event.deliberate && event.now < next.ignoreMotionUntil) break;
        if (next.blanked || event.force) wake();
        break;
    case "BLANK":
        next.blanked = true;
        next.wakePending = false;
        next.ignoreMotionUntil = event.now + 500;
        if (!next.blankRunning) {
            next.blankPending = true;
            if (!next.wakeRunning) blank();
        }
        break;
    case "WAKE_FINISHED":
        next.wakeRunning = false;
        if (next.blankPending) blank();
        break;
    case "BLANK_FINISHED":
        next.blankRunning = false;
        next.ignoreMotionUntil = event.now + 500;
        if (next.wakePending) wake();
        break;
    case "OBSERVED_BLANK":
        next.blanked = true;
        break;
    }
    return { state: next, effects: effects };
}
// Zero means no automatic blank timer, including while a partial secret exists.
function idleDelay(input) {
    if (input.blanked || input.busy || input.passwordLength > 0) return 0;
    return input.passwordMode ? 60000 : 30000;
}
if (typeof module !== "undefined" && module.exports)
    module.exports = { createState: createState, transition: transition, idleDelay: idleDelay };

// DPMS snapshots are evidence only in the lock/display generation they sampled.
function createState() {
    return { epoch: 0, offObserved: false };
}
function invalidate(state) {
    return { epoch: state.epoch + 1, offObserved: false };
}
function observe(state, sampleEpoch, monitors) {
    var next = { epoch: state.epoch, offObserved: state.offObserved };
    var effects = [];
    if (sampleEpoch !== state.epoch || !Array.isArray(monitors))
        return { state: next, effects: effects };
    var outputs = monitors.filter(function(m) { return m && !m.disabled; });
    if (!outputs.length) return { state: next, effects: effects };
    var active = outputs.some(function(m) { return m.dpmsStatus === true; });
    var allOff = outputs.every(function(m) { return m.dpmsStatus === false; });
    if (active && state.offObserved) {
        next.offObserved = false;
        effects.push("SCREEN_WOKE");
    } else if (allOff && !state.offObserved) {
        next.offObserved = true;
        effects.push("DISPLAY_BLANKED");
    }
    return { state: next, effects: effects };
}
if (typeof module !== "undefined" && module.exports)
    module.exports = { createState: createState, invalidate: invalidate, observe: observe };

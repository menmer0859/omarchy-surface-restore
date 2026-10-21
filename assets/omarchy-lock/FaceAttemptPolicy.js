
function createState() {
    return {
        phase: "inactive",
        lockId: 0,
        attemptId: 0,
        secure: false,
        faceAvailable: false,
        blank: false,
        suspended: false,
        wakeId: 0
    };
}

function copyState(state) {
    return {
        phase: state.phase,
        lockId: state.lockId,
        attemptId: state.attemptId,
        secure: state.secure,
        faceAvailable: state.faceAvailable,
        blank: state.blank,
        suspended: state.suspended,
        wakeId: state.wakeId
    };
}

function matchesLock(state, event) {
    return event.lockId === undefined || event.lockId === state.lockId;
}

function matchesAttempt(state, event) {
    return matchesLock(state, event) && event.attemptId === state.attemptId;
}

function transition(state, event) {
    var next = copyState(state);
    var effects = [];

    switch (event.type) {
    case "LOCK_REQUESTED":
        if (state.phase === "scanning")
            effects.push("ABORT_FACE");
        next.phase = "locked_idle";
        next.blank = false;
        next.suspended = false;
        next.wakeId += 1;
        if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
        next.lockId = state.lockId + 1;
        next.attemptId = 0;
        next.secure = false;
        next.faceAvailable = !!event.faceAvailable;
        break;

    case "LOCK_SECURE":
        if (state.phase === "inactive" || !matchesLock(state, event))
            break;
        next.secure = true;
        break;

    case "INTENT":
        if (state.phase !== "locked_idle" || state.blank || state.suspended || !state.secure || !state.faceAvailable || !matchesLock(state, event))
            break;
        next.phase = "scanning";
        next.attemptId = state.attemptId + 1;
        effects.push("START_FACE");
        break;

    case "FACE_SELECTED":
        if (state.phase === "inactive" || state.phase === "scanning" || state.suspended || !state.secure || !state.faceAvailable || !matchesLock(state, event))
            break;
        if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
        next.blank = false;
        next.phase = "scanning";
        next.attemptId = state.attemptId + 1;
        effects.push("START_FACE");
        break;

    case "FACE_RESULT":
        if (state.phase !== "scanning" || !matchesAttempt(state, event))
            break;
        if (event.result === "success") {
            if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
            next.wakeId += 1;
            next.phase = "inactive";
            next.secure = false;
            effects.push("UNLOCK");
        } else {
            next.phase = "failed";
        }
        break;

    case "FACE_TIMEOUT":
        if (state.phase !== "scanning" || !matchesAttempt(state, event))
            break;
        next.phase = "timed_out";
        effects.push("ABORT_FACE");
        break;

    case "PASSWORD_SELECTED":
        if (state.phase === "inactive" || !matchesLock(state, event))
            break;
        if (state.phase === "scanning")
            effects.push("ABORT_FACE");
        if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
        next.wakeId += 1;
        next.phase = "password";
        break;

    case "UNLOCKED":
        if (state.phase !== "inactive" && matchesLock(state, event)) {
            if (state.phase === "scanning")
                effects.push("ABORT_FACE");
            if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
            next.wakeId += 1;
            next.phase = "inactive";
            next.secure = false;
        }
        break;

    case "DISPLAY_BLANKED":
    case "SUSPEND":
        if (state.phase === "inactive" || !matchesLock(state, event)) break;
        if (state.phase === "scanning") effects.push("ABORT_FACE");
        if (state.phase === "wake_delay") effects.push("STOP_WAKE_DELAY");
        next.wakeId += 1;
        next.blank = true;
        next.suspended = event.type === "SUSPEND" || state.suspended;
        if (state.phase === "scanning" || state.phase === "wake_delay") next.phase = "locked_idle";
        break;

    case "SCREEN_WOKE":
    case "RESUME":
        if (state.phase === "inactive" || !matchesLock(state, event)) break;
        if (event.type === "SCREEN_WOKE" && (!state.blank || state.suspended)) break;
        if (event.type === "RESUME" && !state.suspended) break;
        next.blank = false;
        next.suspended = false;
        if (state.phase === "password" || !state.faceAvailable) break;
        next.wakeId += 1;
        next.phase = "wake_delay";
        effects.push("START_WAKE_DELAY");
        break;

    case "WAKE_DELAY_ELAPSED":
        if (state.phase !== "wake_delay" || !matchesLock(state, event) || event.wakeId !== state.wakeId || state.blank || state.suspended) break;
        if (!state.secure || !state.faceAvailable) { next.phase = "locked_idle"; break; }
        next.phase = "scanning";
        next.attemptId += 1;
        effects.push("START_FACE");
        break;

    case "FACE_AVAILABILITY_CHANGED":
        if (!matchesLock(state, event))
            break;
        next.faceAvailable = !!event.faceAvailable;
        if (!next.faceAvailable && (state.phase === "scanning" || state.phase === "wake_delay")) {
            effects.push(state.phase === "scanning" ? "ABORT_FACE" : "STOP_WAKE_DELAY");
            next.wakeId += 1;
            next.phase = "locked_idle";
        }
        break;
    }

    return { state: next, effects: effects };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { createState: createState, transition: transition };

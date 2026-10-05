
function createState() {
    return {
        phase: "inactive",
        lockId: 0,
        attemptId: 0,
        secure: false,
        faceAvailable: false
    };
}

function copyState(state) {
    return {
        phase: state.phase,
        lockId: state.lockId,
        attemptId: state.attemptId,
        secure: state.secure,
        faceAvailable: state.faceAvailable
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
        if (state.phase !== "locked_idle" || !state.secure || !state.faceAvailable || !matchesLock(state, event))
            break;
        next.phase = "scanning";
        next.attemptId = state.attemptId + 1;
        effects.push("START_FACE");
        break;

    case "FACE_SELECTED":
        if (state.phase === "inactive" || state.phase === "scanning" || !state.secure || !state.faceAvailable || !matchesLock(state, event))
            break;
        next.phase = "scanning";
        next.attemptId = state.attemptId + 1;
        effects.push("START_FACE");
        break;

    case "FACE_RESULT":
        if (state.phase !== "scanning" || !matchesAttempt(state, event))
            break;
        if (event.result === "success") {
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
        next.phase = "failed";
        effects.push("ABORT_FACE");
        break;

    case "PASSWORD_SELECTED":
        if (state.phase === "inactive" || !matchesLock(state, event))
            break;
        if (state.phase === "scanning")
            effects.push("ABORT_FACE");
        next.phase = "password";
        break;

    case "UNLOCKED":
        if (state.phase !== "inactive" && matchesLock(state, event)) {
            if (state.phase === "scanning")
                effects.push("ABORT_FACE");
            next.phase = "inactive";
            next.secure = false;
        }
        break;

    case "SUSPEND":
        if (state.phase === "scanning") {
            effects.push("ABORT_FACE");
            next.phase = "locked_idle";
        }
        break;

    case "FACE_AVAILABILITY_CHANGED":
        if (!matchesLock(state, event))
            break;
        next.faceAvailable = !!event.faceAvailable;
        break;
    }

    return { state: next, effects: effects };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { createState: createState, transition: transition };

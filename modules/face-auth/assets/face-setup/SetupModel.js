.pragma library

function selectedOptions(state) {
    var options = [];
    if (state && state.lock === true) options.push("--lock");
    if (state && state.sudo === true) options.push("--sudo");
    if (state && state.polkit === true) options.push("--polkit");
    return options;
}

function parseStatus(raw) {
    try {
        var result = JSON.parse(String(raw || ""));
        return result && result.schemaVersion === 1 && result.checks ? result : null;
    } catch (error) {
        return null;
    }
}

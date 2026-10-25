const assert = require("assert");
const fs = require("fs");
const vm = require("vm");
const source = fs.readFileSync(require.resolve("../assets/face-setup/SetupModel.js"), "utf8").replace(/^\.pragma library\s*/m, "");
const Model = {};
vm.runInNewContext(source, Model);

assert.strictEqual(JSON.stringify(Array.from(Model.selectedOptions({ lock: true, sudo: false, polkit: false }))), JSON.stringify(["--lock"]));
assert.strictEqual(JSON.stringify(Array.from(Model.selectedOptions({ lock: false, sudo: true, polkit: false }))), JSON.stringify(["--sudo"]));
assert.strictEqual(JSON.stringify(Array.from(Model.selectedOptions({ lock: false, sudo: false, polkit: true }))), JSON.stringify(["--polkit"]));
assert.strictEqual(JSON.stringify(Array.from(Model.selectedOptions({ lock: true, sudo: true, polkit: true }))), JSON.stringify(["--lock", "--sudo", "--polkit"]));

const parsed = Model.parseStatus('{"schemaVersion":1,"checks":{},"lock":{"ready":true},"sudo":{"ready":false}}');
assert.strictEqual(parsed.lock.ready, true);
assert.strictEqual(parsed.sudo.ready, false);
assert.strictEqual(Model.parseStatus("not json"), null);

console.log("Face setup model tests passed.");

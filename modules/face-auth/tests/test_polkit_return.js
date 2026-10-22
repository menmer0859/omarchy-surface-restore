const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const model = require(path.join(root, 'assets/omarchy-polkit/PolkitModel.js'));
const source = fs.readFileSync(path.join(root, 'assets/omarchy-polkit/PolkitAgent.qml'), 'utf8');
const admin = {name: 'admin', displayName: 'Administrator', isGroup: false};
const otherAdmin = {name: 'other', displayName: 'Other', isGroup: false};
let restarted = 0, sent = [], cancelled = 0;
const flow = {
  message: 'Authorize a protected action', inputPrompt: 'Password:', supplementaryMessage: '',
  selectedIdentity: admin, identities: [admin, otherAdmin], isResponseRequired: true,
  responseVisible: false, failed: false, isCompleted: false, isSuccessful: false,
  isCancelled: false, cookie: 'original-action',
  restartAuthentication() { restarted++; this.inputPrompt = 'Use face authentication? [y/N]'; return true; },
  submit(value) { sent.push(value); this.isResponseRequired = false; },
  cancelAuthenticationRequest() { cancelled++; }
};
assert.equal(typeof model.canReturnToFace, 'function', 'password return requires a real runtime capability guard');
assert.equal(model.canReturnToFace(flow, flow, admin, false, false), true);
const restartMethod = flow.restartAuthentication; flow.restartAuthentication = undefined;
assert.equal(model.canReturnToFace(flow, flow, admin, false, false), false, 'unpatched runtime cannot offer return');
flow.restartAuthentication = restartMethod;
assert.equal(model.canReturnToFace(flow, {}, admin, false, false), false, 'capability never leaks between protected requests');
assert.equal(model.canReturnToFace(flow, flow, otherAdmin, false, false), false, 'capability never leaks between administrator identities');
for (const [field, value] of [['isResponseRequired', false], ['isCompleted', true], ['isCancelled', true], ['inputPrompt', 'Use face authentication? [y/N]']]) {
  const saved = flow[field]; flow[field] = value;
  assert.equal(model.canReturnToFace(flow, flow, admin, false, false), false, field);
  flow[field] = saved;
}
assert.equal(model.canReturnToFace(flow, flow, admin, true, false), false, 'submitted password cannot restart');
assert.equal(model.canReturnToFace(flow, flow, admin, false, true), false, 'scanning cannot restart');

// Run the actual QML handler bodies, keeping the external AuthFlow boundary
// controlled. Native behavior of that boundary is covered by run-polkit-native.sh.
function method(name) {
  const start = source.indexOf('function ' + name + '(');
  assert.ok(start >= 0, 'production handler exists: ' + name);
  const opening = source.indexOf('{', start);
  let depth = 1, at = opening + 1;
  for (; depth && at < source.length; at++) {
    if (source[at] === '{') depth++;
    if (source[at] === '}') depth--;
  }
  return source.slice(start, at);
}
const context = {
  polkitAgent: {flow}, PolkitModel: model,
  faceConsentFlow: flow, faceConsentIdentity: admin,
  currentPrompt: 'Password:', currentMessage: '', currentSupplementary: '',
  responseRequired: true, responseVisible: false, failed: false,
  faceCheckPending: false, faceFallbackActive: true, errorFlash: true, submitted: false,
  canReturnToFace: true, authView: {passwordText: 'do not retain this password', forceActiveFocus() {}},
  Qt: {callLater(fn) { fn(); }}, refocus() {}
};
vm.createContext(context);
for (const name of ['syncFromFlow', 'returnToFace', 'submitFaceConsent']) vm.runInContext(method(name), context);
context.returnToFace();
assert.equal(restarted, 1, 'explicit return restarts a real PAM conversation');
assert.equal(cancelled, 0, 'return keeps original protected action alive');
assert.deepEqual(sent, [], 'return sends neither a password nor face consent');
assert.equal(flow.selectedIdentity, admin, 'return retains administrator identity');
assert.equal(context.currentPrompt, 'Use face authentication? [y/N]', 'return opens real method picker');
assert.equal(context.authView.passwordText, '', 'return clears password');
assert.equal(context.faceCheckPending, false, 'return leaves camera idle');
flow.inputPrompt = 'Password:'; context.currentPrompt = 'Use face authentication? [y/N]';
context.submitFaceConsent(true);
assert.deepEqual(sent, [], 'stale picker never sends consent into actual password prompt');
flow.inputPrompt = 'Use face authentication? [y/N]';
context.submitFaceConsent(true);
assert.deepEqual(sent, ['y'], 'only second explicit face choice consents to camera');
assert.equal(context.faceCheckPending, true);
context.canReturnToFace = false;
context.returnToFace();
assert.equal(restarted, 1, 'stale or busy return event cannot restart');
console.log('POLKIT_RETURN_CONTROLLER_PASS');

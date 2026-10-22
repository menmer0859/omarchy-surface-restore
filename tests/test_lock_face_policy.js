'use strict';

const assert = require('node:assert/strict');
let policy;
try {
  policy = require('../assets/omarchy-lock/FaceAttemptPolicy.js');
} catch (error) {
  if (error.code !== 'MODULE_NOT_FOUND') throw error;
}
assert.ok(policy, 'face attempt policy module must exist');
const { createState, transition } = policy;

function send(state, type, fields) {
  return transition(state, Object.assign({ type }, fields || {}));
}

function startSecureLock(state) {
  let result = send(state, 'LOCK_REQUESTED', { faceAvailable: true });
  assert.deepEqual(result.effects, []);
  const lockId = result.state.lockId;
  result = send(result.state, 'LOCK_SECURE', { lockId });
  assert.deepEqual(result.effects, []);
  return result.state;
}

{
  let state = startSecureLock(createState());
  let result = send(state, 'INTENT', { lockId: state.lockId });
  assert.deepEqual(result.effects, ['START_FACE']);
  assert.equal(result.state.phase, 'scanning');
  assert.equal(result.state.attemptId, 1);

  result = send(result.state, 'INTENT', { lockId: result.state.lockId });
  assert.deepEqual(result.effects, []);
  assert.equal(result.state.attemptId, 1);

  state = result.state;
  result = send(state, 'FACE_RESULT', {
    lockId: state.lockId,
    attemptId: state.attemptId,
    result: 'failure',
  });
  assert.equal(result.state.phase, 'failed');
  assert.deepEqual(result.effects, []);

  result = send(result.state, 'INTENT', { lockId: result.state.lockId });
  assert.deepEqual(result.effects, []);
  assert.equal(result.state.attemptId, 1);

  result = send(result.state, 'FACE_SELECTED', { lockId: result.state.lockId });
  assert.deepEqual(result.effects, ['START_FACE']);
  assert.equal(result.state.phase, 'scanning');
  assert.equal(result.state.attemptId, 2);
}

{
  let state = createState();
  let result = send(state, 'LOCK_REQUESTED', { faceAvailable: true });
  state = result.state;
  const lockId = state.lockId;
  result = send(state, 'INTENT', { lockId });
  assert.deepEqual(result.effects, []);
  assert.equal(result.state.phase, 'locked_idle');
  result = send(result.state, 'LOCK_SECURE', { lockId });
  assert.deepEqual(result.effects, []);
  assert.equal(result.state.phase, 'locked_idle');
}

{
  let state = startSecureLock(createState());
  let result = send(state, 'INTENT', { lockId: state.lockId });
  const oldLockId = result.state.lockId;
  const oldAttemptId = result.state.attemptId;

  result = send(result.state, 'PASSWORD_SELECTED', { lockId: oldLockId });
  assert.deepEqual(result.effects, ['ABORT_FACE']);
  assert.equal(result.state.phase, 'password');

  let suspended = send(startSecureLock(createState()), 'INTENT');
  const suspendResult = send(suspended.state, 'SUSPEND', { lockId: suspended.state.lockId });
  assert.deepEqual(suspendResult.effects, ['ABORT_FACE']);
  assert.equal(suspendResult.state.phase, 'locked_idle');

  let resumed = send(suspendResult.state, 'RESUME');
  let unlocked = send(resumed.state, 'FACE_SELECTED');
  const unlockResult = send(unlocked.state, 'UNLOCKED', { lockId: unlocked.state.lockId });
  assert.deepEqual(unlockResult.effects, ['ABORT_FACE']);
  assert.equal(unlockResult.state.phase, 'inactive');

  const relocked = send(unlockResult.state, 'LOCK_REQUESTED', { faceAvailable: true });
  assert.ok(relocked.state.lockId > oldLockId);

  const staleResult = send(relocked.state, 'FACE_RESULT', {
    lockId: oldLockId,
    attemptId: oldAttemptId,
    result: 'success',
  });
  assert.ok(!staleResult.effects.includes('UNLOCK'));
  assert.equal(staleResult.state.phase, 'locked_idle');
}

{
  let state = startSecureLock(createState());
  const result = send(state, 'FACE_AVAILABILITY_CHANGED', {
    lockId: state.lockId,
    faceAvailable: true,
  });
  assert.deepEqual(result.effects, []);
  assert.equal(result.state.phase, 'locked_idle');
}

{
  let state = startSecureLock(createState());
  let result = send(state, 'FACE_SELECTED', { lockId: state.lockId });
  assert.deepEqual(result.effects, ['START_FACE']);
  state = result.state;
  result = send(state, 'FACE_TIMEOUT', { lockId: state.lockId, attemptId: state.attemptId });
  assert.deepEqual(result.effects, ['ABORT_FACE']);
  assert.equal(result.state.phase, 'timed_out');
}

{
  let state = startSecureLock(createState());
  let result = send(state, 'INTENT', { lockId: state.lockId });
  const firstLockId = result.state.lockId;
  result = send(result.state, 'UNLOCKED', { lockId: firstLockId });
  state = startSecureLock(result.state);
  result = send(state, 'INTENT', { lockId: state.lockId });

  const staleUnlock = send(result.state, 'UNLOCKED', { lockId: firstLockId });
  assert.deepEqual(staleUnlock.effects, []);
  assert.equal(staleUnlock.state.phase, 'scanning');
  assert.ok(staleUnlock.state.lockId > firstLockId);
}

console.log('Lock face policy tests passed.');

// An actual blank-to-wake edge gets one delayed attempt, never a periodic poll.
{
 let s = startSecureLock(createState());
 let r = send(s, 'SCREEN_WOKE'); assert.deepEqual(r.effects, [], 'lit manual lock is not a wake');
 r = send(s, 'DISPLAY_BLANKED');
 r = send(r.state, 'SCREEN_WOKE');
 assert.equal(r.state.phase, 'wake_delay');
 assert.deepEqual(r.effects, ['START_WAKE_DELAY']);
 const wake = {lockId:r.state.lockId, wakeId:r.state.wakeId};
 r = send(r.state, 'SCREEN_WOKE'); assert.deepEqual(r.effects, [], 'wake bounce cannot rearm');
 r = send(r.state, 'WAKE_DELAY_ELAPSED', wake); assert.deepEqual(r.effects, ['START_FACE']);
 const attempt = {lockId:r.state.lockId, attemptId:r.state.attemptId};
 r = send(r.state, 'FACE_RESULT', {...attempt,result:'failure'});
 assert.deepEqual(send(r.state,'INTENT').effects, [], 'no implicit retry');
 assert.deepEqual(send(r.state,'WAKE_DELAY_ELAPSED',wake).effects, [], 'expired delay cannot retry');
}
{
 let r = send(startSecureLock(createState()),'DISPLAY_BLANKED');
 r=send(r.state,'SCREEN_WOKE'); const stale={lockId:r.state.lockId,wakeId:r.state.wakeId};
 r=send(r.state,'PASSWORD_SELECTED');
 assert.ok(r.effects.includes('STOP_WAKE_DELAY'));
 assert.deepEqual(send(r.state,'WAKE_DELAY_ELAPSED',stale).effects, []);
 r=send(r.state,'DISPLAY_BLANKED');
 assert.deepEqual(send(r.state,'SCREEN_WOKE').effects, ['START_WAKE_DELAY'], 'actual blank starts fresh wake flow after password editing');
}
{
 let r = send(startSecureLock(createState()),'SUSPEND');
 r=send(r.state,'RESUME'); assert.equal(r.state.phase,'wake_delay');
 const old={lockId:r.state.lockId,wakeId:r.state.wakeId};
 r=send(r.state,'SUSPEND');
 assert.deepEqual(send(r.state,'WAKE_DELAY_ELAPSED',old).effects, []);
 r=send(r.state,'RESUME');
 assert.ok(r.state.wakeId > old.wakeId);
 assert.deepEqual(send(r.state,'WAKE_DELAY_ELAPSED',old).effects, []);
 r=send(r.state,'DISPLAY_BLANKED');
 assert.deepEqual(send(r.state,'WAKE_DELAY_ELAPSED',{lockId:r.state.lockId,wakeId:r.state.wakeId}).effects, []);
}
console.log('Wake settling and cancellation tests passed.');

assert.equal(typeof policy.isIntentKey, 'function', 'central intent key filter is required');
const keys={Key_Tab:1,Key_Backtab:2,Key_Shift:3,Key_Control:4,Key_Alt:5,Key_Meta:6,Key_AltGr:7,Key_CapsLock:8,Key_NumLock:9,Key_ScrollLock:10,Key_Super_L:11,Key_Super_R:12,Key_Hyper_L:13,Key_Hyper_R:14,ControlModifier:2,AltModifier:4,MetaModifier:8};
for (const name of ['Key_Shift','Key_Control','Key_Alt','Key_Meta','Key_AltGr','Key_CapsLock','Key_NumLock','Key_ScrollLock','Key_Tab','Key_Backtab']) assert.equal(policy.isIntentKey(keys[name],0,false,keys),false,name+' alone is not intent');
assert.equal(policy.isIntentKey(65,1,false,keys),true,'ordinary shifted character is intent');
assert.equal(policy.isIntentKey(65,2,false,keys),false,'Ctrl shortcut is not face intent');
assert.equal(policy.isIntentKey(65,0,true,keys),false,'repeat is not fresh intent');
console.log('Modifier-only face intent regression passed.');
{
 let r = send(startSecureLock(createState()),'PASSWORD_SELECTED');
 r=send(r.state,'FACE_RETURNED');
 assert.equal(r.state.phase,'locked_idle','return from password opens a quiet face picker');
 assert.deepEqual(r.effects,[],'return itself never consents to camera');
 r=send(r.state,'FACE_SELECTED');
 assert.deepEqual(r.effects,['START_FACE'],'explicit Use face after return starts one attempt');
}

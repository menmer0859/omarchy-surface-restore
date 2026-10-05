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

  let unlocked = send(suspendResult.state, 'INTENT');
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
  assert.equal(result.state.phase, 'failed');
}

console.log('Lock face policy tests passed.');

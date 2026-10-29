import test from 'node:test';
import assert from 'node:assert/strict';
import { validateCallback } from '../firebase-hosting/sign-in/callback.mjs';

const state = 'a'.repeat(43) + '=';
test('accepts the app loopback callback', () => {
  assert.equal(validateCallback('http://127.0.0.1:40000/callback', state).port, '40000');
});
test('never sends a Google credential to an external or modified callback', () => {
  for (const url of [
    'https://evil.example/callback', 'http://127.0.0.1.evil.example:40000/callback',
    'http://127.0.0.1:40000/elsewhere', 'http://user@127.0.0.1:40000/callback',
    'http://127.0.0.1:40000/callback?target=evil', 'http://127.0.0.1:80/callback',
  ]) assert.throws(() => validateCallback(url, state));
  assert.throws(() => validateCallback('http://127.0.0.1:40000/callback', 'bad-state'));
});

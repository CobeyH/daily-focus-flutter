import { initializeApp } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js';
import {
  getAuth, GoogleAuthProvider, inMemoryPersistence,
  setPersistence, signInWithPopup, signOut,
} from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-auth.js';
import { validateCallback } from './callback.mjs';

const button = document.getElementById('sign-in');
const status = document.getElementById('status');
const params = new URLSearchParams(location.hash.slice(1));
history.replaceState(null, '', location.pathname);

try {
  const state = params.get('state') ?? '';
  const callback = validateCallback(params.get('callback'), state);
  const response = await fetch('/__/firebase/init.json');
  if (!response.ok) throw new Error('Could not load sign-in configuration.');
  const auth = getAuth(initializeApp(await response.json()));
  // Credentials must not remain in this browser after the app takes over.
  await setPersistence(auth, inMemoryPersistence);
  button.disabled = false;
  status.textContent = '';
  button.addEventListener('click', async () => {
    button.disabled = true;
    status.textContent = 'Complete sign-in in the Google window.';
    try {
      const result = await signInWithPopup(auth, new GoogleAuthProvider());
      const credential = GoogleAuthProvider.credentialFromResult(result);
      if (!credential?.idToken) throw new Error('Google did not return a sign-in token.');
      callback.hash = new URLSearchParams({ state, idToken: credential.idToken });
      await signOut(auth);
      location.replace(callback.href);
    } catch (error) {
      button.disabled = false;
      status.textContent = error.code === 'auth/operation-not-allowed'
        ? 'Google sign-in needs to be enabled for Daily Focus in Firebase Authentication.'
        : error.code === 'auth/popup-closed-by-user'
          ? 'Sign-in was cancelled. You can try again.'
          : error.code === 'auth/popup-blocked'
            ? 'Allow the Google sign-in popup, then try again.'
            : error.message;
    }
  });
} catch (error) {
  status.textContent = error.message;
}

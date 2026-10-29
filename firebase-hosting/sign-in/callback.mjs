// The credential may only be returned to the native app's loopback listener.
export function validateCallback(value, state) {
  const url = new URL(value);
  if (url.protocol !== 'http:' || url.hostname !== '127.0.0.1' ||
      !url.port || Number(url.port) < 1024 || Number(url.port) > 65535 ||
      url.pathname !== '/callback' || url.search || url.hash ||
      url.username || url.password || !/^[A-Za-z0-9_-]{43}=$/.test(state)) {
    throw new Error('Open Google sign-in from the Daily Focus app.');
  }
  return url;
}

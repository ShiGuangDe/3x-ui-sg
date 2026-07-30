// Vitest setup. The frontend's Base64 utility (used by link generators)
// reaches for `window.btoa` directly. Node 16+ ships btoa/atob on
// globalThis, so we just alias `window` to `globalThis` instead of
// pulling in jsdom — keeps the test env light and avoids a new dep.

if (typeof globalThis.window === 'undefined') {
  (globalThis as unknown as { window: typeof globalThis }).window = globalThis;
}

// RandomUtil.randomUUID() branches on `window.location.protocol` (crypto
// .randomUUID only over HTTPS, else a manual getRandomValues fill). The node
// env has no location, so stub an http origin to drive the manual path —
// which relies on globalThis.crypto (present in Node 18+). Lets factory-based
// tests (presets, defaults) call the client factories without pulling in jsdom.
if (typeof globalThis.location === 'undefined') {
  (globalThis as unknown as { location: { protocol: string } }).location = { protocol: 'http:' };
}

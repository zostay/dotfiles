// Exports the YouTube Music session cookies that ytmusicapi needs, handing them
// to the rotate-music-auth native host which writes the auth file.
//
// Why this has to be an extension: the cookies that actually carry the session
// (__Secure-1PSID, __Secure-3PSID, LOGIN_INFO, SSID, ...) are HttpOnly, so page
// JS and anything driving the page -- including Claude in Chrome -- cannot see
// them. document.cookie exposes 8 of the jar's cookies and not one of them is a
// session cookie. chrome.cookies is the only interface that returns them.
//
// This writes ONLY when asked to. The auth file is a live, password-and-2FA-
// bypassing credential for the Google account, sitting in plaintext at 0600 --
// a weaker tier than Chrome's own Keychain-encrypted cookie store. An earlier
// version kept it continuously fresh on a 15-minute alarm plus every cookie
// rotation; that maximised the window for no benefit, since rotate-music-login
// wakes this worker on demand. Do not add a periodic refresh back.

const HOST = 'com.hanenkamp.rotate_music_auth';
const YTM = 'https://music.youtube.com/';

// rotate-music-login opens YTM with ?rotate-music-auth=wake purely to wake this
// service worker. Matched as an exact query parameter rather than a substring,
// so a crafted link cannot pass it in a path, fragment, or search query.
const WAKE_PARAM = 'rotate-music-auth';
const WAKE_VALUE = 'wake';

// ytmusicapi recomputes `authorization` from the SAPISID cookie before every
// request (ytmusic.py). The stored value only has to contain the string
// SAPISIDHASH, which is what auth_parse.py sniffs to classify the file as
// browser auth -- so a placeholder is correct here, not a shortcut.
const AUTH_PLACEHOLDER = 'SAPISIDHASH recomputed-per-request-by-ytmusicapi';

async function buildHeaders() {
  // Filtering by url (not domain) applies Chrome's own domain/path/secure
  // matching, so we send exactly the jar a real request to YTM would carry.
  const cookies = await chrome.cookies.getAll({ url: YTM });
  if (!cookies.length) {
    throw new Error(`no cookies for ${YTM}`);
  }
  if (!cookies.some((c) => c.name === '__Secure-3PAPISID')) {
    throw new Error('__Secure-3PAPISID missing - not signed in to YouTube Music');
  }

  return {
    accept: '*/*',
    'accept-language': 'en-US,en;q=0.9',
    authorization: AUTH_PLACEHOLDER,
    'content-type': 'application/json',
    cookie: cookies.map((c) => `${c.name}=${c.value}`).join('; '),
    origin: 'https://music.youtube.com',
    referer: YTM,
    'user-agent': navigator.userAgent,
    'x-goog-authuser': '0',
    'x-origin': 'https://music.youtube.com',
  };
}

async function refresh(reason) {
  try {
    const reply = await chrome.runtime.sendNativeMessage(HOST, {
      headers: await buildHeaders(),
    });
    console.log(`[rotate-music-auth] ${reason}: ${reply && reply.status}`);
  } catch (e) {
    console.warn(`[rotate-music-auth] ${reason} failed: ${e.message}`);
  }
}

function isWakeTab(url) {
  try {
    return new URL(url).searchParams.get(WAKE_PARAM) === WAKE_VALUE;
  } catch {
    return false;
  }
}

// The manual escape hatch: click the toolbar icon to refresh without the CLI.
chrome.action.onClicked.addListener(() => refresh('toolbar click'));

// The only automatic trigger. An organic YTM page load deliberately does
// nothing -- otherwise any site could drive native-host spawns and rewrite the
// credential file just by navigating a tab to music.youtube.com.
//
// pendingUrl is the field that actually carries the sentinel. A brand-new tab
// reports it while url is still null, and YTM is an SPA that rewrites its own
// URL before the load finishes -- so an earlier version that waited for
// status === 'complete' and read tab.url could never fire, and looked like it
// worked only because a periodic alarm happened to write inside the poll
// window. Deliberately no logging of the URLs inspected here: this runs for
// every tab, and the console is not the place to accumulate browsing history.
async function maybeWake(tabId, urls, source) {
  if (!urls.some((u) => u && isWakeTab(u))) return;

  await refresh(`login wake (${source})`);
  // We opened this tab ourselves; close it so repeated runs don't litter.
  chrome.tabs.remove(tabId).catch(() => {});
}

chrome.tabs.onCreated.addListener((tab) => {
  maybeWake(tab.id, [tab.pendingUrl, tab.url], 'onCreated');
});

// Fallback for when `open` navigates an existing tab rather than creating one;
// change.url is populated only on an actual navigation, never on organic
// in-page SPA activity.
chrome.tabs.onUpdated.addListener((tabId, change) => {
  maybeWake(tabId, [change.url], 'onUpdated');
});

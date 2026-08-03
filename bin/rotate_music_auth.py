"""Shared YouTube Music auth acquisition for rotate-music and rotate-music-login.

The auth headers are a live credential that bypasses both password and 2FA for
the Google account, so they are treated as single-use: the extension writes the
file, we read it, and we delete it before the first API call. YTMusic accepts a
dict, so nothing downstream needs the file to exist.

Why an extension at all: 12 of the 16 cookies in a jar that actually
authenticates are HttpOnly, and the 4 that document.cookie can see include no
session cookie. chrome.cookies is the only interface that returns them. See
CLAUDE.md for the full reasoning before "simplifying" any of this.
"""

import json
import os
import re
import shlex
import subprocess
import time

HOST_NAME = "com.hanenkamp.rotate_music_auth"
EXTENSION_ID = "bnadenigkfcpiclddcamdoeikmmkkjbp"
YTM = "https://music.youtube.com/"
# Opening this wakes the extension's service worker; it recognises the exact
# query parameter, refreshes, and closes the tab again.
WAKE_URL = f"{YTM}?rotate-music-auth=wake"

CONFIG = os.path.expanduser("~/.rotate-music.yaml")
DEFAULT_AUTH_FILE = "~/.rotate-music-auth-cache.json"

# Present only in a jar that came from chrome.cookies. If the SAPISID family is
# there but none of these are, something scraped document.cookie and the result
# will not authenticate -- a failure that otherwise only shows up as a 401.
HTTPONLY_MARKERS = ("__Secure-1PSID", "__Secure-3PSID", "SSID", "LOGIN_INFO", "HSID")

HOST_DIRS = (
    "~/Library/Application Support/Google/Chrome/NativeMessagingHosts",
    "~/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts",
    "~/Library/Application Support/Chromium/NativeMessagingHosts",
)


class AuthError(Exception):
    """Raised when usable auth headers could not be obtained."""


def auth_file_path():
    try:
        with open(CONFIG) as fh:
            m = re.search(r"^auth_file:\s*(\S+)\s*$", fh.read(), re.MULTILINE)
    except OSError:
        m = None
    return os.path.expanduser(m.group(1) if m else DEFAULT_AUTH_FILE)


def validate(headers):
    """Return (ok, message) for a header dict."""
    if not isinstance(headers, dict):
        return False, "not a header object"

    cookie = headers.get("cookie", "")
    if "__Secure-3PAPISID" not in cookie:
        return False, "cookie is missing __Secure-3PAPISID"
    if not any(m in cookie for m in HTTPONLY_MARKERS):
        return False, "cookie has no HttpOnly session cookies - it will not authenticate"

    # Split rather than count "=" -- base64 padding inside cookie values inflates
    # the count (26 cookies reads as 37).
    return True, f"{len([p for p in cookie.split('; ') if p])} cookies"


def read_headers(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def host_manifest_paths():
    return [
        os.path.expanduser(d)
        for d in HOST_DIRS
        if os.path.isdir(os.path.dirname(os.path.expanduser(d)))
    ]


def host_registered():
    return any(os.path.exists(os.path.join(d, f"{HOST_NAME}.json")) for d in host_manifest_paths())


def install():
    """Register the native messaging host. Returns the paths written."""
    host = os.path.join(os.path.dirname(os.path.realpath(__file__)), "rotate-music-auth-host")
    if not os.access(host, os.X_OK):
        raise AuthError(f"native host is missing or not executable: {host}")

    manifest = {
        "name": HOST_NAME,
        "description": "Writes YouTube Music auth headers for rotate-music",
        "path": host,
        "type": "stdio",
        "allowed_origins": [f"chrome-extension://{EXTENSION_ID}/"],
    }

    targets = host_manifest_paths()
    if not targets:
        raise AuthError("no Chrome profile directory found - is Chrome installed?")

    written = []
    for directory in targets:
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, f"{HOST_NAME}.json")
        with open(path, "w") as fh:
            json.dump(manifest, fh, indent=2)
            fh.write("\n")
        written.append(path)
    return written


def extension_dir():
    repo = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    return os.path.join(repo, "chrome", "rotate-music-auth")


def acquire(timeout=30, quiet=False):
    """Obtain auth headers, consuming them from disk.

    Wakes the extension and waits for it to write the auth file, then reads and
    immediately unlinks it so the credential is on disk for well under a second.

    If the extension does not deliver, falls back to a pre-existing auth file
    (what `rotate-music-login --ask` produces) and leaves that one in place --
    it was created by hand and re-creating it is not automatable.

    Returns (headers, source).
    """
    path = auth_file_path()

    # Stash any hand-made file first; the extension write would replace it.
    existing = read_headers(path)
    if existing is not None and not validate(existing)[0]:
        existing = None
    before = os.path.getmtime(path) if os.path.exists(path) else 0

    if host_registered():
        if not quiet:
            print("Authenticating with YouTube Music...")
        subprocess.run(["open", "-g", "-a", "Google Chrome", WAKE_URL], check=False)

        deadline = time.time() + timeout
        while time.time() < deadline:
            if os.path.exists(path) and os.path.getmtime(path) > before:
                headers = read_headers(path)
                # We caused this write, so consume it. Deleting before the first
                # API call is the whole point -- do not "optimise" this into a
                # cache.
                try:
                    os.unlink(path)
                except OSError:
                    pass
                ok, why = validate(headers)
                if not ok:
                    raise AuthError(f"the extension wrote unusable headers: {why}")
                return headers, "extension"
            time.sleep(0.5)

    if existing is not None:
        return existing, f"existing {path} (left in place)"

    raise AuthError(
        "could not obtain YouTube Music auth.\n"
        + (
            ""
            if host_registered()
            else "The native host is not registered. Run: rotate-music-login --install\n"
        )
        + "Check the extension is loaded at chrome://extensions and that you are\n"
        "signed in to YouTube Music, or fall back to: rotate-music-login --ask"
    )


def parse_curl(curl):
    """Pull the headers out of a 'Copy as cURL' command.

    shlex understands the quoting cURL emits, so this replaces the hand-rolled
    quote/continuation state machine the Perl version needed. Chrome splits long
    commands with backslash-newline, which shlex would otherwise choke on.
    """
    headers = {}
    expect = None
    for token in shlex.split(curl.replace("\\\n", " ")):
        if token in ("-H", "--header"):
            expect = "header"
        elif token in ("-b", "--cookie"):
            expect = "cookie"
        elif expect == "header":
            key, _, value = token.partition(":")
            key = key.strip().lower()
            # Skip HTTP/2 pseudo-headers (:authority, :method, ...).
            if key and value.strip():
                headers[key] = value.strip()
            expect = None
        elif expect == "cookie":
            headers["cookie"] = token
            expect = None
    return headers


def write_headers(path, headers):
    """Write headers for the manual --ask fallback, at 0600.

    O_NOFOLLOW refuses to write the jar through a pre-planted symlink. The
    explicit fchmod matters because os.open's mode argument applies only when the
    file is *created* -- an existing 0644 file (the old Perl version wrote one,
    and ~/.dotfiles.bak can restore one) would otherwise stay world-readable.
    """
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    os.fchmod(fd, 0o600)
    with open(fd, "w") as fh:
        json.dump(headers, fh, indent=4, sort_keys=True)
        fh.write("\n")

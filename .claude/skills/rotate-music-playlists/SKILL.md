---
name: rotate-music-playlists
description: Rotate both real YouTube Music playlists (coder-mix and heavy-rock) with bin/rotate-music, which authenticates itself through the Chrome extension on each run. Reports the tracks that moved in and out of each mix. Run as part of maintenance-weekly.
---

# Rotate music playlists

`bin/rotate-music <rotation>` swaps tracks between a mix and its rotation
playlist on YouTube Music: it moves some tracks out of the active playlist into
the rotation pool and pulls an equal number back in, keeping favorited ("best")
and regular tracks in their configured proportions. The rotations live in
`rotate-music.yaml` (symlinked to `~/.rotate-music.yaml` by `install.sh`).

This skill runs it for the **two real mixes**. `test-mix` is a fixture for
exercising the pipeline against throwaway playlists — leave it out of the sweep.

## Steps

1. **Run the coder mix**, from anywhere (`bin/` is on `$PATH` as `~/bin`):

   ```sh
   rotate-music coder-mix
   ```

   Capture its output. It prints the tracks it moved out ("Moving out of
   rotation:") and back in ("Moving into rotation:"), with `-` marking regular
   tracks and `*` marking favorited ones, under a header giving the playlist
   size, its maximum, and the counts each way. **Those counts are often
   unequal, and that is correct** — the outgoing side also carries whatever the
   mix is over `playlist_max`, trimming it back to 200. Report the asymmetry as
   the trim it is; don't chase it as a bug.

2. **Run the heavy rock mix** the same way, but only if step 1 succeeded — see
   the auth note below:

   ```sh
   rotate-music heavy-rock
   ```

3. **Report** per mix: the tracks that moved out and in, or the failure. Nothing
   here touches the repository, so there is **nothing to commit**.

## Notes

- **Never re-run a rotation that already succeeded.** Rotation is a mutation, not
  a convergence — a second run rotates a second batch of tracks out of the mix.
  If a run fails *after* printing "Moving out of rotation:", it may have already
  moved tracks; report that partial state and let the user decide, rather than
  retrying.

- **Each run authenticates on its own**, and that is deliberate: `acquire()` wakes
  the Chrome extension, reads the credential the native host writes, and unlinks
  it before the first API call. Don't try to make the two runs share one auth —
  see the "YouTube Music rotation auth" section of `CLAUDE.md`.

- **Auth needs Chrome, signed in to YouTube Music.** `acquire()` backgrounds an
  `open -g -a "Google Chrome"` against a wake URL and waits up to 30s for the
  native host to deliver. On a machine where Chrome is absent, signed out, or the
  extension isn't loaded, the run exits with an `AuthError` message. That failure
  is environmental and identical for both mixes, so **stop after the first one** —
  don't run heavy-rock just to collect the same error twice. Report it and suggest
  `rotate-music-login` to diagnose the pipeline end to end.

- **Adding a mix**: if a real rotation is added to `rotate-music.yaml`, add a step
  for it here. The rotation names are the keys under `rotations:`.

---
name: maintenance-weekly
description: Weekly maintenance for the dotfiles repo. Discovered by zed:maintenance as a maintenance-<tag> skill, so /zed:maintenance weekly runs it. Refreshes the model context-window table that bin/sessions depends on, and rotates the YouTube Music playlists.
---

# Weekly maintenance (dotfiles)

Recurring upkeep for this repository, run as part of the weekly maintenance
sweep. Named with the `maintenance-<tag>` convention so `/zed:maintenance weekly`
discovers and runs it.

## Steps

1. **Refresh the model context-window table.** Invoke the
   `refresh-model-context-windows` skill and let it run to completion. It pulls
   the latest Claude model context windows from Anthropic's public docs and
   updates `sessions/models.json` (committing only if the data changed). This
   keeps the `N/M` CONTEXT column in `bin/sessions` accurate as Anthropic ships
   or retires models.

2. **Rotate the music playlists.** Invoke the `rotate-music-playlists` skill
   and let it run to completion. It runs `bin/rotate-music` for both real mixes
   (`coder-mix`, `heavy-rock`), swapping tracks between each mix and its rotation
   pool. It changes nothing in this repo — the output is the report.

   This step depends on Chrome being signed in to YouTube Music (the credential
   comes from the extension on each run). If auth fails, that's environmental:
   record it and carry on with the sweep rather than treating it as a repo
   problem.

3. **Report** what the run did — whether the model table changed and, if so, how,
   plus which tracks rotated in and out of each mix.

## Project-specific

Add further weekly chores here as they come up (cache pruning, branch cleanup,
etc.). Keep each as a concrete, ordered step so the sweep stays non-interactive.

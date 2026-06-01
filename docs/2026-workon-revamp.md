# Revamping and Evolving `workon` and My Daily Project Tooling

I want to re-envision how I manage my project tabs. I currently use a
combination of kitty tabs and tmux sessions to manage my work. This is how I've
worked for the last several years, but with the drastic change in my work style
over the past few months by incorporating vibe coding tools, I need to revamp
this setup. I found a tool called recon, which will feature heavily into this.

I am going to start by describing my current setup and it's history, describe
what recon adds to the mix, describe what I want to be able to do moving
forward, and then I want to plan a way to evolve/revamp my system for the next
iteration.

## History

I come from a Unix background and have always been more comfortable in the
Terminal than anywhere else. I started using DOS in 80s and was never really
comfortable in Windows. I started using Linux in the 90s, mostly without
XWindows or in xterms and started using screen early on. I have a background in
systems administration, so I prefer vi and vim over any other editor and
eschewed IDEs until the past three or four years. I use the vim plugin for
IntelliJ IDEA for most of my editing tasks now, but I still prefer vim itself
as an editor. 

In the early 2000s, I switched to OS X laptops as my daily desktop environment,
primarily for reliability. I still leaned heavily into using Terminal, first via
Terminal.app, then iTerm2, and, most recently, Kitty Terminal for the buttery
smooth graphic accelerated UI. I migrated from screen to tmux at some point and
now depend on that.

I spent my early career as a Java/PHP developer, moved to Perl and did that for
almost 20 years, and then, more recently, become mostly a Go+TypeScript
developer. In the past year, I've also spent a lot of time vibe coding, so I do
whatever I need to, Python, TypeScript, Go, etc., much more language agnostic,
more interested in whatever is best for the problem at hand. But I prefer Go at
this point for most of my solutions. I also, obviously, am a heavy user of shell
scripts, with a strong preference for Zsh, when I control the environment, or
just generic sh when I don't.

Since switching to iTerm2, I developed my little workon script based on how I
worked at $job-5, where I often had several tickets in flight across several
projects. I create a new tab in the terminal and then ran 

```
workon base-dir/project
```

This automatically locates the project I want and then creates a new tmux
session with several standard panes. At $job-5, this included a shell, a vim
editor, a second shell where I would run the dev server locally, and then a
final terminal that would tail and colorize the logs. Over time, this pared down
to just a bash terminal and then a vim editor. And then, last month, I decided I
rarely use the vim editor anymore and it was becoming a problem, so I switch to
a single pane with a terminal on the left side and a Claude Code session on the
right. This is working extremely well now.

In the past, I almost never had more than one change set in flight per project.
For those times when I did, I would just have two (or very rarely three) local
clones of the project and I would use the workon command to select
project, project2, or project3 to pick where I worked. This was before worktrees
(or at least before I knew of worktrees).

## Recon

Prior to vibe coding, I could only work on one thing at a time. However, with
vibe coding, I might now have several tasks I'm working on in parallel by having
an agent working on each thing with me monitoring and switching between tasks
quickly. This creates a problem where I spend a lot of time flipping between
screens to see what is happening. For example, sometimes, I want to monitor a particular
task because I care about how the agent works or want to make sure I understand
what it is working on. But I also want to make sure other tasks keep working, so
I have to flip away periodically to see if they still are, but this takes me
away from the task I want to focus on. 

Recon gives me a way to see what is running in Claude Code at a glance. This is
perfect for solving the monitoring problem.

Recon is not perfect, though, but it is move in the right direction. The thing
that is imperfect at this point is that while recon will provide a nice list of
what is running, if I use it to jump to a session that needs input or that I
want to monitor next, it replaces my kitty tab with the tmux session that has
that Claude session in it and it exits recon. The first can be solved by
changing the way I manage my tabs and tmux sessions. The second is not as nice,
but probably just involves running recon in a shell loop to restart it each time
it stops.

In addition, though, it plays nicely with tmux and I would like to incorporate
some of the bindings the author suggests like being able to jump to the next
agent that needs input using a tmux keybinding and such. But I am getting a
little ahead of myself.

One thing recon does not support, but I would support for, is incorporating
Codex as well as Claude. This is out of scope for now, but I like to use Codex
for some tasks, especially code reviews, goal-oriented work like ETL, and some
other things and recon does not, as far as I know, work with anything but
Claude. This is out of scope for now, but something I want consideration for.

## What I Want

I need the following requirements to be met in the new system:

* Non-Goal: I do not care if we keep using Kitty tabs or multiple tmux sessions.
  Nothing of this level of detail needs to be preserved.

* I want to keep using my workon command to start work. I would actually prefer
  not to have to create a new tab in Kitty each time to do this. If I run
  workon, I would like it to start the new work.

* I want something like the tab bar that Kitty puts across the bottom of my
  terminal to still exist. I need to be able to see, at a glance all the things
  I'm working on. I would like for these "tabs" or whatever to be named like
  `<project>-<work>` where `<project>` is the name of the directory of the
  project (almost always a directory with a git repository) and `<work>` can be
  a single word name for the work tree (for the first work done on a project,
  which will probably be the most important we can just use a generic word like
  "prime"). This "tab" view should highlight whichever work session is current.
  This tab view should always be visible at the bottom. Bonus points if the tabs
  are clickable with the mouse to switch sessions.

* I want each work session to start as a split screen like I use now. Claude on
  the right and a shell on the left. I might split or modify this panel setup or
  start vim or whatever, but this is the initial setup for each work "session"
  (where session doesn't necessarily mean a tmux session).

* I want to modify the way Claude is started in it's panel to allow me to /exit
  without closing that panel entirely. Instead, it should show a menu allowing
  me to start Claude again, start Codex, start a shell, close the session. In 
  fact, I want this for the Shell panel as well. I want to preserve the two
  panel split in each session.

* I want a third panel on the bottom 10 lines of the left side of the split
  panel (i.e., taking up space that would otherwise belong to bash by default)
  to show recon. If recon quits, I want it to restart in that panel, without
  closing the panel.

## The Work

Those are my basic requirements. Plan a solution that will achieve these goals
using best in class tools and configuration with tmux as the centerpiece.

## What Was Built

The plan above became the `workon` system now living in `bin/`. Day-to-day usage
and the full file inventory are in the repo README's "`workon`: per-project tmux
layouts" section; this is the requirement-by-requirement record of how the vision
was realized — and where it diverged.

| Requirement (above) | How it was realized |
|---|---|
| Keep `workon`; don't require a new tab | `bin/workon` creates a *detached* tmux session and `switch-client`s the current client to it, so running `workon` from inside tmux swaps the view in place — no new Kitty tab. |
| A persistent "tab bar" of all work, current one highlighted, clickable | The tmux `status-left` renders one clickable label per session via `bin/work-status`; the current session is highlighted, and `MouseDown1Status` → `bin/work-switch` jumps by index. `Alt-Left`/`Alt-Right` cycle sessions without the prefix. |
| `<project>-<work>` naming; "prime" for the first/most-important work | `workon -w <work>` names the session `<project>-<work>`; the default `prime` stays bare (`<project>`). |
| Split screen: Claude right, shell left | `bin/add-claude` builds it: shell left-top, claude on the right at full height. |
| `/exit` Claude (and the shell) without closing the pane; menu to relaunch claude/codex/shell or close | `bin/work-supervisor` wraps both panes and shows the in-pane menu on exit; `[x]` closes the whole session. |
| Third panel on the bottom-left running the monitor, auto-restarting | `bin/add-claude` adds a ~20% bottom-left pane running `bin/sessions-loop`, which restarts the monitor forever. |
| (Beyond the original ask) Per-session environment | The `.workon.env` / `.workon.local.env` cascade (`bin/workon-env`) seeds the session environment so every pane inherits it. |

### Where it diverged from the plan

- **recon → a unified `sessions` monitor.** The plan leaned on
  [recon](https://github.com/gavraz/recon) as the dashboard. recon's limitation
  (jumping to a session exits recon and replaces the tab) and its Claude-only
  scope pushed the design to `bin/sessions`, a custom Python TUI that *uses*
  `recon json` as its Claude data source but adds: live Codex sessions (via the
  Codex SQLite state + a ppid walk over tmux panes), an alphabetized list
  color-coded by source, a starred current session, a red "waiting for input"
  status, mouse hover/click, and in-pane navigation (`j`/`k`/`Enter`/`n`) that
  switches the client without tearing the pane down. recon is still installed and
  still backs the `prefix g` popup and `prefix i` next-agent jump.
- **Codex is in, not deferred.** The plan listed Codex support as out-of-scope;
  the monitor and the supervisor menu both handle it now.
- **Worktree integration (new).** `workon -w` creates a git worktree at
  `<project>-worktrees/<work>` and anchors Claude there via the `WorktreeCreate`
  hook (`bin/work-worktree-hook`), so a worktree session isn't filed back under
  the main checkout.
- **Clean teardown.** `detach-on-destroy off` plus a `session-closed` hook means
  closing the last session kills the tmux server so the next `workon` cold-starts;
  closing one of several drops the client into another live session.

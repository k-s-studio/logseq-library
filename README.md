# libseq

A single Git repository that keeps **all my Logseq graphs** in sync across every
device through **one GitHub remote** — clone once, run one command, edit in
Logseq, and every commit auto-syncs to the cloud.

## How it works (the short version)

Logseq's auto-commit only works if it finds a `.git` (folder, or a
separate-git-dir pointer file) **inside the graph folder**. But Git treats any
folder containing `.git` as its own repository boundary — so the graphs can't be
plain subfolders of one flat repo.

The way to get *both* "one remote" *and* "a `.git` in every graph folder" is
**Git worktrees**:

- **one** repository, **one** remote;
- `main` holds the tooling (this README, `sys/`, `git-hooks/`, `.libexclude`);
- each graph is its **own branch** under `graphs/*`, checked out as a **worktree**
  into a sibling folder. **Branches are the single source of truth** — there is
  no manifest. The folder name is just the branch with the `graphs/` prefix
  removed (`graphs/MyGraphA` → `./MyGraphA`). Each worktree folder automatically
  has a `.git` pointer file → Logseq's auto-commit is happy, and editing one
  graph only commits that graph.

```
libseq/                        ← main worktree (branch: main), origin = GitHub
├─ .git/                       ← the one object store + shared hooks
├─ .gitignore                  ← ignores the graph worktree folders
├─ .libexclude                 ← graphs to NOT check out (opt-out list)
├─ libseq.bat                  ← Windows entry point (boot / add)
├─ sys/                        ← all the helper scripts
│  ├─ bootstrap.sh             ←   new-device setup
│  ├─ add-graph.sh             ←   create a new graph
│  └─ pull-graph.sh / push-graph.sh  ← Termux (Android) sync
├─ git-hooks/                  ← pre-commit (pull) + post-commit (push), shared
├─ MyGraphA/   ← worktree, branch graphs/MyGraphA, .git pointer → open this in Logseq
└─ MyGraphB/   ← worktree, branch graphs/MyGraphB
```

Why each requirement is met:

| Requirement | How |
|---|---|
| One GitHub remote, pull/edit/push everywhere | One repo; graphs are branches on the same remote |
| All graphs present at once (no branch switching) | Worktrees check out every graph side by side |
| Logseq auto-commit per graph | Each worktree folder has a `.git` pointer; commits are isolated to that branch |
| Graph commit triggers cloud sync | Shared `post-commit` hook runs `git push origin HEAD` (the graph's branch) |
| New device = pull + one command | `git clone` then `libseq boot` |

## Commands

On Windows everything goes through `libseq.bat` (put the repo folder on your PATH,
or call `.\libseq` from inside it). On macOS/Linux/Termux call the scripts in
`sys/` directly.

| Action | Windows | sh |
|---|---|---|
| Set up this device | `libseq boot` | `sh sys/bootstrap.sh` |
| Create a new graph | `libseq add MyGraphC` | `sh sys/add-graph.sh MyGraphC` |

## First-time setup on a new device

```sh
git clone <repo-url> libseq
cd libseq
libseq boot          # wires up hooks + checks out a worktree per graphs/* branch
```

Then open each graph **folder** in Logseq. From now on, every Logseq auto-commit
pulls first (`pre-commit`) and pushes after (`post-commit`).

> Credentials: the hooks never prompt (they set `GIT_TERMINAL_PROMPT=0`). Set up
> SSH keys or a credential helper once per device so pull/push are non-interactive.

## Adding a new graph

```sh
libseq add MyGraphC
```

Creates the `graphs/MyGraphC` branch (with the union-merge `.gitattributes`
seeded), pushes it to the same remote, checks out the worktree, and ignores the
folder on `main`. On your other devices, `git pull` on `main` then `libseq boot`
to check it out.

## Skipping graphs on a device (`.libexclude`)

Every `graphs/*` branch is expanded by default. To keep a graph from being
checked out on a particular device (a template, an archive, or just something
you don't need there), add its name to `.libexclude`, one per line:

```
_sample
```

## Android (Termux)

Logseq for Android can't run git/hooks, so clone the repo in Termux, run
`sh sys/bootstrap.sh`, and use the Termux:Widget scripts (set `LIBRARY_DIR` if
your clone isn't at `storage/documents/libseq`):

- `sys/pull-graph.sh` — pull every graph before editing
- `sys/push-graph.sh` — commit + push every graph after editing

## Concurrent edits

`.gitattributes` uses `merge=union` for `*.md` / `*.org`, so simultaneous edits
on two devices are concatenated instead of producing conflict markers (it keeps
both sides — occasionally you'll tidy a duplicate line). Each graph branch is
seeded with the same policy by `libseq add`. Binaries/assets are deliberately
left out of union merge.

## Future Plans
- add .exe to make all ops available by double-click on all platforms
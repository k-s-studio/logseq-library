# libseq

A single Git repository that keeps **all my Logseq graphs** in sync across every
device through **one GitHub remote** — clone once, run one command, edit in
Logseq, and every commit auto-syncs to the cloud.

## How it works (the short version)

Logseq's auto-commit needs a `.git` **inside the graph folder**. Two kinds exist
and Logseq treats them very differently:

- a **real `.git` directory** → Logseq reuses it as-is. ✅
- a separate-git-dir **`.git` pointer file** → Logseq *rewrites/relocates* it to
  its own `~/.logseq/git/...` location. With shared-store layouts (git worktrees)
  this chains pointers across graphs and eventually corrupts the library repo. ❌

So each graph folder must carry a **real `.git` directory**. The way to get that
*and* keep "one remote" is **submodules (form 1: one remote, branch == graph)**:

- **one** repository, **one** remote;
- `main` holds the tooling (this README, `sys/`, `.libexclude`, `libseq.bat`);
- each graph lives on its **own branch** under `graphs/*` in the same repo, and
  its folder is an **independent clone** of that branch — so it has a real `.git`
  directory (Logseq-safe) and its own isolated object store (Logseq tampering
  with one graph can never reach the library repo);
- the library records each graph as a **true submodule** (`.gitmodules` +
  gitlink), so `main` tracks every graph. The folder name is the branch minus the
  `graphs/` prefix (`graphs/MyGraphA` → `./MyGraphA`).

```
libseq/                        ← superproject (branch: main), origin = GitHub
├─ .git/                       ← real .git dir (its own object store)
├─ .gitmodules                 ← registry: one submodule per graph
├─ .gitignore                  ← whitelist: main tracks only the tooling
├─ .libexclude                 ← graphs to NOT check out on this device
├─ libseq.bat                  ← Windows entry point (boot / add)
├─ sys/                        ← all the tooling
│  ├─ bootstrap.sh             ←   new-device setup (clones each graph)
│  ├─ add-graph.sh             ←   create a new graph
│  ├─ register-submodule.sh    ←   record a graph in .gitmodules
│  ├─ git-hooks/               ←   pre-commit (pull) + post-commit (push)
│  └─ Android-scripts/         ←   pull-graph.sh / push-graph.sh (Termux sync)
├─ MyGraphA/   ← submodule clone, real .git dir, branch graphs/MyGraphA → open in Logseq
└─ MyGraphB/   ← submodule clone, real .git dir, branch graphs/MyGraphB
```

Why each requirement is met:

| Requirement | How |
|---|---|
| One GitHub remote, pull/edit/push everywhere | One repo; graphs are branches on the same remote |
| All graphs present at once (no branch switching) | Each graph is cloned into its own folder, side by side |
| Logseq auto-commit per graph | Each folder has a **real `.git` dir** Logseq reuses; commits stay on that branch |
| Graph commit triggers cloud sync | Per-graph `post-commit` hook runs `git push origin HEAD` (the graph's branch) |
| Library tracks every graph | Each graph is a true submodule (`.gitmodules` + gitlink) |
| New device = pull + one command | `git clone` then `libseq boot` (clones each graph) |

> **Why not `git submodule update`?** That absorbs the submodule's git dir into
> `.git/modules/<name>` and leaves a **pointer file** in the folder — exactly the
> thing Logseq rewrites. `libseq boot` clones each graph directly so the folder
> keeps a real `.git` directory.

## Commands

On Windows everything goes through `libseq.bat` (put the repo folder on your PATH,
or call `.\libseq` from inside it). On macOS/Linux/Termux call the scripts in
`sys/` directly.

| Action | Windows | sh |
|---|---|---|
| Set up this device | `libseq boot` | `sh sys/bootstrap.sh` |
| Create a new graph | `libseq add MyGraphC` | `sh sys/add-graph.sh MyGraphC` |
| Remove a graph | `libseq remove MyGraphC` | `sh sys/remove-graph.sh MyGraphC` |

## First-time setup on a new device

```sh
git clone <repo-url> libseq
cd libseq
libseq boot          # clones each registered graph (real .git dir) + wires hooks
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
seeded), pushes it to the same remote, clones it into `./MyGraphC` as a real-`.git`
submodule, and records it in `.gitmodules` on `main`. On your other devices,
`git pull` on `main` then `libseq boot` to clone it.

## Removing a graph

```sh
libseq remove MyGraphC        # add -y to skip the confirmation prompt
```

On this device it deletes the `./MyGraphC` folder, unregisters the submodule
(gitlink + `.gitmodules` + local config), commits and pushes `main`, and deletes
the remote branch `graphs/MyGraphC` (the irreversible step — you confirm by
retyping the name). It then prints the cleanup to run on your **other devices**:

```sh
cd <libseq>
git pull
rm -rf MyGraphC
git config --remove-section submodule.MyGraphC 2>/dev/null || true
```

A plain `git pull` can't delete an already-cloned folder, so that `rm -rf` is
required per device. Also remove the graph from Logseq's UI so it stops
referencing the old path.

## Skipping graphs on a device (`.libexclude`)

Every graph in `.gitmodules` is cloned by default. To keep a graph from being
checked out on a particular device (a template, an archive, or just something
you don't need there), add its name to `.libexclude`, one per line:

```
Archive
```

## Android (Termux)

Logseq for Android can't run git/hooks, so clone the repo in Termux, run
`sh sys/bootstrap.sh`, and use the Termux:Widget scripts (set `LIBRARY_DIR` if
your clone isn't at `storage/documents/libseq`):

- `sys/Android-scripts/pull-graph.sh` — pull every graph before editing
- `sys/Android-scripts/push-graph.sh` — commit + push every graph after editing

## Concurrent edits

`.gitattributes` uses `merge=union` for `*.md` / `*.org`, so simultaneous edits
on two devices are concatenated instead of producing conflict markers (it keeps
both sides — occasionally you'll tidy a duplicate line). Each graph branch is
seeded with the same policy by `libseq add`. Binaries/assets are deliberately
left out of union merge.

## Future Plans
- add .exe to make all ops available by double-click on all platforms
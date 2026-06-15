# libseq

A single Git repository that keeps **all my Logseq graphs** in sync across every
device through **one GitHub remote** — clone once, run one command, edit in
Logseq, and every commit auto-syncs to the cloud.

## How it works (the short version)

Logseq's auto-commit needs a `.git` **inside the graph folder**. Two kinds exist
and Logseq treats them very differently:

- a **real `.git` directory** → Logseq reuses it as-is. ✅
- a separate-git-dir **`.git` pointer file** → Logseq *rewrites/relocates* it to
  its own `~/.logseq/git/...` location. With shared-store layouts (git worktrees
  or absorbed submodules) this chains pointers across graphs and eventually
  corrupts the library repo. ❌

So each graph folder must carry a **real `.git` directory**. The way to get that
*and* keep "one remote" is **clone-and-ignore (branch == graph)**:

- **one** repository, **one** remote;
- `main` holds the tooling (this README, `sys/`, `.libexclude`, `libseq.bat`);
- each graph lives on its **own branch** under `graphs/*` in the same repo, and
  its folder is an **independent clone** of that branch — so it has a real `.git`
  directory (Logseq-safe) and its own isolated object store (Logseq tampering
  with one graph can never reach the library repo);
- the set of **`graphs/*` branches on the remote is the registry** — there's no
  `.gitmodules` and `main` records nothing about the graphs. The graph folders are
  simply ignored by `main`'s whitelist `.gitignore`. The folder name is the branch
  minus the `graphs/` prefix (`graphs/MyGraphA` → `./MyGraphA`).

```
libseq/                        ← library repo (branch: main), origin = GitHub
├─ .git/                       ← real .git dir (its own object store)
├─ .gitignore                  ← whitelist: main tracks only the tooling
├─ .libexclude                 ← graphs to NOT check out on this device
├─ libseq.bat                  ← Windows entry point (boot / add / remove / clean)
├─ sys/                        ← all the tooling
│  ├─ bootstrap.sh             ←   new-device setup (clones each graphs/* branch)
│  ├─ add-graph.sh             ←   create a new graph
│  ├─ remove-graph.sh          ←   remove a graph (folder + remote branch)
│  ├─ clean.sh                 ←   drop local graphs whose branch is gone
│  ├─ git-hooks/               ←   pre-commit (pull) + post-commit (push)
│  └─ Android-scripts/         ←   pull-graph.sh / push-graph.sh (Termux sync)
├─ MyGraphA/   ← independent clone, real .git dir, branch graphs/MyGraphA → open in Logseq
└─ MyGraphB/   ← independent clone, real .git dir, branch graphs/MyGraphB
```

Why each requirement is met:

| Requirement | How |
|---|---|
| One GitHub remote, pull/edit/push everywhere | One repo; graphs are branches on the same remote |
| All graphs present at once (no branch switching) | Each graph is cloned into its own folder, side by side |
| Logseq auto-commit per graph | Each folder has a **real `.git` dir** Logseq reuses; commits stay on that branch |
| Graph commit triggers cloud sync | Per-graph `post-commit` hook runs `git push origin HEAD` (the graph's branch) |
| Library knows every graph | The `graphs/*` branches on the remote are the registry |
| New device = clone + one command | `git clone` then `libseq boot` (clones each `graphs/*` branch) |

> **Why not submodules / `git submodule update`?** A real submodule pins a commit
> via a gitlink and, on update, absorbs the graph's git dir into
> `.git/modules/<name>`, leaving a **pointer file** Logseq rewrites. Since each
> graph is cloned independently at branch HEAD anyway, that gitlink is pure
> overhead — the `graphs/*` branches are already the source of truth. `libseq boot`
> just clones each branch, so the folder keeps a real `.git` directory.

## Commands

On Windows everything goes through `libseq.bat` (put the repo folder on your PATH,
or call `.\libseq` from inside it). On macOS/Linux/Termux call the scripts in
`sys/` directly.

| Action | Windows | sh |
|---|---|---|
| Set up this device | `libseq boot` | `sh sys/bootstrap.sh` |
| Create a new graph | `libseq add MyGraphC` | `sh sys/add-graph.sh MyGraphC` |
| Remove a graph | `libseq remove MyGraphC` | `sh sys/remove-graph.sh MyGraphC` |
| Drop graphs whose branch is gone | `libseq clean` | `sh sys/clean.sh` |

## First-time setup on a new device

```sh
git clone <repo-url> libseq
cd libseq
libseq boot          # clones each graphs/* branch (real .git dir) + wires hooks
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
seeded), pushes it to the same remote, and clones it into `./MyGraphC` with a real
`.git` dir. Nothing is committed to `main` — the branch *is* the record. On your
other devices, run `libseq boot` to clone it.

## Removing a graph

```sh
libseq remove MyGraphC        # add -y to skip the confirmation prompt
```

On this device it deletes the `./MyGraphC` folder and deletes the remote branch
`graphs/MyGraphC` (the irreversible step — you confirm by retyping the name).
`main` records nothing about graphs, so there's no superproject commit. It then
prints the cleanup to run on your **other devices**:

```sh
cd <libseq>
libseq clean        # deletes local graph folders whose branch is gone
```

`libseq clean` removes any local graph clone whose `graphs/*` branch no longer
exists on the remote. Also remove the graph from Logseq's UI so it stops
referencing the old path.

## Skipping graphs on a device (`.libexclude`)

Every `graphs/*` branch is cloned by default. To keep a graph from being checked
out on a particular device (a template, an archive, or just something you don't
need there), add its name to `.libexclude`, one per line:

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
# logseq-library

A single Git repository that keeps **all my Logseq graphs** in sync across every
device through **one GitHub remote** — clone once, run one script, edit in Logseq,
and every commit auto-syncs to the cloud.

## How it works (the short version)

Logseq's auto-commit only works if it finds a `.git` (folder, or a
separate-git-dir pointer file) **inside the graph folder**. But Git treats any
folder containing `.git` as its own repository boundary — so the graphs can't be
plain subfolders of one flat repo.

The way to get *both* "one remote" *and* "a `.git` in every graph folder" is
**Git worktrees**:

- **one** repository, **one** remote;
- `main` holds the tooling (this README, `git-hooks/`, `Android-scripts/`,
  `graphs.txt`, the scripts);
- each graph is its **own branch** (`graphs/<Name>`) checked out as a **worktree**
  into a sibling folder. Each worktree folder automatically has a `.git` pointer
  file → Logseq's auto-commit is happy, and each graph stays isolated (editing
  one graph only commits that graph).

```
logseq-library/                ← main worktree (branch: main), origin = GitHub
├─ .git/                       ← the one object store + shared hooks
├─ .gitignore                  ← ignores the graph worktree folders
├─ graphs.txt                  ← manifest: <folder> <branch>  (committed on main)
├─ bootstrap.sh                ← new-device, one-shot setup
├─ add-graph.sh                ← create a new graph
├─ git-hooks/                  ← pre-commit (pull) + post-commit (push), shared
├─ Android-scripts/            ← Termux pull/push for Android (no git there)
├─ MyGraphA/   ← worktree, branch graphs/MyGraphA, .git pointer → Logseq opens this
└─ MyGraphB/   ← worktree, branch graphs/MyGraphB
```

Why each requirement is met:

| Requirement | How |
|---|---|
| One GitHub remote, pull/edit/push everywhere | One repo; graphs are branches on the same remote |
| All graphs present at once (no branch switching) | Worktrees check out every graph side by side |
| Logseq auto-commit per graph | Each worktree folder has a `.git` pointer; commits are isolated to that branch |
| Graph commit triggers cloud sync | Shared `post-commit` hook runs `git push origin HEAD` (the graph's branch) |
| New device = pull + one script | `git clone` then `./bootstrap.sh` |

## First-time setup on a new device

```sh
git clone <repo-url> logseq-library
cd logseq-library
./bootstrap.sh          # wires up hooks + checks out a worktree per graph
```

Then open each graph **folder** in Logseq. From now on, every Logseq auto-commit
pulls first (`pre-commit`) and pushes after (`post-commit`).

> Credentials: the hooks never prompt (they set `GIT_TERMINAL_PROMPT=0`). Set up
> SSH keys or a credential helper once per device so pull/push are non-interactive.

## Adding a new graph

```sh
./add-graph.sh MyGraphC
```

This creates the `graphs/MyGraphC` branch (with the union-merge `.gitattributes`
seeded), pushes it to the same remote, adds the worktree, and records it in
`graphs.txt` + `.gitignore` on `main`. On your other devices, just
`git pull` on `main` and re-run `./bootstrap.sh` to check it out.

## Android (Termux)

Logseq for Android can't run git/hooks, so clone the repo in Termux, run
`./bootstrap.sh`, and use the Termux:Widget scripts (set `LIBRARY_DIR` if your
clone isn't at `storage/documents/logseq-library`):

- `Android-scripts/pull-graph.sh` — pull every graph before editing
- `Android-scripts/push-graph.sh` — commit + push every graph after editing

## Concurrent edits

`.gitattributes` uses `merge=union` for `*.md` / `*.org`, so simultaneous edits
on two devices are concatenated instead of producing conflict markers (it keeps
both sides — occasionally you'll tidy a duplicate line). Each graph branch is
seeded with the same policy by `add-graph.sh`. Binaries/assets are deliberately
left out of union merge.

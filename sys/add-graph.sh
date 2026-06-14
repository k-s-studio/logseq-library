#!/bin/sh
#
# add-graph.sh — create a brand-new Logseq graph as its own branch + worktree.
# Invoke via:  libseq add <GraphName>   or   sh sys/add-graph.sh <GraphName>
#
# It creates the graphs/<GraphName> branch (clean orphan history, seeded with
# the union-merge policy), pushes it to the SAME remote, and checks it out as a
# worktree folder. No manifest to maintain — the branch itself is the
# registration, and .gitignore already ignores every non-tooling folder, so the
# worktree stays out of main automatically.
#
# Setup commits bypass the pull/push hooks (-c core.hooksPath=) so first-time
# creation stays clean and predictable.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

name=$1
if [ -z "$name" ]; then
    echo "usage: libseq add <GraphName>" >&2
    exit 1
fi
branch="graphs/$name"
NOHOOK="-c core.hooksPath=/dev/null"

if [ -e "$name" ]; then
    echo "add-graph: '$name' already exists — pick another name." >&2
    exit 1
fi
if git show-ref --verify --quiet "refs/heads/$branch" || \
   git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "add-graph: branch '$branch' already exists. Run 'libseq boot' to check it out." >&2
    exit 1
fi

# Make sure hooks are wired up for everyday use even if boot wasn't run yet.
git config core.hooksPath "$REPO_ROOT/sys/git-hooks"

# 1. Orphan branch with a clean tree, seeded with the union-merge policy so
#    concurrent edits on two devices concatenate instead of conflicting.
git worktree add --detach "$name"
git -C "$name" checkout --orphan "$branch"
git -C "$name" rm -rf --quiet . 2>/dev/null || true
{
    echo '# Concatenate concurrent edits to notes instead of conflicting.'
    echo '*.md  merge=union'
    echo '*.org merge=union'
} > "$name/.gitattributes"
git -C "$name" add .gitattributes
git -C "$name" $NOHOOK commit -m "init graph $name"

# 2. Push to the same remote; set upstream so future pull/push just work.
git -C "$name" push -u origin "$branch"

# The worktree folder needs no .gitignore entry — main's whitelist .gitignore
# ignores every non-tooling folder already.

echo "add-graph: '$name' is ready. Open it in Logseq; commits will auto-sync."

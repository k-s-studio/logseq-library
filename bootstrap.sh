#!/bin/sh
#
# bootstrap.sh — run ONCE on each new device, right after cloning logseq-library.
#
#   git clone <repo-url> logseq-library
#   cd logseq-library
#   ./bootstrap.sh
#
# It does two things:
#   1. Points git at the shared hooks (git-hooks/) so every graph auto-pulls
#      before a commit and auto-pushes after — for ALL worktrees at once
#      (core.hooksPath lives in the shared .git/config).
#   2. Recreates one worktree per graph listed in graphs.txt, so all your
#      graphs are checked out side by side and ready to open in Logseq. Each
#      worktree folder gets a `.git` pointer file, which is exactly what
#      Logseq's auto-commit looks for.
#
# Safe to re-run: already-set-up graphs are skipped.

set -e

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$REPO_ROOT"

if [ ! -f graphs.txt ]; then
    echo "bootstrap: graphs.txt not found in $REPO_ROOT — are you in the repo root?" >&2
    exit 1
fi

# 1. Shared hooks for every worktree. Absolute path so it resolves no matter
#    which graph folder git is invoked from. It's device-local (not pushed),
#    which is fine — every device runs this script.
git config core.hooksPath "$REPO_ROOT/git-hooks"
echo "bootstrap: hooks enabled (core.hooksPath -> git-hooks)."

# 2. Make sure we know about every remote branch, then materialise worktrees.
git fetch origin --prune

while read -r folder branch _; do
    # skip blanks and comments
    case "$folder" in '' | \#*) continue ;; esac
    [ -n "$branch" ] || { echo "bootstrap: '$folder' has no branch in graphs.txt, skipping." >&2; continue; }

    if [ -e "$folder/.git" ]; then
        echo "bootstrap: '$folder' already set up, skipping."
        continue
    fi

    if [ -e "$folder" ]; then
        echo "bootstrap: '$folder' exists but is not a worktree — move it aside first. Skipping." >&2
        continue
    fi

    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        # DWIM: creates a local branch tracking origin/$branch.
        git worktree add "$folder" "$branch"
        echo "bootstrap: checked out '$folder' (branch $branch)."
    else
        echo "bootstrap: branch '$branch' is not on origin yet."
        echo "bootstrap: if this is a brand-new graph, create it with: ./add-graph.sh $folder"
    fi
done < graphs.txt

echo "bootstrap: done. Open the graph folder(s) in Logseq and start editing."

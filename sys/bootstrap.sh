#!/bin/sh
#
# bootstrap.sh — run ONCE on each new device, right after cloning libseq.
# Invoke via:  libseq boot   (Windows)   or   sh sys/bootstrap.sh
#
# Branches are the single source of truth: every branch under graphs/* is a
# graph, and its folder name is the branch with the graphs/ prefix removed
# (graphs/MyGraphA -> ./MyGraphA). The only opt-out is .libexclude, which lists
# graph names that should NOT be expanded into worktrees on this checkout.
#
# What it does:
#   1. Points git at the shared hooks (sys/git-hooks/) for ALL worktrees.
#   2. Checks out one worktree per graphs/* branch (minus .libexclude). Each
#      worktree folder gets a `.git` pointer file — exactly what Logseq's
#      auto-commit looks for — and stays isolated to its own branch.
#
# Safe to re-run: already-checked-out graphs are skipped.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

# 1. Shared hooks for every worktree (absolute path, device-local in .git/config).
git config core.hooksPath "$REPO_ROOT/sys/git-hooks"
echo "bootstrap: hooks enabled (core.hooksPath -> sys/git-hooks)."

# Names listed in .libexclude are not expanded (comments / blanks ignored).
is_excluded() {
    [ -f "$REPO_ROOT/.libexclude" ] || return 1
    grep -v '^[[:space:]]*#' "$REPO_ROOT/.libexclude" \
        | sed 's/[[:space:]]//g' \
        | grep -qx "$1"
}

git fetch origin --prune

found=0
for name in $(git for-each-ref --format='%(refname:lstrip=4)' 'refs/remotes/origin/graphs/*' 2>/dev/null); do
    found=1
    if is_excluded "$name"; then
        echo "bootstrap: '$name' is in .libexclude, skipping."
        continue
    fi

    if [ -e "$name/.git" ]; then
        echo "bootstrap: '$name' already checked out."
    elif [ -e "$name" ]; then
        echo "bootstrap: '$name' exists but isn't a worktree — move it aside first. Skipping." >&2
    else
        git worktree add "$name" "graphs/$name"
        echo "bootstrap: checked out '$name' (branch graphs/$name)."
    fi
done

if [ "$found" -eq 0 ]; then
    echo "bootstrap: no graphs/* branches on origin yet. Create one with: libseq add <Name>"
fi

echo "bootstrap: done. Open the graph folder(s) in Logseq and start editing."

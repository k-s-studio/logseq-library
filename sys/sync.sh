#!/bin/sh
#
# sync.sh — commit every local graph right now (manual flush of all graphs).
# Invoke via:  libseq sync [message]   or   sh sys/sync.sh [message]
#
# Logseq auto-commits a graph while you edit it, but only the graph you have
# open, and only on its own schedule. This walks EVERY local graph clone and
# commits the ones with pending changes immediately — handy before shutting a
# device down, or to force all graphs into sync in one shot.
#
# Each graph folder is an independent clone whose core.hooksPath points at
# sys/git-hooks (wired up by `libseq boot` / `libseq add`). So a plain
# `git commit` here fires the exact same flow Logseq uses:
#   pre-commit  → pull remote changes, then `git add -A`
#   post-commit → push the new commit back to origin
# We don't re-implement pull/push; we just trigger one commit per dirty graph
# and let the shared hooks do the syncing.
#
# Local-only orchestration: it never touches main or any remote branch itself.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

# Optional commit message; default carries a timestamp so the history reads as
# a deliberate manual flush rather than a Logseq auto-commit.
msg=$1
if [ -z "$msg" ]; then
    msg="libseq sync $(date '+%Y-%m-%d %H:%M:%S')"
fi

committed=0
clean=0
failed=0

# A local graph is any top-level folder that is an independent clone checked out
# on a graphs/* branch — same discovery rule as clean.sh, no registry needed.
for d in */; do
    name=${d%/}
    [ -d "$name/.git" ] || continue
    branch=$(git -C "$name" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
    case "$branch" in graphs/*) ;; *) continue ;; esac

    # Nothing pending => leave it alone (the pre-commit pull would just abort the
    # commit with "nothing to commit"). Keep the output quiet for clean graphs.
    if [ -z "$(git -C "$name" status --porcelain 2>/dev/null)" ]; then
        echo "sync: '$name' is clean."
        clean=$((clean + 1))
        continue
    fi

    echo "sync: committing '$name'..."
    # Don't let one graph's failed commit (e.g. a rejected push surfaced by the
    # post-commit hook, or a pull conflict) abort the whole sweep.
    if git -C "$name" commit -m "$msg" >/dev/null 2>&1; then
        echo "sync: '$name' committed and pushed."
        committed=$((committed + 1))
    else
        echo "sync: '$name' commit failed — open a terminal there and run 'git pull' to reconcile." >&2
        failed=$((failed + 1))
    fi
done

echo "sync: done. $committed committed, $clean clean, $failed failed."
[ "$failed" -eq 0 ]

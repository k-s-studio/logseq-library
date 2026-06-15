#!/bin/sh
#
# clean.sh — remove local graph clones whose remote branch no longer exists.
# Invoke via:  libseq clean [-y]   or   sh sys/clean.sh [-y]
#
# When a graph is removed on another device (libseq remove), that device deletes
# the remote branch graphs/<Name>. This device is then left with a stale local
# clone folder. `libseq clean` finds every such orphan — a local graph clone
# whose graphs/* branch is gone from origin — and deletes the folder. Live graphs
# are left untouched.
#
# Local only: it never touches main or any remote branch.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

assume_yes=no
case "$1" in -y | --yes) assume_yes=yes ;; esac

# Refresh remote-tracking refs so the branch-existence check below is accurate.
git fetch origin --prune --quiet 2>/dev/null || true

# A local graph is any top-level folder that is an independent clone checked out
# on a graphs/* branch. That's our candidate set — no registry file needed.
orphans=""
for d in */; do
    name=${d%/}
    [ -d "$name/.git" ] || continue
    branch=$(git -C "$name" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
    case "$branch" in graphs/*) ;; *) continue ;; esac

    # Branch still on origin => live graph, keep it.
    if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        continue
    fi
    orphans="$orphans $name"
done

orphans=$(echo "$orphans" | sed 's/^ *//;s/ *$//')

if [ -z "$orphans" ]; then
    echo "clean: nothing to clean — no local graphs with a missing remote branch."
    exit 0
fi

echo "clean: these graphs have no remote branch and will be removed on this device:"
for name in $orphans; do
    echo "  - ./$name"
done

if [ "$assume_yes" != yes ]; then
    printf "Proceed? [y/N] "
    read -r reply
    case "$reply" in
        y | Y | yes | YES) ;;
        *) echo "clean: aborted." ; exit 1 ;;
    esac
fi

for name in $orphans; do
    if [ -e "$name" ]; then
        rm -rf "$name"
        echo "clean: deleted ./$name"
    fi
done

echo "clean: done."

#!/bin/sh
#
# remove-graph.sh — fully remove a graph from the library.
# Invoke via:  libseq remove <GraphName> [-y]   or   sh sys/remove-graph.sh <GraphName> [-y]
#
# It undoes everything `libseq add` set up, on THIS device:
#   1. deletes the local clone folder ./<Name>
#   2. deletes the remote branch graphs/<Name>
# `main` records nothing about graphs, so there's no superproject commit to make.
# Then prints the cleanup to run on OTHER devices (they still have their own local
# clone, which `libseq clean` removes once the branch is gone).
#
# Destructive: step 2 removes the graph from the cloud. You must confirm by
# retyping the name, or pass -y / --yes to skip the prompt.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

name=$1
assume_yes=no
case "$2" in -y | --yes) assume_yes=yes ;; esac

if [ -z "$name" ]; then
    echo "usage: libseq remove <GraphName> [-y]" >&2
    exit 1
fi
branch="graphs/$name"

# Figure out what actually exists so we only do (and warn about) what's real.
remote_exists=no
git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1 && remote_exists=yes

if [ ! -e "$name" ] && [ "$remote_exists" = no ]; then
    echo "remove-graph: nothing to remove for '$name' (no local folder or remote branch)." >&2
    exit 1
fi

# Confirm before the irreversible parts.
if [ "$assume_yes" != yes ]; then
    echo "About to remove graph '$name':"
    [ -e "$name" ]             && echo "  - delete local folder ./$name"
    [ "$remote_exists" = yes ] && echo "  - DELETE remote branch origin/$branch  (irreversible)"
    printf "Retype the graph name to confirm: "
    read -r reply
    if [ "$reply" != "$name" ]; then
        echo "remove-graph: name did not match, aborted."
        exit 1
    fi
fi

# 1. Local clone (content is safe on origin until step 2).
if [ -e "$name" ]; then
    rm -rf "$name"
    echo "remove-graph: deleted ./$name"
fi

# 2. Remote branch — the canonical copy. This is the irreversible step.
if [ "$remote_exists" = yes ]; then
    git push --quiet origin --delete "$branch" && echo "remove-graph: deleted remote $branch"
fi

cat <<EOF

remove-graph: '$name' removed on this device.

On your OTHER devices, run:
  cd <libseq>
  libseq clean        (Windows)   or   sh sys/clean.sh   (macOS/Linux)

Also remove the graph from Logseq's UI so it stops referencing the old path.
EOF

#!/bin/sh
#
# remove-graph.sh — fully remove a graph from the library (submodule mode).
# Invoke via:  libseq remove <GraphName> [-y]   or   sh sys/remove-graph.sh <GraphName> [-y]
#
# It undoes everything `libseq add` set up, on THIS device:
#   1. deletes the local clone folder ./<Name>
#   2. drops the gitlink from main's index
#   3. removes the submodule entry from .gitmodules
#   4. removes the local submodule config from .git/config
#   5. commits + pushes main
#   6. deletes the remote branch graphs/<Name>
# Then prints the cleanup to run on OTHER devices (a plain `git pull` can't
# delete their already-cloned folder).
#
# Destructive: step 6 removes the graph from the cloud. You must confirm by
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
NOHOOK="-c core.hooksPath=/dev/null"

# Figure out what actually exists so we only do (and warn about) what's real.
registered=no
git config -f .gitmodules --get "submodule.$name.path" >/dev/null 2>&1 && registered=yes
remote_exists=no
git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1 && remote_exists=yes

if [ "$registered" = no ] && [ ! -e "$name" ] && [ "$remote_exists" = no ]; then
    echo "remove-graph: nothing to remove for '$name' (no folder, submodule, or remote branch)." >&2
    exit 1
fi

# Confirm before the irreversible parts.
if [ "$assume_yes" != yes ]; then
    echo "About to remove graph '$name':"
    [ -e "$name" ]              && echo "  - delete local folder ./$name"
    [ "$registered" = yes ]     && echo "  - unregister submodule, then commit + push main"
    [ "$remote_exists" = yes ]  && echo "  - DELETE remote branch origin/$branch  (irreversible)"
    printf "Retype the graph name to confirm: "
    read -r reply
    if [ "$reply" != "$name" ]; then
        echo "remove-graph: name did not match, aborted."
        exit 1
    fi
fi

# 1. Local clone (content is safe on origin until step 6).
if [ -e "$name" ]; then
    rm -rf "$name"
    echo "remove-graph: deleted ./$name"
fi

# 2-5. Unregister the submodule and sync main.
if [ "$registered" = yes ]; then
    git rm --cached --quiet "$name" 2>/dev/null || true
    git config -f .gitmodules --remove-section "submodule.$name" 2>/dev/null || true

    # Drop .gitmodules entirely if no submodules remain, else stage the edit.
    if [ -f .gitmodules ] && ! git config -f .gitmodules --get-regexp '^submodule\.' >/dev/null 2>&1; then
        git rm --cached --quiet .gitmodules 2>/dev/null || true
        rm -f .gitmodules
        echo "remove-graph: removed now-empty .gitmodules"
    else
        git add .gitmodules 2>/dev/null || true
    fi

    git config --remove-section "submodule.$name" 2>/dev/null || true

    if git $NOHOOK commit --quiet -m "remove graph $name"; then
        git push --quiet origin HEAD && echo "remove-graph: pushed main"
    else
        echo "remove-graph: nothing to commit on main (was it already unregistered?)."
    fi
fi

# 6. Remote branch — the canonical copy. This is the irreversible step.
if [ "$remote_exists" = yes ]; then
    git push --quiet origin --delete "$branch" && echo "remove-graph: deleted remote $branch"
fi

cat <<EOF

remove-graph: '$name' removed on this device.

On your OTHER devices, run:
  cd <libseq>
  git pull
  libseq clean        (Windows)   or   sh sys/clean.sh   (macOS/Linux)

Also remove the graph from Logseq's UI so it stops referencing the old path.
EOF

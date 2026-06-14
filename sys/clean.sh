#!/bin/sh
#
# clean.sh — remove local graph clones whose remote branch no longer exists.
# Invoke via:  libseq clean [-y]   or   sh sys/clean.sh [-y]
#
# When a graph is removed on another device (libseq remove), that device deletes
# the remote branch graphs/<Name> and unregisters the submodule from main. After
# you `git pull` here, this device is left with a stale local clone folder and a
# leftover `submodule.<Name>` section in .git/config. `libseq clean` finds every
# such orphan — a known graph whose branch is gone from origin — and deletes the
# folder plus the local config section. Live graphs are left untouched.
#
# Local only: it never touches main, .gitmodules, or any remote branch.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

assume_yes=no
case "$1" in -y | --yes) assume_yes=yes ;; esac

# Refresh remote-tracking refs so the branch-existence check below is accurate.
git fetch origin --prune --quiet 2>/dev/null || true

# Candidate graph names come from both registries:
#   - .gitmodules : graphs main still tracks
#   - .git/config : graphs this device has locally cloned/activated (bootstrap
#                   leaves a submodule.<Name> section behind even after a pull
#                   drops the graph from .gitmodules)
names=$(
    {
        if [ -f .gitmodules ]; then
            for key in $(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$' 2>/dev/null); do
                git config -f .gitmodules "$key"
            done
        fi
        git config --name-only --get-regexp '^submodule\.' 2>/dev/null \
            | sed -n 's/^submodule\.\(.*\)\.[^.]*$/\1/p'
    } | sort -u
)

orphans=""
for name in $names; do
    [ -n "$name" ] || continue

    branch=""
    [ -f .gitmodules ] && branch=$(git config -f .gitmodules "submodule.$name.branch" 2>/dev/null || true)
    [ -n "$branch" ] || branch="graphs/$name"

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
still_registered=""
for name in $orphans; do
    if [ -d "$name" ]; then
        echo "  - ./$name (local folder)"
    else
        echo "  - $name (config only)"
    fi
    if [ -f .gitmodules ] && git config -f .gitmodules --get "submodule.$name.path" >/dev/null 2>&1; then
        still_registered="$still_registered $name"
    fi
done

if [ -n "$still_registered" ]; then
    echo "clean: note —$still_registered still listed in .gitmodules; run 'git pull' first if the removal hasn't synced." >&2
fi

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
    if git config --remove-section "submodule.$name" 2>/dev/null; then
        echo "clean: removed submodule.$name from .git/config"
    fi
done

echo "clean: done."

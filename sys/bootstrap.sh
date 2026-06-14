#!/bin/sh
#
# bootstrap.sh — run ONCE on each new device, right after cloning libseq.
# Invoke via:  libseq boot   (Windows)   or   sh sys/bootstrap.sh
#
# SUBMODULE MODE (form 1: one remote, branch == graph):
# .gitmodules is the registry of graphs. For each one (minus .libexclude), this
# clones the graph's branch into its folder as an INDEPENDENT clone — giving it
# a real `.git` DIRECTORY, which Logseq reuses as-is (it would otherwise rewrite
# a separate-git-dir pointer file and corrupt things). We deliberately do NOT use
# `git submodule update`, because that absorbs the git dir into .git/modules and
# leaves a pointer file behind.
#
# Safe to re-run: already-checked-out graphs are skipped.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

ORIGIN_URL=$(git remote get-url origin)

# Names listed in .libexclude are not checked out on this device.
is_excluded() {
    [ -f "$REPO_ROOT/.libexclude" ] || return 1
    grep -v '^[[:space:]]*#' "$REPO_ROOT/.libexclude" \
        | sed 's/[[:space:]]//g' \
        | grep -qx "$1"
}

if [ ! -f .gitmodules ]; then
    echo "bootstrap: no graphs registered yet. Create one with: libseq add <Name>"
    exit 0
fi

git fetch origin --prune --quiet

found=0
# Iterate the submodule names recorded in .gitmodules.
for key in $(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$'); do
    found=1
    name=$(git config -f .gitmodules "$key")
    branch=$(git config -f .gitmodules "submodule.$name.branch")
    [ -n "$branch" ] || branch="graphs/$name"

    if is_excluded "$name"; then
        echo "bootstrap: '$name' is in .libexclude, skipping."
        continue
    fi

    if [ -d "$name/.git" ]; then
        echo "bootstrap: '$name' already checked out."
        continue
    fi
    if [ -e "$name" ]; then
        echo "bootstrap: '$name' exists but has no real .git dir — move it aside first. Skipping." >&2
        continue
    fi

    # Independent clone => real .git directory (Logseq-safe).
    git clone --quiet -b "$branch" "$ORIGIN_URL" "$name"
    git -C "$name" config core.hooksPath "$REPO_ROOT/sys/git-hooks"
    git config "submodule.$name.url" "$ORIGIN_URL"
    git config "submodule.$name.active" "true"
    echo "bootstrap: checked out '$name' (branch $branch)."
done

if [ "$found" -eq 0 ]; then
    echo "bootstrap: no graphs registered yet. Create one with: libseq add <Name>"
fi

echo "bootstrap: done. Open the graph folder(s) in Logseq and start editing."

#!/bin/sh
#
# bootstrap.sh — run ONCE on each new device, right after cloning libseq.
# Invoke via:  libseq boot   (Windows)   or   sh sys/bootstrap.sh
#
# CLONE-AND-IGNORE MODE:
# Each graph lives on its own branch graphs/<Name> in the SAME GitHub repo. The
# remote `graphs/*` branches ARE the registry — there's no .gitmodules to keep in
# sync. For every such branch (minus .libexclude), this clones it into ./<Name>
# as an INDEPENDENT clone, giving the folder a real `.git` DIRECTORY that Logseq
# reuses as-is. (A submodule/worktree pointer file would get rewritten by Logseq
# and corrupt the layout — hence a plain clone.) The folder is ignored by main's
# whitelist .gitignore, so it never shows up in the library's status.
#
# Safe to re-run: already-checked-out graphs are skipped. "Already checked out" is
# decided by the branch recorded inside each folder's .git, not by folder name, so
# a graph you've renamed locally is recognised and never cloned a second time.

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

# Echo the top-level folder already checked out on branch $1 (any name), if any.
checkout_of_branch() {
    for d in */; do
        d=${d%/}
        [ -d "$d/.git" ] || continue
        if [ "$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$1" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

git fetch origin --prune --quiet

# The graph registry is simply the set of graphs/* branches on origin.
branches=$(git ls-remote --heads origin 'graphs/*' | sed 's#.*refs/heads/##')

if [ -z "$branches" ]; then
    echo "bootstrap: no graphs registered yet. Create one with: libseq add <Name>"
    exit 0
fi

for branch in $branches; do
    name=${branch#graphs/}

    if is_excluded "$name"; then
        echo "bootstrap: '$name' is in .libexclude, skipping."
        continue
    fi

    if existing=$(checkout_of_branch "$branch"); then
        if [ "$existing" = "$name" ]; then
            echo "bootstrap: '$name' already checked out."
        else
            echo "bootstrap: '$name' already checked out as ./$existing (renamed)."
        fi
        continue
    fi
    if [ -e "$name" ]; then
        # rmdir only succeeds when the dir is empty, so this clears a harmless
        # placeholder but refuses to clobber a folder with real content.
        if rmdir "$name" 2>/dev/null; then
            :
        else
            echo "bootstrap: '$name' exists and is not empty — move it aside first. Skipping." >&2
            continue
        fi
    fi

    # Independent clone => real .git directory (Logseq-safe).
    git clone --quiet -b "$branch" "$ORIGIN_URL" "$name"
    git -C "$name" config core.hooksPath "$REPO_ROOT/sys/git-hooks"
    echo "bootstrap: checked out '$name' (branch $branch)."
done

echo "bootstrap: done. Open the graph folder(s) in Logseq and start editing."

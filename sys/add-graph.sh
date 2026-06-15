#!/bin/sh
#
# add-graph.sh — register a Logseq graph as its own branch graphs/<Name>.
# Invoke via:  libseq add <GraphName>   or   sh sys/add-graph.sh <GraphName>
#
# Two modes, picked automatically from whether ./<Name> already exists:
#
#   NEW (folder absent)   — create a brand-new, empty graph from scratch.
#   ADOPT (folder present) — take an existing folder (e.g. a Logseq graph you
#                            already made locally) and turn it into a libseq
#                            graph in place, keeping its current files. If the
#                            folder already has its own .git (directory or pointer
#                            file), you're asked y/n before its git metadata is
#                            replaced (pass -y to skip the prompt).
#
# CLONE-AND-IGNORE MODE (both paths end up here):
#   - The graph lives on its own branch graphs/<Name> in the SAME GitHub repo.
#   - Its folder has a real `.git` DIRECTORY (not a pointer). This is the crucial
#     bit: Logseq reuses a real `.git` directory as-is, whereas it
#     rewrites/relocates separate-git-dir pointer files (which is what corrupted
#     the old worktree layout).
#   - The branch itself is the registry — `main` records NOTHING about the graph,
#     so this never commits to or pushes main. Other devices pick the graph up on
#     `libseq boot`, which clones every graphs/* branch.
#
# The init commit bypasses the pull/push hooks (-c core.hooksPath=/dev/null) so
# first-time creation stays clean and predictable.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

name=$1
assume_yes=no
case "$2" in -y | --yes) assume_yes=yes ;; esac

if [ -z "$name" ]; then
    echo "usage: libseq add <GraphName> [-y]" >&2
    exit 1
fi
branch="graphs/$name"
NOHOOK="-c core.hooksPath=/dev/null"
ORIGIN_URL=$(git remote get-url origin)

# Seed the union-merge policy so concurrent edits on two devices concatenate
# instead of conflicting. Creates .gitattributes if absent; if the folder being
# adopted already has one, append the rules only when they're not present so we
# never clobber the user's existing attributes.
ensure_gitattributes() {
    file="$1/.gitattributes"
    if [ ! -f "$file" ]; then
        {
            echo '# Concatenate concurrent edits to notes instead of conflicting.'
            echo '*.md  merge=union'
            echo '*.org merge=union'
        } > "$file"
    elif ! grep -q 'merge=union' "$file" 2>/dev/null; then
        {
            echo ''
            echo '# Concatenate concurrent edits to notes instead of conflicting.'
            echo '*.md  merge=union'
            echo '*.org merge=union'
        } >> "$file"
    fi
}

# A graphs/<Name> branch on origin always wins as the source of truth — if one
# exists, this device should `libseq boot` to clone it, not create a second one.
if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "add-graph: branch '$branch' already exists. Run 'libseq boot' to check it out." >&2
    exit 1
fi

if [ -e "$name" ] && [ ! -d "$name" ]; then
    echo "add-graph: '$name' exists but is not a directory — pick another name." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# ADOPT: ./<Name> already exists — make it a graph in place, keeping its files.
# ---------------------------------------------------------------------------
if [ -d "$name" ]; then
    # An existing .git — a real directory OR a separate-git-dir pointer file —
    # means the folder is already under some git's control (another repo, an old
    # libseq graph, or a Logseq-rewritten pointer). Re-initializing replaces that
    # git metadata with a fresh libseq graph; the folder's FILES are kept, but its
    # current git history is discarded — so confirm first (or pass -y).
    if [ -e "$name/.git" ]; then
        kind="directory"
        [ -f "$name/.git" ] && kind="pointer file"
        existing_branch=$(git -C "$name" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

        if [ "$assume_yes" != yes ]; then
            echo "add-graph: './$name' already has its own .git ($kind)${existing_branch:+, branch '$existing_branch'}."
            echo "add-graph: re-initialize it as a libseq graph? The folder's files are kept,"
            echo "add-graph: but its current git history is discarded."
            printf "Overwrite? [y/N] "
            read -r reply
            case "$reply" in
                y | Y | yes | YES) ;;
                *) echo "add-graph: aborted, nothing changed." ; exit 0 ;;
            esac
        fi

        # Drop the old git metadata. `rm -rf` clears both a real .git directory and
        # a pointer file (the pointed-to gitdir elsewhere is simply left detached).
        rm -rf "$name/.git"
    fi

    echo "add-graph: adopting existing folder './$name' as graph '$name'."

    # Fresh repo in place, on a clean orphan branch seeded with the current files
    # so the graph starts with exactly what's in the folder (no library history).
    ensure_gitattributes "$name"
    git -C "$name" init --quiet
    git -C "$name" checkout --quiet --orphan "$branch"
    git -C "$name" remote add origin "$ORIGIN_URL"
    git -C "$name" add -A
    git -C "$name" $NOHOOK commit --quiet -m "init graph $name (adopted ./$name)"
    git -C "$name" push --quiet -u origin "$branch"
    git -C "$name" config core.hooksPath "$REPO_ROOT/sys/git-hooks"

    echo "add-graph: '$name' is ready. Open it in Logseq; commits will auto-sync."
    exit 0
fi

# ---------------------------------------------------------------------------
# NEW: ./<Name> does not exist — create a brand-new, empty graph.
# ---------------------------------------------------------------------------

# 1. Clone the library (gives the folder a REAL .git dir), then carve out a clean
#    orphan branch for the graph, seeded with the union-merge policy.
git clone --quiet "$ORIGIN_URL" "$name"
git -C "$name" checkout --quiet --orphan "$branch"
git -C "$name" rm -rf --quiet . >/dev/null 2>&1 || true
ensure_gitattributes "$name"
git -C "$name" add .gitattributes
git -C "$name" $NOHOOK commit --quiet -m "init graph $name"

# 2. Publish the branch to the same remote, set upstream for future pull/push.
git -C "$name" push --quiet -u origin "$branch"

# 3. Wire the shared hooks into this graph clone so Logseq's auto-commit
#    pull-before / push-after just works.
git -C "$name" config core.hooksPath "$REPO_ROOT/sys/git-hooks"

echo "add-graph: '$name' is ready. Open it in Logseq; commits will auto-sync."

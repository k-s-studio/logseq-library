#!/bin/sh
#
# add-graph.sh — create a brand-new Logseq graph as its own branch + submodule.
# Invoke via:  libseq add <GraphName>   or   sh sys/add-graph.sh <GraphName>
#
# SUBMODULE MODE (form 1: one remote, branch == graph):
#   - The graph lives on its own branch graphs/<Name> in the SAME GitHub repo.
#   - Its folder is an INDEPENDENT CLONE of that branch, so it has a real `.git`
#     DIRECTORY (not a pointer). This is the crucial bit: Logseq reuses a real
#     `.git` directory as-is, whereas it rewrites/relocates separate-git-dir
#     pointer files (which is what corrupted the old worktree layout).
#   - The superproject records the graph as a true submodule (.gitmodules +
#     gitlink), so `main` tracks every graph. The submodule is its own repo, so
#     Logseq messing with one graph can never corrupt the library repo.
#
# Setup commits bypass the pull/push hooks (-c core.hooksPath=/dev/null) so
# first-time creation stays clean and predictable.

set -e

SYS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SYS_DIR/.." && pwd)
cd "$REPO_ROOT"

name=$1
if [ -z "$name" ]; then
    echo "usage: libseq add <GraphName>" >&2
    exit 1
fi
branch="graphs/$name"
NOHOOK="-c core.hooksPath=/dev/null"
ORIGIN_URL=$(git remote get-url origin)

if [ -e "$name" ]; then
    echo "add-graph: '$name' already exists — pick another name." >&2
    exit 1
fi
if git show-ref --verify --quiet "refs/heads/$branch" || \
   git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "add-graph: branch '$branch' already exists. Run 'libseq boot' to check it out." >&2
    exit 1
fi

# 1. Clone the library (gives the folder a REAL .git dir), then carve out a clean
#    orphan branch for the graph, seeded with the union-merge policy so
#    concurrent edits on two devices concatenate instead of conflicting.
git clone --quiet "$ORIGIN_URL" "$name"
git -C "$name" checkout --quiet --orphan "$branch"
git -C "$name" rm -rf --quiet . >/dev/null 2>&1 || true
{
    echo '# Concatenate concurrent edits to notes instead of conflicting.'
    echo '*.md  merge=union'
    echo '*.org merge=union'
} > "$name/.gitattributes"
git -C "$name" add .gitattributes
git -C "$name" $NOHOOK commit --quiet -m "init graph $name"

# 2. Publish the branch to the same remote, set upstream for future pull/push.
git -C "$name" push --quiet -u origin "$branch"

# 3. Wire the shared hooks into this graph clone so Logseq's auto-commit
#    pull-before / push-after just works.
git -C "$name" config core.hooksPath "$REPO_ROOT/sys/git-hooks"

# 4. Register the graph as a true submodule so `main` tracks it.
"$SYS_DIR/register-submodule.sh" "$name" "$branch" "$ORIGIN_URL"
git add .gitmodules
git add -f "$name"
git $NOHOOK commit --quiet -m "add graph $name (submodule, $branch)"
git push --quiet origin HEAD

echo "add-graph: '$name' is ready. Open it in Logseq; commits will auto-sync."

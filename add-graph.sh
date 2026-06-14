#!/bin/sh
#
# add-graph.sh — create a brand-new Logseq graph as its own branch + worktree.
#
#   ./add-graph.sh <FolderName> [branch]
#
# Example:
#   ./add-graph.sh MyGraphA            # branch defaults to graphs/MyGraphA
#
# What it does:
#   1. Creates an orphan branch (clean, independent history) for the graph.
#   2. Seeds it with the union-merge .gitattributes policy (so concurrent edits
#      on two devices concatenate instead of conflicting — same as the library).
#   3. Pushes the branch to the SAME remote (one repo, many branches) and adds a
#      worktree folder you can open in Logseq.
#   4. Registers the graph in graphs.txt + .gitignore and commits that on main,
#      so every other device picks it up on its next ./bootstrap.sh.
#
# Setup commits here deliberately bypass the pull/push hooks
# (-c core.hooksPath=) so first-time creation stays clean and predictable.

set -e

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$REPO_ROOT"

folder=$1
if [ -z "$folder" ]; then
    echo "usage: ./add-graph.sh <FolderName> [branch]" >&2
    exit 1
fi
branch=${2:-graphs/$folder}

NOHOOK="-c core.hooksPath=/dev/null"

if [ -e "$folder" ]; then
    echo "add-graph: '$folder' already exists — pick another name." >&2
    exit 1
fi
if git show-ref --verify --quiet "refs/heads/$branch" || \
   git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "add-graph: branch '$branch' already exists. Use ./bootstrap.sh to check it out." >&2
    exit 1
fi

# Make sure hooks are wired up for everyday use even if bootstrap wasn't run yet.
git config core.hooksPath "$REPO_ROOT/git-hooks"

# 1+2. Orphan branch with a clean tree, seeded with the merge policy.
git worktree add --detach "$folder"
git -C "$folder" checkout --orphan "$branch"
git -C "$folder" rm -rf --quiet . 2>/dev/null || true
{
    echo '# Concatenate concurrent edits to notes instead of producing conflicts.'
    echo '# See the library .gitattributes for caveats. Text files only.'
    echo '*.md  merge=union'
    echo '*.org merge=union'
} > "$folder/.gitattributes"
git -C "$folder" add .gitattributes
git -C "$folder" $NOHOOK commit -m "init graph $folder"

# 3. Push to the same remote, set upstream so future pull/push just work.
git -C "$folder" push -u origin "$branch"

# 4. Register in the manifest + ignore the worktree folder from main, then sync.
if ! grep -qsx "$folder $branch" graphs.txt; then
    printf '%s %s\n' "$folder" "$branch" >> graphs.txt
fi
touch .gitignore
if ! grep -qsx "/$folder/" .gitignore; then
    printf '/%s/\n' "$folder" >> .gitignore
fi
git add graphs.txt .gitignore
git $NOHOOK commit -m "add graph $folder ($branch)"
git push origin HEAD

echo "add-graph: '$folder' is ready. Open it in Logseq; commits will auto-sync."

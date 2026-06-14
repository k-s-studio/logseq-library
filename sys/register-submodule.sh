#!/bin/sh
#
# register-submodule.sh <name> <branch> <url>
#
# Records a graph folder as a submodule of the library WITHOUT cloning or
# absorbing its git dir (so the folder keeps its real `.git` directory that
# Logseq reuses). Writes the .gitmodules entry and the local .git/config so
# `git submodule` commands recognise it. The caller stages + commits.
#
# Idempotent: re-running just refreshes the values.

set -e

name=$1
branch=$2
url=$3
if [ -z "$name" ] || [ -z "$branch" ] || [ -z "$url" ]; then
    echo "usage: register-submodule.sh <name> <branch> <url>" >&2
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Tracked registry: what `main` records about each graph.
git config -f .gitmodules "submodule.$name.path"   "$name"
git config -f .gitmodules "submodule.$name.url"     "$url"
git config -f .gitmodules "submodule.$name.branch"  "$branch"

# Local activation so `git submodule status/foreach` see it on this device.
git config "submodule.$name.url"    "$url"
git config "submodule.$name.active" "true"

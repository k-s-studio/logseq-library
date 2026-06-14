#!/usr/bin/bash
#
# Termux (Android) pull: Logseq for Android can't run git itself, so run this
# from a Termux:Widget to refresh every graph before you start editing.
#
# Set LIBRARY_DIR to wherever you cloned libseq (then ran `sh sys/bootstrap.sh`).
source bin/source-ssh-agent
LIBRARY_DIR=${LIBRARY_DIR:-storage/documents/libseq}

cd "$LIBRARY_DIR" || { echo "pull-graph: cannot cd to $LIBRARY_DIR, aborting" >&2; exit 1; }

# Each graph is a submodule clone listed in .gitmodules.
for folder in $(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'); do
    [ -d "$folder/.git" ] || continue
    ( cd "$folder" && git pull ) || echo "pull-graph: '$folder' pull failed" >&2
done

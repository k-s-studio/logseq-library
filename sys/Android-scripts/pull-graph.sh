#!/usr/bin/bash
#
# Termux (Android) pull: Logseq for Android can't run git itself, so run this
# from a Termux:Widget to refresh every graph before you start editing.
#
# Set LIBRARY_DIR to wherever you cloned logseq-library (then ran ./bootstrap.sh).
source bin/source-ssh-agent
LIBRARY_DIR=${LIBRARY_DIR:-storage/documents/logseq-library}

cd "$LIBRARY_DIR" || { echo "pull-graph: cannot cd to $LIBRARY_DIR, aborting" >&2; exit 1; }

while read -r folder branch _; do
    case "$folder" in '' | \#*) continue ;; esac
    [ -d "$folder" ] || continue
    ( cd "$folder" && git pull ) || echo "pull-graph: '$folder' pull failed" >&2
done < graphs.txt

#!/usr/bin/bash
#
# Termux (Android) pull: Logseq for Android can't run git itself, so run this
# from a Termux:Widget to refresh every graph before you start editing.
#
# Set LIBRARY_DIR to wherever you cloned libseq (then ran `sh sys/bootstrap.sh`).
source bin/source-ssh-agent
LIBRARY_DIR=${LIBRARY_DIR:-storage/documents/libseq}

cd "$LIBRARY_DIR" || { echo "pull-graph: cannot cd to $LIBRARY_DIR, aborting" >&2; exit 1; }

# Each graph is an independent clone checked out on a graphs/* branch — discover
# them by scanning the top-level folders (no registry file needed).
for folder in */; do
    folder=${folder%/}
    [ -d "$folder/.git" ] || continue
    case "$(git -C "$folder" rev-parse --abbrev-ref HEAD 2>/dev/null)" in graphs/*) ;; *) continue ;; esac
    ( cd "$folder" && git pull ) || echo "pull-graph: '$folder' pull failed" >&2
done

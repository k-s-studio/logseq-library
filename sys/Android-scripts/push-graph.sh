#!/usr/bin/bash
#
# Termux (Android) push: commit and push every graph's changes. Run from a
# Termux:Widget after editing in Logseq for Android (which can't run git/hooks).
#
# Set LIBRARY_DIR to wherever you cloned libseq (then ran `sh sys/bootstrap.sh`).
source bin/source-ssh-agent
LIBRARY_DIR=${LIBRARY_DIR:-storage/documents/libseq}

cd "$LIBRARY_DIR" || { echo "push-graph: cannot cd to $LIBRARY_DIR, aborting" >&2; exit 1; }

# Each graph is an independent clone checked out on a graphs/* branch — discover
# them by scanning the top-level folders (no registry file needed).
for folder in */; do
    folder=${folder%/}
    [ -d "$folder/.git" ] || continue
    case "$(git -C "$folder" rev-parse --abbrev-ref HEAD 2>/dev/null)" in graphs/*) ;; *) continue ;; esac
    (
        cd "$folder" || exit 1
        git add -A
        # Only commit when something is staged; a no-op commit exits non-zero
        # and would abort before the push, stranding already-committed work.
        git diff --cached --quiet || git commit -m "sync from android"
        git push
    ) || echo "push-graph: '$folder' push failed" >&2
done

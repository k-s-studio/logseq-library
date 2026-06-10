#!/usr/bin/bash
source bin/source-ssh-agent
# Abort with a visible reason if the graph folder isn't where we expect,
# instead of silently running git in the wrong directory (the message shows up
# in the Termux:Widget output even when the exit code doesn't).
cd storage/documents/Diario || { echo "push-graph: cannot cd to storage/documents/Diario, aborting" >&2; exit 1; }
git add -A
# Only commit when something is actually staged. A plain `git commit` with
# nothing to commit exits non-zero, which would abort the script before the
# push — so any already-committed-but-unpushed work would never go out.
git diff --cached --quiet || git commit -m "sync from android"
git push

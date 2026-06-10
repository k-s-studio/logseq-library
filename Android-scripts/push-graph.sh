#!/usr/bin/bash
source bin/source-ssh-agent
# Abort if the graph folder isn't where we expect, instead of running git in
# the wrong directory.
cd storage/documents/Diario || exit 1
git add -A
# Only commit when something is actually staged. A plain `git commit` with
# nothing to commit exits non-zero, which would abort the script before the
# push — so any already-committed-but-unpushed work would never go out.
git diff --cached --quiet || git commit -m "sync from android"
git push

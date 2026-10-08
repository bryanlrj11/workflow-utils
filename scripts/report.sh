#!/usr/bin/env bash
# Store a run's log in a private repository (key in $DEPLOY_KEY, write access).
# Usage: report.sh <owner/repo> <logfile>
set -uo pipefail
repo=$1 log=$(realpath "$2" 2>/dev/null || echo "$2")
[ -f "$log" ] || { echo "no log"; exit 0; }

key=$(mktemp)
dir=$(mktemp -d)
trap 'rm -rf "$key" "$dir"' EXIT
printf '%s\n' "$DEPLOY_KEY" | tr -d '' > "$key"
chmod 600 "$key"
export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
dest="$(date -u +%Y/%m)/$stamp-$GITHUB_WORKFLOW-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT.log"

(
  git clone --quiet --depth 1 "git@github.com:$repo.git" "$dir"
  cd "$dir"
  git config user.name "runner"
  git config user.email "runner@users.noreply.github.com"
  mkdir -p "$(dirname "$dest")"
  cp "$log" "$dest"
  git add "$dest"
  git commit --quiet -m "$GITHUB_WORKFLOW $GITHUB_RUN_ID"
  # two jobs can fail at once: rebase onto the other's push and retry
  for _ in 1 2 3; do
    git push --quiet origin HEAD:main && exit 0
    git pull --quiet --rebase origin main || true
    sleep $((RANDOM % 10 + 1))
  done
  exit 1
) >/dev/null 2>&1 && echo "log stored" || echo "log not stored"

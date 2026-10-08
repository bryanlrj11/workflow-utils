#!/usr/bin/env bash
# Shallow, sparse clone of a repository over SSH with a deploy key, without output.
# Only deploy/jobs is checked out first; then the paths listed in deploy/jobs/<set>.paths.
# Usage: fetch.sh <owner/repo> <dir> <set>   (key in $DEPLOY_KEY)
set -euo pipefail
repo=$1 dir=$2 set=$3

key=$(mktemp)
err=$(mktemp)
trap 'rm -f "$key" "$err"' EXIT
# a key pasted through a web form can arrive with CRLF line endings
printf '%s\n' "$DEPLOY_KEY" | tr -d '\015' > "$key"
chmod 600 "$key"
export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

{
  git clone --quiet --depth 1 --filter=blob:none --sparse "git@github.com:$repo.git" "$dir"
  git -C "$dir" sparse-checkout set deploy/jobs
  mapfile -t paths < "$dir/deploy/jobs/$set.paths"
  git -C "$dir" sparse-checkout set "${paths[@]}"
} >/dev/null 2>"$err" || {
  echo "fetch failed: $(grep -v '^Warning' "$err" | head -3 | tr '\n' ' ' | cut -c1-200)"
  exit 1
}

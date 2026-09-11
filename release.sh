#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=${0:A:h}
SCRIPT_NAME=${0:t}

die() {
  print "$1" >&2
  exit 1
}

if [[ $# -ne 1 || ! "$1" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  die "Usage: $SCRIPT_NAME MAJOR.MINOR.PATCH"
elif ! git -C "$ROOT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  die "Not a git repository"
elif ! BRANCH=$(git -C "$ROOT_DIR" symbolic-ref --quiet --short HEAD); then
  die "HEAD is detached"
fi

GIT_STATUS=(git -C "$ROOT_DIR" status --porcelain --untracked-files=all)

if [[ -n "$("${GIT_STATUS[@]}")" ]]; then
  die "Working tree is not clean"
fi

REMOTE=$(git -C "$ROOT_DIR" config --get remote.pushDefault || true)

if [[ -z "$REMOTE" ]]; then
  REMOTE=$(git -C "$ROOT_DIR" config --get "branch.$BRANCH.remote" || true)
fi

REMOTE=${REMOTE:-origin}

if ! git -C "$ROOT_DIR" remote get-url "$REMOTE" >/dev/null 2>&1; then
  die "Git remote '$REMOTE' does not exist"
fi

LATEST_TAG=$(git -C "$ROOT_DIR" tag --list |
  awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { print }' |
  sort -V | tail -n 1)

if [[ -n "$LATEST_TAG" ]]; then
  COMMITS_SINCE_TAG=$(git -C "$ROOT_DIR" rev-list --count "$LATEST_TAG"..HEAD)
else
  COMMITS_SINCE_TAG=$(git -C "$ROOT_DIR" rev-list --count HEAD)
fi

if (( COMMITS_SINCE_TAG == 0 )); then
  die "current branch has no commits since the latest release tag"
fi

NEXT_TAG="v$1"
TAG_REF="refs/tags/$NEXT_TAG"
GIT_TAG_CHECK=(git -C "$ROOT_DIR" rev-parse --verify --quiet "$TAG_REF")

if "${GIT_TAG_CHECK[@]}" >/dev/null; then
  die "Tag $NEXT_TAG already exists"
fi

REMOTE_TAG_REF="refs/tags/$NEXT_TAG"

GIT_REMOTE_TAG=(
  git -C "$ROOT_DIR" ls-remote --exit-code --tags "$REMOTE" "$REMOTE_TAG_REF"
)

if "${GIT_REMOTE_TAG[@]}" >/dev/null 2>&1; then
  REMOTE_TAG_STATUS=0
else
  REMOTE_TAG_STATUS=$?
fi

(( REMOTE_TAG_STATUS == 2 )) || {
  (( REMOTE_TAG_STATUS == 0 )) && die "Tag $NEXT_TAG already exists on $REMOTE"
  die "Could not check tag $NEXT_TAG on $REMOTE"
}

git -C "$ROOT_DIR" tag -a "$NEXT_TAG" -m "Release $NEXT_TAG"

if (cd "$ROOT_DIR" && ./bundle.sh); then
  :
else
  BUNDLE_STATUS=$?
  git -C "$ROOT_DIR" tag -d "$NEXT_TAG" >/dev/null
  print "Bundling failed; removed local tag $NEXT_TAG." >&2
  exit "$BUNDLE_STATUS"
fi

if git -C "$ROOT_DIR" push "$REMOTE" "$BRANCH" "$NEXT_TAG"; then
  :
else
  PUSH_STATUS=$?
  print "Release $NEXT_TAG is ready, but pushing failed." >&2
  print "Retry with 'git push $REMOTE $BRANCH $NEXT_TAG'"
  exit "$PUSH_STATUS"
fi

printf '%s\n\n' "Released DoTorDoH $NEXT_TAG"
printf '%s\n\n' "Bundle: 'dist/dotordoh'"
printf '%s\n' "Published:"
printf '  %s\n' "$REMOTE/$BRANCH"
printf '  %s\n' "$REMOTE/$NEXT_TAG"

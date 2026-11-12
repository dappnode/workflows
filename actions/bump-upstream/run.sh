#!/usr/bin/env bash
# Map action inputs to `bump-runner update` and run it from the public
# dappnode/tropibot image. Outputs are appended to $GITHUB_OUTPUT by
# bump-runner itself. Kept self-contained: dappnode/tropibot is a private
# repository, so public repositories cannot use its action directly.
set -euo pipefail

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "${value%"${value##*[![:space:]]}"}"
}

lower() {
  trim "$1" | tr '[:upper:]' '[:lower:]'
}

fail() {
  echo "::error title=bump-upstream::$1" >&2
  exit 1
}

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set (run inside GitHub Actions)}"
command -v docker >/dev/null 2>&1 || fail "Docker is required; use a Linux runner such as ubuntu-latest"

workspace="$(cd "$(trim "${INPUT_WORKSPACE:-.}")" 2>/dev/null && pwd -P)" ||
  fail "Workspace '${INPUT_WORKSPACE:-.}' does not exist"

args=(update --workspace "$workspace" --github-output "$GITHUB_OUTPUT")

version="$(trim "${INPUT_VERSION:-}")"
[[ -n "$version" ]] && args+=("--version=$version")

case "$(lower "${INPUT_PIN_DIGEST:-}")" in
  "") ;;
  true | yes | on | 1) args+=(--pin-digest) ;;
  false | no | off | 0) args+=(--no-pin-digest) ;;
  *) fail "pin-digest must be true, false, or empty (got '${INPUT_PIN_DIGEST}')" ;;
esac

case "$(lower "${INPUT_DRY_RUN:-false}")" in
  "" | false | no | off | 0) ;;
  true | yes | on | 1) args+=(--dry-run) ;;
  *) fail "dry-run must be true or false (got '${INPUT_DRY_RUN}')" ;;
esac

image="$(trim "${INPUT_IMAGE:-}")"
[[ -n "$image" ]] && args+=("--image=$image")

upstream="$(trim "${INPUT_UPSTREAM:-}")"
[[ -n "$upstream" ]] && args+=("--upstream=$upstream")

provider="$(lower "${INPUT_PROVIDER:-}")"
case "$provider" in
  "") ;;
  docker | github | docker_tags | docker-tags) args+=("--provider=$provider") ;;
  *) fail "provider must be docker, github, docker_tags, or empty (got '${INPUT_PROVIDER}')" ;;
esac

runner_image="$(trim "${INPUT_RUNNER_IMAGE:-}")"
[[ -z "$runner_image" ]] && runner_image="docker.io/dappnode/tropibot:latest"
pull=missing
[[ "$runner_image" == *:latest ]] && pull=always

output_dir="$(dirname "$GITHUB_OUTPUT")"
echo "Running bump-runner ${args[*]} (image ${runner_image})" >&2

# Run as the runner user so edited files keep their ownership; paths are
# mounted at the same locations so they mean the same thing inside.
exec docker run --rm --pull "$pull" \
  --user "$(id -u):$(id -g)" \
  --env GITHUB_TOKEN \
  --env RUST_LOG \
  --volume "$workspace:$workspace" \
  --volume "$output_dir:$output_dir" \
  --workdir "$workspace" \
  "$runner_image" \
  bump-runner "${args[@]}"

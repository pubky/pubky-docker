#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

BACKEND_ONLY=false

readonly GITHUB_CHECK_REPO="https://github.com/pubky/pubky-core.git"

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [--backend-only] [--help]

Clone the Pubky service repositories next to this directory, check out the
selected refs, build the local Docker images, and start the Docker stack.

Options:
  --backend-only  Skip the franky frontend service.
  --help          Show this help text.
USAGE
}

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' was not found."
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --backend-only)
        BACKEND_ONLY=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done
}

check_requirements() {
  require_command git
  require_command docker

  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker Compose is not available. Install Docker with Compose v2 support."
  fi
}

check_github_access() {
  log "Checking GitHub clone access..."

  if ! git ls-remote "$GITHUB_CHECK_REPO" HEAD >/dev/null 2>&1; then
    fail "Could not access GitHub via git. Check your network connection and Git/GitHub configuration, then try again."
  fi
}

copy_env_file() {
  local env_sample="$SCRIPT_DIR/.env-sample"
  local env_file="$SCRIPT_DIR/.env"

  [ -f "$env_sample" ] || fail "Missing $env_sample."

  if [ -f "$env_file" ]; then
    log "Using existing .env."
    return
  fi

  cp "$env_sample" "$env_file"
  log "Created .env from .env-sample."
}

default_branch_for() {
  local repo_url="$1"
  local branch

  branch="$(git ls-remote --symref "$repo_url" HEAD 2>/dev/null | sed -n 's#^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$#\1#p')"

  if [ -z "$branch" ]; then
    branch="main"
  fi

  printf '%s\n' "$branch"
}

prompt_ref() {
  local name="$1"
  local default_branch="$2"
  local ref

  printf 'Commit, tag, or branch for %s [%s]: ' "$name" "$default_branch" >&2
  IFS= read -r ref || ref=""

  if [ -z "$ref" ]; then
    ref="$default_branch"
  fi

  printf '%s\n' "$ref"
}

ensure_clean_repo() {
  local repo_dir="$1"
  local status

  status="$(git -C "$repo_dir" status --porcelain)"

  if [ -n "$status" ]; then
    fail "$repo_dir has local changes. Commit, stash, or clean them before changing refs."
  fi
}

checkout_ref() {
  local repo_dir="$1"
  local ref="$2"

  git -C "$repo_dir" fetch --tags origin

  if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$ref"; then
    git -C "$repo_dir" checkout --detach "origin/$ref"
    return
  fi

  git -C "$repo_dir" checkout --detach "$ref"
}

clone_or_update_repo() {
  local name="$1"
  local repo_url="$2"
  local target_dir="$3"
  local ref="$4"

  if [ -d "$target_dir/.git" ]; then
    log "Updating $name in $target_dir..."
    ensure_clean_repo "$target_dir"
    checkout_ref "$target_dir" "$ref"
    return
  fi

  if [ -e "$target_dir" ]; then
    fail "$target_dir exists but is not a Git repository."
  fi

  log "Cloning $name into $target_dir..."
  git clone "$repo_url" "$target_dir"
  checkout_ref "$target_dir" "$ref"
}

print_repo_summary() {
  local name="$1"
  local target_dir="$2"
  local commit

  commit="$(git -C "$target_dir" rev-parse --short HEAD)"
  log "Prepared $name at $commit."
}

prepare_repos() {
  local repos=(
    "pubky-nexus|https://github.com/pubky/pubky-nexus.git|pubky-nexus"
    "pubky-core|https://github.com/pubky/pubky-core.git|pubky-core"
    "homegate|https://github.com/pubky/homegate.git|homegate"
  )

  if [ "$BACKEND_ONLY" = false ]; then
    repos+=("franky|https://github.com/pubky/pubky-app.git|franky")
  fi

  local entry
  for entry in "${repos[@]}"; do
    local name repo_url dir_name target_dir default_branch ref

    IFS='|' read -r name repo_url dir_name <<EOF
$entry
EOF

    target_dir="$WORKSPACE_DIR/$dir_name"
    default_branch="$(default_branch_for "$repo_url")"
    ref="$(prompt_ref "$name" "$default_branch")"

    clone_or_update_repo "$name" "$repo_url" "$target_dir" "$ref"
    print_repo_summary "$name" "$target_dir"
  done
}

build_and_start_stack() {
  local -a compose_base
  local -a profiles
  local -a services

  compose_base=(docker compose --project-directory "$SCRIPT_DIR" --file "$SCRIPT_DIR/docker-compose.yml")
  profiles=(--profile backend)
  services=(homeserver nexusd homegate)

  if [ "$BACKEND_ONLY" = false ]; then
    profiles+=(--profile franky)
    services+=(franky)
  fi

  log "Building local Pubky images..."
  "${compose_base[@]}" "${profiles[@]}" build "${services[@]}"

  log "Starting Docker stack..."
  "${compose_base[@]}" "${profiles[@]}" up -d
}

main() {
  parse_args "$@"
  check_requirements
  check_github_access
  copy_env_file
  prepare_repos
  build_and_start_stack

  log "Pubky Docker stack is running."
}

main "$@"

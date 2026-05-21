#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

BACKEND_ONLY=false
BUILD_SERVICES=()
PREPARED_COMMITS=()

readonly GITHUB_CHECK_REPO="https://github.com/pubky/pubky-core.git"
readonly BUILD_STATE_FILE="$SCRIPT_DIR/.build-state"

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [--backend-only] [--help]

Clone the Pubky service repositories next to this directory, check out the
selected refs, build the local Docker images, and start the Docker stack.

Options:
  --backend-only  Skip the pubky-app frontend service.
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

required_services() {
  local services=(homeserver nexusd homegate)

  if [ "$BACKEND_ONLY" = false ]; then
    services+=(pubky-app)
  fi

  printf '%s\n' "${services[@]}"
}

previous_built_commit() {
  local service="$1"
  local existing_service
  local existing_commit

  [ -f "$BUILD_STATE_FILE" ] || return 0

  while read -r existing_service existing_commit; do
    if [ "$existing_service" = "$service" ]; then
      printf '%s\n' "$existing_commit"
      return 0
    fi
  done < "$BUILD_STATE_FILE"

  return 0
}

build_state_is_complete() {
  local service
  local commit

  [ -f "$BUILD_STATE_FILE" ] || return 1

  while IFS= read -r service; do
    commit="$(previous_built_commit "$service")"
    [ -n "$commit" ] || return 1
  done < <(required_services)
}

print_build_state() {
  local service
  local commit
  local short_commit

  log "Existing build state ($BUILD_STATE_FILE):"

  while IFS= read -r service; do
    commit="$(previous_built_commit "$service")"
    short_commit="${commit:0:12}"
    log "  $service: $short_commit"
  done < <(required_services)
}

maybe_offer_resume_prompt() {
  local choice

  build_state_is_complete || return 1

  print_build_state
  printf '\n[s] Start stack now  [c] Choose refs: ' >&2
  IFS= read -r choice || choice=""

  choice="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"

  case "$choice" in
    c|choose)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

mark_service_for_build_if_needed() {
  local service="$1"
  local commit="$2"
  local previous_commit

  PREPARED_COMMITS+=("$service|$commit")
  previous_commit="$(previous_built_commit "$service")"

  if [ "$previous_commit" = "$commit" ]; then
    log "Source unchanged for $service; skipping image build."
    return
  fi

  BUILD_SERVICES+=("$service")
}

record_built_commit() {
  local service="$1"
  local commit="$2"
  local state_dir
  local temp_file
  local existing_service
  local existing_commit

  state_dir="$(dirname "$BUILD_STATE_FILE")"
  temp_file="$BUILD_STATE_FILE.tmp"

  mkdir -p "$state_dir"

  if [ -f "$BUILD_STATE_FILE" ]; then
    while read -r existing_service existing_commit; do
      [ -n "$existing_service" ] || continue
      [ "$existing_service" != "$service" ] || continue
      printf '%s %s\n' "$existing_service" "$existing_commit"
    done < "$BUILD_STATE_FILE" > "$temp_file"
  else
    : > "$temp_file"
  fi

  printf '%s %s\n' "$service" "$commit" >> "$temp_file"
  mv "$temp_file" "$BUILD_STATE_FILE"
}

record_built_commits() {
  local entry
  local service
  local commit

  for entry in "${PREPARED_COMMITS[@]}"; do
    IFS='|' read -r service commit <<EOF
$entry
EOF
    record_built_commit "$service" "$commit"
  done
}

prepare_repos() {
  local repos=(
    "pubky-nexus|https://github.com/pubky/pubky-nexus.git|nexusd"
    "pubky-core|https://github.com/pubky/pubky-core.git|homeserver"
    "homegate|https://github.com/pubky/homegate.git|homegate"
  )

  if [ "$BACKEND_ONLY" = false ]; then
    repos+=("pubky-app|https://github.com/pubky/pubky-app.git|pubky-app")
  fi

  local entry
  for entry in "${repos[@]}"; do
    local name repo_url service target_dir default_branch ref commit

    IFS='|' read -r name repo_url service <<EOF
$entry
EOF

    target_dir="$WORKSPACE_DIR/$name"
    default_branch="$(default_branch_for "$repo_url")"
    ref="$(prompt_ref "$name" "$default_branch")"

    clone_or_update_repo "$name" "$repo_url" "$target_dir" "$ref"
    print_repo_summary "$name" "$target_dir"
    commit="$(git -C "$target_dir" rev-parse HEAD)"
    mark_service_for_build_if_needed "$service" "$commit"
  done
}

build_and_start_stack() {
  local -a compose_base
  local -a profiles

  compose_base=(docker compose --project-directory "$SCRIPT_DIR" --file "$SCRIPT_DIR/docker-compose.yml")
  profiles=(--profile backend)

  if [ "$BACKEND_ONLY" = false ]; then
    profiles+=(--profile pubky-app)
  fi

  if [ "${#BUILD_SERVICES[@]}" -gt 0 ]; then
    log "Building changed Pubky images: ${BUILD_SERVICES[*]}"
    "${compose_base[@]}" "${profiles[@]}" build "${BUILD_SERVICES[@]}"
    record_built_commits
  else
    log "No Pubky source changes detected; skipping image build."
  fi

  log "Starting Docker stack..."
  "${compose_base[@]}" "${profiles[@]}" up
}

main() {
  parse_args "$@"
  check_requirements
  copy_env_file

  if ! maybe_offer_resume_prompt; then
    check_github_access
    prepare_repos
  fi

  build_and_start_stack
  log "Pubky Docker stack is running."
}

main "$@"

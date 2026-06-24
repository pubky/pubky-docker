#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

NOT_RUNNING_SERVICES=()
PUBKY_SERVICES=(homeserver nexusd homegate pubky-app)
SUPPORTING_SERVICES=(postgres nexus-redis nexus-redisinsight nexus-neo4j homegate-prelude)
EXCLUDED_SERVICES=(homegate-db-init)

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME

Show the versions of software running in the Pubky Docker Compose containers.

By default, the script inspects every Compose service and runs a best-effort
version check inside each running container.

Options:
  --help  Show this help text.

Examples:
  ./$SCRIPT_NAME
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
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "This script does not accept service arguments."
        ;;
    esac
    shift
  done
}

compose() {
  docker compose --project-directory "$SCRIPT_DIR" --file "$SCRIPT_DIR/docker-compose.yml" "$@"
}

all_services() {
  compose --profile '*' config --services | sed '/^[[:space:]]*services:[[:space:]]*$/d'
}

service_is_available() {
  local needle="$1"
  local service

  for service in "${available_services[@]}"; do
    [ "$service" = "$needle" ] && return 0
  done

  return 1
}

service_is_excluded() {
  local needle="$1"
  local service

  for service in "${EXCLUDED_SERVICES[@]}"; do
    [ "$service" = "$needle" ] && return 0
  done

  return 1
}

service_was_printed() {
  local needle="$1"
  local service

  for service in "${printed_services[@]}"; do
    [ "$service" = "$needle" ] && return 0
  done

  return 1
}

order_services() {
  local service

  printed_services=()

  for service in "${PUBKY_SERVICES[@]}"; do
    if service_is_available "$service"; then
      printed_services+=("$service")
      printf '%s\n' "$service"
    fi
  done

  for service in "${SUPPORTING_SERVICES[@]}"; do
    if service_is_available "$service"; then
      printed_services+=("$service")
      printf '%s\n' "$service"
    fi
  done

  for service in "${available_services[@]}"; do
    if ! service_was_printed "$service"; then
      printed_services+=("$service")
      printf '%s\n' "$service"
    fi
  done
}

container_for_service() {
  local service="$1"
  local container

  container="$(compose ps --all -q "$service" 2>/dev/null || true)"
  if [ -n "$container" ]; then
    printf '%s\n' "$container"
    return 0
  fi

  container="$(docker ps -aq --filter "label=com.docker.compose.service=$service" 2>/dev/null | head -n 1 || true)"
  if [ -n "$container" ]; then
    printf '%s\n' "$container"
    return 0
  fi

  docker ps -aq --filter "name=^/${service}$" 2>/dev/null | head -n 1 || true
}

inspect_container() {
  local container="$1"
  local format="$2"

  docker inspect --format "$format" "$container" 2>/dev/null || true
}

inspect_image() {
  local image="$1"
  local format="$2"

  docker image inspect --format "$format" "$image" 2>/dev/null || true
}

format_timestamp() {
  local timestamp="$1"
  local formatted=""

  formatted="$(date -u -d "$timestamp" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || true)"
  if [ -n "$formatted" ]; then
    printf '%s\n' "$formatted"
  else
    printf '%s\n' "$timestamp"
  fi
}

version_probe_for_service() {
  local service="$1"

  case "$service" in
    postgres)
      printf '%s\n' 'postgres --version || psql --version'
      ;;
    homeserver)
      printf '%s\n' 'password=$(sed -n "s/^[[:space:]]*admin_password[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" /config.toml | tail -n 1); listen=$(sed -n "s/^[[:space:]]*listen_socket[[:space:]]*=[[:space:]]*\"\(.*\)\".*/\1/p" /config.toml | tail -n 1); port="${listen##*:}"; body=$(wget -qO- --header "X-Admin-Password: $password" "http://127.0.0.1:${port:-6288}/info"); printf "%s\n" "$body" | sed -n "s/.*\"version\":\"\([^\"]*\)\".*/homeserver \1/p"'
      ;;
    nexusd)
      printf '%s\n' 'body=$(wget -qO- http://127.0.0.1:8080/v0/info); version=$(printf "%s\n" "$body" | sed -n "s/.*\"version\":\"\([^\"]*\)\".*/\1/p"); commit=$(printf "%s\n" "$body" | sed -n "s/.*\"commit_hash\":\"\([^\"]*\)\".*/\1/p"); if [ -n "$version" ]; then if [ -n "$commit" ]; then printf "nexusd %s (%s)\n" "$version" "$commit"; else printf "nexusd %s\n" "$version"; fi; fi'
      ;;
    nexus-neo4j)
      printf '%s\n' '/var/lib/neo4j/bin/neo4j --version | sed "s/^/neo4j /" || /var/lib/neo4j/bin/cypher-shell --version'
      ;;
    nexus-redis)
      printf '%s\n' 'redis-server --version || redis-cli --version'
      ;;
    nexus-redisinsight)
      printf '%s\n' 'body=$(wget -qO- http://127.0.0.1:5540/api/info); version=$(printf "%s\n" "$body" | sed -n "s/.*\"appVersion\":\"\([^\"]*\)\".*/\1/p"); [ -n "$version" ] && printf "redisinsight %s\n" "$version"'
      ;;
    homegate-prelude)
      printf '%s\n' 'java -jar /var/wiremock/lib/wiremock-standalone.jar --version || java -jar /var/wiremock/lib/wiremock.jar --version'
      ;;
    homegate)
      printf '%s\n' 'homegate --version || pubky-homegate --version || /usr/local/bin/homegate --version'
      ;;
    pubky-app)
      printf '%s\n' 'node -e "const fs=require(\"fs\"); for (const p of [\"/app/package.json\",\"/usr/src/app/package.json\",\"/package.json\"]) if (fs.existsSync(p)) { const pkg=require(p); console.log([pkg.name,pkg.version].filter(Boolean).join(\" \")); process.exit(0); } process.exit(1)"'
      ;;
    *)
      return 1
      ;;
  esac
}

exec_version_probe() {
  local container="$1"
  local service="$2"
  local probe

  probe="$(version_probe_for_service "$service" || true)"
  [ -n "$probe" ] || return 0

  docker exec "$container" sh -lc "$probe" 2>/dev/null | sed 's/^/  version: /' || true
}

print_image_build_date() {
  local image_id="$1"
  local image_created=""

  image_created="$(inspect_image "$image_id" "{{ .Created }}")"
  if [ -n "$image_created" ]; then
    log "  image built: $(format_timestamp "$image_created")"
  fi
}

print_service_version() {
  local service="$1"
  local container=""
  local state=""
  local image_id=""
  local exec_output=""

  container="$(container_for_service "$service")"

  if [ -z "$container" ]; then
    NOT_RUNNING_SERVICES+=("$service")
    return 0
  fi

  state="$(inspect_container "$container" '{{ .State.Status }}')"
  image_id="$(inspect_container "$container" '{{ .Image }}')"

  if [ "$state" != "running" ]; then
    NOT_RUNNING_SERVICES+=("$service")
    return 0
  fi
  log "$service"
  exec_output="$(exec_version_probe "$container" "$service")"
  if [ -n "$exec_output" ]; then
    printf '%s\n' "$exec_output"
  else
    log "  version: unavailable inside container"
  fi
  print_image_build_date "$image_id"

  log ""
}

print_not_running_services() {
  local service

  if [ "${#NOT_RUNNING_SERVICES[@]}" -eq 0 ]; then
    return 0
  fi

  log "The following containers are not running:"
  for service in "${NOT_RUNNING_SERVICES[@]}"; do
    log "  $service"
  done
}

main() {
  local service
  local -a available_services=()
  local -a printed_services=()

  parse_args "$@"
  require_command docker

  if ! docker compose version >/dev/null 2>&1; then
    fail "Docker Compose is not available. Install Docker with Compose v2 support."
  fi

  while IFS= read -r service; do
    [ -n "$service" ] || continue
    service_is_excluded "$service" && continue
    available_services+=("$service")
  done < <(all_services)

  while IFS= read -r service; do
    [ -n "$service" ] || continue
    print_service_version "$service"
  done < <(order_services)

  print_not_running_services
}

main "$@"

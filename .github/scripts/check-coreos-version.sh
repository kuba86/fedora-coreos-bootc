#!/usr/bin/env bash
# Purpose: Compare the Fedora CoreOS "stable" stream last-modified date with a GHCR image config creation date.
# Exits with success; sets GitHub Actions output newer-version-available=true/false accordingly.
# Requirements: bash, curl, jq, date (GNU coreutils). Network access required.

set -euo pipefail

# Configurable via environment
NAME="${NAME:-kuba86/fedora-coreos-bootc}"
TAG="${TAG:-stable}"
STREAM_URL="${STREAM_URL:-https://builds.coreos.fedoraproject.org/streams/stable.json}"
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"

# Optional: When running under GitHub Actions, GITHUB_OUTPUT is set. Fallback to stdout-only if not set.
GITHUB_OUTPUT_FILE="${GITHUB_OUTPUT:-}"

# Retry helper for transient network errors
retry() {
  local -r max_attempts="${1:-3}"
  shift
  local -i attempt=1
  local delay=2
  until "$@"; do
    if (( attempt >= max_attempts )); then
      return 1
    fi
    sleep "$delay"
    attempt=$(( attempt + 1 ))
    delay=$(( delay * 2 ))
  done
}

log() {
  printf '%s %s\n' "[check-coreos-version]" "$*" >&2
}

set_output() {
  local kv="$1"
  if [[ -n "$GITHUB_OUTPUT_FILE" ]]; then
    printf '%s\n' "$kv" >> "$GITHUB_OUTPUT_FILE"
  else
    printf '%s\n' "$kv"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "Missing dependency: $1"; exit 2; }
}

require_cmd curl
require_cmd jq
require_cmd date

# Fetch registry token
get_token() {
  local url="https://${REGISTRY_HOST}/token?service=${REGISTRY_HOST}&scope=repository:${NAME}:pull"
  retry 4 curl -fsSL "$url" | jq -r '.token'
}

# Fetch image manifest (Docker or OCI)
get_manifest() {
  local token="$1"
  local url="https://${REGISTRY_HOST}/v2/${NAME}/manifests/${TAG}"
  retry 4 curl -fsSL \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
    "$url"
}

# Fetch config blob and extract created date
get_image_created() {
  local token="$1"
  local config_digest="$2"
  local url="https://${REGISTRY_HOST}/v2/${NAME}/blobs/${config_digest}"
  retry 4 curl -fsSL -H "Authorization: Bearer ${token}" "$url" | jq -r '.created'
}

# Fetch CoreOS stream last-modified
get_coreos_last_modified() {
  retry 4 curl -fsSL "$STREAM_URL" | jq -r '.metadata["last-modified"]'
}

main() {
  log "Checking ${NAME}:${TAG} against ${STREAM_URL}"

  local token
  token="$(get_token)"
  if [[ -z "$token" || "$token" == "null" ]]; then
    log "Failed to obtain registry token"
    exit 3
  fi

  local manifest_json
  manifest_json="$(get_manifest "$token")"
  if [[ -z "$manifest_json" ]]; then
    log "Failed to fetch manifest for ${NAME}:${TAG}"
    exit 4
  fi

  local config_digest
  config_digest="$(jq -r '.config.digest // empty' <<<"$manifest_json")"
  if [[ -z "$config_digest" ]]; then
    log "Manifest missing config.digest"
    exit 5
  fi

  local image_created coreos_last_modified
  image_created="$(get_image_created "$token" "$config_digest")"
  coreos_last_modified="$(get_coreos_last_modified)"

  if [[ -z "$image_created" || "$image_created" == "null" ]]; then
    log "Image config lacks .created timestamp"
    exit 6
  fi
  if [[ -z "$coreos_last_modified" || "$coreos_last_modified" == "null" ]]; then
    log "CoreOS stream lacks metadata.last-modified"
    exit 7
  fi

  # Normalize to epoch seconds (GNU date expected)
  local image_ts coreos_ts
  if ! image_ts="$(date -d "$image_created" +%s 2>/dev/null)"; then
    log "Unable to parse image created date: $image_created"
    exit 8
  fi
  if ! coreos_ts="$(date -d "$coreos_last_modified" +%s 2>/dev/null)"; then
    log "Unable to parse CoreOS last-modified date: $coreos_last_modified"
    exit 9
  fi

  # Decision: if CoreOS is newer than the image, rebuild is needed
  if (( coreos_ts > image_ts )); then
    log "CoreOS stream is newer (${coreos_last_modified}) than image (${image_created}); rebuild required"
    set_output "newer-version-available=true"
  else
    log "Image (${image_created}) is up-to-date vs CoreOS (${coreos_last_modified}); no rebuild needed"
    set_output "newer-version-available=false"
  fi
}

main

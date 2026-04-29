#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/../.github/scripts" && pwd)"
  export SCRIPT_PATH="$SCRIPT_DIR/check-fedora-coreos-version.sh"

  # Setup temp directory for mocks
  export TEMP_DIR="$(mktemp -d)"
  export PATH="$TEMP_DIR:$PATH"

  # Setup GitHub outputs file
  export GITHUB_OUTPUT="$(mktemp)"

  # Default environment variables
  export GITHUB_EVENT_NAME="schedule"
  export GITHUB_TOKEN="fake_token"
  export REGISTRY="ghcr.io"
  export GITHUB_ACTOR="fake_actor"
  export IMAGE_NAME="kuba86/fedora-coreos-bootc"
}

teardown() {
  rm -rf "$TEMP_DIR"
  rm -f "$GITHUB_OUTPUT"
}

create_mock() {
  local cmd_name="$1"
  local content="$2"
  local mock_path="$TEMP_DIR/$cmd_name"
  echo "#!/bin/bash" > "$mock_path"
  echo "$content" >> "$mock_path"
  chmod +x "$mock_path"
}

@test "Builds on non-schedule event" {
  export GITHUB_EVENT_NAME="push"

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Not a scheduled run. Build required."* ]]
  grep -q "should_build=true" "$GITHUB_OUTPUT"
}

@test "Fails if upstream curl fails or returns empty/null" {
  create_mock "curl" "echo '{}'"

  run "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to get upstream last-modified timestamp"* ]]
}

@test "Fails if upstream timestamp is empty" {
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"\"}}'"

  run "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to get upstream last-modified timestamp"* ]]
}

@test "Builds if image is not found on registry" {
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"2023-01-01T00:00:00Z\"}}'"

  create_mock "skopeo" '
  if [[ "$1" == "login" ]]; then exit 0; fi
  if [[ "$1" == "inspect" ]]; then exit 1; fi
  '

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Image not found on registry. Build required."* ]]
  grep -q "should_build=true" "$GITHUB_OUTPUT"
}

@test "Builds if current image Created timestamp is null" {
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"2023-01-01T00:00:00Z\"}}'"

  create_mock "skopeo" '
  if [[ "$1" == "login" ]]; then exit 0; fi
  if [[ "$1" == "inspect" ]]; then echo "{\"Created\": null}"; exit 0; fi
  '

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: Failed to get current image creation timestamp. Build required."* ]]
  grep -q "should_build=true" "$GITHUB_OUTPUT"
}

@test "Builds if upstream is newer than current image" {
  # Upstream is from Jan 2
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"2023-01-02T00:00:00Z\"}}'"

  # Current is from Jan 1
  create_mock "skopeo" '
  if [[ "$1" == "login" ]]; then exit 0; fi
  if [[ "$1" == "inspect" ]]; then echo "{\"Created\": \"2023-01-01T00:00:00Z\"}"; exit 0; fi
  '

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Upstream is newer"* ]]
  [[ "$output" == *"Build required."* ]]
  grep -q "should_build=true" "$GITHUB_OUTPUT"
}

@test "Skips build if current image is up to date (newer or equal to upstream)" {
  # Upstream is from Jan 1
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"2023-01-01T00:00:00Z\"}}'"

  # Current is from Jan 2
  create_mock "skopeo" '
  if [[ "$1" == "login" ]]; then exit 0; fi
  if [[ "$1" == "inspect" ]]; then echo "{\"Created\": \"2023-01-02T00:00:00Z\"}"; exit 0; fi
  '

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Image is up to date. Skipping build."* ]]
  grep -q "should_build=false" "$GITHUB_OUTPUT"
}

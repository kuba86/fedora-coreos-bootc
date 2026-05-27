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

@test "Fails if skopeo login fails" {
  create_mock "curl" "echo '{\"metadata\": {\"last-modified\": \"2023-01-01T00:00:00Z\"}}'"
  create_mock "skopeo" "exit 1"

  run "$SCRIPT_PATH"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to login to GHCR"* ]]
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

@test "Skips notification when NTFY_URL is not set" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_TOPIC="my-topic"
  unset NTFY_URL

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Notification skipped: NTFY_URL or NTFY_TOPIC not set."* ]]
}

@test "Skips notification when NTFY_TOPIC is not set" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_URL="https://ntfy.example.com"
  unset NTFY_TOPIC

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Notification skipped: NTFY_URL or NTFY_TOPIC not set."* ]]
}

@test "Sends notification on non-schedule event" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_URL="https://ntfy.example.com"
  export NTFY_TOPIC="my-topic"

  create_mock "curl" "echo 'ok'; exit 0"

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Sending notification: Fedora CoreOS: Manual or push trigger detected, starting build."* ]]
  [[ "$output" == *"Notification sent successfully."* ]]
}

@test "Sends notification with token when provided" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_URL="https://ntfy.example.com/"
  export NTFY_TOPIC="my-topic"
  export NTFY_TOKEN="secret-token"

  create_mock "curl" '
  # Check if Authorization header is present
  if [[ "$*" == *"-H Authorization: Bearer secret-token"* ]]; then
    echo "Auth header found"
  else
    echo "Auth header missing"
    exit 1
  fi
  # Check if URL is correct (handles trailing slash in NTFY_URL)
  if [[ "$*" == *"https://ntfy.example.com/my-topic"* ]]; then
    echo "URL correct"
  else
    echo "URL incorrect: $*"
    exit 1
  fi
  exit 0
  '

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Notification sent successfully."* ]]
}

@test "Gracefully handles notification failure" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_URL="https://ntfy.example.com"
  export NTFY_TOPIC="my-topic"

  create_mock "curl" "exit 1"

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: Failed to send notification."* ]]
}

@test "send_notification uses --data-raw to prevent file inclusion via @ symbol" {
  export GITHUB_EVENT_NAME="push"
  export NTFY_URL="https://ntfy.example.com"
  export NTFY_TOPIC="my-topic"

  # We mock curl to capture the arguments it was called with
  create_mock "curl" 'echo "$@" > "$TEMP_DIR/curl_args"; exit 0'

  run "$SCRIPT_PATH"

  [ "$status" -eq 0 ]
  # Check if curl was called with --data-raw
  grep -q "\-\-data-raw" "$TEMP_DIR/curl_args"
}

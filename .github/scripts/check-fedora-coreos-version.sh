#!/bin/bash
set -e

# 1. Check Event Type
# Always build on non-schedule events (push, workflow_dispatch)
if [ "$GITHUB_EVENT_NAME" != "schedule" ]; then
  echo "Not a scheduled run. Build required."
  echo "should_build=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

# 2. Get Upstream Timestamp
UPSTREAM_JSON=$(curl -fsSL "https://builds.coreos.fedoraproject.org/streams/stable.json")
UPSTREAM_LAST_MODIFIED=$(echo "$UPSTREAM_JSON" | jq -r '.metadata["last-modified"]')
echo "Upstream Last Modified: $UPSTREAM_LAST_MODIFIED"

# 3. Get Current Image Timestamp
# Login to GHCR to inspect the image
echo "$GITHUB_TOKEN" | skopeo login "$REGISTRY" -u "$GITHUB_ACTOR" --password-stdin

# Check if image exists. If not, we must build.
if ! IMAGE_INFO=$(skopeo inspect docker://${REGISTRY}/${IMAGE_NAME}:stable 2>/dev/null); then
  echo "Image not found on registry. Build required."
  echo "should_build=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

CURRENT_CREATED=$(echo "$IMAGE_INFO" | jq -r '.Created')
echo "Current Image Created: $CURRENT_CREATED"

# 4. Compare Timestamps (convert to epoch seconds)
TS_UPSTREAM=$(date -d "$UPSTREAM_LAST_MODIFIED" +%s)
TS_CURRENT=$(date -d "$CURRENT_CREATED" +%s)

if [ "$TS_UPSTREAM" -gt "$TS_CURRENT" ]; then
  echo "Upstream is newer ($TS_UPSTREAM > $TS_CURRENT). Build required."
  echo "should_build=true" >> "$GITHUB_OUTPUT"
else
  echo "Image is up to date. Skipping build."
  echo "should_build=false" >> "$GITHUB_OUTPUT"
fi

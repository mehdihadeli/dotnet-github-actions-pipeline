#!/bin/sh

set -eu

DT_API_BASE_URL="${DT_API_BASE_URL:-http://dtrack-apiserver:8080}"
TRIVY_BASE_URL="${TRIVY_BASE_URL:-http://trivy:8080}"
DEPENDENCY_TRACK_API_KEY="${DEPENDENCY_TRACK_API_KEY:-}"
TRIVY_SERVER_TOKEN="${TRIVY_SERVER_TOKEN:-}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-false}"

if [ -z "$DEPENDENCY_TRACK_API_KEY" ]; then
  echo "DEPENDENCY_TRACK_API_KEY not set. Skip Trivy bootstrap."
  exit 0
fi

if [ -z "$TRIVY_SERVER_TOKEN" ]; then
  echo "TRIVY_SERVER_TOKEN not set. Cannot configure Trivy analyzer."
  exit 1
fi

echo "Waiting for Dependency-Track backend..."
attempt=0
until curl -fsS "$DT_API_BASE_URL/api/openapi.json" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Dependency-Track backend did not become ready in time."
    exit 1
  fi
  sleep 5
done

echo "Waiting for Trivy server..."
attempt=0
until curl -fsS "$TRIVY_BASE_URL/healthz" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Trivy server did not become ready in time."
    exit 1
  fi
  sleep 5
done

payload=$(cat <<EOF
[
  {
    "groupName": "scanner",
    "propertyName": "trivy.enabled",
    "propertyValue": "true"
  },
  {
    "groupName": "scanner",
    "propertyName": "trivy.base.url",
    "propertyValue": "$TRIVY_BASE_URL"
  },
  {
    "groupName": "scanner",
    "propertyName": "trivy.api.token",
    "propertyValue": "$TRIVY_SERVER_TOKEN"
  },
  {
    "groupName": "scanner",
    "propertyName": "trivy.ignore.unfixed",
    "propertyValue": "$TRIVY_IGNORE_UNFIXED"
  }
]
EOF
)

echo "Configuring Dependency-Track Trivy analyzer..."
curl -fsS \
  -X POST \
  "$DT_API_BASE_URL/api/v1/configProperty/aggregate" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $DEPENDENCY_TRACK_API_KEY" \
  -d "$payload" >/dev/null

echo "Dependency-Track Trivy analyzer configured."
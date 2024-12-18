#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

INPUT_USERNAME=${INPUT_USERNAME:-}
INPUT_DOCKER_NETWORK=${INPUT_DOCKER_NETWORK:-}
JOB_CONTAINER_NAME=${JOB_CONTAINER_NAME:-}
INPUT_MOUNT_WS=${INPUT_MOUNT_WS:-}
INPUT_OPTIONS=${INPUT_OPTIONS:-}
INPUT_RUN=${INPUT_RUN:-}

if [[ ! -z "$INPUT_USERNAME" ]]; then
  echo "$INPUT_PASSWORD" | docker login "$INPUT_REGISTRY" -u "$INPUT_USERNAME" --password-stdin
fi

if [[ ! -z "$INPUT_DOCKER_NETWORK" ]]; then
  INPUT_OPTIONS+=("--network=$INPUT_DOCKER_NETWORK")
fi

if [[ "$INPUT_MOUNT_WS" = "true" ]]; then
  if [[ ! -z "$JOB_CONTAINER_NAME" ]]; then
    # If JOB_CONTAINER_NAME exists, use --volumes-from (Gitea support)
    INPUT_OPTIONS+=("--volumes-from=$JOB_CONTAINER_NAME")
    INPUT_OPTIONS+=("-w=${GITHUB_WORKSPACE}")
  else
    REPO=${GITHUB_REPOSITORY//$GITHUB_REPOSITORY_OWNER/}
    WS="$RUNNER_WORKSPACE$REPO"
    INPUT_OPTIONS+=("-v=$WS:$WS")
    INPUT_OPTIONS+=("-w=$WS")
  fi
else
  if [[ ! -z "$INPUT_MOUNT_WS" && "$INPUT_MOUNT_WS" != "false" ]]; then
    WS=$INPUT_MOUNT_WS
    INPUT_OPTIONS+=("-v=$WS:$WS")
    INPUT_OPTIONS+=("-w=$WS")
  fi
fi

if [[ -z "$JOB_CONTAINER_NAME" ]]; then
  # needed for various Github envs and outputs
  # for Gitea just use mount_ws: true
  INPUT_OPTIONS+=("-v=/home/runner/work/_temp:/home/runner/work/_temp")
fi

echo "Docker run options: ${INPUT_OPTIONS[@]}"
INPUT_RUN="${INPUT_RUN//$'\n'/;}"
echo "Running: $INPUT_RUN"

# podman socket workaround, fixed in newer versions: https://github.com/containers/podman/issues/18889
IMAGE_ID=$(
  docker create \
    -e GITHUB_ENV -e GITHUB_OUTPUT -e GITHUB_PATH -e GITHUB_STATE -e GITHUB_STEP_SUMMARY \
    -v "$INPUT_SOCKET:/var/run/docker.sock" \
    ${INPUT_OPTIONS[@]} \
    --entrypoint="$INPUT_SHELL" \
    "$INPUT_IMAGE" \
    -c "$INPUT_RUN"
)
docker start $IMAGE_ID
CODE=$(docker wait $IMAGE_ID)
docker logs $IMAGE_ID
echo "Complete code: $CODE"
docker rm $IMAGE_ID
exit $CODE
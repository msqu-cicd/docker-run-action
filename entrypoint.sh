#!/bin/bash
set -eo pipefail
IFS=$'\n\t '

if [ ! -z "$INPUT_USERNAME" ]; then
  echo "$INPUT_PASSWORD" | docker login "$INPUT_REGISTRY" -u "$INPUT_USERNAME" --password-stdin
fi

if [ ! -z "$INPUT_DOCKER_NETWORK" ]; then
  INPUT_OPTIONS="$INPUT_OPTIONS --network $INPUT_DOCKER_NETWORK"
fi

if [ "$INPUT_MOUNT_WS" = "true" ]; then
  if [ -n "$JOB_CONTAINER_NAME" ]; then
    # If JOB_CONTAINER_NAME exists, use --volumes-from (Gitea support)
    INPUT_OPTIONS="$INPUT_OPTIONS --volumes-from=$JOB_CONTAINER_NAME -w ${GITHUB_WORKSPACE}"
  else
    REPO=${GITHUB_REPOSITORY//$GITHUB_REPOSITORY_OWNER/}
    WS="$RUNNER_WORKSPACE$REPO"
    INPUT_OPTIONS="$INPUT_OPTIONS -v $WS:$WS -w $WS"
  fi
else
  if [[ -n "$INPUT_MOUNT_WS" && "$INPUT_MOUNT_WS" != "false" ]]; then
    WS=$INPUT_MOUNT_WS
    INPUT_OPTIONS="$INPUT_OPTIONS -v $WS:$WS -w $WS"
  fi
fi

echo "Docker run options: ${INPUT_OPTIONS}"

docker run --rm -v "/var/run/docker.sock":"/var/run/docker.sock" $INPUT_OPTIONS --entrypoint="$INPUT_SHELL" "$INPUT_IMAGE" -c "${INPUT_RUN//$'\n'/;}"

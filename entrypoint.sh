#!/usr/bin/env bash
set -e

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
    # If JOB_CONTAINER_NAME does not exist, mount the workspace
    if [ -z "$GITHUB_WORKSPACE" ]; then
      echo "GITHUB_WORKSPACE environment variable not set."
      exit 1
    fi
    INPUT_OPTIONS="$INPUT_OPTIONS -v ${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE} -w ${GITHUB_WORKSPACE}"
  fi
fi

echo "Docker run options: ${INPUT_OPTIONS}"

exec docker run --rm -v "/var/run/docker.sock":"/var/run/docker.sock" $INPUT_OPTIONS --entrypoint="$INPUT_SHELL" "$INPUT_IMAGE" -c "${INPUT_RUN//$'\n'/;}"

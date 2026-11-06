#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

INPUT_USERNAME=${INPUT_USERNAME:-}
INPUT_PASSWORD=${INPUT_PASSWORD:-}
INPUT_REGISTRY=${INPUT_REGISTRY:-}
INPUT_DOCKER_NETWORK=${INPUT_DOCKER_NETWORK:-}
JOB_CONTAINER_NAME=${JOB_CONTAINER_NAME:-}
INPUT_MOUNT_WS=${INPUT_MOUNT_WS:-}
INPUT_OPTIONS=${INPUT_OPTIONS:-}
INPUT_RUN=${INPUT_RUN:-}
INPUT_SOCKET=${INPUT_SOCKET:-}
INPUT_SHELL=${INPUT_SHELL:-/bin/sh}
INPUT_IMAGE=${INPUT_IMAGE:-}
RUNNER_TEMP=${RUNNER_TEMP:-}

if [[ -z "$INPUT_IMAGE" ]]; then
  echo "::error::input 'image' is required" >&2
  exit 1
fi

CONTAINER_ID=""
DOCKER_CONFIG_TMP=""
WAIT_FILE=""

cleanup() {
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm -f "$CONTAINER_ID" > /dev/null 2>&1 || true
  fi
  if [[ -n "$DOCKER_CONFIG_TMP" ]]; then
    rm -rf "$DOCKER_CONFIG_TMP"
  fi
  if [[ -n "$WAIT_FILE" ]]; then
    rm -f "$WAIT_FILE"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -n "$INPUT_USERNAME" ]]; then
  # Keep registry credentials out of the runner's ~/.docker/config.json;
  # the temporary config directory is removed again on exit.
  DOCKER_CONFIG_TMP=$(mktemp -d)
  export DOCKER_CONFIG="$DOCKER_CONFIG_TMP"
  if [[ -n "$INPUT_REGISTRY" ]]; then
    echo "$INPUT_PASSWORD" | docker login "$INPUT_REGISTRY" -u "$INPUT_USERNAME" --password-stdin
  else
    echo "$INPUT_PASSWORD" | docker login -u "$INPUT_USERNAME" --password-stdin
  fi
fi

# Split the options string on whitespace, like a shell command line would be.
OPTS=()
if [[ -n "$INPUT_OPTIONS" ]]; then
  IFS=$' \t\n' read -r -d '' -a OPTS <<< "$INPUT_OPTIONS" || true
fi

if [[ -n "$INPUT_DOCKER_NETWORK" ]]; then
  OPTS+=("--network=$INPUT_DOCKER_NETWORK")
fi

if [[ -n "$INPUT_SOCKET" ]]; then
  OPTS+=("-v" "$INPUT_SOCKET:/var/run/docker.sock")
fi

if [[ "$INPUT_MOUNT_WS" = "true" ]]; then
  if [[ -n "$JOB_CONTAINER_NAME" ]]; then
    # If JOB_CONTAINER_NAME exists, use --volumes-from (Gitea support)
    OPTS+=("--volumes-from=$JOB_CONTAINER_NAME")
    OPTS+=("-w=${GITHUB_WORKSPACE}")
  else
    REPO="/${GITHUB_REPOSITORY#*/}"
    WS="$RUNNER_WORKSPACE$REPO"
    OPTS+=("-v=$WS:$WS")
    OPTS+=("-w=$WS")
  fi
else
  if [[ -n "$INPUT_MOUNT_WS" && "$INPUT_MOUNT_WS" != "false" ]]; then
    WS=$INPUT_MOUNT_WS
    OPTS+=("-v=$WS:$WS")
    OPTS+=("-w=$WS")
  fi
fi

if [[ -z "$JOB_CONTAINER_NAME" && -n "$RUNNER_TEMP" ]]; then
  # needed for various Github envs and outputs
  # for Gitea just use mount_ws: true
  OPTS+=("-v=$RUNNER_TEMP:$RUNNER_TEMP")
fi

# Log the options with env var values redacted: only values registered as
# secrets get masked by the runner, anything else would leak into the log.
LOG_OPTS=""
mask_next=0
for opt in ${OPTS[@]+"${OPTS[@]}"}; do
  if [[ "$mask_next" = "1" ]]; then
    mask_next=0
    if [[ "$opt" == *=* ]]; then
      LOG_OPTS+=" ${opt%%=*}=***"
    else
      LOG_OPTS+=" $opt"
    fi
  elif [[ "$opt" == "-e" || "$opt" == "--env" ]]; then
    mask_next=1
    LOG_OPTS+=" $opt"
  elif [[ "$opt" == -e=*=* || "$opt" == --env=*=* ]]; then
    flag=${opt%%=*}
    kv=${opt#*=}
    LOG_OPTS+=" $flag=${kv%%=*}=***"
  else
    LOG_OPTS+=" $opt"
  fi
done
echo "Docker run options:$LOG_OPTS"

# podman socket workaround, fixed in newer versions: https://github.com/containers/podman/issues/18889
CONTAINER_ID=$(
  docker create \
    -e GITHUB_ENV -e GITHUB_OUTPUT -e GITHUB_PATH -e GITHUB_STATE -e GITHUB_STEP_SUMMARY \
    ${OPTS[@]+"${OPTS[@]}"} \
    --entrypoint="$INPUT_SHELL" \
    "$INPUT_IMAGE" \
    -c "$INPUT_RUN"
)
docker start "$CONTAINER_ID" > /dev/null
docker logs -f "$CONTAINER_ID" &
LOGS_PID=$!

# Run docker wait in the background so bash can react to SIGTERM (job
# cancellation) immediately; the EXIT trap then removes the container.
WAIT_FILE=$(mktemp)
docker wait "$CONTAINER_ID" > "$WAIT_FILE" &
wait "$!"
CODE=$(cat "$WAIT_FILE")

# Collect the remaining log output before removing the container.
wait "$LOGS_PID" 2> /dev/null || true

echo "Complete code: $CODE"
exit "$CODE"

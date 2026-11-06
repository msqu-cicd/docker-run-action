# Docker Run Action

- Suitable for use with [Gitea Actions](https://docs.gitea.com/next/usage/actions/overview)
- Run a specific step in a Docker image.
- Run an image built by a previous step.
- See https://git.msqu.de/CICD/docker-run-action/src/branch/main/action.yml for all the available inputs.

## Inputs

| Input            | Default                | Description                                                                                                        |
| ---------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `image`          | (required)             | Image to run.                                                                                                      |
| `run`            |                        | Script to run in the container. Multi-line scripts are passed to the shell unchanged.                              |
| `shell`          | `/bin/sh`              | Shell used as the container entrypoint. Must be installed in the image.                                            |
| `options`        |                        | Extra `docker create` options, split on whitespace (values containing spaces are not supported).                   |
| `registry`       |                        | Registry to log in to (Docker Hub if empty).                                                                       |
| `username`       |                        | Registry username. Login uses a temporary `DOCKER_CONFIG` that is deleted when the step ends.                      |
| `password`       |                        | Registry password.                                                                                                 |
| `docker_network` | `${{ job.container.network }}` | Docker network for the container.                                                                           |
| `mount_ws`       | `false`                | `true` mounts the workspace and uses it as working directory; a path mounts that directory instead.                |
| `socket`         | `/var/run/docker.sock` | Docker socket path mounted into the container. Set to an empty string to not mount the socket.                     |

### Security note

By default the host Docker socket is mounted into the started container, which
gives the image root-equivalent control over the runner host. When the `run`
script does not need Docker, disable the mount:

```yaml
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    image: alpine:latest
    socket: ''
    run: echo "no docker socket in here"
```

### Gitea notes

- With `mount_ws: true` the workspace is mounted via `--volumes-from` when the
  runner exports `JOB_CONTAINER_NAME` (the name of the job container). If the
  act_runner version in use does not export it, the GitHub path logic is used
  as a fallback.
- `mount_ws: true` is also what makes `$GITHUB_OUTPUT`/`$GITHUB_ENV` writable
  from inside the started container on Gitea.

## Examples

#### Typical Use Case

```yaml
- name: Checkout
  uses: https://github.com/actions/checkout@v5
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
    registry: gcr.io
    image: private-image:latest
    options: -v ${{ github.workspace }}:/work -e ABC=123
    run: |
      echo "Running Script"
      /work/run-script
```

#### Run a Privately-Owned Image
```yaml
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
    registry: gcr.io
    image: test-image:latest
    run: echo "hello world"
```

#### Run an Image Built by a Previous Step
```yaml
- uses: https://github.com/docker/build-push-action@v4
  with:
    tags: test-image:latest
    push: false
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    image: test-image:latest
    run: echo "hello world"
```

#### Use a Specific Shell (Default: /bin/sh)
*Note: The shell must be installed in the container.*
```yaml
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    image: ubuntu:latest
    shell: bash
    run: |
      echo "first line"
      echo "second line"
```

#### Mount Workspace with a Custom Directory
```yaml
- uses: https://git.msqu.de/CICD/docker-run-action@v6.0.0
  with:
    image: docker:latest
    mount_ws: /custom/path
    run: cat /custom/path/someFile
```

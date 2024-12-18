# Docker Run Action

- Suitable for use with [Gitea Actions](https://docs.gitea.com/next/usage/actions/overview)
- Run a specific step in a Docker image.
- Run an image built by a previous step.
- See https://github.com/frozen-tapestry/docker-run-action/blob/v6/action.yml for all the available inputs.

## Examples

#### Typical Use Case

```yaml
- name: Checkout 
  uses: actions/checkout@v4 # Required to mount the GitHub Workspace to a volume 
- uses: frozen-tapestry/docker-run-action@v6
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
- uses: frozen-tapestry/docker-run-action@v6
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
    registry: gcr.io
    image: test-image:latest
    run: echo "hello world"
```

#### Run an Image Built by a Previous Step
```yaml
- uses: docker/build-push-action@v4
  with:
    tags: test-image:latest
    push: false
- uses: frozen-tapestry/docker-run-action@v6
  with:
    image: test-image:latest
    run: echo "hello world"
```

#### Use a Specific Shell (Default: /bin/sh)
*Note: The shell must be installed in the container.*
```yaml
- uses: frozen-tapestry/docker-run-action@v6
  with:
    image: docker:latest
    shell: bash
    run: |
      echo "first line"
      echo "second line"
```

#### Mount Workspace with a Custom Directory
```yaml
- uses: frozen-tapestry/docker-run-action@v6
  with:
    image: docker:latest
    mount_ws: /custom/path
    run: cat /custom/path/someFile
```
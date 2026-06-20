# Antigravity CLI Container

## Image Builds

### Automated Builds

A Github action is defined in `.github/workflows/publish.yml` to build a new image and push this to Dockerhub.  
This is triggered by a workflow in pipedream.com, which makes an POST request whenever a new version is available.

This workflow:

1. Checks if the relevant image version already exists on Docker Hub.
2. If an image doesn't exist for the latest version, automatically builds and pushes it with both the version tag and `latest`.

### Manual build and push

```bash
docker build -t michaelwadman/antigravity-cli:1.0.6 -t michaelwadman/antigravity-cli:latest --build-arg ANTIGRAVITY_VERSION='1.0.6' .
docker push -a michaelwadman/antigravity-cli
```

## Setup and Use

### Local configuration directory

Antigravity CLI uses the directory `~/.gemini/antigravity-cli` to store its configuration and authentication token (stored in `~/.gemini/antigravity-cli/antigravity-oauth-token`).  
If this directory doesn't already exist on your local machine, create it with `mkdir -p ~/.gemini/antigravity-cli`.




## Running

```bash
docker run -it --rm --name antigravity-cli \
  --init \
  -e TERM=$TERM \
  -v "$(pwd):$(pwd)" -w $(pwd) \
  -v "$HOME/.gemini:/root/.gemini" \
  -v "$HOME/.gitconfig:/root/.gitconfig" \
  michaelwadman/antigravity-cli:latest
```

### Notes

- **Git Identity**: Mounting `.gitconfig` allows the agent to make commits using your git identity. If you use a credential manager on your host, you may still need to provide credentials manually or via environment variables inside the container.
- **SSH Support**: If your git repositories use SSH, you may need to mount your SSH keys and/or agent socket to allow the container to authenticate with `-v "$HOME/.ssh:/root/.ssh"` and/or `-v "$SSH_AUTH_SOCK:/run/host-services/ssh-auth.sock" -e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock`. \
  In the Dockerfile, `/etc/ssh/ssh_config` is configured to use absolute paths in `/root/.ssh` to ensure compatibility with rootless Docker and OpenShift (which use random UIDs). Because these environments often lack a valid entry in `/etc/passwd` for the running user, the SSH client cannot automatically resolve the `~` (home) directory regardless of the UID or the `$HOME` environment variable.
- **Docker Support**: To enable the agent to interact with the host's Docker Engine, mount the Docker socket. The configuration depends on your host setup:

  - **Standard (Rootful) Docker**:
    Mount the default socket and add the host's docker group to the container user with `-v /var/run/docker.sock:/var/run/docker.sock --group-add $(stat -c '%g' /var/run/docker.sock)`.  
    The `--group-add` flag is required because the socket is owned by root/docker group on the host; this grants the container's user access.

  - **Rootless Docker**:
    Mount the user-specific socket (no `--group-add` required) with `-v $XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock`.  
    In rootless mode, the socket is already owned by your user, so no additional group permissions are needed.

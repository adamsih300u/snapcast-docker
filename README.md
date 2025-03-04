# Snapserver Docker Container

This repository contains a Docker setup for [Snapcast](https://github.com/badaix/snapcast), a multi-room client-server audio player. The container includes:

- Snapserver (the server component of Snapcast)
- MPV (for streaming radio stations)
- Shairport-Sync (for AirPlay support)
- Librespot (for Spotify Connect support)

## Building the Container

### Local Build

To build the container locally:

```bash
docker build -t snapserver:latest .
```

This will create a multi-stage build that compiles Snapcast, Shairport-Sync, and Librespot from source, resulting in a minimal Alpine-based container.

### GitHub Actions

This repository includes several GitHub Actions workflows:

1. **Build and Push** - Automatically builds and pushes the Docker image to GitHub Container Registry (ghcr.io) when:
   - Changes are pushed to the main/master branch
   - A new tag is created (prefixed with 'v')
   - A pull request is created (build only, no push)
   - The workflow is manually triggered

2. **Docker Test** - Tests that the Docker image builds and runs correctly.

3. **Docker Security Scan** - Scans the Docker image for security vulnerabilities using Trivy.

4. **Dockerfile Lint** - Lints the Dockerfile using Hadolint.

The build workflow creates multi-architecture images for both AMD64 and ARM64 platforms.

To use the pre-built image from GitHub Container Registry:

```bash
docker pull ghcr.io/[username]/snapserver-docker:latest
```

Replace `[username]` with your GitHub username.

## Configuration

The container is designed to be configured via an external configuration file. The default configuration is minimal and can be found in `snapserver.conf`.

### Configuration Options

You can mount your own configuration file to `/etc/snapserver/snapserver.conf` inside the container. The configuration file should follow the format described in the [Snapcast documentation](https://github.com/badaix/snapcast/blob/master/doc/configuration.md).

## Running with Docker

```bash
docker run -d \
  --name snapserver \
  -p 1704:1704 \
  -p 1705:1705 \
  -p 1780:1780 \
  -p 5000:5000 \
  -p 5000:5000/udp \
  -p 5353:5353/udp \
  -v /path/to/your/snapserver.conf:/etc/snapserver/snapserver.conf \
  ghcr.io/[username]/snapserver-docker:latest
```

## Kubernetes Deployment

A sample Kubernetes deployment is provided in `snapserver-deployment.yaml`. This includes:

1. A ConfigMap for the Snapserver configuration
2. A Deployment for the Snapserver container
3. A Service to expose the necessary ports

To deploy to Kubernetes:

```bash
# Edit the ConfigMap in snapserver-deployment.yaml to include your stream configuration
# Update the image reference to point to your container registry

# Apply the deployment
kubectl apply -f snapserver-deployment.yaml
```

### Configuration in Kubernetes

In Kubernetes, the configuration is managed through a ConfigMap. You can edit the ConfigMap directly in the YAML file or update it separately:

```bash
kubectl create configmap snapserver-config --from-file=snapserver.conf=./your-config.conf
```

Or edit an existing ConfigMap:

```bash
kubectl edit configmap snapserver-config
```

## Persistent Storage

For persistent storage in Kubernetes, replace the `emptyDir` volume with a PersistentVolumeClaim:

```yaml
volumes:
- name: data-volume
  persistentVolumeClaim:
    claimName: snapserver-data
```

And create a corresponding PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: snapserver-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

## Networking Considerations

For proper mDNS/Avahi discovery, you may need to use host networking in Docker:

```bash
docker run --network host ghcr.io/[username]/snapserver-docker:latest
```

In Kubernetes, you might need to use a hostPort or a NodePort service, or deploy a separate mDNS reflector. 
#!/usr/bin/env bash
# Deploy the Dogtag WebUI into a running Dogtag Tomcat instance.
#
# Usage:
#   ./deploy.sh                          # Build container, extract, deploy to local Dogtag
#   ./deploy.sh --container <name>       # Deploy into a running container
#   ./deploy.sh --local /var/lib/pki/... # Deploy to a local Dogtag installation
#
# The script builds the SPA via the Containerfile, extracts the webapp files,
# and copies them into the Dogtag Tomcat webapps directory.

set -euo pipefail

IMAGE_NAME="dogtag-webui-tomcat"
WEBAPP_CONTEXT="webui"
DEPLOY_MODE="local"
TARGET_CONTAINER=""
LOCAL_PKI_BASE="/var/lib/pki/pki-tomcat"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --container NAME   Deploy into a running Dogtag container
  --local PATH       Deploy to a local Dogtag installation
                     (default: $LOCAL_PKI_BASE)
  --skip-build       Skip the container build step
  --help             Show this help

Examples:
  $0                              # Build and deploy locally
  $0 --container pki-tomcat       # Deploy into container
  $0 --local /var/lib/pki/pki-ca  # Custom PKI base path
EOF
    exit 0
}

SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container)
            DEPLOY_MODE="container"
            TARGET_CONTAINER="$2"
            shift 2
            ;;
        --local)
            DEPLOY_MODE="local"
            LOCAL_PKI_BASE="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ "$SKIP_BUILD" == "false" ]]; then
    echo "Building $IMAGE_NAME..."
    podman build -t "$IMAGE_NAME" .
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Extracting webapp files..."
CID=$(podman create "$IMAGE_NAME")
podman cp "$CID:/webapp" "$TMPDIR/webapp"
podman rm "$CID" > /dev/null

if [[ "$DEPLOY_MODE" == "container" ]]; then
    DEST="/usr/share/pki/ca/webapps/$WEBAPP_CONTEXT"
    echo "Deploying to container '$TARGET_CONTAINER' at $DEST..."
    podman exec "$TARGET_CONTAINER" mkdir -p "$DEST"
    podman cp "$TMPDIR/webapp/." "$TARGET_CONTAINER:$DEST/"
    echo "Done. Access at https://<host>:8443/$WEBAPP_CONTEXT/"
else
    DEST="$LOCAL_PKI_BASE/ca/webapps/$WEBAPP_CONTEXT"
    echo "Deploying locally to $DEST..."
    sudo mkdir -p "$DEST"
    sudo cp -r "$TMPDIR/webapp/." "$DEST/"
    sudo chown -R pkiuser:pkiuser "$DEST"
    sudo restorecon -R "$DEST" 2>/dev/null || true
    echo "Done. Access at https://localhost:8443/$WEBAPP_CONTEXT/"
fi

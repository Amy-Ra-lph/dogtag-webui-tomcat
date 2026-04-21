# Build the SPA with Vite, then deploy into Dogtag's Tomcat as a webapp.
# No Node.js at runtime — just static files served by Tomcat.
#
# Usage:
#   podman build -t dogtag-webui-tomcat .
#
# The output is a directory that gets overlaid onto an existing Dogtag
# container or host installation. See deploy.sh for options.

# --- Build stage ---
FROM registry.access.redhat.com/ubi10/nodejs-24:latest AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY . .
RUN npm run build

# --- Package stage ---
# Assemble the webapp directory structure for Tomcat deployment.
# This stage produces a /webapp directory that can be:
#   1. Copied into a Dogtag container at /usr/share/pki/ca/webapps/webui/
#   2. Mounted as a volume
#   3. Extracted with: podman cp <container>:/webapp ./webui
FROM registry.access.redhat.com/ubi10/ubi-minimal:latest AS package

COPY --from=builder /app/dist/ /webapp/
COPY tomcat/WEB-INF/ /webapp/WEB-INF/

# Verify the build output
RUN ls -la /webapp/index.html /webapp/WEB-INF/web.xml

# The final image is just the webapp files — extract or copy them
# into your Dogtag Tomcat instance.
CMD ["echo", "Extract webapp files with: podman cp <container>:/webapp ./webui"]

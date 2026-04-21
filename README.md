# Dogtag PKI WebUI (Tomcat Model)

A modern web interface for Dogtag PKI certificate management, deployed as a
static SPA directly inside Dogtag's Tomcat server.

## Architecture

This project takes the **Tomcat-native** approach: the React SPA is built with
Vite and deployed as a Tomcat webapp alongside the existing Dogtag CA webapp.
There is no intermediate proxy layer — the browser talks directly to Dogtag's
REST API.

```
Browser  ──HTTPS──▶  Tomcat (8443)
                       ├── /ca/         (Dogtag CA — REST API + legacy UI)
                       └── /webui/      (this SPA — static files only)
```

### Key benefits over a proxy architecture

- **Native mTLS**: Tomcat handles client certificate authentication directly in
  the TLS handshake. No need to replay certs through a proxy layer.
- **No runtime dependencies**: No Node.js, Fastify, or nginx at runtime. The
  SPA is just static HTML/JS/CSS served by Tomcat.
- **Single origin**: No CORS issues. The SPA and API share the same origin and
  port.
- **Session cookies work naturally**: Dogtag's session cookies are scoped to the
  same origin, so `credentials: "include"` just works.

### Authentication flow

1. **Basic auth**: The SPA sends `Authorization: Basic ...` to
   `/ca/rest/account/login`. Tomcat authenticates against its user database
   (LDAP by default).
2. **Certificate auth**: When the browser has a client certificate for this
   origin, Tomcat can authenticate via mTLS during the TLS handshake. The SPA
   calls `/ca/rest/account/login` with `credentials: "include"` and Tomcat
   returns the authenticated user info.

## Quick start

### Development

```bash
cp .env.example .env
# Place agent cert/key in certs/ for dev proxy authentication
npm install
npm run dev
```

The Vite dev server proxies `/ca/rest` requests to the Dogtag CA (default
`https://localhost:8443`), using the agent cert for mTLS.

### Build and deploy

```bash
# Build the container (produces webapp files, no runtime)
podman build -t dogtag-webui-tomcat .

# Deploy into a running Dogtag container
./deploy.sh --container pki-tomcat

# Or deploy to a local Dogtag installation
./deploy.sh --local /var/lib/pki/pki-tomcat
```

### Manual deployment

```bash
npm run build
sudo cp -r dist/ /var/lib/pki/pki-tomcat/ca/webapps/webui/
sudo cp -r tomcat/WEB-INF/ /var/lib/pki/pki-tomcat/ca/webapps/webui/WEB-INF/
sudo chown -R pkiuser:pkiuser /var/lib/pki/pki-tomcat/ca/webapps/webui/
```

## Project structure

```
src/                  React SPA source (PatternFly 6)
tomcat/WEB-INF/       Tomcat webapp descriptor (SPA routing, caching, security)
Containerfile         Multi-stage build: Node (build) → static files (output)
deploy.sh             Deployment helper script
vite.config.ts        Vite config (base=/webui/, dev proxy to Dogtag)
```

## Comparison with dogtag-webui

| Aspect | dogtag-webui (nginx+Fastify) | dogtag-webui-tomcat |
|--------|------------------------------|---------------------|
| Runtime | Node.js + nginx | Tomcat only |
| Client cert auth | nginx terminates TLS, extracts cert headers | Tomcat native mTLS |
| Proxy layer | Fastify proxies to Dogtag | None (same origin) |
| Deployment | Container with nginx + Node | Copy files into Dogtag |
| LDAP auth | Fastify binds to LDAP | Tomcat's built-in LDAP realm |
| Complexity | Higher (3 processes) | Lower (static files only) |

## License

GPL-3.0-or-later

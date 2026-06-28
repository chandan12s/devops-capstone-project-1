# ---- Stage 1: install production dependencies only ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- Stage 2: minimal runtime image ----
FROM node:20-alpine AS runtime
WORKDIR /app

# Pull the latest patched OS packages at build time rather than trusting
# whatever was baked into the base image when it was last published -
# this is what actually fixes OS-level CVEs (e.g. the openssl one ECR's
# scan flagged), since Alpine ships security patches continuously
# regardless of the base image tag's own publish cadence.
RUN apk update && apk upgrade --no-cache

# Run as a non-root user - never run production containers as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./

USER appuser

ENV NODE_ENV=production
EXPOSE 3000

# Lets Docker/Kubernetes know if the app is actually healthy, not just running
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', res => process.exit(res.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "src/server.js"]
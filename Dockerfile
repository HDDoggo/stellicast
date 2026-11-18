# syntax=docker/dockerfile:1

# ---- build stage: needs devDependencies (Tailwind, TypeScript, Next compiler) ----
FROM node:26-alpine AS builder
# The date keys the build cache so this layer installs today's OS fixes; AppJet keeps it current on deploy.
RUN echo "os-refresh 2026-11-18" && apk upgrade --no-cache
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- runtime stage: production dependencies only ----
FROM node:26-alpine AS runner
# The date keys the build cache so this layer installs today's OS fixes; AppJet keeps it current on deploy.
RUN echo "os-refresh 2026-11-18" && apk upgrade --no-cache
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./next.config.ts

RUN mkdir -p /app /home/appjet && chown -R 10001:10001 /app /home/appjet
ENV HOME=/home/appjet
USER 10001:10001

EXPOSE 3000
# next start binds 0.0.0.0 and honors $PORT.
CMD ["npm", "start"]

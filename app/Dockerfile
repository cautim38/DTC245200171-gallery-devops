# ==============================================================================
# MULTI-STAGE DOCKERFILE CHO GALLERY APP (HARDENING: NON-ROOT USER NODE)
# ==============================================================================

# Stage 1: Build & Dependencies
FROM node:20-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev

# Stage 2: Production Runtime
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Cài đặt curl cho healthcheck
RUN apk add --no-cache curl

# Tạo thư mục uploads và phân quyền cho user node (Hardening Biện pháp 1)
RUN mkdir -p /app/uploads && chown -R node:node /app

# Copy dependencies từ stage trước
COPY --chown=node:node --from=dependencies /app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node src/ ./src/

# Chuyển sang user non-root
USER node

# Khai báo volume cho uploads
VOLUME ["/app/uploads"]

EXPOSE 3000

# Healthcheck định kỳ 30s
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]

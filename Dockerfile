# Multi-stage Docker build for Redis Bloom Filter Application
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm ci

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine AS production

# Install Redis CLI for health checks
RUN apk add --no-cache redis

# Create app user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Copy configuration files
COPY config/ ./config/
COPY scripts/setup-redis-bloom.sh ./scripts/
COPY docs/ ./docs/

# Change ownership to nodejs user
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose the application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); \
    const req = http.request('http://localhost:3000/health', (res) => { \
        process.exit(res.statusCode === 200 ? 0 : 1); \
    }); \
    req.on('error', () => process.exit(1)); \
    req.end();"

# Default command
CMD ["node", "dist/web-server.js"]

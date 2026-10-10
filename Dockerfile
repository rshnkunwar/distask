FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
COPY web/package*.json ./web/
RUN npm install --prefix web --omit=dev

# Copy application files
COPY web/ ./web/

# Data directory for persistent storage
ENV PORT=3000
ENV NODE_ENV=production
ENV DATA_DIR=/app/web/data

EXPOSE 3000

VOLUME ["/app/web/data"]

CMD ["node", "web/server.js"]

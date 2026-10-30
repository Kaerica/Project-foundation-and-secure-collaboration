# Use a slim LTS image to keep the runtime image small.
FROM node:22-bookworm-slim

# Keep application files isolated from the base image filesystem.
WORKDIR /app

# Copy manifests first so dependency installation can use Docker layer caching.
COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund

# Copy the application source after dependencies to preserve the cached layer.
COPY index.js products.js ./

# Run the application without root privileges.
USER node

CMD ["npm", "start"]

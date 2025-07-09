# Use Node.js LTS with Ubuntu base for Playwright compatibility
FROM node:18-bullseye

# Install system dependencies for Playwright
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files first (Docker layer caching optimization)
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Install Playwright browsers
RUN npx playwright install chromium
RUN npx playwright install-deps chromium

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p input output logs

# Set environment variables
ENV NODE_ENV=production
ENV HEADLESS=true

# Run as non-root user for security
RUN groupadd -r automation && useradd -r -g automation automation
RUN chown -R automation:automation /app
USER automation

# Default command
CMD ["npm", "start"]

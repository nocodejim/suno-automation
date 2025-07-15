# Use Node.js LTS with Ubuntu base for Playwright compatibility
FROM node:18-bullseye

# Install system dependencies for Playwright
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libxss1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files first (Docker layer caching optimization)
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Install Playwright browsers and their dependencies.
# This is the recommended way to do it.
RUN npx playwright install --with-deps

# Create user AFTER Playwright installation
RUN groupadd -r automation && useradd -r -g automation automation

# Copy application code and set ownership
COPY . .
RUN chown -R automation:automation /app

# Create necessary directories
RUN mkdir -p input output logs && chown -R automation:automation input output logs

# Set environment variables
ENV NODE_ENV=production
ENV HEADLESS=true

# Switch to non-root user for running the application
USER automation

# Default command
CMD ["npm", "start"]
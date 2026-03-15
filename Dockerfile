# TSL Motion Capture Flutter Web Dockerfile
# Multi-stage build: Flutter SDK -> Nginx

# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.41.4 AS build

# Build arguments for environment variables
ARG GEMINI_API_KEY
ARG CLOUDFLARE_R2_BASE_URL
ARG BACKEND_API_URL

WORKDIR /app

# Copy pubspec files first for caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Create .env file from build arguments
RUN echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env && \
    echo "CLOUDFLARE_R2_BASE_URL=${CLOUDFLARE_R2_BASE_URL}" >> .env && \
    echo "MOTION_STORAGE_MODE=r2" >> .env && \
    echo "BACKEND_API_URL=${BACKEND_API_URL}" >> .env

# Build for web release
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built web files to nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

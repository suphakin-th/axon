# Multi-stage Dockerfile - universal template
# Stages: deps -> dev -> test -> builder -> release
#
# Default language: Node.js 20
# To swap language: change the base images and commands marked with "# swap:"
# See each stage for commented alternatives per language.

# --------------------------------------------------------------------------
# Stage 1: deps
# Install production-only dependencies.
# This layer is cached until the manifest file changes.
# --------------------------------------------------------------------------

# swap: python:3.12-slim | golang:1.22-alpine | php:8.4-cli-alpine
#       eclipse-temurin:21-alpine | ruby:3.3-alpine | mcr.microsoft.com/dotnet/sdk:8.0
FROM node:20-alpine AS deps
WORKDIR /app

# Copy only the manifest first so Docker caches this layer until it changes
COPY package*.json ./
# swap: COPY requirements*.txt ./          # Python
# swap: COPY go.mod go.sum ./              # Go
# swap: COPY composer.json composer.lock ./# PHP
# swap: COPY Gemfile Gemfile.lock ./       # Ruby
# swap: COPY *.csproj ./                   # .NET

RUN npm ci --omit=dev
# swap: pip install --no-cache-dir -r requirements.txt   # Python
# swap: go mod download                                  # Go
# swap: composer install --no-dev --no-interaction       # PHP
# swap: bundle install --without development test        # Ruby
# swap: dotnet restore                                   # .NET


# --------------------------------------------------------------------------
# Stage 2: dev
# Used by docker-compose.dev.yml for local development with hot-reload.
# Includes all dev dependencies.
# --------------------------------------------------------------------------
FROM node:20-alpine AS dev
WORKDIR /app
COPY package*.json ./
RUN npm ci
EXPOSE 3000
CMD ["npm", "run", "dev"]
# swap: CMD ["python", "-m", "flask", "run", "--reload", "--host=0.0.0.0"] # Python
# swap: CMD ["air"]                                                          # Go (air)
# swap: CMD ["php", "artisan", "serve", "--host=0.0.0.0"]                   # PHP


# --------------------------------------------------------------------------
# Stage 3: test
# Used by docker-compose.test.yml in CI.
# Includes all dev dependencies so tests can run.
# --------------------------------------------------------------------------
FROM node:20-alpine AS test
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "test"]
# swap: CMD ["pytest", "-v", "--tb=short"]              # Python
# swap: CMD ["go", "test", "./..."]                     # Go
# swap: CMD ["php", "artisan", "test"]                  # PHP
# swap: CMD ["bundle", "exec", "rspec"]                 # Ruby
# swap: CMD ["dotnet", "test"]                          # .NET


# --------------------------------------------------------------------------
# Stage 4: builder
# Compile or bundle the application.
# Python, PHP, and Ruby do not need this stage - skip to release directly.
# --------------------------------------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# swap: go build -ldflags="-s -w" -o /app/server ./cmd/server  # Go
# swap: mvn package -DskipTests -q                             # Java Maven
# swap: dotnet publish -c Release -o /app/publish              # .NET
# Python / PHP / Ruby: no compile step needed


# --------------------------------------------------------------------------
# Stage 5: release
# Minimal image shipped to production.
# Only contains what is needed to run the app.
# --------------------------------------------------------------------------

# swap: python:3.12-slim | gcr.io/distroless/static:nonroot (Go static binary)
#       php:8.4-fpm-alpine | eclipse-temurin:21-jre-alpine | ruby:3.3-alpine
#       mcr.microsoft.com/dotnet/aspnet:8.0
FROM node:20-alpine AS release
WORKDIR /app

# Run as non-root for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps    /app/node_modules ./node_modules
COPY --from=builder /app/dist         ./dist
COPY package*.json ./

USER appuser
EXPOSE 3000

CMD ["node", "dist/server.js"]
# swap: CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000", "--workers", "2"] # Python
# swap: CMD ["/app/server"]                                                      # Go
# swap: CMD ["java", "-jar", "app.jar"]                                          # Java
# swap: CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]                  # Ruby

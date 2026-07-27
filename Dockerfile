# syntax=docker/dockerfile:1
# Production Dockerfile for ClawTrol (Rails 8.1).
# Release images must be built with the exact 40-character Git SHA.

ARG RUBY_VERSION=3.3.8
ARG BUNDLE_WITHOUT="development test"
ARG APP_REVISION

# =============================================================================
# Stage 1: Build stage - compile gems and precompile assets
# =============================================================================
FROM ruby:${RUBY_VERSION}-slim AS builder
ARG BUNDLE_WITHOUT="development test"
ARG APP_REVISION

RUN printf '%s' "${APP_REVISION}" | grep -Eq '^[0-9a-f]{40}$' || \
    { echo "APP_REVISION must be the exact 40-character lowercase Git SHA" >&2; exit 64; }

# Install build dependencies
# libyaml-dev is required to build psych on Ruby 3.3+ (no longer bundled).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libjemalloc2 \
    libyaml-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without "${BUNDLE_WITHOUT}" && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf vendor/bundle/ruby/*/cache

# Copy application code
COPY . .

# Precompile assets with dummy secret key
RUN SECRET_KEY_BASE=dummy_key_for_precompile \
    RAILS_ENV=production \
    bundle exec rails assets:precompile

# Clean up build artifacts to reduce image size
RUN rm -rf node_modules tmp/cache vendor/bundle/ruby/*/cache

# =============================================================================
# Stage 2: Runtime stage - minimal production image
# =============================================================================
FROM ruby:${RUBY_VERSION}-slim AS runtime
ARG BUNDLE_WITHOUT="development test"
ARG APP_REVISION

LABEL org.opencontainers.image.source="https://github.com/wolverin0/clawtrol" \
      org.opencontainers.image.revision="${APP_REVISION}"

# Install runtime dependencies only.
# libyaml-0-2 is required at runtime for psych on Ruby 3.3+.
# git is required by runtime features that inspect project repositories.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    git \
    libpq5 \
    libjemalloc2 \
    libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Use jemalloc for better memory management
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Set production environment
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    APP_REVISION=${APP_REVISION} \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLE_DEPLOYMENT=1

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Set working directory
WORKDIR /app

# Copy application from builder stage
COPY --from=builder --chown=rails:rails /app /app

# Create necessary directories with proper permissions
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log storage && \
    chown -R rails:rails tmp log storage db

# Switch to non-root user
USER rails

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:3000/health >/dev/null || exit 1

# Database migrations are an explicit pre-deploy gate, never a boot side effect.
ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Default command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

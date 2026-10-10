# syntax=docker/dockerfile:1
# One image for the whole app: Rails serves the API (/api/v1) and the built React app on one origin.
#   docker build -t salary-insights .
#   docker compose up --build        (adds PostgreSQL)

# ---- 1. Build the React app -------------------------------------------------------------
FROM node:22-slim AS frontend
WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ---- 2. Install production gems ---------------------------------------------------------
FROM ruby:3.3.6-slim AS gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV BUNDLE_WITHOUT="development:test" BUNDLE_PATH=/usr/local/bundle
COPY backend/Gemfile backend/Gemfile.lock ./
# Not frozen: the lockfile was resolved on x86_64 Linux, so Bundler adds the build machine's
# platform (e.g. aarch64-linux on Apple Silicon) while installing. Keep that resolved lockfile:
# the app copy below would otherwise overwrite it, and Bundler would try to rewrite it at boot.
RUN bundle install && rm -rf "${BUNDLE_PATH}"/ruby/*/cache && cp Gemfile.lock /tmp/Gemfile.lock.resolved
COPY backend/ ./
RUN cp /tmp/Gemfile.lock.resolved Gemfile.lock && bundle exec bootsnap precompile app/ lib/

# ---- 3. Runtime -------------------------------------------------------------------------
FROM ruby:3.3.6-slim
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 libyaml-0-2 curl && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Frozen at runtime: the app never rewrites Gemfile.lock; any mismatch fails loudly at boot.
ENV RAILS_ENV=production BUNDLE_WITHOUT="development:test" BUNDLE_PATH=/usr/local/bundle BUNDLE_FROZEN=true

COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY --from=gems /app /app
# Hashed assets are served from public/ with long-lived caching; index.html is served by
# FrontendController with "no-cache", so it lives outside public/.
COPY --from=frontend /frontend/dist/assets /app/public/assets
COPY --from=frontend /frontend/dist/index.html /frontend/dist/graphiql.html /app/frontend/

RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p log tmp && chown -R rails:rails log tmp
USER rails

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD curl -fsS http://localhost:3000/up || exit 1
# On start: create/migrate the database, seed demo data if it is empty (only when AUTO_SEED=true), serve.
CMD ["sh", "-c", "bin/rails db:prepare && bin/rails app:seed_if_empty && bin/rails server -b 0.0.0.0 -p 3000"]

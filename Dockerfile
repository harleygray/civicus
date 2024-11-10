# Build stage
FROM elixir:1.17.3-otp-27 AS builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git nodejs npm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set mix env to prod
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config files
COPY config config

# Build assets
COPY assets assets
COPY priv priv
RUN cd assets && npm install && npm run deploy
RUN mix phx.digest

# Compile and release
COPY lib lib
RUN mix compile
RUN mix release

# Runtime stage
FROM debian:bullseye-slim

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 && \
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Copy the release from build stage
COPY --from=builder /app/_build/prod/rel/civicus ./

ENV HOME=/app
ENV PORT=80
ENV PHX_HOST=0.0.0.0

# Verbose logging
ENV ELIXIR_ERL_OPTIONS="+S 1:1 +P 134217727 +K true +A 64 +sbwt very_long +swt very_long +scl false +sub true +spp true +sct true +sbt db +swt very_long +scl false +sub true +spp true +sct true +sbt db"

CMD ["bin/civicus", "start"]
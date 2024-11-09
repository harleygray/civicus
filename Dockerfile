# Multi-stage build for production
FROM elixir:1.17.3-otp-27 AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

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

# Compile the release
COPY lib lib
RUN mix compile
RUN mix release

# Generate the release image
FROM alpine:3.18.4 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copy the release from build stage
COPY --from=build /app/_build/prod/rel/your_app_name ./

# Set environment variables
ENV HOME=/app
ENV PORT=4000

CMD ["bin/your_app_name", "start"]
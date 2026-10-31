# Dev image: build tools for the C extension (gcc + clang, sanitizers, gdb) and
# the Ruby from .ruby-version (the single source of the dev Ruby version),
# built once with ruby-build via mise and cached in the image.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install -y --no-install-recommends \
    build-essential clang gdb valgrind pkg-config autoconf bison \
    libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev libgmp-dev \
    libsqlite3-dev sqlite3 \
  && rm -rf /var/lib/apt/lists/*

ENV MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CONFIG_DIR=/usr/local/share/mise/config \
    MISE_INSTALL_PATH=/usr/local/bin/mise \
    PATH=/usr/local/share/mise/shims:$PATH
COPY .ruby-version /tmp/.ruby-version
RUN curl -fsSL https://mise.run | sh \
  && mise use --global "ruby@$(cat /tmp/.ruby-version)" \
  && chmod -R a+rwX /usr/local/share/mise \
  && ruby -v

# Tooling container: every CLI this repo needs, at the versions pinned in
# mise.toml. Nothing is versioned here, so the image cannot drift from local
# installs or CI.
#
#   docker compose build
#   docker compose run --rm terra        # interactive shell in /work
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git gnupg jq less openssh-client unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Unprivileged user. UID 1000 matches the first user on most Linux hosts, so
# files created in the bind-mounted repo keep sane ownership.
ARG USER_UID=1000
RUN useradd --create-home --uid "${USER_UID}" --shell /bin/bash infra \
 && install -d -o infra -g infra /opt/mise /work

ENV MISE_DATA_DIR=/opt/mise \
    MISE_CONFIG_DIR=/opt/mise/config \
    MISE_CACHE_DIR=/opt/mise/cache \
    MISE_YES=1 \
    PATH=/opt/mise/shims:/home/infra/.local/bin:$PATH \
    TG_TF_PATH=terraform \
    TF_PLUGIN_CACHE_DIR=/home/infra/.terraform.d/plugin-cache

RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

USER infra
WORKDIR /work
COPY --chown=infra:infra mise.toml /work/mise.toml
RUN mise trust /work/mise.toml \
 && mise install \
 && mkdir -p "$TF_PLUGIN_CACHE_DIR" \
 && terraform version && terragrunt --version

CMD ["bash"]

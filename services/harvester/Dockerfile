# ─────────────────────────────────────────────────────────────────
# theHarvester container — built from upstream git at a pinned tag.
# Upstream: https://github.com/laramies/theHarvester  licence: GPLv2
# Pinned tag: 4.10.1 (2026-02-22 release).
#
# Honesty note: theHarvester is NOT distributed via PyPI under that
# name (the PyPI slot is squatted by an unrelated 0.0.1 stub). We
# install from a tagged git checkout instead. This is the upstream
# project's documented install path.
#
# This image is invoked one-shot via `docker compose run --rm` from
# the workflow templates — it is not a long-running daemon.
# ─────────────────────────────────────────────────────────────────
# hadolint global ignore=DL3013
FROM python:3.12-slim-bookworm@sha256:42ada43c4265e1ed6db62ad8df62af99a4abb9a9d49622032522ac76efb0bcef AS build

ARG HARVESTER_VERSION=4.10.1
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Build deps for any wheel-less sub-dependencies (uvloop, lxml, etc.)
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git=1:2.* \
        build-essential \
        libffi-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 --branch "${HARVESTER_VERSION}" \
        https://github.com/laramies/theHarvester.git /opt/theHarvester

WORKDIR /opt/theHarvester
RUN pip install --no-cache-dir .


# ─────────────────────────────────────────────────────────────────
# Runtime stage.
# ─────────────────────────────────────────────────────────────────
FROM python:3.12-slim-bookworm@sha256:42ada43c4265e1ed6db62ad8df62af99a4abb9a9d49622032522ac76efb0bcef AS runtime

ARG HARVESTER_VERSION=4.10.1
LABEL org.opencontainers.image.title="docker-osint-stack/harvester" \
      org.opencontainers.image.description="theHarvester pinned to ${HARVESTER_VERSION}" \
      org.opencontainers.image.source="https://github.com/thunderstornX/docker-osint-stack" \
      org.opencontainers.image.licenses="GPL-2.0-only" \
      net.docker-osint-stack.harvester-version="${HARVESTER_VERSION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HARVESTER_OUT=/home/harvester/out

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1002 harvester \
    && useradd  --system --uid 1002 --gid harvester --create-home --shell /usr/sbin/nologin harvester

COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

RUN mkdir -p "${HARVESTER_OUT}" \
    && chown -R harvester:harvester "${HARVESTER_OUT}"

USER harvester
WORKDIR /home/harvester

# Default to printing help so a stray `docker compose run` is harmless.
ENTRYPOINT ["theHarvester"]
CMD ["-h"]

# ─────────────────────────────────────────────────────────────────
# SpiderFoot container — built from upstream source at pinned tag.
# Upstream: https://github.com/smicallef/spiderfoot   licence: GPLv2
# Pinned ref: v4.0 (2022-04-07). Honest about staleness — this is
# the latest tagged release; later activity sits on master without a
# release tag. Pinning a tag is more reproducible than pinning HEAD.
# ─────────────────────────────────────────────────────────────────
# hadolint global ignore=DL3013
FROM python:3.9-slim-bookworm AS build

ARG SPIDERFOOT_REF=v4.0
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Build deps for native wheels (cryptography, lxml, etc.) — purged in
# the runtime stage.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git=1:2.* \
        ca-certificates \
        build-essential \
        libffi-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 --branch "${SPIDERFOOT_REF}" \
        https://github.com/smicallef/spiderfoot.git /opt/spiderfoot

WORKDIR /opt/spiderfoot
# SpiderFoot pins its own deps in requirements.txt — we honour that
# rather than re-pinning here.
RUN pip install --no-cache-dir -r requirements.txt


# ─────────────────────────────────────────────────────────────────
# Runtime stage — slim, non-root, healthchecked.
# ─────────────────────────────────────────────────────────────────
FROM python:3.9-slim-bookworm AS runtime

ARG SPIDERFOOT_REF=v4.0
LABEL org.opencontainers.image.title="docker-osint-stack/spiderfoot" \
      org.opencontainers.image.description="SpiderFoot built from upstream at pinned tag" \
      org.opencontainers.image.source="https://github.com/thunderstornX/docker-osint-stack" \
      org.opencontainers.image.licenses="GPL-2.0-only" \
      net.docker-osint-stack.spiderfoot-ref="${SPIDERFOOT_REF}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SPIDERFOOT_DATA=/home/spider/data \
    SPIDERFOOT_HOST=0.0.0.0 \
    SPIDERFOOT_PORT=5001

# Runtime libs only — no compilers in the final image.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        libxml2 \
        libxslt1.1 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 1001 spider \
    && useradd  --system --uid 1001 --gid spider --create-home --shell /usr/sbin/nologin spider

# Bring across the SpiderFoot tree and the installed site-packages.
COPY --from=build /opt/spiderfoot /opt/spiderfoot
COPY --from=build /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

COPY --chown=spider:spider spiderfoot.cfg /opt/spiderfoot/spiderfoot.cfg

RUN mkdir -p "${SPIDERFOOT_DATA}" \
    && chown -R spider:spider /opt/spiderfoot "${SPIDERFOOT_DATA}"

USER spider
WORKDIR /opt/spiderfoot
EXPOSE 5001

# Cheap healthcheck — SpiderFoot UI returns HTTP 200 at /.
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=5 \
    CMD curl --silent --fail "http://127.0.0.1:${SPIDERFOOT_PORT}/" || exit 1

# Bind on all interfaces inside the container; Nginx is the only
# externally reachable surface.
ENTRYPOINT ["python", "sf.py"]
CMD ["-l", "0.0.0.0:5001"]

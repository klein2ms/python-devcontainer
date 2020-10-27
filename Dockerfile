ARG VARIANT=3

FROM klein2ms/base-devcontainer:python-${VARIANT} AS base

# Build-time metadata as defined at https://github.com/opencontainers/image-spec/blob/master/annotations.md
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.url="https://github.com/klein2ms/python-devcontainer" \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.documentation="https://github.com/klein2ms/python-devcontainer" \
    org.opencontainers.image.source="https://github.com/klein2ms/python-devcontainer" \
    org.opencontainers.image.title="python-devcontainer" \
    org.opencontainers.image.description="A Python development container for Visual Studio Code"

ENV PYTHONUNBUFFERED=1

# Install pip packages
ONBUILD ARG PIP_DEPS=""
ONBUILD RUN if [ ! -z "$PIP_DEPS" ]; then \
    pip3 --disable-pip-version-check --no-cache-dir install $PIP_DEPS; \
    fi

FROM base AS devcontainer
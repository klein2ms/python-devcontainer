ARG VARIANT=3

FROM mcr.microsoft.com/vscode/devcontainers/python:${VARIANT} AS base

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

# Install build tools
ARG BUILD_DEPS="curl gnupg gnupg2 lsb-release software-properties-common"
ARG APP_DEPS="build-essential libc-dev libfontconfig1 libpq-dev libssl-dev libxml2 libxml2-dev libxslt1-dev libxslt1.1 libz-dev unixodbc-dev"

RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y $BUILD_DEPS \
    && apt-get install --no-install-recommends -y $APP_DEPS \
    && apt-get update \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists

# Install GitHub CLI and Starship shell prompt and setup shell
RUN set -ex \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0 \
    && apt-add-repository https://cli.github.com/packages \
    && apt-get update \
    && apt-get install --no-install-recommends -y fonts-powerline fonts-firacode gh \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists \
    && curl -s https://api.github.com/repos/starship/starship/releases/latest \
    | grep browser_download_url \
    | grep x86_64-unknown-linux-gnu \
    | cut -d '"' -f 4 \
    | wget -qi - \
    && tar xvf starship-*.tar.gz \
    && mv starship /usr/local/bin/ \
    && rm starship-*.tar.gz \
    && echo 'eval "$(starship init zsh)"' >> /root/.zshrc \
    && gh completion -s zsh > /usr/local/share/zsh/site-functions/_gh \
    && gh config set editor "code --wait"

COPY ./config/starship.toml /root/.config/

ENV EDITOR=nano \
    TERM=xterm
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends nano locales \
    && echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8 \
    && apt-get purge -y locales \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists

ONBUILD ARG USERNAME=vscode
ONBUILD ARG USER_UID=1000
ONBUILD ARG USER_GID=$USER_UID

ONBUILD RUN echo 'eval "$(starship init zsh)"' >> /home/$USERNAME/.zshrc \
    && mkdir -p /home/$USERNAME/.config \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME/.config \
    && chmod -R 700 /home/$USERNAME/.config \
    && cp /root/.config/starship.toml /home/$USERNAME/.config/ \
    && chown $USER_UID:$USER_GID /home/$USERNAME/.config/starship.toml

# Update UID/GID if needed
ONBUILD RUN if [ "$USER_GID" != "1000" ] || [ "$USER_UID" != "1000" ]; then \
    groupmod --gid $USER_GID $USERNAME \
    && usermod --uid $USER_UID --gid $USER_GID $USERNAME \
    && chmod -R $USER_UID:$USER_GID /home/$USERNAME; \
    fi

ONBUILD ARG ENABLE_NONROOT_DOCKER="true"
ONBUILD ARG SOURCE_SOCKET=/var/run/docker-host.sock
ONBUILD ARG TARGET_SOCKET=/var/run/docker.sock

# Allow devcontainer to access host docker socket
COPY scripts/docker-debian.sh /tmp/scripts/
RUN bash /tmp/scripts/docker-debian.sh "${ENABLE_NONROOT_DOCKER}" "${SOURCE_SOCKET}" "${TARGET_SOCKET}" "${USERNAME}" \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# Install apt-get packages
ONBUILD ARG DEBIAN_DEPS=""
ONBUILD RUN if [ ! -z "$DEBIAN_DEPS" ]; then \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install --no-install-recommends -y $DEBIAN_DEPS; \
    fi

# Install node and npm packages
ONBUILD ARG NPM_DEPS=""
ENV NVM_DIR=/usr/local/share/nvm
ENV NVM_SYMLINK_CURRENT=true \
    PATH=${NVM_DIR}/current/bin:${PATH}
ONBUILD ARG NODE_VERSION="lts/*"
COPY scripts/install-node.sh /tmp/scripts/
ONBUILD RUN if [ ! -z "$NPM_DEPS" ]; then \
    bash /tmp/scripts/install-node.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}"; \
    fi \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/library-scripts
ONBUILD RUN if [ ! -z "$NPM_DEPS" ]; then \
    npm install -g $NPM_DEPS; \
    fi

# Install pip packages
ONBUILD ARG PIP_DEPS=""
ONBUILD RUN if [ ! -z "$PIP_DEPS" ]; then \
    pip3 --disable-pip-version-check --no-cache-dir install $PIP_DEPS; \
    fi

ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]

FROM base AS devcontainer
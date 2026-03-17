# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-debian:trixie

# set locale environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# set version label
ARG BUILD_DATE
ARG VERSION
ARG OPENSSH_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# core: openssh + locales only — dev tools come from custom script
RUN \
  echo "**** install runtime packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    logrotate \
    nano \
    netcat-openbsd \
    sudo && \
  echo "**** install openssh-server ****" && \
  apt-get install -y --no-install-recommends \
    openssh-client \
    openssh-server \
    openssh-sftp-server && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** setup openssh environment ****" && \
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && \
  usermod --shell /bin/bash abc && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    $HOME/.cache

RUN \
  echo "**** configure locales ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    locales && \
  echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
  locale-gen && \
  update-locale LANG=en_US.UTF-8 && \
  echo "**** install base tools ****" && \
  apt-get install -y --no-install-recommends \
    byobu \
    curl \
    git \
    golang \
    htop \
    jq \
    less \
    mc \
    ncdu \
    tmux \
    vim \
    wget \
    zsh && \
  apt-get clean && \
  rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# run custom install script if provided
ARG CUSTOM_SCRIPT="./custom-install-ssh.sh"
COPY ${CUSTOM_SCRIPT} /opt/custom_install.sh
RUN if [ -f "/opt/custom_install.sh" ]; then /bin/bash /opt/custom_install.sh; fi

# add local files
COPY docker-openssh-server-debian/root /

EXPOSE 2222

VOLUME /config

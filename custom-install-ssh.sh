#!/bin/bash
set -e

# Shared dev tools baked into both webtop and SSH images.
# Base tools (vim, git, zsh, golang, etc.) are already in the Dockerfiles.
# This script adds heavier dev/ops packages on top.

echo "**** install shared dev tools ****"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential openssh-client rsync socat libffi-dev \
  python3 python3-pip python3-venv python3-setuptools python3-dev \
  python3-psycopg2 python3-openssl \
  nmap traceroute iputils-ping bind9-dnsutils inetutils-telnet \
  zip unzip p7zip-full \
  sqlite3 postgresql \
  gnupg ansible awscli \
  subversion apt-transport-https \
  default-jdk maven

echo "**** install Node.js 22 ****"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "**** install podman ****"
apt-get install -y podman fuse-overlayfs slirp4netns uidmap

apt-get clean
rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Add your shared dev tools below!


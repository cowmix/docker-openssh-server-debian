# Fork notes (Debian Trixie)

This is a fork of [linuxserver/docker-openssh-server](https://github.com/linuxserver/docker-openssh-server)
rebased from Alpine onto `ghcr.io/linuxserver/baseimage-debian:trixie`. `README.md` is upstream's
generated file and is left untouched so upstream merges stay clean. Fork-specific behaviour is documented here.

## Differences from upstream

- Debian Trixie base, `en_US.UTF-8` locale configured.
- Extra shell tools baked in: `vim nano tmux byobu zsh mc htop ncdu less tree jq ripgrep pv file lsof
  rsync curl wget git golang zip unzip bash-completion iproute2 (ip/ss) iputils-ping bind9-dnsutils (dig)
  mtr-tiny procps restic`.
- Heavier dev tooling (JDK, Node, podman, ansible, ...) comes from `custom-install-ssh.sh`
  (override with `--build-arg CUSTOM_SCRIPT=...`).
- `UsePAM no` is forced in `/config/sshd/sshd_config` on every start. sshd runs as the unprivileged
  user, so Debian's default `UsePAM yes` denies every login ("Access denied ... by PAM account configuration").
- `/backups` is prepared as a restic destination (see below).

## Building

The Dockerfile defaults assume the parent-directory (compose/submodule) build context. When building
with this repo as the context:

```sh
docker build --build-arg ROOT_SRC=root -t openssh-server-debian .
```

## Restic backup destination

restic talks to this container over **sftp**. Repositories live under `BACKUP_DIR` (default `/backups`).
Always mount a volume there; the container logs a warning if it isn't a mount.

See [`compose.yaml`](compose.yaml) for a ready-to-edit example. The essentials:

- `USER_NAME=restic`. Don't use `backup`: it's an existing Debian system user and init will halt.
- `PUBLIC_KEY=restrict,command="/usr/lib/openssh/sftp-server" ssh-ed25519 AAAA...` for sftp-only client keys.
- A volume mounted at `/backups` (or `BACKUP_DIR`).

The `restrict,command="/usr/lib/openssh/sftp-server"` prefix locks that key to sftp only (no shell, no
forwarding). Drop the prefix for a key that should also get a normal shell.

On the client (`~/.ssh/config`):

```
Host restic-target
  HostName backup.example.lan
  Port 2222
  User restic
  IdentityFile ~/.ssh/restic_ed25519
```

```sh
export RESTIC_PASSWORD_FILE=~/.restic-pass
restic -r sftp:restic-target:/backups/laptop init
restic -r sftp:restic-target:/backups/laptop backup ~/Documents
# without an ssh config entry:
restic -r sftp://restic@backup.example.lan:2222//backups/laptop snapshots
```

`restic` is also installed in the image, so maintenance (`check`, `prune`, `forget`) can run server-side
from a shell: `restic -r /backups/laptop check`.

Notes:
- `/backups` is `chmod 700` and owned by `PUID:PGID`. Ownership is only re-applied recursively when the top
  directory's owner doesn't match, e.g. after changing PUID/PGID.
- On macOS Docker Desktop/OrbStack bind mounts, chown may silently fail and leave `/backups` root-owned.
  Use a named volume there, or a host directory already owned by `PUID`.
- Only one SSH user exists (sshd runs as that user), so every restic client shares it. Separate them by
  repo path and by using different repo passwords.

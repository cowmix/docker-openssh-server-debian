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
- SSH host keys are generated per container at first start. Debian's package creates keys at build time,
  so the build deletes them. Older builds of this fork shipped those shared keys. On startup, keys that
  end in `@buildkitsandbox` are detected and regenerated, and a warning is logged. Clients then see a
  one-time "host key changed" warning: `ssh-keygen -R '[host]:2222'`.
- Startup logs a summary of the login account and every authorized key: fingerprint, comment, and
  shell vs. sftp-only. Duplicate and invalid lines are flagged.

## Building

The Dockerfile defaults assume the parent-directory (compose/submodule) build context. When building
with this repo as the context:

```sh
docker build --build-arg ROOT_SRC=root -t openssh-server-debian .
```

## Restic backup destination

restic talks to this container over **sftp**. Repositories live under `BACKUP_DIR` (default `/backups`).
Always mount a volume there; the container logs a warning if it isn't a mount.

Copy [`compose.example.yaml`](compose.example.yaml) to `compose.yaml` (git-ignored) and edit it. The essentials:

- `USER_NAME=restic`. Don't use `backup`: it's an existing Debian system user and init will halt.
- `PUBLIC_KEY_DIR=/run/keys` with `./keys` mounted there, holding one public key per file:
  - `keys/me.pub` is a plain key line and gets a full shell (ssh, rsync, scp, forwarding).
  - `keys/restic-nas.pub` is `restrict,command="/usr/lib/openssh/sftp-server" ssh-ed25519 AAAA...` and is limited to
    sftp only. restic and scp work with it; a shell, rsync and forwarding are refused. A leaked backup key
    therefore can't log in.
- A volume mounted at `/backups` (or `BACKUP_DIR`).

All keys log in as the same `USER_NAME`. Keys are only ever *added* to `config/.ssh/authorized_keys` at
startup. To revoke a key or change its restriction, edit that file as well. If a key appears there twice,
sshd uses the first matching line.

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

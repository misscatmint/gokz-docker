# gokz-docker

Docker images for running a CS:GO [GOKZ](https://github.com/KZGlobalTeam/gokz)
server, with quality of life plugins and modern default settings included.

## Example `compose.yaml`

```yaml
services:
  gokz:
    container_name: gokz
    build: https://github.com/misscatmint/gokz-docker.git
    restart: unless-stopped
    user: "1000:1000" # see Permissions
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    logging:
      driver: local # rotates the console output Docker keeps
    stdin_open: true
    tty: true
    environment:
      MAP: kz_vnl_crimdaughter
      MAXPLAYERS: 16
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data:/data
    ports:
      - 27015:27015/udp
      # RCON (drop 127.0.0.1: to reach it remotely)
      - 127.0.0.1:27015:27015/tcp
```

```sh
mkdir -p data/csgo/maps
sudo chown -R 1000:1000 data    # skip on rootless Docker, see Permissions
docker compose up -d
docker compose attach gokz      # server console (detach with Ctrl-P Ctrl-Q)
```

Both containers use the host's timezone through the `/etc/localtime` mount. To
give a container its own timezone instead, drop the mount and set `TZ`, e.g.
`TZ: America/Chicago`.

The first start downloads the CS:GO dedicated server (~30 GB) and can take a
while.

## Configuration

These control how the server starts and which files it keeps updated for you.
Everything else, like the server name, is set in the config files.

| Variable | Default | Description |
| --- | --- | --- |
| `MAP` | `kz_hikari_od` | Starting map (downloaded from `sm_dlmap_url` if missing) |
| `MAPCMD` | `map` | Command used to load the starting map (e.g., `host_workshop_map`) |
| `MAXPLAYERS` | `10` | Player slots |
| `PORT` | `27015` | Game port (TCP and UDP) |
| `SERVERCFG` | `server.cfg` | Server config file in `data/csgo/cfg` |
| `FLAGS` | | Extra srcds command-line options (e.g., `-nomaster`) |
| `MAPPOOL` | badservers.net map pool | GOKZ local ranks map pool (empty to skip) |

### API keys

Keys go in files on the data volume, so they never appear in your compose file
or `docker inspect`. Each file holds just the key on one line:

| Key | File |
| --- | --- |
| GOKZ global API key | `data/csgo/cfg/sourcemod/globalapi-key.cfg` |
| Steam Web API key (only needed to load workshop maps) | `data/csgo/webapi_authkey.txt` |

Create them with an editor, make them readable only by the server, and restart
the container:

```sh
chmod 600 data/csgo/cfg/sourcemod/globalapi-key.cfg data/csgo/webapi_authkey.txt
sudo chown 1000:1000 data/csgo/cfg/sourcemod/globalapi-key.cfg data/csgo/webapi_authkey.txt # skip on rootless Docker
```

### Config files

Default configs are copied in on the first start and after each update, but
only when they don't exist yet.

To turn off a bundled plugin, move it into
`addons/sourcemod/plugins/disabled/`. It stays disabled across updates.

## Updating

Rebuild the image and recreate the container:

```sh
docker compose build --pull gokz
docker compose up -d gokz
```

Plugins and other bundled files are updated on the next start. Your configs
are left alone.

## Maps

The optional `gokz-maps` container downloads any maps from the [BadServers KZ
map archive](https://csgo-kz-maps.badservers.net) that you don't have yet,
every day at 4:00 local time. Maps you already have, including ones from other
sources, are never touched. The full archive is large, so check your free disk
space before enabling it.

Example `compose.yaml`:

```yaml
  gokz-maps:
    container_name: gokz-maps
    build:
      context: https://github.com/misscatmint/gokz-docker.git
      target: maps
    restart: unless-stopped
    user: "1000:1000" # see Permissions below
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    logging:
      driver: local
    cpus: 0.5
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data/csgo/maps:/data/csgo/maps
```

The container only gets the maps directory, so it can't touch plugins or
configs. The setup commands above create it; if you skipped them, create it
before starting this service.

Run a sync right away:

```sh
docker compose exec gokz-maps /maps.sh
```

Delete maps that fail their checksum, so the next sync downloads them again:

```sh
docker compose exec gokz-maps /maps.sh verify
```

## Logs

The server console is also written to `data/csgo/logs/console-<port>.log`, with
a timestamp on each line. Every start cleans up old logs:

- The console log is rotated once a day, keeping 30 days, compressed.
- Logs named by date (srcds's, SourceMod's and GlobalAPI's) and crash dumps are
  deleted once they're 30 days old.
- Any other log in `addons/sourcemod/logs/` is rotated once it passes 10 MB,
  keeping the last 3.

Docker's own copy of the console output is capped by the example's `logging:`
setting.

## Crash dumps

When srcds crashes, the next start moves the crash dump into
`data/crashdumps/`. Each `.dmp` has a `.dmp.txt` next to it with the map,
command line, and recent console output, which often points at the culprit.
Nothing is uploaded anywhere, and dumps are deleted after 30 days (see
[Logs](#logs)).

To see the stack traces, use
[dump_syms](https://github.com/mozilla/dump_syms) and
[minidump-stackwalk](https://github.com/rust-minidump/rust-minidump/tree/main/minidump-stackwalk)
(`cargo install`, or prebuilt binaries from their releases):

```sh
find data -name '*.so' -type f -exec dump_syms --store symbols {} \;
minidump-stackwalk --symbols-path symbols data/crashdumps/<file>.dmp
```

The first command reads the unwind tables out of the server's own binaries
(about 500 MB, 15 seconds). Without them, minidump-stackwalk has to guess where
each frame starts, and the trace can be wrong. Rerun it after a game or plugin
update, since the symbols only match the exact binaries that crashed.

Valve's binaries have almost no function names, so their frames show up as
module and offset (e.g. `server.so + 0x1a2b3c`). A frame in
`sourcepawn.jit.x86.so` means the crash happened while a plugin was running,
but the plugin itself isn't named. Dumps contain the server's memory, including
your API keys, so don't share them publicly.

## Permissions

Both containers run as 1000:1000 and never as root, so they can't fix
ownership for you. Every directory you mount, and every mount point inside
`data`, has to exist and be writable by that user before the first start
(the `mkdir` and `chown` in the [example](#example-composeyaml)). If Docker
creates a missing one itself, root owns it and the server can't write to it.

- **Different owner:** set `user: "UID:GID"` on both services to the owner of
  your data directory.
- **Rootless Docker:** set `user: "0:0"` on both services and skip the `chown`.
  Root inside the container is your own user on the host, so it owns your files
  without needing any capabilities, and `cap_drop: [ALL]` still applies.
- **`userns-remap`:** add `userns_mode: host` to both services, or chown your
  data directories to the remapped UID (the start of your subordinate UID range
  plus 1000).

## GOKZ build

The image bundles
[GOKZ 3.8.0-srs1](https://github.com/misscatmint/gokz/releases/tag/3.8.0-srs1)
along with the SteamWorks and GlobalAPI versions it needs. Each one is a build
argument, so you can swap in another release or your own fork.

### GOKZ 3.6.x

GOKZ 3.6.x needs older SteamWorks and GlobalAPI builds. Set all of these
arguments together:

```yaml
  gokz:
    build:
      context: https://github.com/misscatmint/gokz-docker.git
      args:
        GOKZ: https://github.com/misscatmint/gokz/releases/download/3.6.4-srs1/GOKZ-v3.6.4-srs1.zip
        GOKZ_SHA256: 432268d04751d42be4797970663c28c10c3edbb1f37bcbedae6bcf7e733fa838
        STEAMWORKS: https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz
        STEAMWORKS_SHA256: 6679e6dfd19d4c78a71d224ff3f7d72d9becbc256082ed4bce85cbaa1e012713
        GLOBALAPI: https://bitbucket.org/kztimerglobalteam/globalapi-smplugin/downloads/GlobalAPI-v2.0.4.zip
        GLOBALAPI_SHA256: a986650e1fead3a438075aeaa1480f77f8033d048409de49d245bc54f34600d9
```

### Notes

The GOKZ zip must have the same layout as an official GOKZ release. Every URL
needs its matching `_SHA256` (get it with `curl -fsSL URL | sha256sum`), and the
build fails if the download doesn't match, so point them at one fixed release.
Downgrading on an existing `/data` volume isn't guaranteed to work.

## Add-on zips

For servers that can't run this image (e.g. hosts that only let you upload
files), the `bundle` target builds two zips in `dist/` with the same plugins and
configs:

- `gokz-<version>.zip`: everything, configs included, for a new server.
- `gokz-<version>-upgrade.zip`: no configs, for updating a server that already
  has them.

Upload the zip into the server's `csgo` folder and extract it there. After an
upgrade, delete the files listed in `gokz-removed.txt` (it also lists
Accelerator, for servers that had it before). `gokz-sources.txt` lists where
every component comes from.

The zips leave out Accelerator, since outside the image nothing stops it from
uploading crash dumps. The image's start-up tasks (map lists, map pool sync)
don't happen either.

Build them from the repository root, then keep the bundle state for the next
release:

```sh
docker build --target bundle --output dist .
mv dist/files.txt dist/removed.txt bundle/
```

`make bundle` runs both. To bundle another GOKZ build, pass the same [build
arguments](#gokz-36x) (`--build-arg GOKZ=… --build-arg GOKZ_SHA256=…`, or
`GOKZ=… GOKZ_SHA256=… make bundle`). `make clean` deletes `dist/`.

Commit `bundle/files.txt` and `bundle/removed.txt` with each release. The next
upgrade zip's removal list comes from them. The build checks that the upgrade
zip has everything the full zip has except configs, and fails if it doesn't.

## Development

```sh
make lint       # shellcheck and hadolint, run in Docker
make build      # build both images, which checks every pinned download
                # (takes the same GOKZ=… variables as make bundle)
make check      # both of the above
make bundle     # add-on zips in dist/ (see above); make clean removes them
make outdated   # newer tags for the pinned images and GitHub releases (needs
                # skopeo, git and curl)
```

`make outdated` keeps Metamod and SourceMod on 1.12 and lists the downloads it
can't check, which aren't on GitHub. To update a GitHub download, run
`tools/bump.sh OWNER/REPO TAG` with the first two words of its `make outdated`
line. It points `build.sh` at the new release's file of the same name with the
version swapped, updates its sha256 and shows how the archive's file list
changed, so you can check the extract paths. If the file was renamed some other
way, copy its link from the release page and run `tools/bump.sh URL`. If
`build.sh` already has the URL, it only updates the sha256. Read the release
notes, then `make build`. Update the other downloads by hand, and the GOKZ
version mentioned above when bumping GOKZ's default.

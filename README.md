# gokz-docker

Docker images for running a CS:GO [GOKZ](https://github.com/KZGlobalTeam/gokz)
server, with quality of life plugins and modern default settings included.

## Example `compose.yaml`

```yaml
services:
  gokz:
    container_name: gokz
    restart: unless-stopped
    stdin_open: true
    tty: true
    build: ./gokz-docker
    environment:
      NAME: My KZ Server
      MAP: kz_vnl_crimdaughter
      MAXPLAYERS: 16
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./gokz/data:/data
      - ./gokz/etc/addons/sourcemod/configs:/data/csgo/addons/sourcemod/configs
      - ./gokz/etc/cfg:/data/csgo/cfg
    ports:
      - 27015:27015/tcp
      - 27015:27015/udp
```

```sh
docker compose up -d
docker attach gokz    # server console (detach with Ctrl-P Ctrl-Q)
```

Both containers use the host's timezone through the `/etc/localtime` mount. To
give a container its own timezone instead, drop the mount and set `TZ`, e.g.
`TZ: America/Chicago`.

The first start downloads the CS:GO dedicated server (~30 GB) and can take a
while. Only the `/data` volume is required. The two config mounts are optional
and just keep your configs in a separate, easy-to-edit place.

## Configuration

Settings below are applied on every start. Leave one empty to manage that
setting yourself in your config files instead.

| Variable | Default | Description |
| --- | --- | --- |
| `NAME` | | Server name (`hostname`) |
| `PASSWORD` | | Server password (`sv_password`) |
| `MAP` | `kz_hikari_od` | Starting map (downloaded automatically if missing) |
| `MAPCMD` | `map` | Command used to load the starting map (e.g., `host_workshop_map`) |
| `MAXPLAYERS` | `10` | Player slots |
| `PORT` | `27015` | Game port (TCP and UDP) |
| `SERVERCFG` | `server.cfg` | Server config file in `csgo/cfg` |
| `FLAGS` | | Extra srcds command-line options (e.g., `-nomaster`) |
| `APIKEY` | | GOKZ global API key |
| `AUTHKEY` | | Steam Web API key (only needed to load workshop maps) |
| `MINIDUMPACCOUNT` | | SteamID64 for Accelerator crash report uploads |
| `FASTDL` | badservers.net FastDL | Client download URL (`sv_downloadurl`) |
| `DLMAP` | badservers.net maps | Where `!dlmap` downloads maps from |
| `DLMAPLIST` | badservers.net map list | Map list `!dlmap` uses for fuzzy matching |
| `DLMAPSUBDIRS` | `reuploads` | Extra directories `!dlmap` checks |
| `MAPPOOL` | badservers.net map pool | GOKZ local ranks map pool (empty to skip) |
| `PUID` / `PGID` | `1000` | User and group the server runs as (see [Permissions](#permissions)) |

### Config files

Default configs are copied in on the first start and after each update, but
only when they don't exist yet.

To turn off a bundled plugin, move it into `addons/sourcemod/plugins/disabled/`.
It stays disabled across updates.

## Updating

Rebuild the image and recreate the container:

```sh
docker compose build --pull gokz
docker compose up -d gokz
```

Plugins and other bundled files are updated on the next start. Your configs
are left alone.

## Maps

The optional `gokz-maps` container downloads any maps from the
[KZ map archive](https://csgo-kz-maps.badservers.net) that you don't have yet,
every day at 4:00 local time. Maps you already have, including ones from
other sources, are never touched. The full archive is large, so check your
free disk space before enabling it.

Example `compose.yaml`:

```yaml
  gokz-maps:
    container_name: gokz-maps
    restart: unless-stopped
    cpus: 0.5
    build: ./gokz-docker/maps
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./gokz/data:/data
```

Run a sync right away:

```sh
docker exec gokz-maps /maps.sh
```

Delete maps that fail their checksum, so the next sync downloads them again:

```sh
docker exec gokz-maps /maps.sh verify
```

## Permissions

Both containers start as root, take ownership of the directories they need,
and then run as `PUID`:`PGID` (1000:1000 by default). Missing host directories
are created and fixed for you, so set these to the owner of your data
directory and there's nothing else to do.

- **`user:` in compose** skips this entirely and runs as that user. `PUID` and
  `PGID` are ignored, and you're responsible for directory ownership.
- **To run as root**, set `PUID` and `PGID` to `0`. `user: "0:0"` doesn't do
  this.
- **Rootless Docker:** set `PUID` and `PGID` to `0`. Root inside the container
  is your own user on the host, so your files stay owned by you.
- **`userns-remap`:** add `userns_mode: host` to both services, or chown your
  data directories into the remapped UID range.
- **`docker exec`** runs as root by default. Use `docker exec -u 1000:1000 ...`
  for anything that creates or edits files (`/maps.sh` handles this itself).

## GOKZ build

The image bundles
[GOKZ 3.6.4-srs1](https://github.com/misscatmint/gokz/releases/tag/3.6.4-srs1)
along with the SteamWorks and GlobalAPI versions it needs. Each one is a build
argument, so you can swap in another release or your own fork.

### GOKZ 3.7.x

GOKZ 3.7.x needs newer SteamWorks and GlobalAPI builds. Set all four arguments
together:

```yaml
  gokz:
    build:
      context: ./gokz-docker
      args:
        GOKZ: https://github.com/misscatmint/gokz/releases/download/3.7.0-srs1/GOKZ-v3.7.0-srs1.zip
        STEAMWORKS: https://github.com/alliedmodders/SM-SteamWorks/releases/download/v1.2.167/SteamWorks-1.2.167-sm1.12-linux.tar.gz
        STEAMWORKS_PREFIX: ""
        GLOBALAPI: https://github.com/misscatmint/csgo-sm-globalapi/releases/download/v2.1.0/GlobalAPI-v2.1.0.zip
```

`STEAMWORKS_PREFIX` is the folder the SteamWorks archive keeps its files in:
`package` for the default build, and empty for the one above. If you leave it
out, the build fails with `package/addons/sourcemod/extensions: Not found in
archive`.

### Notes

The GOKZ zip must have the same layout as an official GOKZ release. Use URLs
that point to one fixed release: Docker reuses its cached build while a URL
stays the same, even if the file behind it changes. Downgrading on an existing
`/data` volume isn't guaranteed to work.

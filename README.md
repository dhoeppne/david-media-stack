# General Sherman Media Stack

A Docker Compose media server stack supporting single-host and multi-host (NAS + Server) deployments, with [TRaSH hardlinks](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/) for instant moves and zero-copy imports.

## Services

| Service | Purpose | Port |
|---------|---------|------|
| [Gluetun](https://github.com/qdm12/gluetun) | VPN gateway (Mullvad WireGuard) | — |
| [qBittorrent](https://github.com/linuxserver/docker-qbittorrent) | Torrent client (routed through VPN) | 1080 |
| [Plex](https://github.com/linuxserver/docker-plex) | Media server | 32400 |
| [Sonarr](https://github.com/linuxserver/docker-sonarr) | TV show management | 8989 |
| [Radarr](https://github.com/linuxserver/docker-radarr) | Movie management | 7878 |
| [Prowlarr](https://github.com/linuxserver/docker-prowlarr) | Indexer manager | 9696 |
| [Seerr](https://github.com/sctx/overseerr) | Media request UI | 5055 |
| [Reclaimerr](https://github.com/jessielw/reclaimerr) | Media space reclamation | 8249 |
| [Rangarr](https://github.com/judochinx/rangarr) | Manga/anime management | — |
| [Cinerr](https://github.com/alexkouzel/cinerr) | Movie information | 8080 |

## Deployment Modes

### Single-Host (default)

Use the root `docker-compose.yaml` — all services run on one machine. Best for most users.

```bash
cp .env.example .env
# Edit .env with your paths and VPN credentials
docker compose up -d
```

### Multi-Host (NAS + Server)

Splits services across two machines:

- **NAS** (`nas/docker-compose.yaml`): vpn, qbittorrent, plex — services needing direct disk I/O
- **Server** (`server/docker-compose.yaml`): sonarr, radarr, prowlarr, seerr, reclaimerr, rangarr, cinerr — services that communicate via API and access media over NFS

This setup requires NFS to share the data directory from the NAS to the server. See [NFS Setup](#nfs-setup) below.

## Data Directory Structure

This stack uses the [TRaSH hardlinks folder structure](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/). Your `DATAROOT` directory must have this layout:

```
${DATAROOT}/
├── torrents/
│   ├── tv/
│   ├── movies/
│   └── music/
└── media/
    ├── tv/
    ├── movies/
    └── music/
```

**Why this structure matters:** Sonarr and Radarr mount the entire `DATAROOT` as `/data` inside their containers. Since `torrents/` and `media/` are under the same mount point, the filesystem can use hardlinks instead of copying files. This means:

- **No duplicate disk usage** — a completed download and its library entry share the same disk blocks
- **Instant imports** — no waiting for multi-GB file copies
- **Seeding continues** — the torrent client still sees the file in its original location

### qBittorrent Category Setup

Configure qBittorrent download categories to match the folder structure:

| Category | Save Path |
|----------|-----------|
| tv | `/data/torrents/tv` |
| movies | `/data/torrents/movies` |
| music | `/data/torrents/music` |

### Sonarr/Radarr Root Folder Setup

| App | Root Folder |
|-----|------------|
| Sonarr | `/data/media/tv` |
| Radarr | `/data/media/movies` |

## First-Time Setup

1. Copy the appropriate `.env.example` to `.env` and fill in your values
2. Create the data directory structure:
   ```bash
   mkdir -p /path/to/data/{torrents/{tv,movies,music},media/{tv,movies,music}}
   ```
3. Create the `wanfacing` Docker network (if using seerr with a reverse proxy):
   ```bash
   docker network create wanfacing
   ```
4. Start the stack:
   ```bash
   docker compose up -d
   ```
5. Configure each service via its web UI (see ports table above)

## Multi-Host Setup

### NAS Deployment

```bash
cd nas/
cp .env.example .env
# Edit .env — set DATAROOT to local disk path (e.g., /mnt/user/data)
docker compose up -d
```

### NFS Setup

The server accesses the NAS data directory over NFS. A single NFS export of the entire `DATAROOT` is required — do not export `torrents/` and `media/` separately, or hardlinks will not work.

#### Unraid

1. Go to **Settings > NFS**
2. Enable NFS
3. Add an export rule for your data directory (e.g., `/mnt/user/data`)
4. Set the server IP in the allowed hosts with read/write access

#### Generic Linux NAS

Add to `/etc/exports`:
```
/path/to/data  server_ip(rw,sync,no_subtree_check,no_root_squash)
```
Then run `exportfs -ra`.

#### Verify NFS from the Server

```bash
# Install NFS client if needed
sudo apt install nfs-common

# Test the mount
sudo mount -t nfs4 NAS_IP:/path/to/data /mnt/test
ls /mnt/test  # Should show torrents/ and media/
sudo umount /mnt/test
```

> **Note:** You do not need a persistent NFS mount in `/etc/fstab` — Docker creates the NFS mount automatically via the named volume driver options in the server compose file.

### Server Deployment

```bash
cd server/
cp .env.example .env
# Edit .env — set NAS_IP and NAS_NFS_PATH
docker compose up -d
```

### Cross-Host App Configuration

Since services are split across hosts, configure connections using the NAS IP address:

| App | Setting | Value |
|-----|---------|-------|
| Sonarr | Download Client → qBittorrent Host | `NAS_IP:1080` |
| Radarr | Download Client → qBittorrent Host | `NAS_IP:1080` |
| Seerr | Plex Server | `NAS_IP:32400` |
| Prowlarr | Sonarr/Radarr | `media_sonarr:8989` / `media_radarr:7878` (same host) |

### PUID/PGID Consistency

The `PUID` and `PGID` values **must match** between NAS and server `.env` files. NFS uses numeric UIDs for file ownership — if they don't match, you'll get permission errors when Sonarr/Radarr try to hardlink or move files.

## Arcane GitOps Deployment (Server)

The server stack integrates with [Arcane](https://getarcane.app/docs) for automatic deployment from this Git repository.

### Setup

1. In the Arcane web UI, go to **Customize > Git Repositories** and add this repo
2. Go to **Projects > From Git Repo** and configure:
   - **Repository:** select the repo you just added
   - **Branch:** `main`
   - **Docker Compose Path:** `server/docker-compose.yaml`
3. Fill in the `.env` values in the Arcane UI (these are editable even though the compose file is read-only)
4. Enable **Auto Sync** to automatically pull and redeploy on git push

### How It Works

- Arcane clones the repo and reads `server/docker-compose.yaml`
- The compose file is **read-only** in Arcane (Git is the source of truth)
- Environment variables (`.env`) are **editable** in the Arcane UI
- All services have the `arcane.stack.auto-update` label, so Arcane also checks for new container images periodically
- When you push changes to `main`, Arcane detects the update and redeploys the stack

## VPN Configuration

This stack uses [Gluetun](https://github.com/qdm12/gluetun) with Mullvad WireGuard. You need three values from your Mullvad WireGuard config file:

| Env Var | Source | Format |
|---------|--------|--------|
| `WIREGUARD_KEY` | `PrivateKey` in config | Base64 string |
| `WIREGUARD_ADDRESS` | `Address` in config | CIDR notation (e.g., `x.x.x.x/32`) |
| `SERVER_CITIES` | Your choice | e.g., `Vancouver` ([full list](https://github.com/qdm12/gluetun/wiki/Mullvad-servers)) |

## Migrating from the Old Folder Structure

If you're upgrading from the previous layout (`downloads/` + `complete/{tv,movies}`):

1. **Stop the stack** and pause all active torrents
2. **Reorganize files:**
   ```bash
   cd $DATAROOT

   # Create new structure
   mkdir -p torrents/{tv,movies,music} media/{tv,movies,music}

   # Move downloads
   mv downloads/complete/* torrents/    # or sort into tv/movies subdirs
   rm -rf downloads/

   # Move media libraries
   mv complete/tv/* media/tv/
   mv complete/movies/* media/movies/
   rm -rf complete/
   ```
3. **Update `.env`** if your `DATAROOT` path changed
4. **Start the stack** with the new compose file
5. **Reconfigure apps:**
   - qBittorrent: update default save path and category paths
   - Sonarr: update root folder to `/data/media/tv`
   - Radarr: update root folder to `/data/media/movies`
   - Plex: update library paths if changed

## References

- [TRaSH Hardlinks and Instant Moves Guide](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/)
- [TRaSH Docker Setup for Hardlinks](https://trash-guides.info/Hardlinks/How-to-setup-for/Docker/)
- [Gluetun Mullvad Servers](https://github.com/qdm12/gluetun/wiki/Mullvad-servers)
- [Arcane Documentation](https://getarcane.app/docs)
- [Plex Account Reclamation](https://github.com/linuxserver/docker-plex/issues/282#issuecomment-1141890033)

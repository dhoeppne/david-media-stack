#!/usr/bin/env bash
#
# migrate.sh — Migrate media stack data from old folder structure to TRaSH hardlinks layout.
#
# OLD STRUCTURE:              NEW STRUCTURE:
# ${DATAROOT}/                ${DATAROOT}/
# ├── complete/               ├── torrents/
# │   ├── tv/                 │   ├── tv/
# │   └── movies/             │   └── movies/
# └── downloads/              └── media/
#     └── <files>                  ├── tv/
#                                  └── movies/
#
# What this script does:
#   1. Renames complete/tv/    → media/tv/
#   2. Renames complete/movies/ → media/movies/
#   3. Removes the now-empty complete/ directory
#   4. Asks whether to wipe downloads/ and turn it into torrents/{tv,movies}/
#      - If yes: deletes downloads/ and creates torrents/tv/ and torrents/movies/
#      - If no:  creates torrents/tv/ and torrents/movies/ alongside the untouched downloads/
#
# Safety:
#   - Uses 'mv' (rename), not copy — instant on the same filesystem, no data duplication
#   - Never touches files outside complete/ and downloads/
#   - Exits on any error (set -e) so partial moves don't leave things in a broken state
#   - Dry-run mode available with --dry-run flag
#
# Usage:
#   ./migrate.sh /path/to/dataroot
#   ./migrate.sh --dry-run /path/to/dataroot
#

set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────────────────────

DRY_RUN=false

# Print an informational message
info() {
    echo "[INFO]  $*"
}

# Print a warning
warn() {
    echo "[WARN]  $*"
}

# Print an error and exit
die() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Run a command, or just print it in dry-run mode
run() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# ─── Argument parsing ──────────────────────────────────────────────────────────

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    info "Dry-run mode — no changes will be made."
    shift
fi

DATAROOT="${1:-}"

if [[ -z "$DATAROOT" ]]; then
    echo "Usage: $0 [--dry-run] /path/to/dataroot"
    echo ""
    echo "  --dry-run   Show what would happen without making changes"
    exit 1
fi

# ─── Validation ─────────────────────────────────────────────────────────────────

# Make sure DATAROOT exists and is a directory
[[ -d "$DATAROOT" ]] || die "DATAROOT does not exist or is not a directory: $DATAROOT"

# Make sure the old structure is present (complete/ with tv/ and movies/ inside)
[[ -d "$DATAROOT/complete" ]]        || die "Expected directory not found: $DATAROOT/complete"
[[ -d "$DATAROOT/complete/tv" ]]     || die "Expected directory not found: $DATAROOT/complete/tv"
[[ -d "$DATAROOT/complete/movies" ]] || die "Expected directory not found: $DATAROOT/complete/movies"

# Make sure the new structure doesn't already exist (avoid clobbering)
[[ ! -e "$DATAROOT/media" ]]    || die "Destination already exists: $DATAROOT/media — looks like migration already ran?"
[[ ! -e "$DATAROOT/torrents" ]] || die "Destination already exists: $DATAROOT/torrents — looks like migration already ran?"

info "DATAROOT: $DATAROOT"
echo ""

# ─── Step 1: Show what we're working with ────────────────────────────────────────

info "Current contents of DATAROOT:"
ls -la "$DATAROOT"
echo ""

# ─── Step 2: Create the new media/ directory and move libraries into it ─────────

info "Creating media/ directory..."
run mkdir -p "$DATAROOT/media"

# Move the TV library: complete/tv/ → media/tv/
info "Moving complete/tv/ → media/tv/ ..."
run mv "$DATAROOT/complete/tv" "$DATAROOT/media/tv"

# Move the movie library: complete/movies/ → media/movies/
info "Moving complete/movies/ → media/movies/ ..."
run mv "$DATAROOT/complete/movies" "$DATAROOT/media/movies"

# ─── Step 3: Clean up the old complete/ directory ────────────────────────────────

# Check if there's anything left in complete/ besides tv/ and movies/ (which we just moved)
REMAINING=$(find "$DATAROOT/complete" -mindepth 1 -maxdepth 1 2>/dev/null || true)

if [[ -z "$REMAINING" ]]; then
    # complete/ is empty — safe to remove
    info "Removing empty complete/ directory..."
    run rmdir "$DATAROOT/complete"
else
    # Something else is in complete/ — leave it alone and warn the user
    warn "complete/ still contains files after moving tv/ and movies/:"
    echo "$REMAINING"
    warn "Leaving complete/ in place. You may want to inspect these files."
fi

echo ""

# ─── Step 4: Handle the downloads/ directory ─────────────────────────────────────

if [[ -d "$DATAROOT/downloads" ]]; then
    # Show the user what's in downloads/ so they can make an informed decision
    DOWNLOAD_COUNT=$(find "$DATAROOT/downloads" -type f 2>/dev/null | wc -l | tr -d ' ')
    DOWNLOAD_SIZE=$(du -sh "$DATAROOT/downloads" 2>/dev/null | cut -f1)

    echo "─────────────────────────────────────────────────────────"
    echo "The downloads/ directory contains $DOWNLOAD_COUNT file(s) totaling $DOWNLOAD_SIZE."
    echo ""
    echo "To fully migrate to the TRaSH layout, downloads/ should be replaced"
    echo "with torrents/{tv,movies}/ where qBittorrent saves categorized downloads."
    echo ""
    echo "Options:"
    echo "  yes — Delete downloads/ and create torrents/tv/ and torrents/movies/"
    echo "  no  — Keep downloads/ untouched and create torrents/tv/ and torrents/movies/ alongside it"
    echo "─────────────────────────────────────────────────────────"

    if $DRY_RUN; then
        info "Dry-run mode — skipping prompt, showing both outcomes."
        echo "[DRY-RUN] If yes: rm -rf $DATAROOT/downloads"
        echo "[DRY-RUN] mkdir -p $DATAROOT/torrents/tv"
        echo "[DRY-RUN] mkdir -p $DATAROOT/torrents/movies"
    else
        read -rp "Delete downloads/? (yes/no): " ANSWER

        case "$ANSWER" in
            yes|YES|y|Y)
                info "Deleting downloads/ ..."
                rm -rf "$DATAROOT/downloads"
                info "Deleted."
                ;;
            *)
                info "Leaving downloads/ untouched."
                info "You'll need to manually sort or remove its contents later."
                ;;
        esac
    fi
else
    info "No downloads/ directory found — skipping."
fi

# ─── Step 5: Create the torrents/ category directories ───────────────────────────

# These are where qBittorrent will save downloads, organized by category.
# Even if we kept downloads/, we still create torrents/ for the new layout.
info "Creating torrents/tv/ and torrents/movies/ ..."
run mkdir -p "$DATAROOT/torrents/tv"
run mkdir -p "$DATAROOT/torrents/movies"

echo ""

# ─── Done ────────────────────────────────────────────────────────────────────────

info "Migration complete. New structure:"
if command -v tree &>/dev/null; then
    # tree gives a nice visual, but only show 2 levels deep to keep it readable
    tree -L 2 "$DATAROOT"
else
    # Fallback if tree isn't installed
    find "$DATAROOT" -maxdepth 2 -type d | sort | sed "s|$DATAROOT|.|"
fi

echo ""
info "Next steps:"
info "  1. Update your .env file if DATAROOT changed"
info "  2. Start the stack with the new docker-compose.yaml"
info "  3. In qBittorrent, set category save paths:"
info "       tv     → /data/torrents/tv"
info "       movies → /data/torrents/movies"
info "  4. In Sonarr, set root folder to /data/media/tv"
info "  5. In Radarr, set root folder to /data/media/movies"

#!/bin/sh
# /qompassai/blobs/scripts/quickstart.sh
# Qompass AI Ghost QuickStart: Blobs Bootstrapper
# Copyright (C) 2025 Qompass AI, All rights reserved
###########################################################
set -eu
printf '╭───────────────────────────────────────────╮\n'
printf '│    Qompass AI · Ghost Blobs Quick Start   │\n'
printf '╰───────────────────────────────────────────╯\n\n'
printf '    © 2025 Qompass AI. All rights reserved   \n\n'
DEFAULT_USER="$(id -nu)"
DEFAULT_UID="$(id -u)"
printf "Enter your Linux username [%s]: " "$DEFAULT_USER"
read -r CLAM_USER
[ -z "$CLAM_USER" ] && CLAM_USER="$DEFAULT_USER"
USER_HOME=$(getent passwd "$CLAM_USER" | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    printf "❌ Could not determine home directory for user '%s'.\n" "$CLAM_USER"
    exit 1
fi
USER_ID=$(id -u "$CLAM_USER" 2>/dev/null || echo "")
[ -z "$USER_ID" ] && USER_ID="$DEFAULT_UID"
DATABASE="$USER_HOME/.local/share/clamav"
CACHE="$USER_HOME/.cache/clamav"
CONFIG="$USER_HOME/.config/clamav"
SOCKET="/run/user/$USER_ID/clamav/clamd.sock"
mkdir -p "$DATABASE" "$CACHE" "$CONFIG"
printf "Writing user-level ClamAV configs for user: %s\n" "$CLAM_USER"
printf "Config dir:   %s\n" "$CONFIG"
printf "Data dir:     %s\n" "$DATABASE"
printf "Cache dir:    %s\n" "$CACHE"
printf "Socket:       %s\n" "$SOCKET"
printf "UID:          %s\n" "$USER_ID"
cat >"$CONFIG/clamd.conf" <<EOF
DatabaseDirectory $DATABASE
LocalSocket $SOCKET
LocalSocketMode 660
LogFile $CACHE/clamd.log
LogTime yes
LogVerbose yes
User $CLAM_USER
MaxThreads 4
ReadTimeout 300
EOF
cat >"$CONFIG/freshclam.conf" <<EOF
DatabaseDirectory $DATABASE
LocalSocket $SOCKET
LogTime yes
UpdateLogFile $CACHE/freshclam.log
DatabaseMirror database.clamav.net
Checks 4
DatabaseOwner $CLAM_USER
EOF
printf "✅ Generated configs in %s/clamd.conf and %s/freshclam.conf\n" "$CONFIG" "$CONFIG"
CVD_BASE="https://database.clamav.net"
FILES="daily.cvd bytecode.cvd freshclam.dat"
printf "\nDownloading latest ClamAV database files to %s...\n" "$DATABASE"
for f in $FILES; do
    url="$CVD_BASE/$f"
    dst="$DATABASE/$f"
    printf "  → Downloading %s...\n" "$f"
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL "$url" -o "$dst"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dst"
    else
        printf "❌ Error: curl or wget required to download %s\n" "$f"
        exit 1
    fi
    printf "     ↳ saved to: %s\n" "$dst"
done
HASH_JSON="$DATABASE/hashes.json"
cd "$DATABASE"
printf '{\n' >"$HASH_JSON"
for f in daily.cvd bytecode.cvd freshclam.dat; do
    if [ -e "$f" ]; then
        sum=$(sha256sum "$f" | awk '{print $1}')
        printf '  "%s": "%s",\n' "$f" "$sum" >>"$HASH_JSON"
    fi
done
head -n -1 "$HASH_JSON" >"${HASH_JSON}.tmp"
tail -n 1 "$HASH_JSON" | sed 's/,$//' >>"${HASH_JSON}.tmp"
printf '}\n' >>"${HASH_JSON}.tmp"
mv "${HASH_JSON}.tmp" "$HASH_JSON"
cd - >/dev/null 2>&1 || true
printf "✅ hashes.json generated in %s\n" "$DATABASE"
printf '\nAll files are now ready:\n'
for f in daily.cvd bytecode.cvd freshclam.dat; do
    printf "  %s/%s\n" "$DATABASE" "$f"
done
printf "  %s/hashes.json\n" "$DATABASE"
printf "\nYou can now run ClamAV tools using configs at:\n"
printf "  freshclam --config-file=\"%s/freshclam.conf\"\n" "$CONFIG"
printf "  clamd    --config-file=\"%s/clamd.conf\"\n" "$CONFIG"

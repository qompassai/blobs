#!/bin/sh
# /qompassai/blobs/scripts/quickstart.sh
# Qompass AI Ghost QuickStart Config Generator
# Copyright (C) 2025 Qompass AI, All rights reserved
###########################################################
set -eu
printf '╭───────────────────────────────────────────╮\n'
printf '│    Qompass AI · ClamAV quickstart         │\n'
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
printf "Writing user-level ClamAV configs for user: %s\n\n" "$CLAM_USER"
printf "Config dir:   %s\n" "$CONFIG"
printf "Data dir:     %s\n" "$DATABASE"
printf "Cache dir:    %s\n" "$CACHE"
printf "Socket:       %s\n" "$SOCKET"
printf "UID:          %s\n" "$USER_ID"
cat >"$CONFIG/clamd.conf" <<EOF
# Qompass AI Clamd Config
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
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
printf "\n✅ Generated %s/clamd.conf\n" "$CONFIG"
cat >"$CONFIG/freshclam.conf" <<EOF
# Qompass AI Clamav Config
# Copyright (C) 2025 Qompass AI, All rights reserved
#################################################### 
DatabaseDirectory $DATABASE
LocalSocket $SOCKET
LogTime yes
UpdateLogFile $CACHE/freshclam.log
DatabaseMirror database.clamav.net
Checks 4
DatabaseOwner $CLAM_USER
EOF
printf "✅ Generated %s/freshclam.conf\n\n" "$CONFIG"
printf 'You can now run:\n'
printf '  freshclam --config-file="%s/freshclam.conf"\n' "$CONFIG"
printf '  clamd    --config-file="%s/clamd.conf"\n\n' "$CONFIG"
printf 'All paths are set for user: %s\n' "$CLAM_USER"
printf 'All paths are set for user: %s\n' "$CLAM_USER"
HASH_JSON="$DATABASE/hashes.json"
cd "$DATABASE"
found_any=0
printf '{\n' >"$HASH_JSON"
for f in main.cvd daily.cvd bytecode.cvd; do
    if [ -e "$f" ]; then
        sum=$(sha256sum "$f" | awk '{print $1}')
        printf '  "%s": "%s",\n' "$f" "$sum" >>"$HASH_JSON"
        found_any=1
    fi
done
if [ "$found_any" -ne 0 ]; then
    head -n -1 "$HASH_JSON" >"${HASH_JSON}.tmp"
    tail -n 1 "$HASH_JSON" | sed 's/,$//' >>"${HASH_JSON}.tmp"
    printf '}\n' >>"${HASH_JSON}.tmp"
    mv "${HASH_JSON}.tmp" "$HASH_JSON"
    printf "✅ Generated %s\n" "$HASH_JSON"
else
    printf '⚠ No .cvd files found in %s, hashes.json not generated.\n' "$DATABASE"
    rm -f "$HASH_JSON"
fi
cd - >/dev/null 2>&1 || true
exit 0

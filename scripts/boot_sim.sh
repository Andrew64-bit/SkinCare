#!/usr/bin/env bash
# Avvia (se serve) il simulatore di riferimento e aspetta che sia pronto. Stampa l'UDID.
set -euo pipefail
DEVICE="${1:-iPhone 17 Pro}"
RUNTIME="${2:-iOS-26-2}"
UDID=$(xcrun simctl list devices available -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if '$RUNTIME' in runtime:
        for device in devices:
            if device['name'] == '$DEVICE':
                print(device['udid']); sys.exit(0)
sys.exit('simulatore non trovato: $DEVICE / $RUNTIME')
")
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "$UDID"

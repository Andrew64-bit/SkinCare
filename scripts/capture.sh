#!/usr/bin/env bash
# Uso: scripts/capture.sh <bundle-id> <out.png> [light|dark] [standard|axl] [env KEY=VALUE ...]
# Avvia l'app sul simulatore di riferimento con l'aspetto e la taglia di testo richiesti, aspetta il
# rendering e salva la cattura. Le variabili d'ambiente extra vanno all'app (es. SKINCARE_UITEST=1).
set -euo pipefail
bundle="$1"; out="$2"; appearance="${3:-light}"; textsize="${4:-standard}"; shift 4 || shift $#
UDID=$("$(dirname "$0")/boot_sim.sh")
xcrun simctl ui "$UDID" appearance "$appearance"
if [ "$textsize" = "axl" ]; then
  xcrun simctl ui "$UDID" content_size accessibility-large
else
  xcrun simctl ui "$UDID" content_size medium
fi
xcrun simctl terminate "$UDID" "$bundle" >/dev/null 2>&1 || true
envargs=()
for kv in "$@"; do envargs+=("SIMCTL_CHILD_$kv"); done
env ${envargs[@]+"${envargs[@]}"} xcrun simctl launch "$UDID" "$bundle" >/dev/null
sleep "${CAPTURE_DELAY:-4}"
mkdir -p "$(dirname "$out")"
xcrun simctl io "$UDID" screenshot --type=png "$out" >/dev/null
echo "$out"

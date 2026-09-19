#!/usr/bin/env bash
# Uso: gauntlet/blind.sh <pezzo> <round> <nostra.png> <bar.png>
# Copia le due catture come A.png/B.png con assegnazione casuale in rounds/<pezzo>/round-<round>/
# e scrive la mappa in mapping.txt (da NON mostrare al critico).
set -euo pipefail
piece="$1"; round="$2"; ours="$3"; bar="$4"
dir="$(dirname "$0")/rounds/$piece/round-$round"
mkdir -p "$dir"
if [ $((RANDOM % 2)) -eq 0 ]; then
  cp "$ours" "$dir/A.png"; cp "$bar" "$dir/B.png"; echo "A=ours B=bar" > "$dir/mapping.txt"
else
  cp "$bar" "$dir/A.png"; cp "$ours" "$dir/B.png"; echo "A=bar B=ours" > "$dir/mapping.txt"
fi
echo "$dir"

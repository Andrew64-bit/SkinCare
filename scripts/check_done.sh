#!/usr/bin/env bash
# Prova di completamento (definition of done del piano 2026-09-19).
# Stampa DONE=PASS solo se TUTTE le verifiche passano nello stesso run. Scrive solo in build/check.
# Nessuna pipe sulle righe che decidono l'esito (lezione: `| tail` maschera l'exit code).
# REQUIRE_REMOTE=1 rende bloccante anche il controllo del catalogo remoto (dopo la pubblicazione).
# Niente `-e`: ogni verifica è dentro un if/else che aggiorna `status`, così il run arriva in fondo e
# riporta TUTTI i fallimenti in una volta; l'esito finale dipende solo da `status`.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="build/check"
mkdir -p "$OUT"
status=0
summary=()
step() { printf '\n=== %s ===\n' "$1"; }
ok() { echo "✔ $1"; }
fail() { echo "✘ $1"; status=1; }

step "1. xcodegen + swiftlint"
if xcodegen generate --quiet; then ok "xcodegen generate"; else fail "xcodegen generate"; fi
if git diff --quiet -- SkinCare.xcodeproj/project.pbxproj; then
  ok "project.pbxproj coerente con project.yml"
else
  fail "project.pbxproj differisce da project.yml: rigenerare e committare"
fi
if swiftlint lint --strict --quiet; then ok "swiftlint --strict"; else fail "swiftlint --strict"; fi

step "2. swift test — SkinCareKit"
if (cd Packages/SkinCareKit && swift test > "../../$OUT/kit-test.log" 2>&1); then
  kit=$(grep -oE "with [0-9]+ tests" "$OUT/kit-test.log" | head -1 | grep -oE "[0-9]+")
  ok "SkinCareKit: ${kit:-?} test verdi"; summary+=("kit ${kit:-?} test")
else
  fail "SkinCareKit: test falliti (vedi $OUT/kit-test.log)"
fi

step "3. swift test — catalog-builder + verify dello snapshot"
# Build da pulito: la .build del builder può conservare oggetti con il vecchio layout dei tipi del Kit.
(cd Tools/catalog-builder && swift package clean > /dev/null 2>&1) || true
if (cd Tools/catalog-builder && swift test > "../../$OUT/builder-test.log" 2>&1); then
  builder=$(grep -oE "with [0-9]+ tests" "$OUT/builder-test.log" | head -1 | grep -oE "[0-9]+")
  ok "catalog-builder: ${builder:-?} test verdi"; summary+=("builder ${builder:-?} test")
else
  fail "catalog-builder: test falliti (vedi $OUT/builder-test.log)"
fi
SNAPSHOT="Packages/SkinCareKit/Sources/SkinCareKit/Resources/catalog.json"
if (cd Tools/catalog-builder && swift run -c release catalog-builder verify "../../$SNAPSHOT" > "../../$OUT/verify.log" 2>&1) \
   && grep -q "QUALITY=PASS" "$OUT/verify.log"; then
  products=$(grep -oE "qualità: [0-9]+ prodotti" "$OUT/verify.log" | grep -oE "[0-9]+")
  ok "snapshot: QUALITY=PASS (${products:-?} prodotti)"; summary+=("snapshot ${products:-?} prodotti")
else
  fail "snapshot: QUALITY=FAIL (vedi $OUT/verify.log)"
fi

step "4. xcodebuild test — UI (iPhone 17 Pro, iOS 26.2)"
./scripts/boot_sim.sh > /dev/null
rm -rf "$OUT/ui.xcresult"
if xcodebuild -project SkinCare.xcodeproj -scheme SkinCare \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
     -derivedDataPath build/DerivedData -resultBundlePath "$OUT/ui.xcresult" \
     -parallel-testing-enabled NO -quiet test CODE_SIGNING_ALLOWED=NO > "$OUT/ui-test.log" 2>&1; then
  ok "xcodebuild test"
else
  fail "xcodebuild test (vedi $OUT/ui-test.log)"
fi
if [ -d "$OUT/ui.xcresult" ]; then
  ui=$(xcrun xcresulttool get test-results summary --path "$OUT/ui.xcresult" 2>/dev/null \
       | python3 -c 'import sys,json; d=json.load(sys.stdin); print("%d/%d passati, %d falliti, %d saltati" % (d["passedTests"], d["totalTestCount"], d["failedTests"], d.get("skippedTests", 0)))')
  echo "  UI: $ui"; summary+=("UI $ui")
  case "$ui" in *" 0 falliti"*) ;; *) fail "test UI falliti";; esac
fi

step "5. gauntlet"
for piece in P1 P2 P3 P4 P5 P6 P7; do
  if grep -qE "^ESITO $piece: (VINTO|CAP)" gauntlet/LOG.md 2>/dev/null; then
    ok "$piece: $(grep -E "^ESITO $piece:" gauntlet/LOG.md | tail -1)"
  else
    fail "$piece: nessun esito finale in gauntlet/LOG.md"
  fi
done
refs=$(ls gauntlet/reference/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$refs" -ge 4 ]; then ok "catture del bar: $refs"; else fail "catture del bar: $refs (minimo 4)"; fi
won=0
for piece in P1 P2 P3 P4 P5 P6 P7; do
  case "$(grep -E "^ESITO $piece:" gauntlet/LOG.md 2>/dev/null | tail -1)" in "ESITO $piece: VINTO"*) won=$((won + 1));; esac
done
summary+=("gauntlet vinti $won/7")

step "6. verificatore a contesto fresco"
if grep -qE "^VERIFICATORE: PASS" PROGRESS.md; then ok "VERIFICATORE: PASS in PROGRESS.md"; else fail "esito del verificatore assente in PROGRESS.md"; fi

step "7. catalogo remoto e immagini ritagliate"
URL=$(grep -oE 'https://[^"]+/catalog\.json' SkinCare/AppConfig.swift | head -1)
CUTOUT=$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); u=[p["image"].get("cutoutURL") for p in c["products"] if p["image"].get("cutoutURL")]; print(u[0] if u else "")' "$SNAPSHOT")
remote_ok=1
if curl -sfI --max-time 15 "$URL" > "$OUT/remote-head.txt" 2>/dev/null && grep -qi '^etag:' "$OUT/remote-head.txt"; then
  ok "catalogo remoto: 200 con ETag ($URL)"
else
  remote_ok=0
fi
if [ -n "$CUTOUT" ] && curl -sfI --max-time 15 "$CUTOUT" > "$OUT/cutout-head.txt" 2>/dev/null && grep -qi 'content-type: image/png' "$OUT/cutout-head.txt"; then
  ok "immagine ritagliata remota: 200 image/png ($CUTOUT)"
else
  remote_ok=0
fi
# ogni cutoutURL dello snapshot deve avere il file 400×400 in docs/images
if python3 - "$SNAPSHOT" <<'PY'
import json, sys, struct, os
c = json.load(open(sys.argv[1])); missing = 0; bad = 0; n = 0
for p in c["products"]:
    u = p["image"].get("cutoutURL")
    if not u: continue
    n += 1; f = os.path.join("docs/images", os.path.basename(u))
    if not os.path.exists(f): missing += 1; continue
    with open(f, "rb") as h:
        head = h.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n": bad += 1; continue
    w, hgt = struct.unpack(">II", head[16:24])
    if (w, hgt) != (400, 400): bad += 1
print(f"cutoutURL: {n}, file mancanti {missing}, non 400x400 PNG {bad}")
sys.exit(0 if n > 0 and missing == 0 and bad == 0 else 1)
PY
then ok "file dei ritagli coerenti con lo snapshot"; else fail "file dei ritagli mancanti o non 400×400 (vedi sopra)"; fi
if [ $remote_ok -eq 1 ]; then
  summary+=("remoto ok")
elif [ "${REQUIRE_REMOTE:-0}" = "1" ]; then
  fail "catalogo remoto o immagine ritagliata non raggiungibili ($URL, $CUTOUT)"
else
  echo "· remoto non ancora pubblicato o non raggiungibile: non bloccante (REQUIRE_REMOTE=1 per renderlo tale)"
  summary+=("remoto n/d")
fi

joined=""
for item in "${summary[@]}"; do joined="${joined:+$joined · }$item"; done
echo
if [ $status -eq 0 ]; then
  echo "DONE=PASS · $joined · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
  echo "DONE=FAIL · $joined · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  exit 1
fi

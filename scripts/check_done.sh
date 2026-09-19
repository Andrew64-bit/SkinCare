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
for piece in P1 P2 P3 P4 P5; do
  if grep -qE "^ESITO $piece: (VINTO|CAP)" gauntlet/LOG.md 2>/dev/null; then
    ok "$piece: $(grep -E "^ESITO $piece:" gauntlet/LOG.md | tail -1)"
  else
    fail "$piece: nessun esito finale in gauntlet/LOG.md"
  fi
done
refs=$(ls gauntlet/reference/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$refs" -ge 4 ]; then ok "catture del bar: $refs"; else fail "catture del bar: $refs (minimo 4)"; fi
won=0
for piece in P1 P2 P3 P4 P5; do
  case "$(grep -E "^ESITO $piece:" gauntlet/LOG.md 2>/dev/null | tail -1)" in "ESITO $piece: VINTO"*) won=$((won + 1));; esac
done
summary+=("gauntlet vinti $won/5")

step "6. verificatore a contesto fresco"
if grep -qE "^VERIFICATORE: PASS" PROGRESS.md; then ok "VERIFICATORE: PASS in PROGRESS.md"; else fail "esito del verificatore assente in PROGRESS.md"; fi

step "7. catalogo remoto"
URL=$(grep -oE 'https://[^"]+/catalog\.json' SkinCare/AppConfig.swift | head -1)
if curl -sfI --max-time 15 "$URL" > "$OUT/remote-head.txt" 2>/dev/null && grep -qi '^etag:' "$OUT/remote-head.txt"; then
  ok "catalogo remoto: 200 con ETag ($URL)"; summary+=("remoto ok")
elif [ "${REQUIRE_REMOTE:-0}" = "1" ]; then
  fail "catalogo remoto non raggiungibile o senza ETag ($URL)"
else
  echo "· catalogo remoto non ancora pubblicato o non raggiungibile: non bloccante (REQUIRE_REMOTE=1 per renderlo tale)"
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

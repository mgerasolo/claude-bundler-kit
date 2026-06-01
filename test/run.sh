#!/usr/bin/env bash
# Self-test for the scrubber. Copies the fixture to a temp dir, scrubs it,
# and asserts that secrets/PII are redacted while normal content survives.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT_DIR/lib/scrub.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/sources"
cp "$KIT_DIR/test/fixture.conf" "$TMP/sources/fixture.conf"

scrub_dir "$TMP/sources" "$TMP/report.md" >/dev/null
F="$TMP/sources/fixture.conf"

fail=0
must_gone() { if grep -qE "$1" "$F"; then echo "FAIL: still present -> $1"; fail=1; else echo "ok: redacted -> $2"; fi; }
must_keep() { if grep -qF "$1" "$F"; then echo "ok: kept    -> $1"; else echo "FAIL: lost legit content -> $1"; fail=1; fi; }

must_gone 'sk-proj-ABCDEF'        'OpenAI key'
must_gone 'ghp_ABCDEF'            'GitHub token'
must_gone 'supersecretvalue123'   'password value'
must_gone 'someone@example\.com'  'email'
must_gone '10\.0\.0\.33'          'internal IP'
must_gone 'banner\.local'         'private hostname'
must_gone '555-123-4567'          'phone number'
must_keep 'normal_setting = hello-world'

echo
if [ "$fail" -eq 0 ]; then echo "ALL SCRUB TESTS PASSED"; else echo "SCRUB TESTS FAILED"; exit 1; fi

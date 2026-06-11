#!/usr/bin/env bash
# share.sh — publish the scrubbed bundle. Sourced by claude-bundler.sh.
# All share paths require the scrub step to have run (SECRETS-REPORT.md present).

_require_scrubbed() {
  local out="$1"
  if [ ! -f "$out/SECRETS-REPORT.md" ]; then
    echo "Refusing to share: no SECRETS-REPORT.md found. Run the scrub step first." >&2
    return 1
  fi
  # Re-scrub the WHOLE bundle (incl. any docs written after the first scrub)
  # so nothing sensitive leaves the machine.
  if command -v scrub_dir >/dev/null 2>&1; then
    echo "Re-scrubbing the full bundle before share..."
    scrub_dir "$out" "$out/SECRETS-REPORT.md" >/dev/null 2>&1 || true
  fi
  # Final verification pass with the external scanners.
  if command -v deep_scan >/dev/null 2>&1; then
    echo "Final deep scan before share..."
    if ! deep_scan "$out" "$out/DEEPSCAN-REPORT.md"; then
      echo
      echo "⚠️  The deep scan flagged potential secrets in $out/DEEPSCAN-REPORT.md"
      read -r -p "Findings present. Type 'share anyway' to proceed: " ack
      [ "$ack" = "share anyway" ] || { echo "Share cancelled — fix the findings and re-run."; return 1; }
    fi
  fi
  # In AUTO mode the deep-scan gate already ran upstream (and aborted on
  # findings), so don't prompt — just proceed.
  if [ "${AUTO:-0}" = "1" ]; then return 0; fi
  echo
  echo "Before sharing, confirm you've reviewed: $out/SECRETS-REPORT.md and DEEPSCAN-REPORT.md"
  read -r -p "Have you reviewed them and are OK to share? [y/N]: " r
  [[ "$r" =~ ^[Yy] ]] || { echo "Share cancelled."; return 1; }
}

share_github() {
  local out="$1" name="$2" visibility="$3"
  _require_scrubbed "$out" || return 0
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI ('gh') not found. Install it (https://cli.github.com) and re-run,"
    echo "or choose the zip option instead."
    if [ "${AUTO:-0}" = "1" ]; then
      echo "AUTO mode: falling back to a zip you can email."
      share_zip "$out" "$name"
    fi
    return 0
  fi
  if [ "${AUTO:-0}" = "1" ] && ! gh auth status >/dev/null 2>&1; then
    echo "gh is not authenticated. AUTO mode: falling back to a zip you can email."
    share_zip "$out" "$name"
    return 0
  fi
  ( cd "$out"
    git init -q 2>/dev/null || true
    git add -A
    git -c user.email="bundler@local" -c user.name="Claude Bundler" commit -qm "Claude setup bundle: $name" 2>/dev/null || true
    echo "Creating $visibility GitHub repo: $name-bundle"
    gh repo create "$name-bundle" "--$visibility" --source=. --push --description "My Claude setup, gathered with Claude Bundler Kit"
  ) && echo "Pushed to GitHub. Share the repo URL above with your reviewer."
}

share_zip() {
  local out="$1" name="$2"
  _require_scrubbed "$out" || return 0
  local zip="$PWD/${name}-bundle.zip"
  if command -v zip >/dev/null 2>&1; then
    ( cd "$(dirname "$out")" && zip -rq "$zip" "$(basename "$out")" )
  else
    zip="$PWD/${name}-bundle.tar.gz"
    tar -czf "$zip" -C "$(dirname "$out")" "$(basename "$out")"
  fi
  echo "Created: $zip"
  echo "Attach that file to an email and send it."
}

share_templink() {
  local out="$1" name="$2"
  _require_scrubbed "$out" || return 0
  local tmp="/tmp/${name}-bundle.tar.gz"
  tar -czf "$tmp" -C "$(dirname "$out")" "$(basename "$out")"
  echo "Uploading to a temporary public file-share..."
  echo "(The link is public-but-unlisted and expires; only send it to your reviewer.)"
  if command -v curl >/dev/null 2>&1; then
    local url
    url=$(curl -fsS -F "file=@${tmp}" https://0x0.st 2>/dev/null) || url=""
    if [ -n "$url" ]; then
      echo "Share link: $url"
    else
      echo "Upload failed. Use the zip option instead: $tmp is ready to attach."
    fi
  else
    echo "curl not found. Use the zip option instead: $tmp is ready to attach."
  fi
}

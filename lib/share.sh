#!/usr/bin/env bash
# share.sh — publish the scrubbed bundle. Sourced by claude-bundler.sh.
# Every share path re-scrubs + re-scans first; none runs until that gate passes.

# Human-readable size of a path.
_size_of() { du -sh "$1" 2>/dev/null | cut -f1; }
# Size in KB of a file (portable).
_kb_of()   { du -k "$1" 2>/dev/null | cut -f1; }

_require_scrubbed() {
  local out="$1"
  if [ ! -f "$out/SECRETS-REPORT.md" ]; then
    echo "Refusing to share: no SECRETS-REPORT.md found. Run the scrub step first." >&2
    return 1
  fi
  if command -v scrub_dir >/dev/null 2>&1; then
    echo "Re-scrubbing the full bundle before share..."
    scrub_dir "$out" "$out/SECRETS-REPORT.md" >/dev/null 2>&1 || true
  fi
  if command -v deep_scan >/dev/null 2>&1; then
    echo "Final deep scan before share..."
    if ! deep_scan "$out" "$out/DEEPSCAN-REPORT.md"; then
      echo
      echo "⚠️  The deep scan flagged potential secrets in $out/DEEPSCAN-REPORT.md"
      if [ "${AUTO:-0}" = "1" ]; then
        echo "AUTO mode: refusing to share. Fix the findings and re-run."
        return 1
      fi
      read -r -p "Findings present. Type 'share anyway' to proceed: " ack
      [ "$ack" = "share anyway" ] || { echo "Share cancelled — fix the findings and re-run."; return 1; }
    fi
  fi
  # AUTO already gated above; don't prompt.
  if [ "${AUTO:-0}" = "1" ]; then return 0; fi
  echo
  echo "Before sharing, confirm you've reviewed: $out/SECRETS-REPORT.md and DEEPSCAN-REPORT.md"
  read -r -p "Have you reviewed them and are OK to share? [y/N]: " r
  [[ "$r" =~ ^[Yy] ]] || { echo "Share cancelled."; return 1; }
}

share_github() {
  local out="$1" name="$2" visibility="$3"

  # Public is OFF by default — a config bundle should not be world-readable.
  if [ "$visibility" = "public" ] && [ "${ALLOW_PUBLIC:-0}" != "1" ]; then
    echo "Refusing to create a PUBLIC repo for a config bundle (safety default)."
    if [ "${AUTO:-0}" = "1" ]; then
      echo "AUTO mode: using a PRIVATE repo instead. (Re-run with --allow-public to force public.)"
      visibility="private"
    else
      echo "Re-run with --allow-public if you truly want public, or use github-private."
      return 0
    fi
  fi

  _require_scrubbed "$out" || return 0

  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI ('gh') not found. Install it (https://cli.github.com), run"
    echo "'gh auth login', and re-run — or use the zip option."
    [ "${AUTO:-0}" = "1" ] && { echo "AUTO mode: falling back to a zip."; share_zip "$out" "$name"; }
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh is not logged in. Run 'gh auth login' first."
    [ "${AUTO:-0}" = "1" ] && { echo "AUTO mode: falling back to a zip."; share_zip "$out" "$name"; }
    return 0
  fi

  ( cd "$out"
    git init -q 2>/dev/null || true
    git add -A
    git -c user.email="bundler@local" -c user.name="Claude Bundler" \
        commit -qm "Claude setup bundle: $name" 2>/dev/null || true
    echo "Creating $visibility GitHub repo: $name-bundle ($(_size_of "$out"))"
    gh repo create "$name-bundle" "--$visibility" --source=. --push \
       --description "My Claude setup, gathered with Claude Bundler Kit (scrubbed)"
  ) || { echo "Repo create/push failed."; return 0; }

  echo "Pushed to GitHub."
  # Auto-invite the reviewer to a PRIVATE repo so they can pull it.
  if [ -n "${INVITE_USER:-}" ] && [ "$visibility" = "private" ]; then
    local owner; owner="$(gh api user -q .login 2>/dev/null)"
    if gh api --method PUT "repos/$owner/$name-bundle/collaborators/$INVITE_USER" >/dev/null 2>&1; then
      echo "Invited '$INVITE_USER' as a collaborator — they'll get a notification to accept,"
      echo "then can clone: gh repo clone $owner/$name-bundle"
    else
      echo "Could not auto-invite '$INVITE_USER'. Add them under the repo's"
      echo "Settings → Collaborators, or check the username."
    fi
  fi
  echo "When your reviewer has pulled it, you can delete the repo: gh repo delete $name-bundle"
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
  echo "Created: $zip ($(_size_of "$zip"))"
  local kb; kb="$(_kb_of "$zip")"
  if [ "${kb:-0}" -gt 20000 ] 2>/dev/null; then
    echo "⚠️  That's over ~20 MB — many mail servers will bounce it."
    echo "    Prefer: --share github-private --invite <your-github-username>  (or --share templink)."
  else
    echo "Small enough to email. Or use --share github-private for a cleaner hand-off."
  fi
}

share_templink() {
  local out="$1" name="$2"
  _require_scrubbed "$out" || return 0
  local tmp="${TMPDIR:-/tmp}/${name}-bundle.tar.gz"
  tar -czf "$tmp" -C "$(dirname "$out")" "$(basename "$out")"
  echo "Tarball: $tmp ($(_size_of "$tmp"))"
  echo "Uploading to a temporary file-share..."
  echo "NOTE: the link is unlisted but anyone WITH the link can fetch it — only"
  echo "send it directly to your reviewer; it expires on its own."
  if command -v curl >/dev/null 2>&1; then
    local url; url="$(curl -fsS -F "file=@${tmp}" https://0x0.st 2>/dev/null)" || url=""
    if [ -n "$url" ]; then echo "Share link: $url"
    else echo "Upload failed. Use the zip option instead: $tmp is ready to attach."; fi
  else
    echo "curl not found. Use the zip option instead: $tmp is ready to attach."
  fi
}

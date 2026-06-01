#!/usr/bin/env bash
#
# Claude Bundler Kit — interactive wizard
# Gathers your Claude setup, scrubs secrets + PII, inventories executable
# content for the recipient, and helps you share it.
#
# Read-only on your real config. Nothing leaves your machine until secrets
# have been scrubbed and you confirm the report.
#
# Flags:
#   --dry-run   Show what WOULD be gathered, copy nothing, then exit.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for m in gather scrub inventory safety share; do
  # shellcheck disable=SC1090
  source "$KIT_DIR/lib/$m.sh"
done

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
ask()   { local p="$1" d="${2:-}" r; if [ -n "$d" ]; then read -r -p "$p [$d]: " r; echo "${r:-$d}"; else read -r -p "$p: " r; echo "$r"; fi; }
confirm(){ local r; read -r -p "$1 [y/N]: " r; [[ "$r" =~ ^[Yy] ]]; }

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
export DRY_RUN

# ---------------------------------------------------------------------------
# 1. Welcome + overview
# ---------------------------------------------------------------------------
clear || true
bold "================================================================"
bold "  Claude Bundler Kit"
bold "================================================================"
echo
echo "This wizard gathers everything you use with Claude into one clean,"
echo "shareable bundle so someone else can review it and learn."
echo
bold "What it will do:"
echo "  1. Copy your Claude config — CLAUDE.md (+@imports), settings,"
echo "     plugins/MCP, subagents, skills, commands, hooks, output-styles,"
echo "     plus claude-related shell/cron lines and an ENVIRONMENT.md."
echo "  2. Scrub secrets AND PII (keys, tokens, passwords, emails, internal"
echo "     IPs, private hostnames, phone numbers, your username in paths)."
echo "  3. Inventory all executable content so your reviewer knows what's"
echo "     runnable before they run it (EXECUTABLE-CONTENT.md)."
echo "  4. Add plain-English summaries + your idea-to-ship workflow via Claude."
echo "  5. Let you share it: public/private GitHub repo, an emailable zip,"
echo "     or a temporary file-share link."
echo
yellow "READ-ONLY on your real files. Credential-shaped files (.env/.pem/.ssh/"
yellow "etc.) are never copied. Nothing is shared until secrets are scrubbed."
echo

if [ "$DRY_RUN" = "1" ]; then
  bold ">> DRY RUN — showing what would be gathered, copying nothing."
  gather_config "/tmp/claude-bundler-dryrun" || true
  echo; green "Dry run complete. Re-run without --dry-run to build the bundle."
  exit 0
fi

confirm "Ready to start?" || { echo "Aborted. Nothing was changed."; exit 0; }

# ---------------------------------------------------------------------------
# 2. Name the bundle + options
# ---------------------------------------------------------------------------
echo
NAME="$(ask "Name your bundle (letters, numbers, dashes)" "my-claude-setup")"
NAME="$(echo "$NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"; [ -z "$NAME" ] && NAME="my-claude-setup"
OUT_DIR="$PWD/${NAME}-bundle"

if [ -e "$OUT_DIR" ]; then
  yellow "A folder named ${NAME}-bundle already exists at $OUT_DIR"
  confirm "Reuse / overwrite its contents?" || { echo "Aborted."; exit 0; }
fi
mkdir -p "$OUT_DIR/sources"

FINGERPRINT=0
if confirm "Also include a non-source project fingerprint (manifests + layout, NOT your code)?"; then
  FINGERPRINT=1
fi
export FINGERPRINT
green "Bundle will be built at: $OUT_DIR"

# ---------------------------------------------------------------------------
# 3. Gather + environment
# ---------------------------------------------------------------------------
echo; bold ">> Gathering your Claude config..."
gather_config "$OUT_DIR"
gather_fingerprint "$OUT_DIR"
capture_environment "$OUT_DIR"
green "Gather complete."

# ---------------------------------------------------------------------------
# 4. Scrub secrets + PII (mandatory before any share)
# ---------------------------------------------------------------------------
echo; bold ">> Scrubbing secrets + PII..."
scrub_dir "$OUT_DIR/sources" "$OUT_DIR/SECRETS-REPORT.md"
green "Scrub complete. Review $OUT_DIR/SECRETS-REPORT.md"

# ---------------------------------------------------------------------------
# 5. Recipient-safety manifest
# ---------------------------------------------------------------------------
echo; bold ">> Inventorying executable content for your reviewer..."
build_safety_manifest "$OUT_DIR"

# ---------------------------------------------------------------------------
# 6. Summaries + workflow docs (Claude layer)
# ---------------------------------------------------------------------------
echo; bold ">> Adding summaries + workflow docs..."
WIZARD_PROMPT="$KIT_DIR/prompts/WIZARD-PROMPT.md"
if command -v claude >/dev/null 2>&1 && confirm "The 'claude' CLI is available. Run it now to write summaries into the bundle?"; then
  ( cd "$OUT_DIR" && claude -p "You are documenting an already-gathered Claude setup bundle in the current directory. sources/ holds redacted copies of the user's real config; ENVIRONMENT.md and EXECUTABLE-CONTENT.md already exist. Following $KIT_DIR/prompts/, write CONFIG-INVENTORY.md, TOOLS-AND-REFERENCES.md, WORKFLOW.md, SUMMARY-TABLE.md and a top-level README.md. For each component give a plain-English summary, original source path, and a GitHub/homepage URL if public (else 'not found'). Never un-redact anything." ) \
    && green "Claude wrote the summary docs." \
    || yellow "Claude run failed — paste $WIZARD_PROMPT into Claude Code in $OUT_DIR instead."
else
  yellow "Add summaries: open Claude Code in $OUT_DIR and paste $WIZARD_PROMPT"
fi

# ---------------------------------------------------------------------------
# 7. Share
# ---------------------------------------------------------------------------
echo; bold ">> How do you want to share this bundle?"
echo "  1) Public GitHub repo   2) Private GitHub repo"
echo "  3) Zip (for email)      4) Temporary file-share link"
echo "  5) Nothing for now"
CHOICE="$(ask "Choose 1-5" "3")"
case "$CHOICE" in
  1) share_github "$OUT_DIR" "$NAME" "public" ;;
  2) share_github "$OUT_DIR" "$NAME" "private" ;;
  3) share_zip "$OUT_DIR" "$NAME" ;;
  4) share_templink "$OUT_DIR" "$NAME" ;;
  *) echo "Left the bundle at $OUT_DIR. You can share it later." ;;
esac

echo; green "Done. Bundle: $OUT_DIR"

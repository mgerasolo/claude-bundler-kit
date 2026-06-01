#!/usr/bin/env bash
#
# Claude Bundler Kit — interactive wizard
# Gathers your Claude setup, scrubs secrets, and helps you share it.
#
# Read-only on your real config. Nothing leaves your machine until secrets
# have been scrubbed.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/gather.sh
source "$KIT_DIR/lib/gather.sh"
# shellcheck source=lib/scrub.sh
source "$KIT_DIR/lib/scrub.sh"
# shellcheck source=lib/share.sh
source "$KIT_DIR/lib/share.sh"

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
ask()   { local p="$1" d="${2:-}" r; if [ -n "$d" ]; then read -r -p "$p [$d]: " r; echo "${r:-$d}"; else read -r -p "$p: " r; echo "$r"; fi; }
confirm(){ local r; read -r -p "$1 [y/N]: " r; [[ "$r" =~ ^[Yy] ]]; }

# ---------------------------------------------------------------------------
# 1. Welcome + overview
# ---------------------------------------------------------------------------
clear || true
bold "================================================================"
bold "  Claude Bundler Kit"
bold "================================================================"
echo
echo "This wizard will gather everything you use with Claude into one"
echo "clean, shareable bundle so someone else can review it and learn."
echo
bold "What it will do:"
echo "  1. Copy your Claude config (CLAUDE.md, settings, plugins, MCP,"
echo "     skills, slash commands, hooks) into a new bundle folder."
echo "  2. Scrub every secret it finds (keys, tokens, passwords, emails)."
echo "  3. Add plain-English summaries + your idea-to-ship workflow via Claude."
echo "  4. Let you share it: public/private GitHub repo, an emailable zip,"
echo "     or a temporary file-share link."
echo
yellow "It is READ-ONLY on your real files. It only reads and copies."
yellow "Nothing is shared until secrets have been scrubbed."
echo
confirm "Ready to start?" || { echo "Aborted. Nothing was changed."; exit 0; }

# ---------------------------------------------------------------------------
# 2. Name the bundle
# ---------------------------------------------------------------------------
echo
DEFAULT_NAME="my-claude-setup"
NAME="$(ask "Name your bundle (letters, numbers, dashes)" "$DEFAULT_NAME")"
NAME="$(echo "$NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"
[ -z "$NAME" ] && NAME="$DEFAULT_NAME"
OUT_DIR="$PWD/${NAME}-bundle"

if [ -e "$OUT_DIR" ]; then
  yellow "A folder named ${NAME}-bundle already exists at $OUT_DIR"
  confirm "Reuse / overwrite its contents?" || { echo "Aborted."; exit 0; }
fi
mkdir -p "$OUT_DIR/sources"
green "Bundle will be built at: $OUT_DIR"

# ---------------------------------------------------------------------------
# 3. Gather
# ---------------------------------------------------------------------------
echo
bold ">> Gathering your Claude config..."
gather_config "$OUT_DIR"
green "Gather complete."

# ---------------------------------------------------------------------------
# 4. Scrub secrets (mandatory before any share)
# ---------------------------------------------------------------------------
echo
bold ">> Scrubbing secrets..."
scrub_dir "$OUT_DIR/sources" "$OUT_DIR/SECRETS-REPORT.md"
green "Scrub complete. Review $OUT_DIR/SECRETS-REPORT.md"
echo
dim "Open SECRETS-REPORT.md and confirm nothing sensitive remains before sharing."

# ---------------------------------------------------------------------------
# 5. Summaries + workflow docs (Claude layer)
# ---------------------------------------------------------------------------
echo
bold ">> Adding summaries + workflow docs..."
WIZARD_PROMPT="$KIT_DIR/prompts/WIZARD-PROMPT.md"
if command -v claude >/dev/null 2>&1; then
  if confirm "The 'claude' CLI is available. Run it now to write summaries into the bundle?"; then
    ( cd "$OUT_DIR" && claude -p "You are documenting an already-gathered Claude setup bundle in the current directory. The folder sources/ contains redacted copies of the user's real config. Following the structure described in $KIT_DIR/prompts/, write CONFIG-INVENTORY.md, TOOLS-AND-REFERENCES.md, WORKFLOW.md, SUMMARY-TABLE.md and a top-level README.md. For each component give a plain-English summary, the original source path, and a GitHub/homepage URL if it's a public project (else 'not found'). Do not un-redact anything." ) \
      && green "Claude wrote the summary docs." \
      || yellow "Claude run failed — paste $WIZARD_PROMPT into Claude Code manually instead."
  else
    yellow "Skipped. Paste $WIZARD_PROMPT into Claude Code (opened in $OUT_DIR) to add summaries."
  fi
else
  yellow "'claude' CLI not found."
  echo "To add the summary docs: open Claude Code in $OUT_DIR and paste:"
  echo "   $WIZARD_PROMPT"
fi

# ---------------------------------------------------------------------------
# 6. Share
# ---------------------------------------------------------------------------
echo
bold ">> How do you want to share this bundle?"
echo "  1) Public GitHub repo"
echo "  2) Private GitHub repo"
echo "  3) Zip file (for email)"
echo "  4) Temporary file-share link"
echo "  5) Nothing for now — just leave the folder"
CHOICE="$(ask "Choose 1-5" "3")"

case "$CHOICE" in
  1) share_github "$OUT_DIR" "$NAME" "public" ;;
  2) share_github "$OUT_DIR" "$NAME" "private" ;;
  3) share_zip "$OUT_DIR" "$NAME" ;;
  4) share_templink "$OUT_DIR" "$NAME" ;;
  *) echo "Left the bundle at $OUT_DIR. You can share it later." ;;
esac

echo
green "Done. Bundle: $OUT_DIR"

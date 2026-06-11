#!/usr/bin/env bash
#
# Claude Bundler Kit — gather your Claude setup, scrub secrets + PII, inventory
# executable content for the recipient, and share it.
#
# Read-only on your real config. Files are redacted at copy time; external
# scanners run before anything is shared.
#
# USAGE
#   ./claude-bundler.sh                 interactive wizard (asks a few questions)
#   ./claude-bundler.sh --auto          one-shot: build + scrub + scan + zip, no prompts
#   ./claude-bundler.sh --dry-run       show what would be gathered, copy nothing
#
# FLAGS
#   --auto                 non-interactive; sensible defaults; no questions
#   --preflight            run only the dependency checks, then exit (verify a machine)
#   --name <name>          bundle name (default: my-claude-setup)
#   --share <method>       zip | github-private | github-public | templink | none
#                          (default in --auto: zip)
#   --invite <gh-user>     with github-private, auto-invite this GitHub user
#                          (default: mgerasolo; set CBK_DEFAULT_INVITE to change)
#   --project <path>       a repo to probe for git worktrees (repeatable)
#   --allow-public         REQUIRED to use --share github-public (off by default)
#   --fingerprint          include a non-source project fingerprint
#   --with-claude          in --auto, also run the claude CLI to write summaries
#   --yes                  assume yes to overwrite prompts (implied by --auto)
#   --dry-run              list what would be gathered, then exit
#   -h, --help             this help
#
# RECOMMENDED private hand-off (nothing public, revocable):
#   ./claude-bundler.sh --auto --share github-private --invite THEIR_GH_USERNAME

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for m in gather scrub deepscan inventory safety process profile analysis share; do
  # shellcheck disable=SC1090
  source "$KIT_DIR/lib/$m.sh"
done

# Default reviewer to invite to a private repo (override with --invite, or set
# CBK_DEFAULT_INVITE). Any GitHub username works.
DEFAULT_INVITE="${CBK_DEFAULT_INVITE:-mgerasolo}"
PROJECT_PATHS=""

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
ask()   { local p="$1" d="${2:-}" r; if [ -n "$d" ]; then read -r -p "$p [$d]: " r; echo "${r:-$d}"; else read -r -p "$p: " r; echo "$r"; fi; }
confirm(){ local r; read -r -p "$1 [y/N]: " r; [[ "$r" =~ ^[Yy] ]]; }

# ---- defaults / flag parsing ----------------------------------------------
AUTO=0; DRY_RUN=0; YES=0; FINGERPRINT=0; WITH_CLAUDE=0; PREFLIGHT_ONLY=0; ALLOW_PUBLIC=0
NAME=""; SHARE_METHOD=""; INVITE_USER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --auto) AUTO=1; YES=1 ;;
    --yes|-y) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --preflight) PREFLIGHT_ONLY=1 ;;
    --fingerprint) FINGERPRINT=1 ;;
    --with-claude) WITH_CLAUDE=1 ;;
    --allow-public) ALLOW_PUBLIC=1 ;;
    --name) shift; NAME="${1:-}" ;;
    --share) shift; SHARE_METHOD="${1:-}" ;;
    --invite) shift; INVITE_USER="${1:-}" ;;
    --project) shift; PROJECT_PATHS="${PROJECT_PATHS}${1:-}"$'\n' ;;
    -h|--help) sed -n '2,48p' "$0" | sed -E 's/^# ?//'; exit 0 ;;
    *) red "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done
# Default the reviewer to invite (still overridable per run).
[ -z "$INVITE_USER" ] && INVITE_USER="$DEFAULT_INVITE"
export DRY_RUN FINGERPRINT AUTO INVITE_USER ALLOW_PUBLIC PROJECT_PATHS

# ---- preflight ------------------------------------------------------------
have(){ command -v "$1" >/dev/null 2>&1; }
preflight() {
  local missing_critical=0
  bold ">> Preflight — checking what's available:"
  echo "  OS: $(uname -s 2>/dev/null || echo unknown) ($(uname -m 2>/dev/null))"
  for c in perl find file; do
    if have "$c"; then echo "  ✅ $c"; else echo "  ❌ $c (REQUIRED)"; missing_critical=1; fi
  done
  echo "  Secret scanners (optional but recommended — at least one):"
  local any_scanner=0
  for s in betterleaks gitleaks trufflehog detect-secrets; do
    if have "$s"; then echo "    ✅ $s"; any_scanner=1; else echo "    ➖ $s (not installed)"; fi
  done
  [ "$any_scanner" = 0 ] && yellow "    none installed — regex scrub + entropy flag still run; 'brew install betterleaks' recommended"
  echo "  Sharing helpers:"
  have gh  && echo "    ✅ gh (GitHub share)"     || echo "    ➖ gh (needed only for github-* share)"
  have zip && echo "    ✅ zip"                    || echo "    ➖ zip (will fall back to tar.gz)"
  have curl && echo "    ✅ curl (temp link)"      || echo "    ➖ curl (needed only for templink share)"
  have claude && echo "    ✅ claude CLI (summaries)" || echo "    ➖ claude CLI (summaries skipped if absent)"
  echo
  return "$missing_critical"
}

# ---------------------------------------------------------------------------
# Welcome
# ---------------------------------------------------------------------------
[ "$AUTO" = 1 ] || clear || true
bold "================================================================"
bold "  Claude Bundler Kit"
bold "================================================================"
echo

if ! preflight; then
  red "Missing a required tool above. Install it and re-run."
  [ "$(uname -s 2>/dev/null)" = "Darwin" ] && yellow "On macOS: 'brew install betterleaks gitleaks' for the best scan."
  exit 1
fi
if [ "$PREFLIGHT_ONLY" = 1 ]; then
  green "Preflight only — nothing was built. Your machine is ready when the"
  green "REQUIRED tools above are all ✅. Send this output back if unsure."
  exit 0
fi

# ---- dry run --------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
  bold ">> DRY RUN — showing what would be gathered, copying nothing."
  gather_config "/tmp/claude-bundler-dryrun" || true
  echo; green "Dry run complete. Re-run without --dry-run to build the bundle."
  exit 0
fi

# ---- interactive intro / confirm ------------------------------------------
if [ "$AUTO" = 0 ]; then
  echo "This builds one clean, shareable bundle of your Claude setup. It is"
  echo "READ-ONLY on your files, redacts each file as it's copied, never copies"
  echo "credential-shaped files (.env/.pem/.ssh), and runs secret scanners"
  echo "before anything is shared."
  echo
  confirm "Ready to start?" || { echo "Aborted. Nothing was changed."; exit 0; }
fi

# ---- name + output --------------------------------------------------------
if [ "$AUTO" = 0 ] && [ -z "$NAME" ]; then
  NAME="$(ask "Name your bundle (letters, numbers, dashes)" "my-claude-setup")"
fi
[ -z "$NAME" ] && NAME="my-claude-setup"
NAME="$(echo "$NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-')"; [ -z "$NAME" ] && NAME="my-claude-setup"
OUT_DIR="$PWD/${NAME}-bundle"

if [ -e "$OUT_DIR" ]; then
  if [ "$YES" = 1 ]; then yellow "Overwriting existing $OUT_DIR"
  else
    yellow "A folder named ${NAME}-bundle already exists at $OUT_DIR"
    confirm "Reuse / overwrite its contents?" || { echo "Aborted."; exit 0; }
  fi
fi
mkdir -p "$OUT_DIR/sources"

# fingerprint question (interactive only)
if [ "$AUTO" = 0 ] && [ "$FINGERPRINT" = 0 ]; then
  confirm "Also include a non-source project fingerprint (manifests + layout, NOT your code)?" && FINGERPRINT=1
fi
export FINGERPRINT
green "Bundle will be built at: $OUT_DIR"

# ---- gather ---------------------------------------------------------------
echo; bold ">> Gathering your Claude config (redacting each file as it lands)..."
gather_config "$OUT_DIR"
gather_fingerprint "$OUT_DIR"
capture_environment "$OUT_DIR"
capture_process_flow "$OUT_DIR"
capture_profile "$OUT_DIR"
capture_analysis "$OUT_DIR"
green "Gather complete."

# ---- scrub verify ---------------------------------------------------------
echo; bold ">> Verifying redaction (full-tree pass)..."
scrub_dir "$OUT_DIR/sources" "$OUT_DIR/SECRETS-REPORT.md"

# ---- deep scan gate -------------------------------------------------------
echo; bold ">> Deep secret scan (verification)..."
DEEP_OK=1
deep_scan "$OUT_DIR/sources" "$OUT_DIR/DEEPSCAN-REPORT.md" || DEEP_OK=0
if [ "$DEEP_OK" = 1 ]; then
  green "Deep scan clean (or no scanners installed — see DEEPSCAN-REPORT.md)."
else
  yellow "⚠️  Deep scan flagged potential secrets — see $OUT_DIR/DEEPSCAN-REPORT.md"
  if [ "$AUTO" = 1 ]; then
    red "AUTO mode will NOT share a bundle with flagged secrets."
    red "Bundle left at $OUT_DIR. Review DEEPSCAN-REPORT.md, fix, and re-run."
    exit 2
  fi
fi

# ---- recipient-safety manifest -------------------------------------------
echo; bold ">> Inventorying executable content for your reviewer..."
build_safety_manifest "$OUT_DIR"

# ---- summaries (claude layer) --------------------------------------------
WIZARD_PROMPT="$KIT_DIR/prompts/WIZARD-PROMPT.md"
run_claude_summaries() {
  ( cd "$OUT_DIR" && claude -p "You are documenting an already-gathered Claude setup bundle in the current directory. sources/ holds redacted copies of the user's real config; ENVIRONMENT.md and EXECUTABLE-CONTENT.md already exist. Following $KIT_DIR/prompts/, write CONFIG-INVENTORY.md, TOOLS-AND-REFERENCES.md, WORKFLOW.md, SUMMARY-TABLE.md and a top-level README.md. For each component give a plain-English summary, original source path, and a GitHub/homepage URL if public (else 'not found'). Never un-redact anything." )
}
echo; bold ">> Summaries + workflow docs..."
if [ "$AUTO" = 1 ]; then
  if [ "$WITH_CLAUDE" = 1 ] && have claude; then
    run_claude_summaries && green "Claude wrote the summary docs." || yellow "Claude run failed; bundle still has sources + reports."
  else
    yellow "Skipped summaries (auto mode). To add: open Claude Code in $OUT_DIR and paste $WIZARD_PROMPT"
  fi
elif have claude && confirm "Run the 'claude' CLI now to write summaries into the bundle?"; then
  run_claude_summaries && green "Claude wrote the summary docs." \
    || yellow "Claude run failed — paste $WIZARD_PROMPT into Claude Code in $OUT_DIR instead."
else
  yellow "Add summaries later: open Claude Code in $OUT_DIR and paste $WIZARD_PROMPT"
fi

# ---- share ----------------------------------------------------------------
export AUTO
do_share() {
  case "$1" in
    github-public)  share_github "$OUT_DIR" "$NAME" "public" ;;
    github-private) share_github "$OUT_DIR" "$NAME" "private" ;;
    zip)            share_zip "$OUT_DIR" "$NAME" ;;
    templink)       share_templink "$OUT_DIR" "$NAME" ;;
    none|"")        echo "Left the bundle at $OUT_DIR. Share it later." ;;
    *) yellow "Unknown share method '$1' — leaving bundle at $OUT_DIR." ;;
  esac
}

if [ "$AUTO" = 1 ]; then
  [ -z "$SHARE_METHOD" ] && SHARE_METHOD="zip"
  echo; bold ">> Sharing via: $SHARE_METHOD"
  do_share "$SHARE_METHOD"
elif [ -n "$SHARE_METHOD" ]; then
  do_share "$SHARE_METHOD"
else
  echo; bold ">> How do you want to share this bundle?"
  echo "  1) Public GitHub repo   2) Private GitHub repo"
  echo "  3) Zip (for email)      4) Temporary file-share link"
  echo "  5) Nothing for now"
  case "$(ask "Choose 1-5" "3")" in
    1) do_share github-public ;;
    2) do_share github-private ;;
    3) do_share zip ;;
    4) do_share templink ;;
    *) do_share none ;;
  esac
fi

echo; green "Done. Bundle: $OUT_DIR"
echo "Bundle size: $(du -sh "$OUT_DIR" 2>/dev/null | cut -f1)"

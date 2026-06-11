#!/usr/bin/env bash
# gather.sh — copy Claude config into the bundle, mirroring original layout.
# Read-only on source files. Sourced by claude-bundler.sh.
#
# Honors:
#   DRY_RUN=1   -> list what would be copied, copy nothing
#   FINGERPRINT=1 -> also capture a non-source project fingerprint

# Files we must NEVER copy, even if found under a scanned dir.
_is_excluded() {
  case "$1" in
    *.env|*.env.*|*.pem|*.key|*.p12|*.pfx|*.keystore|*.jks) return 0 ;;
    *id_rsa*|*id_ed25519*|*id_ecdsa*|*id_dsa*) return 0 ;;
    */.ssh/*|*/.aws/credentials|*/.netrc|*/.npmrc|*/.pypirc) return 0 ;;
    *credentials*|*.secret|*secrets.json|*.gnupg/*) return 0 ;;
  esac
  return 1
}

# Copy a file into <out>/sources/, preserving a path that mirrors its origin.
_copy_into_sources() {
  local src="$1" out="$2"
  [ -f "$src" ] || return 0
  if _is_excluded "$src"; then
    echo "  ! skipped (credential-shaped, never copied): $src"
    return 0
  fi
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "  would copy: $src"
    return 0
  fi
  local rel="${src#"$HOME"/}"; rel="${rel#/}"
  local dest="$out/sources/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest" 2>/dev/null || cp "$src" "$dest"
  # Redact AT COPY TIME — a raw secret never rests in the bundle unscrubbed.
  command -v scrub_file >/dev/null 2>&1 && scrub_file "$dest" >/dev/null 2>&1 || true
  echo "  + $src"
}

# Copy text-ish files under a directory (skip bulk + binaries + excluded).
_copy_tree() {
  local dir="$1" out="$2"
  [ -d "$dir" ] || return 0
  find "$dir" -type f \
    ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/cache/*' \
    ! -name '*.log' ! -size +512k \
    2>/dev/null | while read -r f; do
      _copy_into_sources "$f" "$out"
    done
}

# Follow @import references inside a CLAUDE.md and copy the referenced files.
_follow_imports() {
  local md="$1" out="$2" base
  [ -f "$md" ] || return 0
  base="$(dirname "$md")"
  { grep -oE '@[A-Za-z0-9._/~-]+' "$md" 2>/dev/null || true; } | sed 's/^@//' | while read -r ref; do
    case "$ref" in
      ~*) ref="${ref/#\~/$HOME}" ;;
      /*) : ;;
      *)  ref="$base/$ref" ;;
    esac
    [ -f "$ref" ] && _copy_into_sources "$ref" "$out"
  done
}

gather_config() {
  local out="$1"
  local proj="$PWD"

  echo " CLAUDE.md files (+ @imports):"
  for md in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.local.md" \
            "$proj/CLAUDE.md" "$proj/.claude/CLAUDE.md" "$proj/CLAUDE.local.md"; do
    _copy_into_sources "$md" "$out"; _follow_imports "$md" "$out"
  done
  find "$proj" -maxdepth 3 -name 'CLAUDE*.md' 2>/dev/null | while read -r f; do
    _copy_into_sources "$f" "$out"; _follow_imports "$f" "$out"
  done

  echo " Settings:"
  for s in settings.json settings.local.json; do
    _copy_into_sources "$HOME/.claude/$s" "$out"
    _copy_into_sources "$proj/.claude/$s" "$out"
  done

  echo " Plugins / MCP config:"
  _copy_into_sources "$HOME/.claude.json" "$out"
  _copy_into_sources "$HOME/.mcp.json" "$out"
  _copy_into_sources "$proj/.mcp.json" "$out"
  # plugin/marketplace manifests (config only, never the plugin code)
  if [ -d "$HOME/.claude/plugins" ]; then
    find "$HOME/.claude/plugins" -maxdepth 3 -type f \
         \( -name '*.json' -o -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) \
         ! -path '*/node_modules/*' 2>/dev/null | while read -r f; do
      _copy_into_sources "$f" "$out"
    done
  fi

  echo " Subagents:"
  _copy_tree "$HOME/.claude/agents" "$out"
  _copy_tree "$proj/.claude/agents" "$out"

  echo " Skills:"
  _copy_tree "$HOME/.claude/skills" "$out"
  _copy_tree "$proj/.claude/skills" "$out"

  echo " Slash commands:"
  _copy_tree "$HOME/.claude/commands" "$out"
  _copy_tree "$proj/.claude/commands" "$out"

  echo " Hooks:"
  _copy_tree "$HOME/.claude/hooks" "$out"
  _copy_tree "$proj/.claude/hooks" "$out"

  echo " Output styles / statusline:"
  _copy_tree "$HOME/.claude/output-styles" "$out"
  _copy_into_sources "$HOME/.claude/statusline.sh" "$out"

  echo " Rules (if present):"
  _copy_tree "$HOME/.claude/rules" "$out"
  _copy_tree "$proj/.claude/rules" "$out"

  echo " Claude-related shell wrappers / cron:"
  _gather_shell_and_cron "$out"
}

# Pull lines that mention `claude` from shell rc files + crontab (scrubbed later).
_gather_shell_and_cron() {
  local out="$1"
  [ "${DRY_RUN:-0}" = "1" ] && { echo "  would scan shell rc + crontab for 'claude'"; return 0; }
  local dest="$out/sources/shell"; mkdir -p "$dest"
  for rc in "$HOME/.zshrc" "$HOME/.zshrc.local" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.aliases"; do
    [ -f "$rc" ] || continue
    grep -niE 'claude|anthropic' "$rc" 2>/dev/null \
      | sed "s|^|$(basename "$rc"): |" >> "$dest/claude-related-shell.txt" || true
  done
  crontab -l 2>/dev/null | grep -iE 'claude|anthropic' > "$dest/claude-related-cron.txt" 2>/dev/null || true
  # Redact these immediately too (aliases/cron can embed tokens).
  if command -v scrub_file >/dev/null 2>&1; then
    for sf in "$dest"/*.txt; do [ -f "$sf" ] && scrub_file "$sf" >/dev/null 2>&1 || true; done
  fi
  [ -s "$dest/claude-related-shell.txt" ] && echo "  + shell rc lines mentioning claude"
  [ -s "$dest/claude-related-cron.txt" ] && echo "  + crontab lines mentioning claude"
  find "$dest" -type f -empty -delete 2>/dev/null || true
}

# Optional: a NON-SOURCE fingerprint of the current project (context for reviewer).
gather_fingerprint() {
  local out="$1" proj="$PWD"
  [ "${FINGERPRINT:-0}" = "1" ] || return 0
  local fp="$out/PROJECT-FINGERPRINT.md"
  {
    echo "# Project Fingerprint (context only — not source code)"
    echo
    echo "- Directory: $(basename "$proj")"
    echo "- Detected manifests:"
    for m in package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile pom.xml build.gradle Dockerfile docker-compose.yml; do
      [ -f "$proj/$m" ] && echo "  - $m"
    done
    echo "- CI config:"
    [ -d "$proj/.github/workflows" ] && ls "$proj/.github/workflows" 2>/dev/null | sed 's/^/  - .github\/workflows\//'
    echo "- Top-level layout:"
    ls -1 "$proj" 2>/dev/null | head -40 | sed 's/^/  - /'
  } > "$fp"
  # Copy manifests themselves (small, non-secret) for the reviewer.
  for m in package.json requirements.txt pyproject.toml go.mod Cargo.toml Dockerfile docker-compose.yml; do
    _copy_into_sources "$proj/$m" "$out"
  done
  echo "  + project fingerprint written"
}

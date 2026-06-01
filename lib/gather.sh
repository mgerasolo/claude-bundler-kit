#!/usr/bin/env bash
# gather.sh — copy Claude config into the bundle, mirroring original layout.
# Read-only on source files. Sourced by claude-bundler.sh.

# Copy a file into <out>/sources/, preserving a path that mirrors its origin.
_copy_into_sources() {
  local src="$1" out="$2"
  [ -f "$src" ] || return 0
  # Mirror layout: strip leading / and ~, keep the rest.
  local rel="${src#"$HOME"/}"
  rel="${rel#/}"
  local dest="$out/sources/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest" 2>/dev/null || cp "$src" "$dest"
  echo "  + $src"
}

# Copy every file under a directory (filtered to text-ish config files).
_copy_tree() {
  local dir="$1" out="$2"
  [ -d "$dir" ] || return 0
  # Limit depth + skip obvious bulk (node_modules, caches, transcripts).
  find "$dir" -type f \
    ! -path '*/node_modules/*' \
    ! -path '*/.git/*' \
    ! -path '*/cache/*' \
    ! -path '*/plugins/*/node_modules/*' \
    ! -name '*.log' \
    2>/dev/null | while read -r f; do
      _copy_into_sources "$f" "$out"
    done
}

gather_config() {
  local out="$1"
  local proj="$PWD"

  echo " CLAUDE.md files:"
  _copy_into_sources "$HOME/.claude/CLAUDE.md" "$out"
  _copy_into_sources "$proj/CLAUDE.md" "$out"
  _copy_into_sources "$proj/.claude/CLAUDE.md" "$out"
  # any nested project CLAUDE.md (shallow)
  find "$proj" -maxdepth 3 -name 'CLAUDE.md' 2>/dev/null | while read -r f; do
    _copy_into_sources "$f" "$out"
  done

  echo " Settings:"
  _copy_into_sources "$HOME/.claude/settings.json" "$out"
  _copy_into_sources "$HOME/.claude/settings.local.json" "$out"
  _copy_into_sources "$proj/.claude/settings.json" "$out"
  _copy_into_sources "$proj/.claude/settings.local.json" "$out"

  echo " Plugins / MCP servers:"
  _copy_into_sources "$HOME/.claude.json" "$out"
  _copy_into_sources "$HOME/.mcp.json" "$out"
  _copy_into_sources "$proj/.mcp.json" "$out"

  echo " Skills:"
  _copy_tree "$HOME/.claude/skills" "$out"
  _copy_tree "$proj/.claude/skills" "$out"

  echo " Slash commands:"
  _copy_tree "$HOME/.claude/commands" "$out"
  _copy_tree "$proj/.claude/commands" "$out"

  echo " Hooks:"
  _copy_tree "$HOME/.claude/hooks" "$out"
  _copy_tree "$proj/.claude/hooks" "$out"

  echo " Rules (if present):"
  _copy_tree "$HOME/.claude/rules" "$out"
  _copy_tree "$proj/.claude/rules" "$out"
}

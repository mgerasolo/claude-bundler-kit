#!/usr/bin/env bash
# inventory.sh — capture environment/version + installed plugins + MCP servers
# via the claude CLI (when present). Writes ENVIRONMENT.md to the bundle root.
# Sourced by claude-bundler.sh. Read-only.

capture_environment() {
  local out="$1"
  local env_md="$out/ENVIRONMENT.md"
  {
    echo "# Environment"
    echo
    echo "Captured by Claude Bundler Kit for reproducibility."
    echo
    echo "## System"
    echo '```'
    echo "OS:    $(uname -srm 2>/dev/null)"
    echo "Shell: ${SHELL:-unknown}"
    echo '```'
    echo

    echo "## Claude Code"
    echo '```'
    if command -v claude >/dev/null 2>&1; then
      claude --version 2>/dev/null || echo "claude --version: unavailable"
    else
      echo "claude CLI not found on PATH"
    fi
    echo '```'
    echo

    echo "## Installed plugins"
    echo '```'
    if command -v claude >/dev/null 2>&1; then
      claude plugin list 2>/dev/null || echo "claude plugin list: unavailable in this version"
    else
      echo "claude CLI not found"
    fi
    echo '```'
    echo

    echo "## MCP servers"
    echo '```'
    if command -v claude >/dev/null 2>&1; then
      claude mcp list 2>/dev/null || echo "claude mcp list: unavailable in this version"
    else
      echo "claude CLI not found"
    fi
    echo '```'
  } > "$env_md"
  echo "  + ENVIRONMENT.md (version + plugins + MCP servers)"
}

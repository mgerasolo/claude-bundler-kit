#!/usr/bin/env bash
# analysis.sh — ANALYSIS.md: a human-readable synthesis of the whole ~/.claude
# setup + REAL usage (from session transcripts) + Claude-related tooling.
# Sourced by claude-bundler.sh. Depends on safety.sh (_describe_script).
#
# PRIVACY: session transcripts are NEVER copied. We only COUNT how often each
# tool / MCP server is invoked by extracting tool-call NAMES (no args, no
# content). Tool names are not secrets.

# Rank tool-call names across recent session transcripts → "NNN name" lines.
_tool_usage() {
  local files
  files="$(find "$HOME/.claude" -maxdepth 4 -name '*.jsonl' -type f 2>/dev/null | head -400)"
  [ -z "$files" ] && return 0
  printf '%s\n' "$files" | while IFS= read -r f; do
    [ -f "$f" ] && grep -hoE '"name":"(mcp__[A-Za-z0-9_-]+__[A-Za-z0-9_-]+|Bash|Read|Edit|Write|MultiEdit|Glob|Grep|Task|Agent|Skill|WebFetch|WebSearch|NotebookEdit|TodoWrite)"' "$f" 2>/dev/null
  done \
    | sed -E 's/"name":"//; s/"$//' \
    | awk -F'__' '/^mcp__/{print "mcp:" $2; next} {print}' \
    | sort | uniq -c | sort -rn
}

# Count invocations for one MCP server name from the usage tally.
_mcp_count() { echo "$1" | awk -v s="mcp:$2" '$2==s{print $1; f=1} END{if(!f)print 0}'; }

capture_analysis() {
  local out="$1"
  local src="$out/sources"
  local md="$out/ANALYSIS.md"
  local _ee=0; [[ $- == *e* ]] && _ee=1; set +e

  local usage; usage="$(_tool_usage)"

  {
    echo "# Analysis — this Claude setup (shareable)"
    echo
    echo "A plain-English analysis of \`~/.claude\` and related tooling: what's"
    echo "configured, what actually gets used, and what's worth learning from."
    echo "Usage numbers come from session transcripts — **counts only; transcripts"
    echo "are never copied into this bundle.**"
    echo

    # ---- Rules ----
    echo "## Rules"
    local rules; rules="$(find "$src" -path '*/rules/*' -name '*.md' 2>/dev/null | sort)"
    if [ -n "$rules" ]; then
      echo "$(printf '%s\n' "$rules" | wc -l | tr -d ' ') rule file(s):"
      printf '%s\n' "$rules" | while IFS= read -r r; do
        local desc; desc="$(awk 'NR<=15 && /^# /{sub(/^# +/,""); print; exit}' "$r" 2>/dev/null)"
        [ -z "$desc" ] && desc="$(grep -m1 -E '\S' "$r" 2>/dev/null | cut -c1-80)"
        echo "- **$(basename "$r")** — ${desc:-（no title）}"
      done
    else
      echo "_No rule files found._"
    fi
    echo

    # ---- Hooks ----
    echo "## Hooks"
    local settings; settings="$(find "$src" -name 'settings.json' 2>/dev/null | head -1)"
    if [ -n "$settings" ]; then
      local ev evs=""
      for ev in PreToolUse PostToolUse UserPromptSubmit SessionStart Stop SubagentStop Notification PreCompact; do
        grep -q "\"$ev\"" "$settings" 2>/dev/null && evs="${evs}$ev "
      done
      echo "- Hook events configured: ${evs:-none}"
    fi
    local hookfiles; hookfiles="$(find "$src" -path '*/hooks/*' -type f 2>/dev/null | sort)"
    if [ -n "$hookfiles" ]; then
      echo "- Hook scripts:"
      printf '%s\n' "$hookfiles" | while IFS= read -r h; do
        echo "    - **$(basename "$h")** — $(_describe_script "$h" 2>/dev/null)"
      done
    else
      echo "- No hook scripts found in config."
    fi
    echo

    # ---- MCP servers + usage ----
    echo "## MCP servers (configured + actual usage)"
    local mcp_files names f
    mcp_files="$(find "$src" -maxdepth 3 \( -name '.mcp.json' -o -name '.claude.json' \) 2>/dev/null)"
    names=""
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      names="${names}$(awk '
        /"mcpServers"[[:space:]]*:[[:space:]]*\{/ {inblk=1; depth=1; next}
        inblk {
          if (depth==1 && $0 ~ /^[[:space:]]*"[A-Za-z0-9_.\-]+"[[:space:]]*:[[:space:]]*\{/) {
            k=$0; sub(/^[[:space:]]*"/,"",k); sub(/".*/,"",k); print k }
          o=gsub(/{/,"{"); c=gsub(/}/,"}"); depth+=o-c; if(depth<=0) inblk=0
        }' "$f" 2>/dev/null || true) "
    done <<< "$mcp_files"
    names="$(echo "$names" | tr ' ' '\n' | sed '/^$/d' | sort -u)"
    if [ -n "$names" ]; then
      echo
      echo "| MCP server | invocations | usage |"
      echo "|------------|------------:|-------|"
      printf '%s\n' "$names" | while IFS= read -r s; do
        local c band; c="$(_mcp_count "$usage" "$s")"
        if   [ "${c:-0}" -ge 20 ] 2>/dev/null; then band="HIGH"
        elif [ "${c:-0}" -ge 5 ]  2>/dev/null; then band="medium"
        else band="low / unused"; fi
        echo "| $s | ${c:-0} | $band |"
      done
      echo
      echo "_HIGH ≥20 calls · medium 5-19 · low/unused <5 (over recent transcripts)._"
    else
      echo "_No MCP servers found in config._"
    fi
    echo

    # ---- Overall tool usage ----
    echo "## Tool usage — what gets used a lot (from transcripts)"
    if [ -n "$usage" ]; then
      echo '```'
      echo "$usage" | head -25
      echo '```'
      echo "Top of the list = high usage; bottom = rarely used. \`mcp:<server>\`"
      echo "rows are MCP tools collapsed per server; the rest are built-in tools."
    else
      echo "_No session transcripts found (none under ~/.claude/projects). Usage"
      echo "numbers will appear once there's session history._"
    fi
    echo

    # ---- Claude-related tooling ----
    echo "## Claude monitoring & related tooling"
    # usage monitors
    command -v ccusage >/dev/null 2>&1 && echo "- **ccusage** installed — tracks Claude Code token usage/cost." || true
    command -v claude-monitor >/dev/null 2>&1 && echo "- **claude-monitor** installed — live usage monitor." || true
    if [ -n "$settings" ] && grep -qiE 'OTEL|CLAUDE_CODE_ENABLE_TELEMETRY' "$settings" 2>/dev/null; then
      echo "- **OpenTelemetry** enabled in settings — exports Claude Code metrics/traces."
    fi
    # python packages
    local py
    py="$({ command -v pip3 >/dev/null 2>&1 && pip3 list 2>/dev/null; command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null; } \
          | grep -iE 'claude|anthropic' | head -15 || true)"
    if [ -n "$py" ]; then
      echo "- Python packages related to Claude/Anthropic:"
      echo '```'; echo "$py"; echo '```'
    fi
    # npm globals
    local npmg
    npmg="$(npm ls -g --depth=0 2>/dev/null | grep -iE 'claude|anthropic|ccusage' | head -15 || true)"
    if [ -n "$npmg" ]; then
      echo "- npm global packages related to Claude:"
      echo '```'; echo "$npmg"; echo '```'
    fi
    [ -z "$py$npmg" ] && ! command -v ccusage >/dev/null 2>&1 && echo "- (no Claude-specific monitoring tools or packages detected)"
    echo

    echo "## Where to go deeper"
    echo "- **PROFILE.md** — one-glance quantified summary + things to learn from."
    echo "- **PROCESS-FLOW.md** — worktrees, testing/CI, git discipline, dev-env per repo."
    echo "- **WORKFLOW.md** — the human-written idea→ship narrative."
    echo "- **sources/** — the redacted config itself."
  } > "$md"

  [ "$_ee" = 1 ] && set -e
  echo "  + ANALYSIS.md (rules · hooks · MCP usage · tooling — narrative analysis)"
}

#!/usr/bin/env bash
# profile.sh — PROFILE.md: a one-glance, quantified summary of the setup +
# auto-highlighted "things worth learning from". Sourced by claude-bundler.sh.
# Depends on process.sh helpers (_all_repos, _top_commands). Read-only.

_count() { find "$1" $2 2>/dev/null | wc -l | tr -d ' '; }

# extract first "key": "value" from a settings file
_setting() { # <file> <key>
  grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$1" 2>/dev/null \
    | head -1 | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/'
}

capture_profile() {
  local out="$1"
  local src="$out/sources"
  local md="$out/PROFILE.md"
  # Best-effort detectors; disable errexit locally so a missing marker can't abort.
  local _ee=0; [[ $- == *e* ]] && _ee=1; set +e

  # config counts
  local n_skills n_cmds n_agents n_hooks n_rules
  n_skills="$(_count "$src" "-path */skills/* -name SKILL.md")"
  [ "${n_skills:-0}" = 0 ] && n_skills="$(_count "$src" "-path */skills/* -name *.md")"
  n_cmds="$(_count "$src" "-path */commands/* -name *.md")"
  n_agents="$(_count "$src" "-path */agents/* -name *.md")"
  n_hooks="$(_count "$src" "-path */hooks/* -type f")"
  n_rules="$(_count "$src" "-path */rules/* -name *.md")"

  # settings: model + permission mode
  local settings model pmode
  settings="$(find "$src" -name 'settings.json' 2>/dev/null | head -1)"
  model="$( [ -n "$settings" ] && _setting "$settings" model )"
  pmode="$( [ -n "$settings" ] && _setting "$settings" defaultMode )"

  # hooks events present
  local hook_events=""
  if [ -n "$settings" ]; then
    local ev
    for ev in PreToolUse PostToolUse UserPromptSubmit SessionStart Stop Notification; do
      grep -q "\"$ev\"" "$settings" 2>/dev/null && hook_events="${hook_events}${ev} "
    done
  fi

  # MCP servers (names, heuristic)
  local mcp_files mcp_names f
  mcp_files="$(find "$src" -maxdepth 3 \( -name '.mcp.json' -o -name '.claude.json' \) 2>/dev/null)"
  mcp_names=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Scope to the mcpServers object and grab only its direct keys (server names),
    # tracking brace depth so nested "env": {...} keys aren't mistaken for servers.
    mcp_names="${mcp_names}$(awk '
      /"mcpServers"[[:space:]]*:[[:space:]]*\{/ {inblk=1; depth=1; next}
      inblk {
        if (depth==1 && $0 ~ /^[[:space:]]*"[A-Za-z0-9_.\-]+"[[:space:]]*:[[:space:]]*\{/) {
          k=$0; sub(/^[[:space:]]*"/,"",k); sub(/".*/,"",k); print k
        }
        o=gsub(/{/,"{"); c=gsub(/}/,"}"); depth+=o-c; if(depth<=0) inblk=0
      }' "$f" 2>/dev/null || true) "
  done <<< "$mcp_files"
  mcp_names="$(echo "$mcp_names" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')"
  local n_mcp; n_mcp="$(echo "$mcp_names" | wc -w | tr -d ' ')"

  # repo-derived booleans (bounded)
  local repos has_ci=no has_tests=no has_precommit=no langs="" wt_repos=0 r i=0
  repos="$(_all_repos 2>/dev/null || true)"
  while IFS= read -r r; do
    [ -n "$r" ] && [ -e "$r/.git" ] || continue
    i=$((i+1)); [ "$i" -gt 12 ] && break
    [ -d "$r/.github/workflows" ] && has_ci=yes
    [ -f "$r/.pre-commit-config.yaml" ] || [ -d "$r/.husky" ] && has_precommit=yes
    { [ -f "$r/pytest.ini" ] || grep -qsiE '"(jest|vitest|mocha|playwright)"' "$r/package.json" 2>/dev/null \
      || grep -qs 'pytest' "$r/pyproject.toml" 2>/dev/null; } && has_tests=yes
    [ -f "$r/package.json" ] && langs="${langs}JS/TS "
    { [ -f "$r/pyproject.toml" ] || [ -f "$r/requirements.txt" ]; } && langs="${langs}Python "
    [ -f "$r/go.mod" ] && langs="${langs}Go "
    [ -f "$r/Cargo.toml" ] && langs="${langs}Rust "
    [ "$(git -C "$r" worktree list 2>/dev/null | wc -l | tr -d ' ')" -gt 1 ] 2>/dev/null && wt_repos=$((wt_repos+1))
  done <<< "$repos"
  langs="$(echo "$langs" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')"

  # tracker signals
  local linear=no; grep -rqilE 'linear' "$src" 2>/dev/null && linear=yes
  local gh_inst=no; command -v gh >/dev/null 2>&1 && gh_inst=yes
  local claude_wt=no; find "$src" -iname '*worktree*' 2>/dev/null | grep -q . && claude_wt=yes

  {
    echo "# Profile — at a glance"
    echo
    echo "Auto-generated highlights of this Claude setup. Skim this first."
    echo
    echo "## Setup"
    echo "- Model: ${model:-unknown}    ·    Permission mode: ${pmode:-unknown (likely default 'ask')}"
    echo "- Config: **$n_skills** skills · **$n_agents** subagents · **$n_cmds** commands · **$n_hooks** hook files · **$n_rules** rules"
    echo "- Hook events active: ${hook_events:-none detected}"
    echo "- MCP servers wired (**$n_mcp**): ${mcp_names:-none detected}"
    echo
    echo "## Workflow"
    echo "- Worktrees: Claude worktree skill=${claude_wt}; repos using git worktrees=${wt_repos}"
    echo "- Issue tracking: Linear=${linear}; GitHub CLI=${gh_inst}"
    echo "- Languages seen: ${langs:-unknown}"
    echo "- Quality gates: CI=${has_ci}; automated tests=${has_tests}; pre-commit=${has_precommit}"
    echo
    echo "## Uses a lot (top commands from history)"
    echo '```'
    _top_commands 10 2>/dev/null || true
    echo '```'
    echo
    echo "## Things worth learning from"
    local any=0
    _learn(){ echo "- $1"; any=1; }
    [ "$claude_wt" = yes ] || [ "$wt_repos" -gt 0 ] && _learn "Uses **worktrees** for parallel/isolated task work."
    [ "$linear" = yes ] && _learn "Tracks work in **Linear** (structured issue flow)."
    [ "$gh_inst" = yes ] && _learn "Uses **GitHub** issues/PRs from the CLI."
    [ "$has_ci" = yes ] && _learn "Has **CI gates** — automated checks before merge."
    [ "$has_tests" = yes ] && _learn "Keeps **automated tests** (reliability backbone)."
    [ "$has_precommit" = yes ] && _learn "Runs **pre-commit hooks** (catches issues before commit)."
    [ -n "$pmode" ] && [ "$pmode" != "default" ] && _learn "Gives Claude autonomy via permission mode **$pmode**."
    [ "${n_skills:-0}" -ge 10 ] 2>/dev/null && _learn "Heavy **skills** user ($n_skills) — codified repeatable workflows."
    [ "${n_hooks:-0}" -ge 3 ] 2>/dev/null && _learn "Automates with **hooks** ($n_hooks files) — guardrails/automation."
    [ "${n_mcp:-0}" -ge 2 ] 2>/dev/null && _learn "Wires Claude to external tools via **MCP**: ${mcp_names}."
    [ "$any" = 0 ] && echo "- (not enough signal yet — see PROCESS-FLOW.md detail)"
    echo
    echo "_Full detail in PROCESS-FLOW.md; the human-written narrative is in WORKFLOW.md._"
  } > "$md"

  [ "$_ee" = 1 ] && set -e
  echo "  + PROFILE.md (one-glance highlights + things worth learning from)"
}

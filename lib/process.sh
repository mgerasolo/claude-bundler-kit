#!/usr/bin/env bash
# process.sh — capture *how the person works*: worktrees, issue tracking,
# Linear, and which process commands they actually use. Writes PROCESS-FLOW.md.
# Sourced by claude-bundler.sh. Read-only.
#
# PRIVACY: shell history can contain secrets, so we NEVER copy it — we only
# count how many times specific process-relevant command patterns appear.
# Raw history lines never enter the bundle.
#
# Inputs (globals, optional):
#   PROJECT_PATHS  newline-separated repo paths to probe for git worktrees

# Discover candidate git repos under common dev roots (shallow, bounded).
_discover_repos() {
  local roots=("$HOME/dev" "$HOME/code" "$HOME/Code" "$HOME/projects" "$HOME/Projects" \
               "$HOME/src" "$HOME/work" "$HOME/repos" "$HOME/Developer" "$HOME/git")
  local r
  for r in "${roots[@]}"; do
    [ -d "$r" ] || continue
    find "$r" -maxdepth 2 -type d -name .git 2>/dev/null | sed 's|/\.git$||'
  done | sort -u | head -30
}

# Count occurrences of a fixed string across the user's shell histories.
_hist_count() {
  local pat="$1" total=0 h c
  for h in "$HOME/.zsh_history" "$HOME/.bash_history" "$HOME/.local/share/fish/fish_history"; do
    [ -f "$h" ] || continue
    c="$(grep -aciF "$pat" "$h" 2>/dev/null || true)"; c="${c:-0}"
    total=$((total + c))
  done
  echo "$total"
}

capture_process_flow() {
  local out="$1"
  local md="$out/PROCESS-FLOW.md"
  local src="$out/sources"

  {
    echo "# Process Flow Signals"
    echo
    echo "How this person appears to work — worktrees, issue tracking, and the"
    echo "process commands they actually run. Signals, not certainties; see"
    echo "WORKFLOW.md for the narrative. (Shell history is **never** copied — the"
    echo "counts below are derived from it without exposing any command text.)"
    echo

    echo "## Worktrees"
    # Claude Code worktree skill/command present in the gathered config?
    local wt_files
    wt_files="$(find "$src" -iname '*worktree*' 2>/dev/null | sed "s|$src/||")"
    if [ -n "$wt_files" ]; then
      echo "- Claude Code worktree skill/command: **present**"
      echo "$wt_files" | sed 's/^/    - /'
    else
      echo "- Claude Code worktree skill/command: not found in config"
    fi
    # git worktrees across probed/discovered repos
    local repos probed=0 with_wt=0
    repos="$(printf '%s\n' "${PROJECT_PATHS:-}"; _discover_repos)"
    repos="$(printf '%s\n' "$repos" | sed '/^$/d' | sort -u)"
    echo "- git worktrees found in repos:"
    if [ -z "$repos" ]; then
      echo "    (no repos discovered; re-run with --project <path> to point at one)"
    else
      local repo n
      while IFS= read -r repo; do
        [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || continue
        probed=$((probed+1))
        n="$(git -C "$repo" worktree list 2>/dev/null | wc -l | tr -d ' ')"
        if [ "${n:-0}" -gt 1 ] 2>/dev/null; then
          with_wt=$((with_wt+1))
          echo "    - $(basename "$repo"): $n worktrees"
        fi
      done <<< "$repos"
      echo "    ($probed repo(s) probed; $with_wt using multiple worktrees)"
    fi
    echo

    echo "## Issue tracking"
    command -v gh >/dev/null 2>&1 && echo "- GitHub CLI (gh): installed" || echo "- GitHub CLI (gh): not installed"
    # Linear signals: MCP server / CLI / config references
    local linear_hits
    linear_hits="$(grep -rilE 'linear' "$src" 2>/dev/null | sed "s|$src/||" | head -10)"
    command -v linear >/dev/null 2>&1 && echo "- Linear CLI: installed" || true
    if [ -n "$linear_hits" ]; then
      echo "- Linear referenced in config (MCP server / settings):"
      echo "$linear_hits" | sed 's/^/    - /'
    else
      echo "- Linear: no references found in config"
    fi
    echo

    echo "## Command usage (from shell history — counts only, no command text)"
    echo
    echo "| Process signal | times seen |"
    echo "|----------------|-----------:|"
    # label : grep-pattern
    local rows=(
      "Claude Code worktrees (/worktree):/worktree"
      "git worktree:git worktree"
      "git branch:git branch"
      "git rebase:git rebase"
      "git stash:git stash"
      "GitHub issues (gh issue):gh issue"
      "GitHub PRs (gh pr):gh pr"
      "gh repo:gh repo"
      "Linear:linear"
      "beads (bd):bd "
      "jujutsu (jj):jj "
      "tmux:tmux"
      "make:make "
      "just:just "
    )
    local entry label pat
    for entry in "${rows[@]}"; do
      label="${entry%%:*}"; pat="${entry#*:}"
      echo "| $label | $(_hist_count "$pat") |"
    done
    echo
    echo "_A 0 usually means 'not used' — but history depth varies, so treat low"
    echo "counts as weak signal and confirm in WORKFLOW.md._"
  } > "$md"

  echo "  + PROCESS-FLOW.md (worktrees, issue tracking, command-usage signals)"
}

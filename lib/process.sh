#!/usr/bin/env bash
# process.sh — capture *how the person works*: worktrees, issue tracking,
# testing/quality gates, git/PR discipline, planning, dev-env, and which
# commands/tools they lean on. Writes PROCESS-FLOW.md. Sourced by claude-bundler.sh.
#
# PRIVACY: shell history can contain secrets, so we NEVER copy it — we only
# derive COUNTS and COMMAND NAMES (first token, no args) from it. Repo probing
# is read-only and reports presence of marker files, not their contents.
#
# Inputs (globals, optional):
#   PROJECT_PATHS  newline-separated repo paths to probe in detail

# ---- discovery ------------------------------------------------------------
_discover_repos() {
  local roots=("$HOME/dev" "$HOME/code" "$HOME/Code" "$HOME/projects" "$HOME/Projects" \
               "$HOME/src" "$HOME/work" "$HOME/repos" "$HOME/Developer" "$HOME/git" "$HOME")
  local r
  for r in "${roots[@]}"; do
    [ -d "$r" ] || continue
    find "$r" -maxdepth 2 -type d -name .git 2>/dev/null | sed 's|/\.git$||'
  done | sort -u | head -30
}

_all_repos() {
  { printf '%s\n' "${PROJECT_PATHS:-}"; _discover_repos; } | sed '/^$/d' | sort -u
}

# ---- history-derived signals (counts + command names only) ----------------
_histories() {
  local h
  for h in "$HOME/.zsh_history" "$HOME/.bash_history" "$HOME/.local/share/fish/fish_history"; do
    [ -f "$h" ] && echo "$h"
  done
}

_hist_count() {
  local pat="$1" total=0 h c
  while IFS= read -r h; do
    c="$(grep -aciF "$pat" "$h" 2>/dev/null || true)"; c="${c:-0}"
    total=$((total + c))
  done < <(_histories)
  echo "$total"
}

# Top command NAMES by frequency (first token; zsh ': ts:0;cmd' prefix stripped).
_top_commands() {
  local n="${1:-20}"
  _histories | while IFS= read -r h; do cat "$h" 2>/dev/null; done \
    | sed -E 's/^: [0-9]+:[0-9]+;//' \
    | sed -E 's/^[[:space:]]*(sudo|command|time|nohup)[[:space:]]+//' \
    | awk '{print $1}' \
    | grep -aE '^[A-Za-z0-9_./-]+$' 2>/dev/null \
    | grep -avE '=' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -"$n"
}

# ---- per-repo detection (presence of marker files = process signal) -------
# echoes markdown bullets for one repo
_repo_report() {
  local repo="$1" rel; rel="$(basename "$repo")"
  echo "### $rel"
  echo "    path: $repo"
  local found=""
  _mark(){ [ -e "$repo/$1" ] && found="${found}$2; "; }
  _markglob(){ compgen -G "$repo/$1" >/dev/null 2>&1 && found="${found}$2; "; }

  # CI / hooks
  [ -d "$repo/.github/workflows" ] && found="${found}GitHub Actions ($(find "$repo/.github/workflows" -maxdepth 1 -name '*.yml' -o -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ') workflow(s)); "
  _mark ".gitlab-ci.yml" "GitLab CI"; _mark ".circleci" "CircleCI"
  _mark ".pre-commit-config.yaml" "pre-commit"; _mark ".husky" "husky"; _mark "lefthook.yml" "lefthook"
  echo "    CI/hooks: ${found:-none detected}"; found=""

  # Tests
  _mark "pytest.ini" "pytest"; _markglob "**/conftest.py" "pytest(conftest)"
  grep -qsiE '"(jest|vitest|mocha|playwright)"' "$repo/package.json" 2>/dev/null && found="${found}js-test(jest/vitest/...); "
  grep -qs 'pytest' "$repo/pyproject.toml" 2>/dev/null && found="${found}pytest; "
  compgen -G "$repo/*_test.go" >/dev/null 2>&1 && found="${found}go test; "
  _mark "spec" "rspec(spec/)"
  # rough test:source ratio
  local t s
  t="$(find "$repo" -type f \( -iname '*test*' -o -iname '*spec*' \) ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/vendor/*' 2>/dev/null | wc -l | tr -d ' ')"
  s="$(find "$repo" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.rs' \) ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/vendor/*' 2>/dev/null | wc -l | tr -d ' ')"
  echo "    tests: ${found:-none detected} | files: ${t} test / ${s} source"; found=""

  # Lint / format / types
  _markglob ".eslintrc*" "eslint"; _markglob ".prettierrc*" "prettier"
  _mark "biome.json" "biome"; _mark ".rubocop.yml" "rubocop"; _mark ".flake8" "flake8"
  grep -qsE '\[tool\.ruff\]|^ruff' "$repo/pyproject.toml" 2>/dev/null && found="${found}ruff; "
  grep -qsE '\[tool\.black\]' "$repo/pyproject.toml" 2>/dev/null && found="${found}black; "
  if [ -f "$repo/tsconfig.json" ]; then
    grep -qs '"strict"[[:space:]]*:[[:space:]]*true' "$repo/tsconfig.json" 2>/dev/null \
      && found="${found}tsconfig(strict); " || found="${found}tsconfig; "
  fi
  _mark "mypy.ini" "mypy"
  echo "    lint/format/types: ${found:-none detected}"; found=""

  # Git / PR discipline
  _markglob ".github/PULL_REQUEST_TEMPLATE*" "PR template"
  _mark ".github/ISSUE_TEMPLATE" "issue templates"; _mark ".github/CODEOWNERS" "CODEOWNERS"; _mark "CODEOWNERS" "CODEOWNERS"
  local merges convk total_c
  merges="$(git -C "$repo" log --merges --oneline -200 2>/dev/null | wc -l | tr -d ' ')"
  total_c="$(git -C "$repo" log --oneline -200 2>/dev/null | wc -l | tr -d ' ')"
  convk="$(git -C "$repo" log --pretty=%s -100 2>/dev/null | grep -cE '^(feat|fix|chore|docs|refactor|test|build|ci|perf)(\(.+\))?!?:' || true)"
  local claudeco; claudeco="$(git -C "$repo" log --pretty=%b -100 2>/dev/null | grep -ciE 'Co-Authored-By:.*(Claude|Anthropic)' || true)"
  echo "    git: ${found:-}commits(last200)=${total_c}, merges=${merges}, conventional=${convk:-0}/100, claude-coauthored=${claudeco:-0}/100"; found=""

  # Planning artifacts
  _mark "PLAN.md" "PLAN.md"; _mark "ROADMAP.md" "ROADMAP"; _mark "CHANGELOG.md" "CHANGELOG"
  _mark "specs" "specs/"; _mark "docs/adr" "ADRs"; _mark "docs/decisions" "decisions/"
  echo "    planning: ${found:-none detected}"; found=""

  # Dev environment
  _mark "Makefile" "make"; _mark "justfile" "just"; _mark "Taskfile.yml" "task"
  _mark ".devcontainer" "devcontainer"; _mark "Dockerfile" "docker"; _mark "docker-compose.yml" "compose"
  _mark ".nvmrc" "nvmrc"; _mark ".tool-versions" "asdf/mise"; _mark "mise.toml" "mise"
  _mark "pnpm-lock.yaml" "pnpm"; _mark "bun.lockb" "bun"; _mark "yarn.lock" "yarn"; _mark "package-lock.json" "npm"
  _mark "poetry.lock" "poetry"; _mark "uv.lock" "uv"; _mark "Cargo.lock" "cargo"
  _mark "nx.json" "nx"; _mark "turbo.json" "turborepo"; _mark "pnpm-workspace.yaml" "pnpm-workspace"
  echo "    dev-env: ${found:-none detected}"; found=""
}

capture_process_flow() {
  local out="$1"
  local md="$out/PROCESS-FLOW.md"
  local src="$out/sources"
  # Detectors are best-effort (lots of "&& set var" probes that return 1 when a
  # marker is absent). Disable errexit locally so a missing marker can't abort.
  local _ee=0; [[ $- == *e* ]] && _ee=1; set +e

  {
    echo "# Process Flow Signals"
    echo
    echo "How this person appears to work — worktrees, trackers, testing/quality"
    echo "gates, git discipline, planning, dev-env, and the commands they lean on."
    echo "Signals, not certainties; see WORKFLOW.md for the narrative."
    echo "(Shell history is **never** copied — only counts + command names are derived.)"
    echo

    echo "## Worktrees"
    local wt_files
    wt_files="$(find "$src" -iname '*worktree*' 2>/dev/null | sed "s|$src/||" || true)"
    if [ -n "$wt_files" ]; then
      echo "- Claude Code worktree skill/command: **present**"
      echo "$wt_files" | sed 's/^/    - /'
    else
      echo "- Claude Code worktree skill/command: not found in config"
    fi
    local repos probed=0 with_wt=0 repo n
    repos="$(_all_repos)"
    echo "- git worktrees across repos:"
    if [ -z "$repos" ]; then
      echo "    (no repos discovered; re-run with --project <path>)"
    else
      while IFS= read -r repo; do
        [ -e "$repo/.git" ] || continue
        probed=$((probed+1))
        n="$(git -C "$repo" worktree list 2>/dev/null | wc -l | tr -d ' ')"
        [ "${n:-0}" -gt 1 ] 2>/dev/null && { with_wt=$((with_wt+1)); echo "    - $(basename "$repo"): $n worktrees"; }
      done <<< "$repos"
      echo "    ($probed repo(s) probed; $with_wt using multiple worktrees)"
    fi
    echo

    echo "## Issue / work tracking"
    command -v gh >/dev/null 2>&1 && echo "- GitHub CLI (gh): installed" || echo "- GitHub CLI (gh): not installed"
    local linear_hits
    linear_hits="$(grep -rilE 'linear' "$src" 2>/dev/null | sed "s|$src/||" | head -10 || true)"
    command -v linear >/dev/null 2>&1 && echo "- Linear CLI: installed" || true
    if [ -n "$linear_hits" ]; then
      echo "- Linear referenced in config:"; echo "$linear_hits" | sed 's/^/    - /'
    else
      echo "- Linear: no references found in config"
    fi
    echo

    echo "## Per-repo process (testing · quality · git · planning · dev-env)"
    echo
    if [ -z "$repos" ]; then
      echo "_No repos discovered. Re-run with --project <path> for this section._"
    else
      local detailed=0
      while IFS= read -r repo; do
        [ -e "$repo/.git" ] || continue
        detailed=$((detailed+1)); [ "$detailed" -gt 8 ] && { echo "_(...more repos omitted; showing first 8)_"; break; }
        _repo_report "$repo"
        echo
      done <<< "$repos"
    fi

    echo "## Commands you use a lot (from shell history — names only, no args)"
    echo
    echo '```'
    _top_commands 20 || true
    echo '```'
    echo
    echo "## Specific process signals (history counts)"
    echo
    echo "| Signal | times seen |"
    echo "|--------|-----------:|"
    local rows=(
      "Claude Code worktrees (/worktree):/worktree"
      "git worktree:git worktree"
      "git rebase:git rebase" "git stash:git stash"
      "GitHub issues (gh issue):gh issue" "GitHub PRs (gh pr):gh pr"
      "Linear:linear" "beads (bd):bd " "jujutsu (jj):jj "
      "Claude CLI (claude):claude" "tmux:tmux" "docker:docker"
      "pytest:pytest" "npm/pnpm test:test"
    )
    local entry label pat
    for entry in "${rows[@]}"; do
      label="${entry%%:*}"; pat="${entry#*:}"
      echo "| $label | $(_hist_count "$pat") |"
    done
    echo
    echo "_Low counts = weak signal (history depth varies). Confirm in WORKFLOW.md._"
  } > "$md"

  [ "$_ee" = 1 ] && set -e
  echo "  + PROCESS-FLOW.md (worktrees · trackers · testing · git · planning · dev-env · usage)"
}

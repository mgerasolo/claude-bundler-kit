#!/usr/bin/env bash
# safety.sh — recipient-safety manifest + risk scan. Sourced by claude-bundler.sh.
#
# This bundle contains EXECUTABLE config (hooks, skill scripts). It may be emailed
# to someone who then reads or runs it. This step inventories every script and
# flags risky / prompt-injection patterns so the recipient reviews before running.

# One-line "what it does" guess: first shebang + first meaningful comment/docstring.
_describe_script() {
  local f="$1" sheb desc
  sheb="$(head -1 "$f" 2>/dev/null | grep -E '^#!' || true)"
  desc="$(grep -m1 -E '^\s*#[^!].*[A-Za-z]' "$f" 2>/dev/null | sed 's/^\s*#\s*//' \
         || grep -m1 -E '^\s*(//|\*|""")' "$f" 2>/dev/null | sed 's/^\s*[/*"]*\s*//')"
  echo "${desc:-no description comment}${sheb:+  [${sheb#\#!}]}"
}

build_safety_manifest() {
  local out="$1"
  local man="$out/EXECUTABLE-CONTENT.md"
  local src="$out/sources"

  {
    echo "# Executable Content — REVIEW BEFORE RUNNING"
    echo
    echo "> ⚠️ This bundle contains scripts and hooks copied from the author's setup."
    echo "> They are provided for **learning**. Read each one before you run it."
    echo "> Hooks in particular execute automatically inside Claude Code."
    echo
    echo "## Scripts & hooks in this bundle"
    echo
    echo "| File | What it appears to do |"
    echo "|------|------------------------|"
  } > "$man"

  local nscripts=0
  while IFS= read -r -d '' f; do
    nscripts=$((nscripts + 1))
    echo "| ${f#"$src"/} | $(_describe_script "$f") |" >> "$man"
  done < <(find "$src" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.zsh' \
              -o -name '*.py' -o -name '*.js' -o -name '*.ts' \) -print0 2>/dev/null
           # also catch extensionless files with a shebang
           find "$src" -type f ! -name '*.*' -print0 2>/dev/null)

  {
    echo
    echo "## Risk flags (patterns worth a closer look)"
    echo
    echo "Lines below matched patterns that are commonly risky (remote-exec,"
    echo "destructive deletes, base64 exfil, or prompt-injection phrasing)."
    echo "A match is **not** proof of malice — review the context."
    echo
    echo '```'
  } >> "$man"

  local flags
  flags="$(grep -rnIE \
    'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh|rm[[:space:]]+-rf[[:space:]]+(/|~|\$HOME)|base64[[:space:]]+(-d|--decode)|/dev/tcp/|nc[[:space:]]+-e|eval[[:space:]]+\$\(|ignore (all )?previous instructions|disregard (the )?above' \
    "$src" 2>/dev/null | sed "s|$src/||" | head -100 || true)"

  if [ -n "$flags" ]; then
    echo "$flags" >> "$man"
  else
    echo "(no risky patterns matched)" >> "$man"
  fi
  echo '```' >> "$man"

  {
    echo
    echo "**$nscripts script/hook file(s) inventoried.**"
    if [ -n "$flags" ]; then
      echo
      echo "⚠️ Some risk flags fired — read the flagged files before running anything."
    fi
  } >> "$man"

  echo "  + EXECUTABLE-CONTENT.md ($nscripts script(s) inventoried)"
  [ -n "$flags" ] && echo "  ⚠️  risk flags fired — see EXECUTABLE-CONTENT.md"
  return 0
}

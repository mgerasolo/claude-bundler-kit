#!/usr/bin/env bash
# deepscan.sh — verification layer. After our regex scrubber redacts known
# formats, run industry secret-scanners over the bundle to catch anything that
# slipped (custom/high-entropy tokens, 800+ known credential types, live secrets).
#
# Sourced by claude-bundler.sh.
#   deep_scan <bundle_dir> <report_path>
#     -> writes DEEPSCAN-REPORT.md
#     -> returns 0 if clean OR no scanners available
#     -> returns 1 if any scanner reported a finding (share should hard-stop)

# Lightweight Shannon-entropy flag: list long high-entropy tokens for human
# review. Pure perl, always available — the floor when no scanner is installed.
_entropy_flag() {
  local dir="$1"
  find "$dir" -type f 2>/dev/null | while read -r f; do
    file "$f" 2>/dev/null | grep -qiE 'text|json|ascii|script' || continue
    perl -ne '
      while (/([A-Za-z0-9_\-+\/]{24,})/g) {
        my $s = $1;
        next if $s =~ /REDACTED/;
        my %c; $c{$_}++ for split //, $s;
        my $H = 0; for (values %c) { my $p = $_/length($s); $H -= $p*log($p)/log(2); }
        if ($H >= 4.0) { print "$ARGV:$.: $s\n"; }
      }
    ' "$f" 2>/dev/null
  done | head -50
}

deep_scan() {
  local dir="$1" report="$2"
  local found=0 ran=0
  local tmp; tmp="$(mktemp -d)"

  {
    echo "# Deep Scan Report (verification layer)"
    echo
    echo "Industry secret-scanners run over the bundle AFTER our regex scrubber,"
    echo "to catch anything the known-format rules missed. A finding here means"
    echo "**stop and review that file before sharing.**"
    echo
  } > "$report"

  # --- betterleaks (preferred: by the Gitleaks creators) ---
  if command -v betterleaks >/dev/null 2>&1; then
    ran=$((ran+1))
    echo "## betterleaks" >> "$report"
    if betterleaks dir "$dir" --no-banner >"$tmp/bl.txt" 2>&1; then
      echo "- ✅ no findings" >> "$report"
    else
      echo "- ⚠️ potential finding(s) — see details below" >> "$report"
      echo '```' >> "$report"
      grep -iE 'finding|secret|rule|file|line' "$tmp/bl.txt" 2>/dev/null | head -60 >> "$report" \
        || tail -40 "$tmp/bl.txt" >> "$report"
      echo '```' >> "$report"
      found=1
    fi
    echo >> "$report"
  fi

  # --- gitleaks ---
  if command -v gitleaks >/dev/null 2>&1; then
    ran=$((ran+1))
    echo "## gitleaks" >> "$report"
    if gitleaks detect --source "$dir" --no-git --redact \
         --report-format json --report-path "$tmp/gitleaks.json" >/dev/null 2>&1; then
      echo "- ✅ no findings" >> "$report"
    else
      local n; n=$(grep -c '"RuleID"' "$tmp/gitleaks.json" 2>/dev/null || echo "?")
      echo "- ⚠️ $n potential finding(s) — see details below" >> "$report"
      echo '```' >> "$report"
      grep -E '"(RuleID|File|StartLine)"' "$tmp/gitleaks.json" 2>/dev/null | head -60 >> "$report" || true
      echo '```' >> "$report"
      found=1
    fi
    echo >> "$report"
  fi

  # --- trufflehog ---
  if command -v trufflehog >/dev/null 2>&1; then
    ran=$((ran+1))
    echo "## trufflehog (filesystem)" >> "$report"
    trufflehog filesystem "$dir" --no-update --json > "$tmp/th.json" 2>/dev/null || true
    local n; n=$(grep -c '"SourceMetadata"' "$tmp/th.json" 2>/dev/null || echo 0)
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
      echo "- ⚠️ $n result(s) (includes unverified) — review before sharing" >> "$report"
      echo '```' >> "$report"
      grep -oE '"DetectorName":"[^"]*"|"file":"[^"]*"' "$tmp/th.json" 2>/dev/null | head -60 >> "$report" || true
      echo '```' >> "$report"
      found=1
    else
      echo "- ✅ no results" >> "$report"
    fi
    echo >> "$report"
  fi

  # --- detect-secrets ---
  if command -v detect-secrets >/dev/null 2>&1; then
    ran=$((ran+1))
    echo "## detect-secrets" >> "$report"
    detect-secrets scan "$dir" > "$tmp/ds.json" 2>/dev/null || true
    local n; n=$(grep -c '"type"' "$tmp/ds.json" 2>/dev/null || echo 0)
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
      echo "- ⚠️ $n potential secret(s) flagged (entropy + plugins) — review" >> "$report"
      found=1
    else
      echo "- ✅ no findings" >> "$report"
    fi
    echo >> "$report"
  fi

  # --- entropy fallback (always) ---
  echo "## High-entropy token flags (review-only)" >> "$report"
  local ent; ent="$(_entropy_flag "$dir")"
  if [ -n "$ent" ]; then
    echo "Long high-entropy strings that are NOT already redacted. Most are" >> "$report"
    echo "harmless (hashes, IDs) — but eyeball them for anything secret-like:" >> "$report"
    echo '```' >> "$report"
    echo "$ent" | sed "s|$dir/||" >> "$report"
    echo '```' >> "$report"
  else
    echo "- ✅ no un-redacted high-entropy strings over threshold" >> "$report"
  fi
  echo >> "$report"

  # --- summary ---
  {
    echo "## Summary"
    if [ "$ran" -eq 0 ]; then
      echo
      echo "⚠️ **No external scanners were installed**, so only our regex scrubber"
      echo "+ the entropy flag above ran. For maximum safety install at least one:"
      echo
      echo '```'
      echo "# betterleaks (recommended — by the Gitleaks creators)"
      echo "brew install betterleaks   # or: https://github.com/betterleaks/betterleaks"
      echo "# gitleaks   (fast, widely used)"
      echo "brew install gitleaks      # or: https://github.com/gitleaks/gitleaks"
      echo "# trufflehog (verifies live secrets)"
      echo "brew install trufflehog    # or: https://github.com/trufflesecurity/trufflehog"
      echo "# detect-secrets"
      echo "pipx install detect-secrets"
      echo '```'
    elif [ "$found" -eq 1 ]; then
      echo
      echo "⚠️ **At least one scanner flagged something.** Open the flagged files,"
      echo "confirm whether it's a real secret, and redact before sharing."
    else
      echo
      echo "✅ **$ran scanner(s) ran, no findings.** Combined with the regex scrub,"
      echo "the bundle is clear of known secret formats."
    fi
  } >> "$report"

  rm -rf "$tmp"
  echo "  deep scan: $ran external scanner(s) ran; findings=$found"
  return "$found"
}

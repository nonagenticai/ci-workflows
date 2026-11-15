#!/usr/bin/env bash
# Refuse to publish private infrastructure.
#
# This is the second half of the public-repo rule. `gitleaks` catches credentials; this catches
# the identifiers around them: internal hostnames, tailnet addresses, host names and private
# repository paths. It scans every tracked file, so it also covers docs, fixtures and recorded
# test data — the places a scrub forgets.
#
# Exit 1 lists every violation. Exit 0 prints the allowlisted and warn-only hits.
#
# Allowlist: `.ci/private-refs.allow`, one rule per line:
#     path/glob:pattern  # why this line is safe to publish
# `path/glob` is a shell glob matched against the repo-relative path; `pattern` is an ERE matched
# against the whole `git grep` hit (`path:line:text`). A justification is mandatory in review —
# the guard does not enforce it, humans do.
#
# Run it locally before pushing, from the root of the repository being checked:
#     git clone --depth 1 https://github.com/nonagenticai/ci-workflows .ci-workflows
#     bash .ci-workflows/scripts/no-private-refs.sh
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 2

# Hard failures. No \b: BSD/macOS regcomp has no word boundary, and this must behave the same on
# the dev box and on the runner. The trailing-boundary groups below are hand-rolled stand-ins for
# \b, for that reason.
HARD=(
  # Needs a boundary AFTER the word, not before. A bare `\.internal` matched the Python function
  # name `main.internal_mint_tenant_bundle_token` on four lines of `licenses` migrations, and a
  # Rust test helper `c.internal(…)` on 107 lines of `agent` — a false positive on the very repos
  # this guard exists to clear. A hostname is always followed by a delimiter (port, path, quote,
  # space, end of line); an identifier is followed by `_`, and a method call by `(`.
  '\.internal([^A-Za-z0-9_(]|$)'
  '100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}'
  # Needs a boundary BEFORE the word. A bare `ts\.net` matched `parts.netloc` in `licenses`'
  # models.py (the `t` of `parts` plus `.netloc`). A real MagicDNS name is preceded by `.` or a
  # quote, never by an identifier character.
  '(^|[^A-Za-z0-9_-])ts\.net'
  'strato-(server|vps)'
  'nonagenticai/gitops-production'
  # A documented login into an address that only exists inside our network (measured: a public
  # repo published `ssh mf1@192.168.1.119 "echo mf1 | sudo -S -u postgres psql …"`). RFC1918 alone
  # stays a warning because test fixtures use it constantly; *reaching* one from a shell does not,
  # which is what all three rules below have in common.
  'ssh +[A-Za-z0-9._-]+@(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)'
  'sudo +-[A-Za-z]*S'
  # Estate machine names, but only where they are unambiguously a host. A bare name would be a
  # false positive — `pgx` is the Go Postgres driver (`jackc/pgx`), and short identifiers like
  # `hp1` appear in ordinary test data. So this names them only next to a login command or a DNS
  # suffix, which is the two ways one actually gets written down.
  '(ssh|scp|rsync) +[^ ]*(mf1|hp1|hp2|mini1|mini2|mini3|worker3)'
  '(^|[^A-Za-z0-9_-])(mf1|hp1|hp2|mini1|mini2|mini3|worker3)\.(local|internal|ts\.net)([^A-Za-z0-9_-]|$)'
)

# Warnings only: RFC1918 literals are usually a test fixture, but they are still an address.
SOFT=(
  '192\.168\.[0-9]{1,3}\.[0-9]{1,3}'
  '(^|[^0-9.])10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
)

allowed() {
  # $1 = full hit line; returns 0 when an allowlist rule covers it.
  local hit="$1" file="${1%%:*}" rule glob pat
  [ -f .ci/private-refs.allow ] || return 1
  while IFS= read -r rule || [ -n "$rule" ]; do
    rule="${rule%%#*}"
    rule="$(printf '%s' "$rule" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$rule" ] || continue
    glob="${rule%%:*}"
    pat="${rule#*:}"
    pat="$(printf '%s' "$pat" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -n "$glob" ] && [ -n "$pat" ] || continue
    # shellcheck disable=SC2254 # glob match is intended
    case "$file" in
      $glob) printf '%s\n' "$hit" | grep -qE -- "$pat" && return 0 ;;
    esac
  done < .ci/private-refs.allow
  return 1
}

hard_args=()
for p in "${HARD[@]}"; do hard_args+=(-e "$p"); done
soft_args=()
for p in "${SOFT[@]}"; do soft_args+=(-e "$p"); done

# This script and its allowlist necessarily spell the patterns out; everything else is scanned.
# Both layouts are excluded because the script is tracked at `scripts/no-private-refs.sh` in this
# repository (which runs it against itself in selftest) and at `scripts/ci/…` where conveyor
# first lived; a consumer repo tracks neither.
SCAN=(-- . ':(exclude)scripts/no-private-refs.sh' ':(exclude)scripts/ci/no-private-refs.sh' ':(exclude).ci/private-refs.allow')

fail=0
allow_count=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  if allowed "$hit"; then
    allow_count=$((allow_count + 1))
    echo "allowed: $hit"
  else
    echo "PRIVATE: $hit"
    fail=1
  fi
done < <(git grep -nI -E "${hard_args[@]}" "${SCAN[@]}" || true)

while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  echo "warn (RFC1918): $hit"
done < <(git grep -nI -E "${soft_args[@]}" "${SCAN[@]}" || true)

echo
if [ "$fail" -ne 0 ]; then
  echo "FAILED: private infrastructure is referenced in tracked files (see PRIVATE lines above)."
  echo "Remove it, or add a reviewed rule to .ci/private-refs.allow with a justification."
  exit 1
fi
echo "OK: no private infrastructure references in $(git ls-files | wc -l | tr -d ' ') tracked files ($allow_count allowlisted)."

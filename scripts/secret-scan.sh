#!/usr/bin/env bash
# Scan the caller's tree for credentials, in DIRECTORY mode.
#
# Dir mode, not range mode: the private archetype scans the commits an event adds (which is why
# it can be red-on-arrival nowhere), but for a PUBLIC repository a pre-existing credential is a
# leak whether or not the current PR touched it. So this scans everything and the repo carries a
# baseline (`.betterleaksignore`) for the adjudicated non-secrets.
#
# Config resolution, in order — same rule the fleet uses:
#   1. the scanned repo's own `.betterleaks.toml`
#   2. this repository's fleet copy (the public counterpart of gitops-production's)
#
# `--config` is REQUIRED. betterleaks only auto-loads a target's own config under
# `--unsafe-auto-load-config`; a bare `betterleaks dir` scans with the BUILT-IN defaults, which
# are not the fleet's (measured on conveyor: 605 findings, 600 of them local dev DSNs).
set -euo pipefail

version=1.10.1
sha=c174b42d7aa60caf58c0c3e555c0e4bed01fe6b0d99a412bce777b5af4ce913e

root="$(git rev-parse --show-toplevel)"
workflow_dir="${CI_WORKFLOWS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
tmp="${RUNNER_TEMP:-/tmp}"

if ! command -v betterleaks >/dev/null 2>&1; then
  curl -fsSL -o "$tmp/betterleaks.tgz" \
    "https://github.com/betterleaks/betterleaks/releases/download/v${version}/betterleaks_${version}_linux_x64.tar.gz"
  echo "${sha}  $tmp/betterleaks.tgz" | sha256sum -c -
  mkdir -p "$tmp/bin"
  tar -xzf "$tmp/betterleaks.tgz" -C "$tmp/bin" betterleaks
  export PATH="$tmp/bin:$PATH"
fi

args=(dir --redact --exit-code 1 --no-banner)

if [ -f "$root/.betterleaks.toml" ]; then
  echo "config: the scanned repo's own .betterleaks.toml"
  args+=(--config="$root/.betterleaks.toml")
else
  echo "config: the fleet copy shipped by ci-workflows"
  args+=(--config="$workflow_dir/.betterleaks.toml")
fi

if [ -f "$root/.betterleaksignore" ]; then
  args+=(--gitleaks-ignore-path "$root/.betterleaksignore")
fi

cd "$root"
betterleaks "${args[@]}" .

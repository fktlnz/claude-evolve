#!/usr/bin/env bash
# claude-evolve installer (Hermes extensions fork) — registers the plugin's
# marketplace and installs it. Idempotent.
set -euo pipefail

FORK_URL="https://github.com/fktlnz/claude-evolve"
UPSTREAM_URL="https://github.com/taipm/claude-evolve"
# Default to this fork (Hermes extensions: fact memory, /grill, /build-skill).
# Override with EVOLVE_SOURCE to install the upstream original instead.
SRC="${EVOLVE_SOURCE:-$FORK_URL}"

echo "claude-evolve installer (Hermes extensions fork)"
echo "  source: $SRC"

if ! command -v claude >/dev/null 2>&1; then
    echo "error: 'claude' CLI not found. Install Claude Code first." >&2
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 not found (required). Install Python 3.8+." >&2
    exit 1
fi

echo "==> Registering marketplace"
claude plugin marketplace add "$SRC" 2>/dev/null \
    || claude plugin marketplace update claude-evolve 2>/dev/null \
    || true

echo "==> Installing plugin"
claude plugin install claude-evolve@claude-evolve

echo
echo "Installed. Restart Claude Code (or run /reload-skills)."
echo "Check it:  /claude-evolve:status"
echo "Try also:  /claude-evolve:grill <plan>  and  /claude-evolve:build-skill <name>"
echo "Fork:      $FORK_URL"
echo "Upstream:  $UPSTREAM_URL"

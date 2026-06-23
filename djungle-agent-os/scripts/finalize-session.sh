#!/usr/bin/env bash
# v4.6.0 (ADR-008b rev.2) — hook SessionEnd: finalizer best-effort.
#
# NON è un percorso di cattura — la cattura è già avvenuta turno per turno via
# digest-on-turn.sh (hook Stop). Qui chiudiamo la sessione (close_and_digest
# senza transcript: il server marca ended_at, niente ri-digest). Best-effort:
# SessionEnd è inaffidabile (non scatta su /clear) → mai critico.
#
# Input (stdin): JSON hook con transcript_path. Auth: CLAUDE_PLUGIN_OPTION_API_KEY.

set -uo pipefail

MCP_URL="https://agents-api.djungle.io/mcp"
API_KEY="${CLAUDE_PLUGIN_OPTION_API_KEY:-${AGENT_OS_API_KEY:-}}"

[ -z "$API_KEY" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# NB: JSONL Cowork doppio-codificato → virgolette escapate (\"session_id\":...).
# Il backslash opzionale (\\?) matcha sia escaped sia pulito.
DB_SID="$(grep -oE 'session_id\\?"[[:space:]]*:[[:space:]]*\\?"[0-9a-fA-F-]{36}' "$TRANSCRIPT_PATH" 2>/dev/null \
  | tail -n1 | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' || true)"
[ -z "$DB_SID" ] && exit 0

# close_and_digest senza transcript → solo chiusura (la cattura è già fatta).
REQ="$(jq -n --arg sid "$DB_SID" '
  { jsonrpc:"2.0", id:1, method:"tools/call",
    params:{ name:"close_and_digest", arguments:{ session_id:$sid, trigger:"idle" } } }' 2>/dev/null)"
[ -z "$REQ" ] && exit 0

curl -s --max-time 15 -X POST "$MCP_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$REQ" >/dev/null 2>&1 || true

exit 0

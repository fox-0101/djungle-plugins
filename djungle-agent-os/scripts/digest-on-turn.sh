#!/usr/bin/env bash
# v4.6.0 (ADR-008b rev.2) — hook Stop: cattura per-turno del Session Digestion.
#
# Scatta dopo OGNI risposta dell'agente in Cowork (deterministico, imposto dal
# runtime). Legge il transcript locale, estrae il DELTA dal cursore di sessione,
# e fa POST JSON-RPC a digest_turn sul MCP server. Il server estrae i fact con
# Haiku e applica la commit policy del tenant.
#
# Input (stdin): JSON dell'hook Claude Code, con almeno:
#   { "session_id": "<cowork session id>", "transcript_path": "<path .jsonl>" }
# Auth: API key del tenant via userConfig → env CLAUDE_PLUGIN_OPTION_API_KEY.
#
# Best-effort: ogni errore è silenzioso (exit 0) — un hook che fallisce NON
# deve mai bloccare la conversazione dell'utente.

set -uo pipefail

MCP_URL="https://agents-api.djungle.io/mcp"
API_KEY="${CLAUDE_PLUGIN_OPTION_API_KEY:-${AGENT_OS_API_KEY:-}}"

# Guard: niente key, niente jq → no-op pulito.
if [ -z "$API_KEY" ]; then exit 0; fi
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
COWORK_SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# DB session_id: l'ultimo UUID emesso da invoke_agent nel transcript
# (il tool result contiene "session_id":"<uuid>"). Prendiamo l'ultimo.
DB_SID="$(grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[0-9a-fA-F-]{36}"' "$TRANSCRIPT_PATH" 2>/dev/null \
  | tail -n1 | grep -oE '[0-9a-fA-F-]{36}' || true)"
[ -z "$DB_SID" ] && exit 0

# agent_id: ultimo "agent_id":"AGT-N" nel transcript (default AGT-0)
AGENT_ID="$(grep -oE '"agent_id"[[:space:]]*:[[:space:]]*"AGT-[0-9]+"' "$TRANSCRIPT_PATH" 2>/dev/null \
  | tail -n1 | grep -oE 'AGT-[0-9]+' || true)"
[ -z "$AGENT_ID" ] && AGENT_ID="AGT-0"

# Cursore per-sessione: quante righe del transcript già processate.
CURSOR_DIR="${TMPDIR:-/tmp}/agentos-digest-cursors"
mkdir -p "$CURSOR_DIR" 2>/dev/null || true
CURSOR_FILE="$CURSOR_DIR/$(printf '%s' "$TRANSCRIPT_PATH" | shasum 2>/dev/null | cut -c1-16)"
LAST_LINE=0
[ -f "$CURSOR_FILE" ] && LAST_LINE="$(cat "$CURSOR_FILE" 2>/dev/null || echo 0)"
TOTAL_LINES="$(wc -l < "$TRANSCRIPT_PATH" 2>/dev/null | tr -d ' ' || echo 0)"
# Niente righe nuove → niente da digerire
[ "$TOTAL_LINES" -le "$LAST_LINE" ] 2>/dev/null && exit 0

# Estrae il delta (righe nuove) e lo converte in [{role,content}] leggendo i
# campi standard JSONL di Claude Code: .message.role + testo dei content block.
DELTA_JSON="$(tail -n +"$((LAST_LINE + 1))" "$TRANSCRIPT_PATH" 2>/dev/null | jq -c -s '
  [ .[]
    | select(.message != null)
    | { role: (.message.role // .type // "user"),
        content: (
          ( .message.content // [] )
          | if type=="string" then .
            else ( [ .[]? | select(.type=="text") | .text ] | join("\n") )
            end
        )
      }
    | select(.content != null and (.content | length) > 0)
    | { role: (if .role=="assistant" then "agent" else .role end), content: .content }
  ]' 2>/dev/null || echo '[]')"

# Niente contenuto utile nel delta → aggiorna comunque il cursore e esci.
NCOUNT="$(printf '%s' "$DELTA_JSON" | jq 'length' 2>/dev/null || echo 0)"
if [ "${NCOUNT:-0}" -eq 0 ] 2>/dev/null; then
  printf '%s' "$TOTAL_LINES" > "$CURSOR_FILE" 2>/dev/null || true
  exit 0
fi

# Payload JSON-RPC tools/call → digest_turn
REQ="$(jq -n --arg sid "$DB_SID" --arg aid "$AGENT_ID" --argjson delta "$DELTA_JSON" '
  { jsonrpc:"2.0", id:1, method:"tools/call",
    params:{ name:"digest_turn", arguments:{ session_id:$sid, agent_id:$aid, transcript_delta:$delta } } }' 2>/dev/null)"
[ -z "$REQ" ] && exit 0

# POST best-effort (timeout corto, output scartato). Avanza il cursore solo se
# la chiamata ritorna senza errore di rete.
if curl -s --max-time 20 -X POST "$MCP_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$REQ" >/dev/null 2>&1; then
  printf '%s' "$TOTAL_LINES" > "$CURSOR_FILE" 2>/dev/null || true
fi

exit 0

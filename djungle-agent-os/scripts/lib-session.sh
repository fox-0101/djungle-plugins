#!/usr/bin/env bash
# lib-session.sh — estrazione del session_id dal transcript (ADR-014b).
# UNICA implementazione per gli hook: la convenzione vive in
# skills/_shared/session-threading.md. L'ultimo marcatore vince.

# Marcatore a formato fisso: <!-- agentos-session id=<uuid> code=... tenant=... agent=... -->
# Niente virgolette nei valori → immune al doppio encoding JSONL (regressione 4.6.1).
agentos_extract_session_id() {
  # $1 = path transcript
  grep -oE 'agentos-session id=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$1" 2>/dev/null \
    | tail -1 | cut -d= -f2
}

# Fallback SOLO per transcript nati prima del plugin 4.7.0 (nessun marcatore):
# la vecchia estrazione dal JSON escapato. Da rimuovere quando i transcript
# pre-4.7 non sono più in circolazione.
agentos_extract_session_id_legacy() {
  grep -oE 'session_id\\?"[[:space:]]*:[[:space:]]*\\?"[0-9a-fA-F-]{36}' "$1" 2>/dev/null \
    | tail -1 | grep -oE '[0-9a-fA-F-]{36}' | tr 'A-F' 'a-f'
}

# Entry point per gli hook: marcatore prima, legacy poi, vuoto se niente.
agentos_session_id() {
  local sid
  sid="$(agentos_extract_session_id "$1")"
  [ -z "$sid" ] && sid="$(agentos_extract_session_id_legacy "$1")"
  printf '%s' "$sid"
}

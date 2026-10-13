#!/usr/bin/env bash
# lib-session.sh — estrazione del session_id dal transcript (ADR-014b).
# UNICA implementazione per gli hook: la convenzione vive in
# skills/_shared/session-threading.md. L'ultimo marcatore vince.

# Marcatore a formato fisso: <!-- agentos-session id=<uuid> code=... tenant=... agent=... -->
# Niente virgolette nei valori → immune al doppio encoding JSONL (regressione 4.6.1).
#
# BKL-0148 (plugin 4.43.1): il marcatore conta SOLO nel testo dei messaggi
# dell'assistente, che è dove lo emettono le skill. Il 13/10 un `cat` di
# session-threading.md (un risultato di tool) ha portato in una chat di
# sviluppo l'esempio del file, e l'hook ha mandato 288 turni in una sessione di
# Set su djungle-bridge chiusa da quattro mesi. Lo stesso valeva per un
# marcatore incollato dall'utente da un'altra chat. Righe JSONL non valide si
# saltano (fromjson?) invece di fermare la lettura.
agentos_extract_session_id() {
  # $1 = path transcript
  jq -rR '
    fromjson?
    | select((.message.role // .type) == "assistant")
    | .message.content
    | if type == "string" then .
      elif type == "array" then (.[]? | select(.type == "text") | .text)
      else empty end
  ' "$1" 2>/dev/null \
    | grep -oE 'agentos-session id=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | tail -1 | cut -d= -f2
}

# Entry point per gli hook: il marcatore, o vuoto. Il fallback dei transcript
# di prima del plugin 4.7 (qualunque "session_id":"<uuid>" nel JSON) è stato
# tolto con BKL-0148: in una chat che chiama tool con session_id prendeva il
# primo uuid che trovava, cioè lo stesso difetto per un'altra via.
agentos_session_id() {
  agentos_extract_session_id "$1"
}

---
name: scribe-status
description: |
  Show the current Scribe capture buffer (read-only). Trigger when the user says "/scribe-status", "scribe status", "cosa ha catturato lo scribe?", "buffer scribe", "fammi vedere i fact catturati", "what has scribe captured?". Useful for debug pre-/wb to see what's in the buffer before committing. Read-only — no side effects.
---

# Scribe Status — read-only buffer inspection (v3.3.0)

Mostra cosa lo Scribe ha catturato finora nella session corrente (o ultime N pending dell'utente). **Read-only**: nessuna modifica, nessuna conferma richiesta, niente commit. Utile per:

- **Debug**: capire perché il `/wb` propone certi delta — guardarli prima
- **Sanity check**: vedere se la cattura sta funzionando dopo aver raccontato fatti
- **Pre-/wb review**: ispezione veloce prima del commit batch

## When to trigger

- `/scribe-status`
- "cosa ha catturato lo scribe?" / "what has scribe captured?"
- "buffer scribe"
- "fammi vedere i fact catturati"
- "scribe debug"

## Step-by-step

### 1. Recupera session_id

Dal payload `invoke_agent` salvato all'apertura della session corrente.

Se non c'è session attiva (es. utente fa `/scribe-status` direttamente in chat senza aver invocato): chiedi "Quale session vuoi ispezionare? Posso mostrarti tutti i tuoi buffer pending con `list_pending_scribe`."

### 2. Call `scribe_review`

```
scribe_review({ session_id: "<uuid>" })
```

Response:

```json
{
  "buffer_id": "uuid|null",
  "facts": [...],
  "groups": [
    {
      "initiative_slug": "agent-os-platform",
      "initiative_name": "Agent OS Platform",
      "resolved": true,
      "deltas": [...]
    }
  ],
  "expires_at": "2026-05-11T..."
}
```

### 3. Render output

#### Se `buffer_id === null` (nessun buffer pending)

```
Scribe buffer — vuoto.
Nessun fact catturato in questa session. Prosegui con la chat —
i fatti che racconti verranno bufferizzati automaticamente.
```

#### Se ci sono fact

```
Scribe buffer — N fact su M iniziative · scade tra Xh

[1] agent-os-platform · Agent OS Platform
    last_3_moves: + "(2026-05-10) Pubblicato endpoint /state"  · high
    decisions_log: + [2026-05-10] Schema visibility binario  · high

[2] bp-djungle-holding-2026 · BP Djungle Holding 2026
    stage: building → delivered  · medium

[3] new-slug-not-resolved · ⚠️  iniziativa non riconosciuta
    open_loops: + "..."  · medium

Per applicare: /wb (review batch) o /sota-update (fact singolo).
Per scartare tutti: il /wb permette di scegliere "n".
```

Annotazioni inline:
- `· high` / `· medium` → confidence
- `⚠️ iniziativa non riconosciuta` → `groups[i].resolved === false` (slug non match nel registry — andrà gestito al `/wb`)
- countdown TTL ("scade tra Xh") in formato umano (es. "23h 12m")

#### Se `expires_at < now()` (buffer scaduto)

```
Scribe buffer — scaduto (TTL 24h superato).
Il sistema lo marcherà come 'expired' al prossimo cleanup. Niente da fare.
```

### 4. Mai applicare

Questa skill **non chiama** `scribe_commit`, `scribe_reject`, o tool di scrittura. Se l'utente dopo `/scribe-status` dice "applica" / "salva" → invita a fare `/wb` per il flusso completo (close session + memory_log + commit pipeline).

## Use cases concreti

### A — Sanity check durante chat lunga

```
Utente: "ok abbiamo deciso di non procedere con Tour in Vespa"
[Scribe cattura: type=decision, slug=tour-in-vespa-deal, confidence=high]
Utente: "/scribe-status"
→ skill mostra: 1 fact su tour-in-vespa-deal: decisions_log: + [2026-05-10] non procediamo con Tour in Vespa
Utente: "ok perfetto, continuiamo"
```

### B — Debug pre-/wb

```
Utente: [conversazione di 20 minuti con Iron]
Utente: "/scribe-status"
→ skill mostra 8 fact su 4 iniziative
Utente: "ah lo slug bp-shoppycode non c'è ancora — procediamo a /wb e lo creo lì"
```

### C — Pulizia mentale

```
Utente: "prima di chiudere fammi vedere cosa ha catturato"
Utente: "/scribe-status"
→ skill mostra 3 fact ma 1 sembra sbagliato
Utente: "/wb review-singolo"  → poi accetta solo 2
```

## Cosa NON fa

- ❌ Non modifica il buffer.
- ❌ Non chiude la session.
- ❌ Non chiama `scribe_commit` né `scribe_reject`.
- ❌ Non scrive su `sota_sections`, `memory_logs`, `handoffs`.
- ❌ Non crea iniziative se trova slug non risolti — solo li segnala.

## Edge case — Multiple session

Se l'utente ha più session aperte e fa `/scribe-status` senza specificare quale: chiama `list_pending_scribe()` (default: tutti i buffer pending dell'utente) e mostra summary multi-session:

```
Hai 3 buffer Scribe pending:

· session SES-INV-... (Iron, 2 ore fa) — 5 fact su 3 iniziative
· session SES-INV-... (Vince, 30 min fa) — 2 fact su 1 iniziativa
· session SES-INV-... (Doc, 5 min fa, current) — 1 fact su 1 iniziativa

Quale vuoi ispezionare nel dettaglio? [SES-... / SES-... / SES-... / current]
```

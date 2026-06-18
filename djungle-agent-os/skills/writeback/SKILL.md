---
name: writeback
description: |
  Session writeback command for Agent OS. Use this skill whenever the user says "/writeback", "writeback", "salva sessione", "chiudi sessione", "session log", "wb", or any variation of wanting to save/log what happened during an agent session. This is the WRITEBACK step of the Agent OS flow (INVOKE > CHAT > WRITEBACK > EVOLVE). v4.5.0 introduce la Session Digestion server-side (scribe_digest): la cattura dei fact non dipende più dall'agente in-prompt — il server estrae i fact dal transcript completo con Haiku al momento del /wb, poi review + commit con conferma utente.
---

# Writeback — Agent OS Session Logger (v4.5.0)

Close the loop on every agent session. Pipeline:

1. **Close** — chiudi session con summary
2. **Memory logs** — cross-post selettivo
3. **Digest** — `scribe_digest` estrae i fact dal transcript completo (v4.5.0)
4. **Review** — l'utente conferma / scarta / review puntuale
5. **Commit** — apply tutto in transazione, audit log

Terzo step del cycle Agent OS: **INVOKE > CHAT > WRITEBACK > EVOLVE**.

> **v4.6.0 — il `/wb` è ora l'override manuale.** Da v4.6 il writeback è
> automatico (ADR-008b): cambiando agente o lasciando idle la sessione, il
> server la chiude e digerisce da solo, applicando la commit policy del tenant
> (HIGH → SOTA, MEDIUM → coda `/review-queue`). `/wb` resta per chi vuole
> chiudere e rivedere **subito**, con controllo pieno sui delta — è il path
> interattivo qui descritto. La maggior parte delle sessioni non ha più bisogno
> di un `/wb` esplicito.

> **v4.5.0 — cambio architetturale (ADR-008a).** Fino alla v4.4 la cattura
> dei fact dipendeva dall'agente che chiamava `scribe_capture` in-prompt dopo
> ogni turno. Non funzionava (cattura nel ~1,85% delle sessioni). Ora la
> cattura è **server-side e deterministica**: al `/wb` chiami `scribe_digest`
> passando il transcript completo della conversazione → il server estrae i
> fact con Haiku 4.5 → popola il buffer → poi `scribe_review` lo legge. La
> cattura è garantita, non più sperata.

## Cosa cattura il writeback

Il writeback è il momento di **sincronizzazione**. Cattura due classi di dati:

### A — Summary + Memory logs (esistente da v3.2.1)

Analizzi la conversazione ed estrai contenuto per 6 categorie:

1. **Learnings & Insight** — Informazioni nuove, connessioni inattese.
2. **Decisioni Prese** — Scelte concrete, direzione, trade-off, motivazione.
3. **Performance Assessment** — Quality, efficiency, tone. Rate: `Excellent`, `Good`, `Adequate`, `Needs Improvement`.
4. **Feedback Ricevuto** — Correzioni, lodi, segnali di frustrazione.
5. **Segnali di Evoluzione** — Cose che suggeriscono che il prompt/knowledge dell'agente vadano aggiornati.
6. **Stato Progetto** — Task completati, nuovi task, blockers, deadline.

Il summary va in `close_session({summary})`. Cross-post selettivo in `write_memory_log` per le righe che vuoi recuperare alla prossima invocazione.

### B — Scribe buffer via Session Digestion (v4.5.0+)

Al `/wb` chiami `scribe_digest` passando il **transcript completo** della
conversazione. Il server estrae i **fact** (8 tipi: stage_change, move_done,
decision, open_loop_new/closed, reference, metric, next_action_change) con
Haiku 4.5, applica confidence gating, e popola il buffer pending della
session. Poi `scribe_review` lo legge e l'utente conferma. Vedi **Step 3.5-5**.

## Step-by-step

### Step 1 — Recupera contesto sessione

Dal payload `invoke_agent` salvato all'apertura della session:

- `session_id` (UUID) — required per chiudere la session e fetch buffer Scribe
- `session.agent_id` (es. `AGT-2`)
- `session.initiative_id` (UUID, v3.2.0+) — `resolved_initiative.id`. Null se la session non era legata a iniziativa
- `touched_initiatives[]` — eventuali iniziative cross-touched durante la chat (build dalla conversazione)

Se `session_id` non recuperabile (utente ha invocato fuori da Cowork), salta Step 4 (close_session) e fai solo write_memory_log + chiedi all'utente lo slug iniziativa per i memory_log.

### Step 2 — Close session

```
close_session({
  session_id: "<uuid>",
  summary: "## Sommario Sessione\n[summary]\n\n## Learnings & Insight\n- ...\n\n## Decisioni Prese\n- ...\n\n## Performance\n**Rating:** Good\n[explanation]\n\n## Feedback Ricevuto\n- ...\n\n## Segnali di Evoluzione\n- ...\n\n## Stato Progetto\n- ..."
})
```

Response: `{ok, session_id, ended_at, already_closed}`. Se `already_closed: true` (retry post-errore), salta scrittura memory_log se già fatti — ma procedi con Step 3-6 (lo Scribe buffer è separato).

### Step 3 — Cross-post memory logs (con initiative_id v3.2.1+)

Per ogni learning/decision/feedback/evolution di alto valore:

```
write_memory_log({
  agent_id: "<session.agent_id>",
  type: "learning",
  content: "...",
  tags: [...],
  initiative_id: "<session.initiative_id>",       // PROPAGA SEMPRE
  touched_initiatives: ["<other-uuid>"]           // se applicabile
})
```

Heuristic: "voglio vedere questo prima della prossima sessione su questa iniziativa?". Se sì → memory_log. Altrimenti resta solo nel summary.

> **Nota v3.2.1 fix:** `initiative_id` deve sempre essere propagato dalla session se esiste, altrimenti il record è orfano e il Probe non lo vede.

### Step 3.5 — Digest del transcript (v4.5.0, OBBLIGATORIO prima del review)

Questo è il cuore della v4.5.0. Prima di leggere il buffer, **digerisci** il
transcript della conversazione corrente. Costruisci l'array `transcript`
dai messaggi della chat (i turni dell'utente e dell'agente in questa
sessione) e chiama:

```
scribe_digest({
  session_id: "<uuid>",
  agent_id: "<session.agent_id>",     // es. "AGT-2"
  transcript: [
    { role: "user",  content: "<messaggio utente 1>" },
    { role: "agent", content: "<risposta agente 1>" },
    { role: "user",  content: "<messaggio utente 2>" },
    ...
  ]
})
```

Response: `{ facts_extracted, buffer_id, facts[], skipped? }`.

- Includi **tutti** i turni rilevanti della sessione corrente, in ordine.
  Il server vede il transcript completo → disambigua meglio (es. un loop
  aperto e poi chiuso nella stessa chat si annulla).
- Il server estrae, applica confidence gating (scarta `low`), e popola il
  buffer pending. È **idempotente**: se la session è già digerita
  (`skipped: "already_digested"`), ritorna il buffer esistente.
- Se `skipped: "digest_failed"` (timeout Haiku, ecc.): procedi comunque —
  il `/wb` non si blocca. Comunica all'utente che la digestione non è
  riuscita e che può rifare `/wb`.

Dopo `scribe_digest`, il buffer è popolato → procedi a Step 4.

### Step 4 — Load Scribe buffer

```
scribe_review({ session_id: "<uuid>" })
```

Response shape:

```json
{
  "buffer_id": "uuid|null",
  "facts": [...],
  "groups": [
    {
      "initiative_slug": "agent-os-platform",
      "initiative_name": "Agent OS Platform",
      "resolved": true,
      "deltas": [
        { "fact_index": 0, "type": "move_done", "section": "last_3_moves",
          "preview": "last_3_moves: + \"...\"", "confidence": "high",
          "source_quote": "..." }
      ]
    }
  ],
  "expires_at": "2026-05-11T..."
}
```

Se `buffer_id === null` o `facts.length === 0`: niente fact catturati, salta a Step 6.

### Step 5 — Review batch con utente

Mostra preview raggruppato. Esempio output:

```
Pipeline Scribe ha rilevato 5 fact-update su 3 iniziative. Confermi?

[1] agent-os-platform · Agent OS Platform
    last_3_moves: + "(2026-05-10) Pubblicato endpoint /state"
    decisions_log: + [2026-05-10] Schema visibility binario public/private — owner_tenant_id univoco

[2] bp-djungle-holding-2026 · BP Djungle Holding 2026
    stage: building → delivered
    last_3_moves: + "(2026-05-10) Inviato BP a soci 14 maggio"

[3] storytelling-ai · Storytelling AI
    open_loops: + "[2026-05-10] Validare pricing tier consumer"

Y / n / review-singolo
```

Opzioni:

- **Y** (default) → `scribe_commit({buffer_id})` → applica TUTTI i delta in transazione
- **n** → `scribe_reject({buffer_id, reason: "user_rejected_all"})`
- **review-singolo** → per ogni fact mostra:
  ```
  [1/5] agent-os-platform · last_3_moves
        + "(2026-05-10) Pubblicato endpoint /state"
        confidence: high · "...source quote..."
        Y / n
  ```
  Accumula gli `accepted_fact_indices`, poi `scribe_commit({buffer_id, accepted_fact_indices})`.

Se `groups[i].resolved === false` (slug non match nel registry):
- non rifiutarlo silenziosamente
- propone all'utente: "Ho rilevato fact su `<slug>` ma non corrisponde a iniziativa esistente. Crea ora come bozza, salta, o salva con altro slug?"

### Step 6 — Confirm to user

```
Writeback completato per Doc

Session SES-INV-... chiusa (initiative: agent-os-platform)
Performance: Good
3 memory_logs scritti (linkati ad agent-os-platform)

Scribe pipeline:
  ✅ 4 fact applicati su 2 iniziative (agent-os-platform, bp-djungle-holding-2026)
  ⏭ 1 fact scartato in review-singolo
  ⚠ 0 errori
```

Se nessuna pipeline Scribe (Step 4 vuoto): ometti la sezione "Scribe pipeline".
Se errori in commit: list `errors[]` con `fact_index` e messaggio.

## Important Notes

- Italiano per i contenuti, inglese per i parametri tool (`type: "learning"` non `"apprendimento"`).
- Il summary della session è la single source of truth — accurato, non lusinghiero.
- Cross-posting memory_log selettivo: quality over quantity.
- **v3.2.1: SEMPRE propaga `initiative_id` ai memory_logs se la session l'aveva.** Bug evitato.
- **v4.5.0: la cattura è server-side via `scribe_digest`.** NON aspettarti che il buffer sia già popolato all'arrivo del `/wb` — devi chiamare `scribe_digest` col transcript completo (Step 3.5) PRIMA di `scribe_review`. È questo il fix del bug "Scribe vuoto": non dipendere più dalla cattura in-prompt durante la chat.
- **La pipeline Scribe è il modo principale di aggiornare le SOTA.** Niente più `/sota-update` manuale dopo ogni sessione — lo fa il wb.
- Se l'MCP server ritorna 401, OAuth scaduto: l'utente deve disconnettere/riconnettere il connettore (Customize → Plugin → Connectors → Djungle agent os). Magic-link < 1 min, no env vars in v3+.
- Se `buffer_id` non esiste (es. sessione senza fact catturati, oppure tutti scartati con confidence=low), Step 4-5 si saltano silenziosamente.

## Cosa NON fa il writeback

- ❌ Non popola `what_it_is` automaticamente — è una decisione semantica del CEO/agente in chat dialogica.
- ❌ Non crea iniziative nuove — quello è compito di `/initiative create` o del Resolver+Classifier in `invoke_agent`.
- ❌ Non chiude handoff pending — quello succede durante la chat con `acknowledge_handoff(status='consumed', notes)`.
- ❌ Non sostituisce un `/sota-update` esplicito — è un complemento per i delta automatici.
- ❌ Non auto-applica i delta Scribe senza review utente. Confidence=low già scartato server-side; medium/high sempre passa per review.

## Edge case — Buffer scaduto

Se `scribe_review` ritorna `expires_at < now()`: il buffer è scaduto (TTL 24h, dovrebbe essere già marked `expired` dal cleanup function, ma defensive check). Comunica all'utente "buffer scaduto, ignoro" e procedi senza Step 5.

## Edge case — Multi-session nella stessa chat

Se l'utente ha invocato 2 agenti nella stessa chat e ora fa `/wb`, ogni session ha il proprio buffer. La skill chiude **solo la session corrente** (l'ultima invocata). Le altre restano open con i loro buffer pending — saranno processate al prossimo `/wb` per quella session, oppure offerte come "recovery" alla prossima invoke (vedi skill `/invoke` step 5).

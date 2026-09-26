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
> automatico e **hook-driven** (ADR-008b rev.2): un hook `Stop` del plugin
> scatta dopo ogni risposta dell'agente e chiama `digest_turn` col delta del
> transcript → il server estrae i fact e applica la commit policy del tenant
> (vedi «Dove finiscono i fatti» sotto). `/wb` resta per chi vuole chiudere e
> rivedere **subito** con controllo pieno — è il path interattivo qui descritto.
>
> **Stato misurato al 22/09/2026: l'hook non arriva al server.** `last_digest_at` è vuoto
> su tutte le sessioni dal 26/08 tranne una (BKL-0039). Finché non è corretto,
> una sessione chiusa senza `/wb` (nuova invoke, inattività) **non salva niente**:
> il `/wb` non è un override, è l'unico writeback che funziona.
>
> Richiede: Personal API Key configurata nel plugin (userConfig `api_key`).
> Fuori da Cowork (web/desktop) gli hook non scattano → resta il `/wb` manuale.

> **v4.5.0 — cambio architetturale (ADR-008a).** Fino alla v4.4 la cattura
> dei fact dipendeva dall'agente che chiamava `scribe_capture` in-prompt dopo
> ogni turno. Non funzionava (cattura nel ~1,85% delle sessioni). Ora la
> cattura è **server-side e deterministica**: al `/wb` chiami `scribe_digest`
> passando il transcript completo della conversazione → il server estrae i
> fact con Haiku 4.5 → popola il buffer → poi `scribe_review` lo legge. La
> cattura è garantita, non più sperata.

## Dove finiscono i fatti (commit policy `confidence_gated`, server v4.43.0+)

Vale per `close_and_digest` e `digest_turn`, cioè per il writeback che applica
la policy del tenant senza review interattiva:

| Fatto | Sessione con iniziativa | Sessione senza iniziativa |
|---|---|---|
| HIGH sulla stessa iniziativa della sessione | SOTA, in automatico | — |
| HIGH su un'iniziativa esistente | review (fuori scope) | **memoria dell'agente + review** |
| HIGH senza iniziativa | review | **memoria dell'agente** |
| HIGH su slug inesistente o ambiguo | review | review |
| MEDIUM | review | review |
| LOW | scartato | scartato |

La memoria dell'agente è **una** riga `memory_logs` per digest (tipo
`observation`, tag `digest`), con le iniziative nominate in
`touched_initiatives`: compare nella pagina dell'agente al prossimo invoke e in
quella delle iniziative citate. È ciò che dà continuità agli agenti trasversali
(Focus, Bookey), che non hanno un'iniziativa. La risposta la conta in
`memorized_to_agent`: riportalo all'utente accanto ad `auto_committed` e
`queued_for_review`.

`always_confirm` manda tutto nel buffer pending; `auto_all` salta il gate di
confidence ma non quello di scope.

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

Il `session_id` si recupera dal **marcatore `agentos-session`** nel transcript (l'ultimo vince) — formato e recupero in `skills/_shared/session-threading.md`. Se il marcatore manca: `list_open_sessions` (proponi all'utente, aspetta conferma); se non ci sono sessioni aperte: fermati con "nessuna sessione attiva: apri con `/invoke <agente>` e ripeti". NIENTE percorsi degradati: dal server ≥4.12.1 ogni write senza `session_id` viene rifiutata (ADR-014a).

### Step 1.5 — Il link di questa chat (server ≥ 4.46.0, BKL-0088)

Il tasto **Riprendi** della home del portal apre la chat in cui la sessione è
vissuta, se la sessione ha salvato il proprio link. Nessuna chat può trovare
il link delle altre: lo scrive la sessione stessa, qui.

- **Claude Code desktop:** leggilo da solo. `get_session` con `"self"` (tool
  della sessione desktop) restituisce `link`, nella forma
  `claude://claude.ai/epitaxy/<id>`. Non chiedere niente.
- **claude.ai (web, app, iPhone) e Cowork:** nessuno strumento espone il link.
  Chiedi una riga sola, insieme al resto del /wb: *«Se vuoi riprenderla dal
  portal, incollami il link di questa chat (barra degli indirizzi, o Condividi
  → Copia link). Altrimenti vado avanti.»* Un no, o nessuna risposta, va bene:
  il portal ripiega sul comando da copiare.

Solo link a Claude (`https://claude.ai/…` o `claude://claude.ai/…`). Un link
non valido il server lo scarta senza bloccare la chiusura, e lo dice in
`chat_url: "scartato"`.

### Step 2 — Close session

```
close_session({
  session_id: "<uuid>",
  chat_url: "<link dallo Step 1.5, se c'è — altrimenti ometti il campo>",
  summary: "## Sommario Sessione\n[summary]\n\n## Learnings & Insight\n- ...\n\n## Decisioni Prese\n- ...\n\n## Performance\n**Rating:** Good\n[explanation]\n\n## Feedback Ricevuto\n- ...\n\n## Segnali di Evoluzione\n- ...\n\n## Stato Progetto\n- ..."
})
```

Response: `{ok, session_id, ended_at, already_closed, chat_url}` — `chat_url` vale `salvato`, `scartato` o `assente`. Se `already_closed: true` (retry post-errore), salta scrittura memory_log se già fatti — ma procedi con Step 3-6 (lo Scribe buffer è separato).

### Step 3 — Cross-post memory logs (con initiative_id v3.2.1+)

Per ogni learning/decision/feedback/evolution di alto valore:

```
write_memory_log({
  session_id: "<session_id>",                    // REQUIRED (ADR-014a) — dal marcatore
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

### Step 5.5 — Skill candidata (plugin 4.34.0, BKL-0076)

Guarda la sessione: l'agente ha eseguito un **workflow multi-passo che
l'utente ha già fatto fare prima, o che dice di voler rifare** (stessa
sequenza di strumenti e passaggi, input diversi)? Se no, salta lo step in
silenzio. Se sì, **una riga, una volta**:

```
Questa procedura (<nome in 3-5 parole>) sembra ripetibile: la metto in backlog come skill candidata? Y / n
```

Con `n` o silenzio non fai niente. Con `Y`:

1. Scrivi la bozza del SKILL.md nello standard del plugin: frontmatter
   `name` (slug) e `description` (trigger), poi i passi, i tool nell'ordine
   in cui li hai usati e cosa NON fare. Niente segreti, API key, email o dati
   del cliente: sostituiscili con segnaposto.
2. Accoda:
   ```
   create_backlog_item({
     session_id: "<uuid>",
     project_slug: "agent-os-v2",
     type: "feature",
     source: "agente",
     source_detail: "<slug-agente> · <SES-code>",
     title: "Skill candidata: <name>",
     body: "PERCHÉ È RIPETIBILE\n<una riga>\n\nEVIDENZA\n- sessione <SES-code>\n- \"<citazione letterale dell'utente>\"\n- passi: <tool/azioni in ordine>\n\nBOZZA SKILL.md\n<bozza integrale>"
   })
   ```
3. Conferma in una riga: `→ BKL-NNNN, skill candidata in inbox`.

Al massimo **una** proposta per sessione. La skill **non** si installa da
qui: diventa attiva solo se il triage la accetta e un umano fa il merge della
PR sul plugin. Se vale anche nel resto del flusso, lo dirà ADR-035.

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
- ❌ Non auto-applica i delta Scribe senza review utente **finché il /wb è in corso**. Confidence=low già scartato server-side. Se però il /wb si interrompe prima di `scribe_commit` o `scribe_reject`, il buffer non resta sospeso: lo finalizza il server (vedi «Edge case — /wb interrotto»).

## Edge case — /wb interrotto (server v4.52.0+, BKL-0080)

Un buffer che nessuno conferma **non scade più in silenzio**. Lo sweep delle sessioni ferme lo finalizza quando né il buffer né la sessione si muovono da più della soglia di idle del tenant (default 30 minuti). `scribe_review` tocca la sessione, quindi un /wb in corso non viene preso a metà. Lo sweep gira col cron giornaliero e a ogni evento del Dispatcher sul tenant.

Il server applica la **stessa commit policy** di `close_and_digest`:
- HIGH in scope → SOTA;
- il resto → coda di review (`/review-queue`, `/librarian-triage`).

Partono **declassati**, cioè tutto in review e niente in SOTA:
- i buffer oltre le 24 ore;
- i tenant con `always_confirm`;
- le sessioni meet e i client essential.

Oltre i 30 giorni il buffer si chiude `expired` senza essere riversato.

Due conseguenze per questa skill:
- Se l'utente torna al dialog dopo la soglia, `scribe_review` può ritornare `buffer_id: null` e `scribe_commit` `applied: 0` senza errori: il buffer è già stato finalizzato. Non dire «niente da salvare». Di' che i fatti sono già stati smistati dal server e che quelli non scritti in SOTA sono in `/review-queue`.
- `expires_at` non è più una scadenza per i fatti. Se `scribe_review` ritorna `expires_at < now()` su un buffer ancora `pending`, procedi con lo Step 5 come sempre: non ignorarlo.

## Edge case — Multi-session nella stessa chat

Se l'utente ha invocato 2 agenti nella stessa chat e ora fa `/wb`, ogni session ha il proprio buffer. La skill chiude **solo la session corrente** (l'ultima invocata). Le altre restano open con i loro buffer pending: le processa il prossimo `/wb` per quella session, o le offre il recovery alla prossima invoke (skill `/invoke` step 3.7). Se non succede nessuna delle due, dopo la soglia di idle le finalizza il server (vedi «Edge case — /wb interrotto»).

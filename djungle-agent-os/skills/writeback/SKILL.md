---
name: writeback
description: |
  Session writeback command for Agent OS. Use this skill whenever the user says "/writeback", "writeback", "salva sessione", "chiudi sessione", "session log", "wb", or any variation of wanting to save/log what happened during an agent session. This is the WRITEBACK step of the Agent OS flow (INVOKE > CHAT > WRITEBACK > EVOLVE). It analyzes the current conversation, extracts learnings, decisions, performance data, and evolution signals, then saves everything via the Djungle Agent OS MCP server. v3.2.1+: propaga initiative_id ai memory_logs/handoff e propone aggiornamenti SOTA dal summary.
---

# Writeback — Agent OS Session Logger (v3.2.1)

Close the loop on every agent session. Analyze the conversation and persist what matters via the Djungle Agent OS MCP server.

Third step of the Agent OS cycle: **INVOKE > CHAT > WRITEBACK > EVOLVE**.

## What Writeback Captures

Analyze the full conversation and extract:

1. **Learnings & Insight** — New information, surprising connections. Focus on what was *non-obvious*.
2. **Decisions Made** — Concrete choices, direction changes, trade-offs. Include the reasoning.
3. **Performance Assessment** — Quality, efficiency, tone. Rate: `Excellent`, `Good`, `Adequate`, `Needs Improvement`
4. **Feedback Received** — Corrections, praise, frustration signals, preference revelations.
5. **Evolution Signals** — Things suggesting the agent's prompt/knowledge/capabilities should be updated.
6. **Project Status Updates** — Tasks completed, new tasks, blockers, deadlines.

## Step-by-Step Process

### Step 1: Identify the Active Agent, Session, and Initiative

From the conversation history (the `invoke_agent` response payload), recover:

- `agent_id` (e.g. `AGT-2`) — the agent that was invoked
- `session_id` (UUID) — returned by `invoke_agent` when the session started
- **`session_initiative_id`** (UUID, v3.2.0+) — `resolved_initiative.id` from the invoke payload, if the invoke included `initiative_input`. **null** if the session was not bound to an initiative.
- **`touched_initiatives`** (UUID[], v3.2.0+) — set if during the chat the user/agent explicitly mentioned other initiatives that were touched (cross-references, dependencies). Build this from the conversation. Default: empty.

If neither agent nor session_id is available, ask the user which agent this session was with and invoke fresh (or skip the session close step).

> **Critical (v3.2.1 fix):** the writeback MUST propagate `session_initiative_id` (and `touched_initiatives` if any) to every memory_log and handoff written below. The previous version omitted these fields and produced orphan records — Probe couldn't surface them in `recent_memory_logs` for that initiative.

### Step 2: Analyze the Conversation

Extract content for each of the 6 categories. Be thorough but concise. Write in Italian.

Ask yourself:
- What would be most valuable to know before the *next* session?
- What changed that the agent's profile should reflect?
- What decisions were made that shouldn't be revisited?

### Step 3: Close the Session with a Summary

Use the MCP tool `close_session` with the `session_id` from invoke and a full summary:

```
close_session({
  session_id: "<uuid from invoke_agent>",
  summary: "## Sommario Sessione\n[summary]\n\n## Learnings & Insight\n- [items]\n\n## Decisioni Prese\n- [items]\n\n## Performance\n**Rating:** Good\n[explanation]\n\n## Feedback Ricevuto\n- [items]\n\n## Segnali di Evoluzione\n- [items]\n\n## Stato Progetto\n- [items]"
})
```

`close_session` (v3.2.0+) ritorna `{ok, session_id, ended_at, already_closed}` — basta verificare `ok: true`. Se `already_closed: true`, qualcuno ha già chiuso la sessione (es. retry post errore di rete) — non rifare i memory_logs successivi se già scritti.

### Step 4: Cross-post High-Impact Items to Memory Logs (con initiative_id!)

For each **high-impact** learning, decision, or feedback item, use `write_memory_log`. **In v3.2.1 SEMPRE passa `initiative_id` se la sessione era legata a un'iniziativa**:

```
write_memory_log({
  agent_id: "AGT-2",
  type: "learning",                    // learning | decision | context | evolution | observation
  content: "Full context — enough to understand why this matters",
  tags: ["optional", "tags"],
  initiative_id: "<session_initiative_id>",   // v3.2.0+, REQUIRED se sessione legata a iniziativa
  touched_initiatives: ["<other-init-uuid>"]  // v3.2.0+, opzionale, se il MEM tocca anche altre iniziative
})
```

Pick `type` deliberately:
- `learning` — a non-obvious insight worth remembering
- `decision` — a concrete choice and its reasoning
- `context` — background that informs future sessions
- `evolution` — a signal that the agent's profile should change
- `observation` — passive notes (use sparingly; learnings are usually better)

Only cross-post items genuinely useful for future sessions. Heuristic: "Would I want to see this before the next session?"

> **Failure mode evitato (era il bug v3.1.x):** se `session_initiative_id` esiste ma NON viene passato qui, il memory_log risulta orfano (initiative_id NULL) e Probe non lo vede tra i `recent_memory_logs` di quell'iniziativa. È equivalente a perderlo per la knowledge dell'iniziativa — il content resta in DB, ma fuori dal contesto vivo.

### Step 5: Propose SOTA Updates (v3.2.1+, opzionale ma raccomandato)

Se la sessione era legata a un'iniziativa (`session_initiative_id` non null), prima di chiudere proponi all'utente 1-3 aggiornamenti SOTA derivati dal summary. Le sezioni canoniche più adatte al writeback sono:

- **`last_3_moves`** — aggiungi 1 bullet per la mossa principale di questa sessione, formato `(YYYY-MM-DD) breve descrizione`. Mantieni solo le ultime 3 (drop quella più vecchia). Quasi sempre da popolare se c'è stato un output concreto.
- **`decisions_log`** — append-only: per ogni "Decisione Presa" del summary aggiungi una riga `[YYYY-MM-DD] decisione — motivazione 1-line`. Spesso da popolare.
- **`current_state`** — sostituisci/integra solo se il summary contiene un cambio di stato strutturale dell'iniziativa (es. nuovo deploy, milestone raggiunto, blocker scomparso). Più raro.
- **`open_loops`** — aggiungi 1 riga per ogni loop nuovo aperto dalla sessione (item ⏳ o 🟡 nello "Stato Progetto"), formato `[YYYY-MM-DD] descrizione 1-line`. Rimuovi quelli risolti durante la sessione.
- **`next_action`** — sostituisci con la prossima azione concreta emersa dal summary, se cambia.
- **`what_it_is`** — RARAMENTE: solo se la sessione ha ridefinito il prodotto/iniziativa stessa.

Mostra le proposte all'utente come diff:

```
SOTA agent-os-platform — propongo:

📝 last_3_moves — APPEND:
+ (2026-05-06) Pubblicazione guida prodotto su agents.djungle.io/guide

📝 decisions_log — APPEND:
+ [2026-05-06] Format guida HTML web-first non PDF — manutenzione e nav interna

📝 open_loops — APPEND:
+ [2026-05-06] Workflow auto-gen guida da SOTA (MEM-014) da progettare per v3.3

Confermi tutti / scarta / modifica?
```

Su conferma, chiama `update_sota_section` per ognuna:

```
update_sota_section({
  initiative_slug: "agent-os-platform",
  section_name: "last_3_moves",
  content_md: "<contenuto integrato — non solo il diff>",
  actor_agent: "AGT-2"   // l'agente di questa sessione
})
```

Importante:
- `content_md` è il contenuto **completo** della sezione post-update, non il diff. Per APPEND, prima leggi con `get_sota_section` e poi concatena.
- `actor_agent` registra in audit_log che è stato l'agente (non l'utente direttamente) a proporre il cambio.
- Per `last_3_moves` cap a 3 elementi (FIFO drop).

### Step 6: Confirm to User

Presenta riepilogo finale:

```
Writeback completato per [Agent Name]

Session chiusa: SES-INV-... (initiative: agent-os-platform)
Performance: Good
3 items scritti in Memory Logs (linkati a agent-os-platform)
SOTA aggiornata: last_3_moves + decisions_log
Evoluzione: 1 segnale (vedi MEM-NNN)
```

Se la sessione NON era legata a iniziativa: ometti la riga "linkati a..." e la riga SOTA.

## Important Notes

- Italiano per i contenuti, inglese per i parametri tool (`type: "learning"`, non `"apprendimento"`).
- Il summary della session è la single source of truth — accurato, non lusinghiero.
- Cross-posting selettivo: quality over quantity.
- **v3.2.1: SEMPRE propagare `initiative_id` ai memory_logs se la sessione l'aveva.** Questo è IL fix principale di questa versione — non saltarlo.
- **SOTA proposal è opzionale ma raccomandato.** Se l'utente vuole velocità ("wb veloce"), salta Step 5. Se è un wb normale, proponi.
- Se l'MCP server ritorna 401, l'OAuth è scaduto: l'utente deve disconnettere/riconnettere il connettore (Customize → Plugin → Connectors → Djungle agent os). Magic-link < 1 minuto, no env vars in v3+.
- Se `session_id` non è recuperabile (utente ha invocato l'agente fuori da questa Cowork session, es. su Notion v1), salta Step 3 e fai solo `write_memory_log` — sono indipendenti dalle sessioni. In quel caso `initiative_id` va chiesto all'utente o omesso.

## Cosa NON fa il writeback

- ❌ Non popola `what_it_is` automaticamente — è una decisione semantica del CEO/agente in chat dialogica.
- ❌ Non crea iniziative nuove — quello è compito di `/initiative create` o del classifier nel resolver di `invoke_agent`.
- ❌ Non chiude handoff pending — quello succede durante la chat con `acknowledge_handoff(status='consumed', notes)`.
- ❌ Non sostituisce un `/sota-update` esplicito — è un complemento, non un duplicato.

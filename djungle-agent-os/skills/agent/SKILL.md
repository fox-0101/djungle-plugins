---
name: agent
description: |
  Manage your owned agents (CRUD owner-only). Trigger when the user says "/agent list", "/agent show <slug>", "/agent create ...", "/agent update <slug> ...", "/agent publish <slug>", "/agent unpublish <slug>", "/agent archive <slug>", "/agent stats <slug>", "/agent versions <slug>", "/agent restore <slug> <N>", "crea agente", "pubblica agente", "modifica system prompt di X", "archivia agente", "ripristina versione". Owner-only: agisci solo su agenti del tenant corrente. v3.5.0+ · versioning v4.1.0+.
---

# /agent — Manage owned agents (v4.1.0)

CRUD owner-only sugli agenti del tenant corrente. RLS server-side impedisce write cross-tenant: anche se passi uno slug di un agente di un altro tenant, l'update ritornerà error.

## Sub-commands

### `/agent list`

Mostra tutti gli agenti del tenant (active + draft, esclusi archived). Usa `list_agents`. Output:

```
Agenti tenant djungle (10):

ACTIVE (3):
  · AGT-1  dean    Growth Strategist        public  v1
  · AGT-2  lora    CPO Challenger           public  v1
  · AGT-3  vince   CMO                      public  v1

DRAFT (7):
  · AGT-4  spacey  Program Director         public  v1
  · AGT-5  iron    COO                      public  v1
  · ...

Comandi: /agent show <slug> · /agent update <slug> ... · /agent publish <slug>
```

### `/agent show <slug>`

Mostra dettaglio agente. Usa `get_agent({agent_name: "<slug>"})`. Output:

```
Agente: Doc (AGT-8)
  Slug:        doc
  Role:        Chief AI Architect
  Status:      draft · Visibility: public
  Owner:       djungle (verified)
  Modules:     8 linked (preflight-check, scribe-capture, doc-identity, ...)
  Knowledge:   25 entries linked
  Capabilities: 5 linked
  Last invoked: 2026-05-10 11:08 (35 invocazioni totali)

System prompt (first 400 chars):
  ## Profilo: Doc — Chief AI Architect
  Doc è la mente tecnica di tutto Agent OS...
  [...truncated]

Vuoi: /agent update doc system_prompt="..." · /agent publish doc · /agent stats doc
```

### `/agent create`

Crea un nuovo agente. Sintassi:

```
/agent create <slug> "<name>" "<role>" "<system_prompt>" [--visibility=public|private] [--status=active|draft]
```

Esempi:

```
/agent create cassia "Cassia" "Cybersecurity Auditor" "Cassia è una specialista..." --visibility=private --status=draft
```

Chiama `create_agent({slug, name, role, system_prompt, visibility, status})`. Default: `visibility=private`, `status=draft`. Il server auto-genera `agent_id` come prossimo `AGT-N` libero per il tenant.

Conferma:
```
Agente Cassia creato.
  agent_id: AGT-11
  slug: cassia
  visibility: private (solo tu lo vedi)
  status: draft
Per pubblicarlo: /agent publish cassia
```

### `/agent update <slug> <field>=<value>`

Aggiorna uno o più campi. Campi modificabili: `name`, `role`, `system_prompt`, `short_description`, `long_description`, `status`.

Esempi:

```
/agent update cassia role="Senior Cybersecurity Auditor"
/agent update cassia status=active
/agent update doc system_prompt="<new prompt>"
```

Per `system_prompt` lungo, suggerisci all'utente di passare un file path o di scrivere il prompt direttamente nella chat (multi-line). Mostra preview pre-confirm:

```
Stai per aggiornare doc:
  - system_prompt: 14029 chars → 15203 chars (+1174)
Confermi? [Y/n]
```

Su Y → chiama `update_agent({slug, system_prompt})`.

### `/agent publish <slug>` / `/agent unpublish <slug>`

```
/agent publish cassia
```

Chiama `publish_agent({slug})`. Setta `visibility=public` + `published_at=now()`. L'agente diventa visibile a tutti i tenant (marketplace).

```
✓ Agente cassia pubblicato.
  visibility: private → public
  published_at: 2026-05-10 11:30
  Ora visibile a tutti i tenant nel marketplace.
```

`/agent unpublish <slug>` riporta a `private` (non lo cancella, lo nasconde).

### `/agent archive <slug> [--reason="..."]`

Soft-delete. L'agente sparisce dalle liste ma resta in DB per audit.

```
/agent archive cassia --reason="experiment finito"
```

Chiama `archive_agent({slug, reason})`. Setta `archived_at=now()`, `visibility=private`, `status=archived`.

⚠️ **Conferma esplicita** prima di archiviare se l'agente ha invoke_count > 0:

```
Cassia ha 14 invocazioni e 3 sessioni storiche. L'archiviazione la nasconde
ma le sessioni restano leggibili. Confermi archive? [Y/n]
```

### `/agent stats <slug>`

Mostra usage stats:

```
Stats Cassia (AGT-11):
  Totale invocazioni: 14
  Last invoked:        2026-05-10 09:22
  Top consumers:
    · djungle (Alessandro): 10 invocazioni
    · djungle (Giulietta):  4 invocazioni
  Sessioni associate: 9 (5 chiuse, 4 aperte)
```

Implementazione: query a `agent_invocations` group by `consumer_tenant_id` + count sessions. Nota: questa query non ha un tool MCP dedicato in v3.5.0 — fai una sequenza di chiamate (`list_marketplace_agents` per stats di base + query custom se serve dettaglio).

### `/agent versions <slug>` (v4.1.0)

Mostra la history versioni dell'agente. Append-only — ogni modifica al `system_prompt` crea una nuova versione. Owner-only.

Chiama `list_agent_versions({slug})`. Output:

```
Versioni di Annie (AGT-101):

v3  2026-05-11 14:22  Alessandro    "raffinato tono pratico, vincoli output max 200 parole"
v2  2026-05-11 11:08  Alessandro    "aggiunti vincoli su KPI, settore manifatturiero"
v1  2026-05-11 09:38  Alessandro    "v1 — creazione iniziale via portal"

Comandi:
  /agent restore annie 2    — ripristina v2 come nuova versione corrente
  /agent show annie         — vedi versione attuale
```

### `/agent restore <slug> <version>` (v4.1.0)

Ripristina una versione precedente. **Append-only**: NON sovrascrive la versione corrente, crea una v(N+1) con il prompt di vM. Owner-only.

```
/agent restore annie 2
```

Chiama `restore_agent_version({slug, version_number: 2})`. Conferma esplicita:

```
Stai per ripristinare annie a v2 (creata 2026-05-11 11:08).
Verrà creata v4 con il prompt di v2 (la v3 corrente resta nella history).
Confermi? [Y/n]
```

Su Y → tool MCP risponde con `new_version: 4`. Aggiorna l'utente:

```
✓ annie ripristinata.
  v4 (corrente) ← prompt di v2
  Storia: v1 · v2 · v3 · v4 (4 versioni totali)
```

## Important rules

- **Owner-only writes:** non puoi modificare agenti di altri tenant (RLS lo blocca). Per modificare il tuo, devi essere `owner_tenant_id = current tenant`.
- **System prompt è grosso:** quando aggiorni, mostra sempre la diff in chars + preview di 200 char dei primi 200 char dopo l'update.
- **Versioning v4.1.0:** ogni modifica al `system_prompt` crea automaticamente una nuova riga in `agent_versions` (append-only). Le altre modifiche (name, role, descriptions) NON creano una version. Storage attivo + restore UI da v4.1, UI di history visuale rimane TBD v4.2.
- **Marketplace visibility:** `public` = visibile a tutti i tenant via `list_marketplace_agents`. `private` = solo il tenant. Cambio di visibility è reversibile in qualsiasi momento.
- **Archive vs Delete:** in v3.5.0 c'è solo soft-delete (archive). Hard-delete via SQL admin se serve davvero (audit log conserva).

## Cosa NON fa

- ❌ Non modifica agenti di altri tenant (RLS blocca)
- ❌ Non gestisce link a moduli/capabilities/knowledge — UI dedicata TBD v4.2
- ❌ Non clone-from-marketplace — se vuoi adottare un agente public di un altro tenant, lo invochi direttamente con `invoke_agent` (la sua identità resta del publisher)
- ❌ Knowledge upload (PDF/URL) — TBD v4.2

## Edge cases

- **Slug duplicato:** error 23505 → suggerire variante (`cassia-2`)
- **Agente in stato draft + visibility=public:** legalmente accettato (moltiplica `agents_catalog` view che filtra `status=active`, quindi nel marketplace non si vede). Status=active per renderlo visibile pubblicamente.
- **system_prompt < 20 chars:** Zod validation fallisce → suggerire prompt più ricco

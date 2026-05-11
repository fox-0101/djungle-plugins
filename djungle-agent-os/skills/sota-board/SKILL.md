---
name: sota-board
description: |
  Crea o aggiorna un dashboard live "Iniziative & SOTA" nel sidebar Cowork del cliente, come artifact persistente. Trigger quando l'utente dice "/sota-board", "/dashboard", "mostra dashboard", "apri dashboard SOTA", "fammi vedere le iniziative in dashboard", "crea board iniziative". L'artifact è tenant-isolated automaticamente: ogni cliente vede solo le proprie iniziative + domini + SOTA. v4.1.1+.
---

# /sota-board — Dashboard Iniziative & SOTA nel sidebar Cowork (v4.1.1)

Crea (o aggiorna) un artifact persistente nel sidebar Cowork che mostra il dashboard live delle iniziative del tenant, raggruppate per domain/stage/type, con la SOTA in modalità expand-on-click. Tenant-isolated automaticamente — il JS dentro l'artifact chiama il nostro MCP server tramite `window.cowork.callMcpTool` che usa la session auth del cliente.

## Architettura — leggi prima di eseguire

Due livelli MCP distinti:

```
LIVELLO 1 — Skill prompt (questa skill)
  Claude in Cowork chiama tool LATO COWORK CLIENT:
    · mcp__cowork__list_artifacts     → verifica se "initiatives-sota" esiste
    · mcp__cowork__create_artifact    → crea nuovo
    · mcp__cowork__update_artifact    → aggiorna esistente
  Questi tool NON passano dal nostro server agents-api.djungle.io.

LIVELLO 2 — HTML runtime (artifact-template.html)
  Quando il cliente apre l'artifact, il JS interno chiama:
    window.cowork.callMcpTool('mcp__<server_uuid>__list_initiatives', {})
    window.cowork.callMcpTool('mcp__<server_uuid>__list_domains', {})
    window.cowork.callMcpTool('mcp__<server_uuid>__get_sota', {slug})
  Questi proxy passano dal nostro server, tenant-scoped via API key.
```

La skill **non** fa MCP calls al nostro server. Solo l'HTML runtime lo fa, al momento dell'apertura.

## Comportamento

Quando l'utente invoca `/sota-board` (o alias `/dashboard`):

1. **Verifica esistenza artifact**:
   - chiama `mcp__cowork__list_artifacts`
   - cerca artifact con `id == "initiatives-sota"`

2. **Se esiste → UPDATE**:
   - leggi il contenuto di `skills/sota-board/artifact-template.html` (path relativo nel plugin)
   - chiama `mcp__cowork__update_artifact` con:
     - `id: "initiatives-sota"`
     - `html: <contenuto template>`
   - conferma utente: "✓ Dashboard aggiornato. Apri 'Live artifacts' nel sidebar Cowork."

3. **Se non esiste → CREATE**:
   - leggi il contenuto di `skills/sota-board/artifact-template.html`
   - chiama `mcp__cowork__create_artifact` con:
     - `id: "initiatives-sota"`
     - `title: "Iniziative & SOTA"`
     - `description: "Dashboard live delle tue iniziative con SOTA in expand-on-click"`
     - `html: <contenuto template>`
   - conferma utente: "✓ Dashboard creato nel sidebar Cowork. Trovalo in 'Live artifacts'."

## Naming

```
artifact_id = "initiatives-sota"     // semplice, no prefisso tenant
```

Razionale: Cowork già isola gli artifact per session/tenant via API key. Niente collisioni cross-tenant possibili. Niente lookup necessario per recuperare tenant_slug.

## Output utente

### Caso CREATE

```
✓ Dashboard "Iniziative & SOTA" creato nel sidebar Cowork.

Aprilo da "Live artifacts" → "initiatives-sota".
Mostra le tue iniziative raggruppate per domain/stage/type, con:
  · filtri stage (idea/exploring/building/operating)
  · filtri type (business/thesis/experiment/sideproject)
  · click su iniziativa → SOTA expand (6 sezioni canoniche)
  · auto-refresh quando re-apri

Dati live dal tuo tenant. Aggiorna il SOTA con /sota-update e l'artifact si
ricarica al prossimo open.
```

### Caso UPDATE

```
✓ Dashboard "Iniziative & SOTA" aggiornato.

Re-apri "initiatives-sota" dal sidebar per vedere la nuova versione.
(Se hai l'artifact già aperto, fai un hard refresh: Cmd+Shift+R.)
```

## Important rules

- **Niente MCP call al nostro server in questa skill.** Solo tool `mcp__cowork__*` lato client. Se Claude prova a chiamare `list_initiatives` qui, sta sbagliando — quello è lavoro del JS dentro l'HTML runtime.
- **Artifact id costante** `"initiatives-sota"`. Mai variare. Mai aggiungere prefissi tenant.
- **HTML va letto da path** `skills/sota-board/artifact-template.html`. Non rigenerarlo, non modificarlo a runtime.
- **No conferma esplicita pre-create**. L'utente ha già detto `/sota-board`, basta. Procedi diretto.
- **Errori cowork**: se `mcp__cowork__list_artifacts` non disponibile (es. plugin Cowork mancante), spiega che servono i tool nativi Cowork per gestire artifacts.

## Edge cases

- **Plugin Cowork non installato**: tool `mcp__cowork__*` mancanti → segnala all'utente "Servono i tool nativi Cowork per gli artifact. Verifica che Cowork sia attivo come applicazione desktop (non solo claude.ai web)."
- **HTML template non trovato**: se Claude non riesce a leggere il file, fallback con messaggio "Template artifact non trovato nel plugin. Riprova dopo reinstall del plugin djungle-agent-os v4.1.1."
- **window.cowork.callMcpTool non disponibile a runtime**: lato artifact, l'HTML mostra già un errore guidato. Lato skill, niente da fare — è limite Cowork client.

## Cosa NON fa

- ❌ Non chiama il nostro MCP server (è lavoro del JS interno)
- ❌ Non personalizza il template per cliente (template uniforme)
- ❌ Non gestisce notifiche push quando SOTA cambia (TBD futura)
- ❌ Non export PDF/CSV del dashboard (TBD futura)
- ❌ Non altri dashboard (handoff-board, agent-stats — valutiamo dopo 30gg uso)

## Note tecniche

- Server UUID hardcoded nel template: `mcp__01dc3b55-669d-420d-978b-172c610befe4`. Se cambia il prefisso, va editato in una riga (`const SERVER = '...'`).
- Dedup client-side già attivo nel JS dell'HTML (defense in depth dopo hotfix v3.5 SOTA dedup DB-side).
- Auto-refresh on open (no polling continuo per non bruciare quota MCP).

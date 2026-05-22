---
name: sota-board
description: |
  Apri il dashboard "Iniziative & SOTA" del tenant attivo nel portal web. Trigger quando l'utente dice "/sota-board", "/dashboard", "/dashboard sota", "mostra dashboard", "apri dashboard SOTA", "fammi vedere le iniziative", "lista iniziative dashboard". v4.4.4+.
---

# /sota-board — Dashboard Iniziative & SOTA nel portal (v4.4.4)

Ritorna all'utente il link al **dashboard web** delle iniziative del tenant attivo. Il dashboard è multi-tenant, sempre fresco, server-side rendered.

## Storia & deprecazione

Versioni precedenti (v4.1.1-v4.4.3) creavano un **artefatto Cowork** persistente nel sidebar. Quell'approccio si è rivelato strutturalmente instabile per:

- **Allowlist sandbox**: l'artefatto non poteva fare fetch a `agents-api.djungle.io` (subdomain bloccato)
- **OAuth volatile**: connector token scaduto ogni 1-2h
- **UUID volatile**: il prefix MCP cambia ad ogni reconnect plugin
- **Multi-tenant impossibile**: REST pubblico tenant-fisso + MCP auth volatile

Da v4.4.4 la dashboard vive nel **portal**: stesso dominio, auth Supabase stabile, multi-tenant nativo via `active_tenant_id`. L'artefatto Cowork `djungle-initiatives-sota` è **deprecato** (storico, non più creato).

## Comportamento

Quando l'utente invoca `/sota-board` (o alias `/dashboard`, `/dashboard sota`):

**NIENTE chiamate MCP, NIENTE artefatti**. Rispondi solo con un messaggio testuale:

```
📊 Il tuo dashboard Iniziative & SOTA è qui:
https://agents.djungle.io/dashboard/sota

Mostra le iniziative del tenant attivo, raggruppate per dominio, con SOTA
espandibile. Sempre fresco — i dati arrivano server-side da Supabase.
Multi-tenant: se cambi tenant col tuo switcher portal, il dashboard cambia
automaticamente i dati.
```

Personalizzazione opzionale: se sai già il tenant attivo (es. da `get_active_tenant`), puoi aggiungere "tenant attivo: <emoji> <nome>".

## Cosa NON fa

- ❌ Non crea artefatti Cowork (deprecato)
- ❌ Non chiama MCP tool per recuperare dati
- ❌ Non mostra le iniziative inline in chat (la chat non è il posto giusto per un dashboard)

## Note tecniche

- Portal page: `app/dashboard/sota/page.tsx` (Next.js Server Component)
- Data fetch: query dirette a Supabase con `active_tenant_id` da cookie (v4.4.0 user-aware auth)
- Lazy SOTA: click iniziativa → `GET /api/sota/<slug>` → carica sezioni
- Design: porting del template `docs/sota-board-artifact-template.html` ai design token del portal (dark theme)
- Multi-tenant: switch tenant nel portal → refresh → dashboard cambia dati

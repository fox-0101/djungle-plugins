---
name: tenant
description: |
  Gestione multi-tenant di Agent OS — un user può possedere/usare N tenant. v4.4.0: switch fluido in Cowork via MCP (richiede Personal API Key user-scoped). Trigger quando l'utente dice "/tenant", "/tenant list", "/tenant switch <slug>", "/tenant status", "che tenant sto usando", "su quale tenant sono", "cambia tenant a X", "switcha a X". v4.4.0+.
---

# /tenant — Multi-tenant Agent OS (v4.4.0)

Un user può avere **N tenant** (workspace isolati: API key, agenti, iniziative,
memorie, Librarian, tutto separato per RLS). v4.4.0 sblocca lo **switch fluido
in Cowork** via MCP tool, senza dover toccare l'API key del connettore.

## Modello auth

Due tipi di API key:

| Tipo | Prefix | Comportamento |
|---|---|---|
| **Tenant-scoped** (legacy) | `aos_<...>` | Una key = un tenant fisso. Per cambiare tenant cambi la key nel connettore. |
| **Personal** (user-scoped, v4.4+) | `aos_u_<...>` | Una key sola per tutti i tuoi tenant. Switchi via `/tenant switch <slug>`. |

Genera/sostituisci la Personal Key da `agents.djungle.io/dashboard/api-keys`.
Raccomandata se hai 2+ tenant.

## Comportamento

### `/tenant` o `/tenant status`

Chiama il tool MCP **`get_active_tenant`** → ritorna slug, nome, brand emoji,
ruolo, chi ha settato l'attivo (portal / cowork / default) e quando.

Output:
```
{emoji} {nome} ({slug}) — sei {ruolo}
Settato da: {set_by} · {set_at}
```

### `/tenant list`

Chiama **`list_my_tenants`** → mostra tutti i tenant dell'user con emoji,
ruolo, default (★), attivo (✓):

```
✓ 🔵 Djungle Holding (djungle) — owner ★
  🟠 FNX (fnx) — owner
  🟣 Acme Spa (acme) — member

Switch: /tenant switch <slug>
```

### `/tenant switch <slug>`

Chiama **`set_active_tenant({ tenant_slug: <slug>, set_by: "cowork" })`** →
server UPSERT su `user_active_tenant` → le **prossime** chiamate MCP useranno
quel tenant automaticamente.

Conferma:
```
✓ Switchato su {emoji} {nome}.
Le prossime invocazioni agenti, /sota, /briefing ecc. opereranno su {slug}.
```

Errori frequenti:
- **"Non sei membro di X"** → non hai una membership su quel tenant.
- **"User-scoped API keys are disabled"** → il server ha il flag spento,
  contatta l'admin.
- **"Questo tool richiede un user reale"** → stai usando una tenant-scoped
  key. Genera una Personal Key dal portal per abilitare lo switch fluido.

### Sincronia portal ↔ Cowork

Single source of truth: `user_active_tenant` su Supabase. Switch fatto nel
portal propaga al next MCP call da Cowork e viceversa. Niente cookie
cross-domain, niente race.

## Cosa NON fa

- ❌ Non crea tenant — la creazione è nel portal (serve magic-link auth).
- ❌ Non cambia da sola l'API key del connettore Cowork — quello è UI Cowork.
- ❌ Non mostra dati cross-tenant insieme — isolamento per privacy.

## Note

- Owner vs member: chi crea un tenant ne è owner (può gestire agenti,
  generare API key, abilitare Librarian). Member = accesso operativo, non
  amministrativo.
- Tenant di default: quello attivato all'accesso iniziale, se non hai
  switchato esplicitamente. Si setta da `/dashboard/tenants`.
- Override una-tantum: passare l'header HTTP `X-Tenant-Override: <slug>` a
  una chiamata MCP forza quel tenant solo per quella richiesta (non altera
  user_active_tenant). Utile per integrazioni puntuali.

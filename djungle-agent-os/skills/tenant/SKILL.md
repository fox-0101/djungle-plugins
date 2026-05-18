---
name: tenant
description: |
  Gestione multi-tenant di Agent OS — un user può possedere/appartenere a N tenant (workspace isolati). Trigger quando l'utente dice "/tenant", "/tenant list", "/tenant switch <slug>", "che tenant sto usando", "su quale tenant sono", "cambia tenant", "crea un nuovo tenant", "gestisci i miei tenant". v4.3.0+.
---

# /tenant — Multi-tenant Agent OS (v4.3.0)

Un user di Agent OS può avere **N tenant**: workspace completamente isolati
(API key, agenti, iniziative, memorie, Librarian — tutto separato per RLS).
Casi tipici: holding con più società, consulenti multi-cliente, separazione
business/personal.

## Modello — due contesti indipendenti

| Contesto | Dove si gestisce | Cosa controlla |
|---|---|---|
| **Tenant attivo nel portal** | `agents.djungle.io/dashboard/tenants` | Cosa vedi nella dashboard web (cookie `active_tenant_id`) |
| **Tenant attivo in Cowork** | Connettore MCP `djungle-agent-os` | Su quale tenant operano le skill/tool in chat (l'API key del connettore) |

I due sono **indipendenti per design**: puoi avere il portal su un tenant e
Cowork su un altro — due contesti operativi paralleli, non è un bug.

## Comportamento della skill

### `/tenant` o `/tenant list`

Cowork opera sul tenant identificato dall'**API key del connettore MCP**.
Per sapere quali tenant possiedi e qual è il default, apri
`agents.djungle.io/dashboard/tenants` — lì vedi la lista completa con ruolo
(owner/member), tenant attivo e default.

Mostra all'utente:

```
I tuoi tenant si gestiscono dal portal:
  agents.djungle.io/dashboard/tenants

Cowork opera sul tenant della API key configurata nel connettore
djungle-agent-os. Per cambiare tenant in Cowork → /tenant switch.
```

### `/tenant switch <slug>`

Cowork punta a un tenant tramite l'**API key** del connettore MCP. Per
switchare il tenant attivo in Cowork:

1. Apri `agents.djungle.io/dashboard/tenants` e attiva il tenant desiderato
2. Vai in `agents.djungle.io/dashboard/api-keys` di quel tenant e copia/genera la sua API key
3. In Cowork: **Customize → Connettori → djungle-agent-os** → incolla la API key del nuovo tenant
4. Le nuove chiamate MCP opereranno sul tenant scelto

Spiega questi passi all'utente — la skill **non** può cambiare l'API key del
connettore da sola (è gestita dalla UI connettori di Cowork).

### `/tenant create` / "crea un nuovo tenant"

La creazione di un tenant si fa dal portal:
`agents.djungle.io/dashboard/tenants/new`. Compili nome + slug + tipo, ottieni
subito la API key `primary` del nuovo tenant (mostrata una sola volta).

## Cosa NON fa

- ❌ Non cambia da sola l'API key del connettore Cowork (UI connettori).
- ❌ Non crea tenant via MCP — la creazione è nel portal (serve magic-link auth).
- ❌ Non mostra dati cross-tenant insieme — ogni tenant è isolato per privacy.

## Note

- Owner vs member: chi crea un tenant ne è **owner** (può generare API key,
  gestire agenti, abilitare il Librarian). Un **member** ha accesso operativo
  ma non amministrativo.
- Tenant di default: quello che vedi all'accesso al portal prima di switchare.
  Si imposta da `/dashboard/tenants`.
- B2B invitations (owner che invita altri user al suo tenant) — non ancora
  disponibile, previste in v4.4.0.

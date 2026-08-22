---
name: tenant
description: |
  Gestione multi-tenant di Agent OS — un user può possedere/usare N tenant. Da v4.32 lo switch imposta il DEFAULT per le sessioni nuove: non sposta il lavoro già aperto, e una chiamata senza sessione su chi ha più workspace CHIEDE dove. Trigger quando l'utente dice "/tenant", "/tenant list", "/tenant switch <slug>", "/tenant status", "che tenant sto usando", "su quale tenant sono", "cambia tenant a X", "switcha a X", o quando il server risponde con una domanda sul workspace. v4.4.0+.
---

# /tenant — Multi-tenant Agent OS (v4.32)

Un user può avere **N tenant** (workspace isolati: API key, agenti, iniziative,
memorie, Librarian, tutto separato per RLS).

**La cosa da sapere prima di tutte (ADR-029).** Il "tenant attivo" non è dove
stai lavorando: è il **default per le sessioni nuove**, ed è una variabile
condivisa fra tutte le tue chat. Dove stai lavorando lo dice il `session_id`
della sessione aperta in questa chat, e quello non lo sposta nessuno.

È successo tre volte in due giorni prima che il server smettesse di
indovinare: una chat sposta l'attivo, un'altra continua a credersi altrove.
Il caso peggiore non è l'errore — è la risposta: `list_backlog` sul workspace
sbagliato non fallisce, risponde «coda vuota».

## Modello auth

Due tipi di API key:

| Tipo | Prefix | Comportamento |
|---|---|---|
| **Tenant-scoped** (legacy) | `aos_<...>` | Una key = un tenant fisso. Per cambiare tenant cambi la key nel connettore. |
| **Personal** (user-scoped, v4.4+) | `aos_u_<...>` | Una key sola per tutti i tuoi tenant. Il workspace lo sceglie la sessione, non la key. |

Genera/sostituisci la Personal Key da `agents.djungle.io/dashboard/api-keys`.
Raccomandata se hai 2+ tenant.

## Comportamento

### `/tenant` o `/tenant status`

Chiama il tool MCP **`get_active_tenant`** → ritorna slug, nome, brand emoji,
ruolo, chi ha settato il default e quando, `e_un_default`, e `sessioni_aperte`
con il tenant di ciascuna.

Output:
```
Default per le sessioni nuove: {emoji} {nome} ({slug}) — sei {ruolo}
Settato da: {set_by} · {set_at}
Sessioni aperte: {codice} su {slug} · {codice} su {slug}
```

Se `e_un_default` è falso la credenziale fissa il tenant: non c'è nessun
default da spostare, e va detto così invece di offrire uno switch.

### `/tenant list`

Chiama **`list_my_tenants`** → mostra tutti i tenant dell'user con emoji,
ruolo e default (★). Il campo `is_active` marca **il default**, non "dove stai
lavorando": non chiamarlo attivo nell'output, o si ricrea l'equivoco che
ADR-029 ha appena tolto.

```
★ 🔵 Djungle Holding (djungle) — owner   ← default per le sessioni nuove
  🟠 FNX (fnx) — owner
  🟣 Acme Spa (acme) — member

Default: /tenant switch <slug> · Lavorare su uno: /invoke <agente>
```

### `/tenant switch <slug>`

Chiama **`set_active_tenant({ tenant_slug: <slug>, set_by: "cowork" })`**.

> **Non è uno switch di contesto.** Imposta il default da cui nasceranno le
> sessioni nuove. Non tocca nessuna sessione aperta — né questa né quelle
> delle altre chat — e resta una variabile per utente, condivisa.

Se la risposta porta `sessioni_aperte_altrove`, **dillo**: sono le chat che
restano dove sono, ed è la parte che chi switcha si aspetta di aver spostato.

Conferma:
```
✓ Default per le sessioni nuove: {emoji} {nome} ({slug}).
  Non sposta niente di già aperto — hai sessioni su: {altri slug}.
  Per lavorare su {slug} ADESSO: /invoke <agente> (nasce lì).
```

**Se l'utente vuole lavorare su un altro workspace in questa chat**, lo switch
non è la strada: la sessione in corso è nata dove è nata. La strada è aprirne
una nuova dichiarando il workspace — `/invoke <agente>` e rispondere `<slug>`
alla domanda. Per legare stabilmente un PROGETTO a un tenant resta la riga
`tenant: <slug>` nel CLAUDE.md, che /invoke passa come `tenant_slug`.

### Quando il server chiede «su quale workspace?»

Da v4.32 una chiamata che non dichiara niente, fatta da chi ha più di un
workspace, non riceve dati: riceve `dialog_required: true` con l'elenco.

Non è un errore e non va ritentata uguale. **Presenta le scelte all'utente**
(default per primo) e richiama lo stesso tool aggiungendo:

- `session_id` — se in questa chat c'è il marcatore `agentos-session`, usa
  quello: è la risposta giusta quasi sempre, e non sposta niente;
- `tenant_slug` — se una sessione non c'è, o se l'utente vuole leggere
  esplicitamente altrove.

Se la domanda arriva su `/invoke` o `create_session`, il testo è diverso
(«dove apro la sessione?») e la risposta è `tenant_slug`: lì una sessione da
cui ereditare non c'è ancora.

Errori frequenti:
- **"Non sei membro di X"** → non hai una membership su quel tenant.
- **"User-scoped API keys are disabled"** → il server ha il flag spento,
  contatta l'admin.
- **"Questo tool richiede un user reale"** → stai usando una tenant-scoped
  key. Genera una Personal Key dal portal per abilitare lo switch fluido.

### Portal e Cowork

`user_active_tenant` su Supabase è il default condiviso, e lo scrivono in tre:
il portal, questa skill e l'API. Uno switch nel portal cambia quindi il default
anche per Cowork — ma **non** il tenant di una sessione già aperta, e non fa
più decidere in silenzio una lettura senza sessione: da v4.32 quella chiede.

Se una chat sembra "essere finita altrove", la domanda giusta non è «qual è
l'attivo» ma «qual è il `session_id` di questa chat e su che tenant è nato».

## Cosa NON fa

- ❌ Non crea tenant — la creazione è nel portal (serve magic-link auth).
- ❌ Non cambia da sola l'API key del connettore Cowork — quello è UI Cowork.
- ❌ Non mostra dati cross-tenant insieme — isolamento per privacy.

## Note

- Owner vs member: chi crea un tenant ne è owner (può gestire agenti,
  generare API key, abilitare Librarian). Member = accesso operativo, non
  amministrativo.
- Tenant di default: da dove nascono le sessioni se non dichiari altro. Si
  setta da `/dashboard/tenants` o con `/tenant switch`. Non è "dove stai
  lavorando".
- Override una-tantum: passare l'header HTTP `X-Tenant-Override: <slug>` a
  una chiamata MCP forza quel tenant solo per quella richiesta (non altera
  user_active_tenant). Utile per integrazioni puntuali.

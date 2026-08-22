# Session threading — convenzione unica (ADR-014b, plugin ≥ 4.7.0)

Questa è la SOLA definizione del marcatore di sessione. Le SKILL.md e gli
hook la richiamano, NON la riparafrasano: una convenzione ripetuta a mano in
sei posti diverge in sei modi.

## Il marcatore

Subito dopo ogni `invoke_agent` andato a buon fine, il client emette **una
riga a formato fisso** nella conversazione (non prosa):

```
<!-- agentos-session id=<uuid> code=<codice> tenant=<tenant-slug> agent=<agent-slug> -->
```

Esempio reale:

```
<!-- agentos-session id=7cfc5539-12dc-46be-91a6-54ca6b979269 code=SES-INV-1785254774980 tenant=djungle agent=set -->
```

**Regole del formato — letterali, nessuna variante ammessa:**

1. Una sola riga, che inizia con `<!-- agentos-session ` e finisce con ` -->`.
2. Quattro campi, SEMPRE questi, SEMPRE in quest'ordine: `id=` `code=` `tenant=` `agent=`.
3. Separatore: un singolo spazio. **Nessuna virgoletta attorno ai valori**
   (le virgolette nel transcript JSONL vengono escapate: è la causa della
   regressione 4.6.1).
4. Valori: `id` = uuid minuscolo; `code` = codice sessione com'è (es.
   `SES-INV-1785254774980`); `tenant` e `agent` = slug `[a-z0-9-]`.
5. Emesso ANCHE quando `dialog_required` si risolve e la sessione nasce al
   secondo giro di `invoke_agent`.
6. Nessuna interpolazione di testo libero dentro la riga.

## Estrazione — una regola per tutti

**L'ultimo marcatore nel transcript vince** (una chat può contenere più
invoke: la sessione corrente è la più recente).

Regex canonica (skill / prosa):

```
<!-- agentos-session id=([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) code=([A-Za-z0-9-]+) tenant=([a-z0-9-]+) agent=([a-z0-9-]+) -->
```

Shell (hook — vedi `scripts/lib-session.sh`, che è l'unica implementazione da
usare negli script):

```sh
grep -oE 'agentos-session id=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$TRANSCRIPT" | tail -1 | cut -d= -f2
```

Il marcatore non contiene virgolette né backslash: sopravvive identico al
doppio encoding del transcript JSONL.

## Recupero quando il marcatore manca (ordine, senza scorciatoie)

1. **Marcatore nel transcript** → si usa (l'ultimo).
2. **Assente** → chiama `list_open_sessions` (filtro: agente corrente).
   - Esattamente UNA sessione → **proponila all'utente** con codice e ora di
     apertura, e ASPETTA conferma.
   - Più d'una → elencale e chiedi quale.
   - **Mai selezione silenziosa, nemmeno quando è ovvia.**
3. **Nessuna** → errore con il rimedio dentro:
   *"Nessuna sessione attiva: apri con `/invoke <agente>` e ripeti."*

## Anche le LETTURE seguono la sessione (B9, server ≥ 4.12.2)

I tool read-only accettano `session_id` **opzionale**: passalo SEMPRE quando
sei dentro una sessione. Senza, la lettura viene risolta sul **tenant attivo**
— che può essere un altro workspace, se l'utente ha altre chat aperte o ha
switchato dal portal. Una chat su djungle con attivo spallanzani si vedrebbe
servire la SOTA del tenant sbagliato.

Vale per: `get_sota`, `get_sota_section`, `probe_initiative_context`,
`list_initiatives`, `get_initiative`, `list_pending_handoffs`,
`list_memory_logs`, `list_review_queue`, `list_pending_scribe`,
`list_references`, `get_briefing`, `list_agents`, `list_domains`.

Ogni risposta porta `tenant_slug`: se non coincide con quello del marcatore,
**fermati e segnalalo all'utente** — stai leggendo il workspace sbagliato.

## La domanda sul workspace (ADR-029 D4b, server ≥ 4.32)

Da v4.32 una chiamata **senza `session_id` e senza `tenant_slug`**, fatta da
chi ha più di un workspace, non riceve dati: riceve

```json
{ "dialog_required": true,
  "dialog_payload": { "kind": "tenant", "question": "...", "tenants": [ ... ] } }
```

È la stessa forma del dialogo dell'iniziativa ambigua, ed è il rimedio a un
guasto che non faceva rumore: il tenant attivo è condiviso fra le chat, e una
lettura sul workspace sbagliato **non fallisce, risponde**.

Regola, valida per ogni skill:

1. **Non ritentare la stessa chiamata.** Non è un errore transitorio.
2. Se in questa chat c'è il marcatore `agentos-session`, la risposta è già
   lì: richiama il tool con quel `session_id`. È il caso normale, e in quel
   caso la domanda non doveva nemmeno arrivare — se arriva, il `session_id`
   non era stato passato: passalo, e correggi il gesto.
3. Se una sessione non c'è, **presenta le scelte all'utente** (`tenants`, il
   default per primo) e richiama con `tenant_slug`. Non scegliere tu.
4. Su `invoke_agent` e `create_session` la domanda è «dove **apro** la
   sessione»: lì `session_id` non esiste ancora, la risposta è `tenant_slug`.

Non applicabile a `list_my_tenants`, `get_active_tenant`, `set_active_tenant`
e `list_open_sessions`: sono i quattro tool con cui ci si orienta e rispondono
sempre.

## Divieti

- **Niente file "sessione corrente" su disco** (`~/.djungle/current-session`
  o simili): è l'architettura di `active_tenant` — globale mutabile per
  macchina, contesa fra chat concorrenti. Riprodurrebbe il difetto che
  ADR-014/014a hanno chiuso e che ADR-029 ha finito di chiudere. Lo stato di
  sessione non vive in un posto condiviso fra sessioni.
- **Niente sessione implicita** per far passare una scrittura: si fallisce
  col messaggio del punto 3. Nessun tipo "scratch".
- **Niente estrazione da prosa variabile**: solo il marcatore.

## Chi consuma questa convenzione

`skills/invoke` (produttore), `skills/writeback`, `skills/handoff`,
`skills/sota-update`, `scripts/digest-on-turn.sh`,
`scripts/finalize-session.sh` (via `scripts/lib-session.sh`).

---
name: backlog
description: |
  Manda un'idea, un bug o un debito tecnico nella coda di sviluppo di un progetto. Trigger quando l'utente dice "/backlog <progetto> <testo>", "metti in backlog", "segna che va sistemato", "apri un item su X", "accoda questa cosa", "aggiungi al backlog di X". Testo libero, nessun campo obbligatorio: tipo, priorità e stima li mette il triage. v4.21.0+.
---

# /backlog — la porta di ingresso (v4.21.0, ADR-024 §2.3b)

> **Sessione (ADR-014b / B9).** Passa `session_id` a ogni chiamata. Recupero e
> formato del marcatore: `skills/_shared/session-threading.md`. Controlla il
> `tenant_slug` in risposta: se non è quello della sessione, fermati.

Una riga da qualunque chat e la cosa è in coda. **L'attrito in ingresso è ciò
che uccide i backlog**: qui non si chiede niente all'utente oltre al testo.

## Uso

```
/backlog agent-os-v2 il briefing del Librarian arriva vuoto quando non ci sono alert
/backlog belloemeglio i siti generati non hanno la meta description
/backlog quella cosa dei log che si perdono
```

## Comportamento

**1. Risolvi il progetto.**

Se il primo token dopo `/backlog` è uno slug di progetto noto, quello è il
progetto e il resto è il testo. Altrimenti chiama `list_projects` e:

- un solo progetto plausibile dal testo → **proponilo e aspetta conferma**;
- più d'uno o nessuno → elenca gli slug e chiedi quale. Mai scelta silenziosa.

Se l'utente nomina un sito-cliente belloemeglio (`parrocchia-online`,
`tennis-club-…`), **non è un progetto**: l'item va su `belloemeglio`, perché la
causa e la correzione stanno nella fabbrica. Dillo in mezza riga e procedi.

**2. Accoda.**

```
create_backlog_item({
  session_id: "<uuid>",
  project_slug: "agent-os-v2",
  title: "<una riga, riscritta pulita dal testo dell'utente>",
  body: "<il testo integrale dell'utente, più il contesto della sessione se pertinente>",
  type: "bug",            // SOLO se evidente dal testo. Nel dubbio ometti.
  source: "owner"
})
```

**3. Conferma in una riga.**

```
→ BKL-0007 su agent-os-v2 (bug, in inbox)
```

E torna a quello che stavate facendo. L'item è un effetto collaterale della
conversazione, non il suo nuovo argomento.

## Cosa NON fare

- ❌ **Non chiedere priorità, effort o impatto.** Sono del triage (`/triage`).
  Chiederli in ingresso è l'attrito che fa smettere di usare la coda.
- ❌ **Non creare il progetto** se manca dall'anagrafica: il tool fallisce
  elencando quelli noti. Accoda su `agent-os-platform` scrivendo nel body qual
  è il progetto vero, oppure chiedi se va registrato con `create_project`.
- ❌ **Non aprire un item per ogni sintomo** dello stesso guasto: uno, con
  l'elenco dei sintomi nel body.
- ❌ **Non riformulare al punto di perdere l'originale**: il `title` è tuo, il
  `body` contiene le parole dell'utente.

## Varianti

- `/backlog` senza argomenti → mostra i progetti in anagrafica e chiedi.
- "segna che il cliente X ha chiesto Y" → `source: "cliente"` e
  `source_detail` col canale (WhatsApp, mail, chiamata). **Attenzione:** un
  item da cliente non si potrà chiudere senza una risposta al cliente — è
  voluto, dillo all'utente quando lo crei.

## Errori

- Progetto non in anagrafica → il messaggio del tool elenca quelli validi.
- `session_id` mancante → vedi `skills/_shared/session-threading.md`. In
  alternativa, per questa write è ammesso `tenant_slug` dichiarato.
- 401 → sessione OAuth scaduta: disconnetti e riconnetti il connettore.

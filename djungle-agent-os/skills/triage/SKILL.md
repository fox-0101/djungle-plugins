---
name: triage
description: |
  Processa gli item in inbox della coda di sviluppo: per ognuno propone tipo, priorità, impatto ed effort, e per quelli che meritano sviluppo produce il messaggio pronto per l'implementatore (bozza di ADR se strutturale, prompt diretto se piccolo). Trigger quando l'utente dice "/triage", "triagea il backlog", "smaltiamo l'inbox", "cosa c'è da decidere in coda", "priorizza gli item". Skill di Doc (AGT-8). v4.21.0+.
---

# /triage — dalla coda al lavoro (v4.21.0, ADR-024 §2.4)

> **Sessione (ADR-014b / B9).** Passa `session_id` a ogni chiamata. Recupero e
> formato del marcatore: `skills/_shared/session-threading.md`.

Gira su **Doc**. Prende gli item in `inbox` e per ognuno produce quattro cose,
poi — per quelli che meritano sviluppo — il messaggio pronto da mandare a chi
implementa.

**Le decisioni le conferma l'utente prima di ogni scrittura.** Questa skill
propone; non scrive finché non le viene detto di sì.

## 1. Leggi

```
list_backlog({ session_id: "<uuid>", status: "inbox" })
```

Se è vuota, dillo in una riga e proponi `list_backlog({ stale_days: 30 })` —
gli item fermi da un mese sono l'altra metà del lavoro di triage.

## 2. Per ogni item, proponi quattro cose

| Cosa | Come |
|---|---|
| **type** | feature · bug · debt · security · chore · spike |
| **priority** | **P0** rompe la produzione o espone dati · **P1** blocca un cliente o un incasso · **P2** migliora · **P3** sarebbe bello |
| **impact** | **una riga di impatto reale, non una categoria.** "Tre clienti su abbonamento non vedono il sito" è impatto; "migliora l'affidabilità" non lo è |
| **effort** | S · M · L · XL |

Più la quinta, che non va in tabella: **serve un ADR?**

- **Sì** se tocca il modello dati, la superficie MCP, l'isolamento fra tenant,
  o una decisione che qualcuno rileggerà fra sei mesi chiedendosi perché.
- **No** per tutto il resto: un item piccolo si chiude con un prompt diretto.

Presenta la proposta compatta e chiedi conferma in blocco:

```
BKL-0007 · agent-os-v2 · il briefing arriva vuoto senza alert
  → bug · P2 · "il briefing del lunedì sembra rotto quando invece non c'è niente da dire" · S · niente ADR

BKL-0008 · belloemeglio · i siti generati non hanno meta description
  → debt · P1 · "40 siti su abbonamento invisibili su Google: è il prodotto che non funziona" · M · ADR (tocca la fabbrica)

Confermi? (tutto / solo alcuni / correggo)
```

## 3. Scrivi (dopo la conferma)

```
triage_backlog_item({
  session_id: "<uuid>", code: "BKL-0007",
  type: "bug", priority: 2, impact: "...", effort: "S"
})
```

Un item in `inbox` che riceve una priorità passa da solo a `triaged`.

## 4. Produci il messaggio per l'implementatore

**Regola in vigore, non negoziabile: mai un work order intermedio.** O una
bozza di ADR, o un prompt diretto. Niente di mezzo.

### Item strutturale → bozza di ADR

Scrivi l'ADR (Contesto → Decisione → Alternative → Conseguenze → **Verifica**)
e salvalo:

```
create_adr({
  session_id: "<uuid>", project_slug: "belloemeglio",
  title: "...", body_md: "...",
  implementation_brief: "<obiettivo, file coinvolti, vincoli, cosa NON toccare>",
  backlog_refs: ["BKL-0008"]
})
```

Il **code lo assegna il server**: non proporne uno, non citarne uno tuo prima
della risposta. È il meccanismo che ha chiuso le collisioni di numerazione.

Due campi decidono se l'ADR potrà mai entrare in lavorazione, quindi scrivili
subito e non "dopo":

- `implementation_brief` — obiettivo, file, vincoli. È il payload che riceve
  chi implementa, che sia Claude Code o Codex.
- una sezione **`## Verifica`** nel body — il criterio con cui si dichiara
  finito. Senza, `update_adr_status(..., 'in_implementation')` viene rifiutato
  dal server.

Poi, quando l'utente decide di mandarlo in lavorazione:

```
update_adr_status({ code: "ADR-0NN", status: "approved" })
update_adr_status({ code: "ADR-0NN", status: "in_implementation" })
```

Da lì l'implementatore apre e dice solo *"procedi con quello che c'è da
implementare"*: `get_next_adr` gli serve body + brief.

### Item piccolo → prompt diretto

Un blocco copiabile senza modifiche, con i file coinvolti e il criterio di
chiusura:

```
In agent-os-v2: `src/cron/librarian.ts` genera il briefing anche quando
`alerts` è vuoto, e il risultato è una sezione con l'intestazione e niente
sotto. Metti un ramo esplicito "nessuna segnalazione questa settimana".
Verifica: run con zero alert → il briefing lo dice, non lo tace.
```

## 5. Il "quando" non è tuo

Gli item con priorità e stima **passano a Focus**, che li colloca nel tempo
reale di Alessandro — ha già il contesto dei vincoli familiari e delle altre
dieci cose in corso. Chiudi proponendo l'handoff, non un calendario:

```
/handoff focus — 4 item triageati da collocare (1 P1, 3 P2)
```

## Cosa NON fare

- ❌ **Non scrivere niente prima della conferma dell'utente**, nemmeno se la
  proposta è ovvia.
- ❌ **Non produrre un work order.** Bozza di ADR o prompt diretto.
- ❌ **Non inventare il code dell'ADR**: lo assegna il server.
- ❌ **Non mettere una data**: la priorità è tua, il calendario è di Focus.
- ❌ **Non chiudere gli item da cliente** senza la risposta al cliente: il
  server rifiuta, ed è voluto.

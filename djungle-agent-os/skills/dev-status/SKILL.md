---
name: dev-status
description: |
  Stato di sviluppo di tutti i progetti: item aperti per progetto e priorità, P0 in evidenza, ADR in corso, item fermi da troppo. Trigger quando l'utente dice "/dev-status", "come stanno i progetti", "cosa c'è in coda", "che lavoro ho aperto", "stato sviluppo", "quanti bug aperti", "che ADR sono in corso". Read-only. v4.21.0+.
---

# /dev-status — lo stato senza doverlo chiedere (v4.21.0, ADR-024 §2.6)

> **Sessione (ADR-014b / B9).** Passa `session_id` a ogni chiamata di lettura:
> senza, si legge dal tenant attivo — che può essere un altro workspace.
> Formato del marcatore: `skills/_shared/session-threading.md`. Controlla il
> `tenant_slug` in risposta: se non è quello della sessione, fermati.

Sola lettura. Tre chiamate, nessuna scrittura.

```
list_projects({ session_id: "<uuid>" })
list_backlog({ session_id: "<uuid>" })                      // solo aperti, ordinati per priorità
list_adrs({ session_id: "<uuid>", status: "in_implementation" })
```

## Formato

```
Stato sviluppo — djungle

⚠ P0 — 1
  BKL-0012  belloemeglio   40 siti senza meta description   (debt, M, 6gg)

ADR in lavorazione — 1
  ADR-025  belloemeglio  Monitoraggio sintetico dei siti pubblicati  (v2, brief ✓)

Coda per progetto
  agent-os-v2      [A]  4 aperti   P1:1  P2:2  P3:1
  belloemeglio     [A]  6 aperti   P0:1  P1:2  P2:2  ·1 da triageare
  bookey           [B]  2 aperti   ·2 da triageare
  bridge-portfolio [B]  —
  agentizer-platform [B] 1 aperto  P3:1
  vespa-dashboard  [B]  —
  agent-os-portal  [A]  —

Da triageare: 3 item in inbox → /triage
```

Regole di resa:

- **I P0 stanno in cima, sempre, anche se sono zero** (in quel caso: `P0 — nessuno`).
  Una riga che compare solo quando le cose vanno male è una riga che nessuno
  impara a cercare.
- La classe di presidio (`[A]` / `[B]`) accanto a ogni progetto: dice quanto
  costa un guasto lì, ed è il contesto della priorità.
- Progetto senza item aperti → `—`, non lo si nasconde: un progetto silenzioso
  può essere sano o abbandonato, e la differenza si vede solo se compare.
- Età in giorni sugli item P0 e P1.
- In coda al riepilogo, se ci sono item in `inbox`, il rimando a `/triage`.

## Varianti

- `/dev-status <progetto>` → solo quel progetto, con la lista completa degli
  item aperti (non solo i conteggi) e gli ADR di quel progetto in ogni stato.
- `/dev-status fermi` → `list_backlog({ stale_days: 30 })`: gli item senza
  movimento da un mese. **È la prova negativa del §4**: un backlog dove tutto
  entra e niente esce smette di essere guardato dopo tre mesi. Se la lista è
  lunga, proponi di chiuderne — meglio una coda corta e vera che una lunga e
  finta.

## Cosa NON fa

- ❌ Non scrive, non triagea, non chiude nulla. Per quello: `/triage`.
- ❌ Non inventa lo stato della CI né l'ultimo deploy: **oggi non sono in
  questi dati.** Arrivano con la pagina `/dev` del portal, che legge le API
  GitHub e Vercel. Se l'utente li chiede, dillo invece di stimarli.
- ❌ Non elenca i siti-cliente belloemeglio: non sono progetti, sono il
  prodotto della fabbrica (ADR-024 §2.5).

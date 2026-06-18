---
name: pnl-snapshot
description: |
  Genera uno snapshot commerciale del P&L di un cliente prospect (startup o PMI) per Han. Trigger quando l'utente dice "/pnl-snapshot", "fai uno snapshot del P&L di [cliente]", "leggi questo P&L", "analizza questo conto economico", "dammi le leve di cost-out di [cliente]", "che cosa possiamo agentificare in questo P&L". Skill di Han (AGT-10) — output include dual verdict SOLO-fit / Consulting-fit. Richiede KNW-Han-06 (leve cost-out per dipartimento) per essere completa.
---

# `/pnl-snapshot` — P&L Cost-Out Snapshot per Han

Skill commerciale di Han: trasforma il P&L di un prospect in uno strumento di vendita. Parse, diagnosi, top 5 leve di cost-out via AI, dual verdict commerciale (SOLO-fit / Consulting-fit / Both / Neither).

**Owner agent:** Han (AGT-10) — Co-Founder Agentico Djungle SOLO & Consulting Partner.

---

## Quando si attiva

- `/pnl-snapshot` (senza argomenti) → chiede il file e i parametri base
- `/pnl-snapshot [cliente]` → recupera P&L del cliente da knowledge se presente, altrimenti chiede
- "fai uno snapshot del P&L di [X]"
- "leggi questo P&L" (con file allegato)
- "analizza il conto economico di [X]"
- "che leve di cost-out abbiamo su questo cliente?"
- "dammi un P&L cost-out per [cliente]"

---

## Input richiesti

**Obbligatori:**
- File P&L del cliente (xlsx, csv, pdf, o testo strutturato), oppure testo libero del P&L incollato
- Periodo di riferimento (anno fiscale, trimestre, YTD)
- Settore del cliente
- Headcount totale + ricavi annui

**Opzionali (raccomandati):**
- Stage (seed / Series A / B+ / PMI consolidata)
- Cassa attuale e runway
- Budget AI già speso e tooling già in uso
- Obiettivo dichiarato dal cliente (cost-out, scaling, ristrutturazione, M&A prep)

**Se mancano gli obbligatori:** Han chiede in modo diretto senza giri di parole. Non procede al snapshot finché non ha i dati base.

---

## Workflow

### Step 1 — Parsing P&L

A seconda del formato di input:
- **xlsx/csv** → invoca skill `xlsx` per leggere e strutturare le righe
- **pdf** → invoca skill `pdf` per estrarre testo, poi parse strutturato
- **testo libero** → parse diretto in formato strutturato { categoria: voce: importo }

Output di questo step: tabella P&L normalizzata (Ricavi, COGS, Gross Profit, OPEX per categoria, EBITDA, Risultato Netto) con valori assoluti e % sui ricavi.

### Step 2 — Diagnosi

Han produce una diagnosi sintetica:

1. **Voci di costo dominanti** — top 5 voci per assoluto e per % sui ricavi
2. **Scostamento da benchmark settoriale** — se settore + stage permettono benchmark, segnala dove il cliente è fuori scala (es. "personale al 65% sui ricavi vs benchmark settore SaaS 35–45%")
3. **Profilo di salute** — gross margin, EBITDA margin, burn (se startup), rule of 40 (se SaaS)
4. **Red flag immediati** — segnali di crisi o di opportunità

### Step 3 — Top 5 leve di cost-out via AI

Han identifica le 5 voci di costo più aggredibili via agentificazione, ranked per:
- **Impatto € annuo** stimato (saving annuo)
- **Facilità implementativa** (1-5)
- **Payback period** (mesi)

Per ogni leva:
- Descrizione dell'intervento
- Dipartimento target (sales, ops, CS, finance, HR, marketing)
- Stack consigliato (LLM + framework + tooling)
- Costo mensile LLM stimato
- Saving annuo atteso
- Time-to-deploy
- KPI di successo

**Reference knowledge:** KNW-Han-06 (P&L reading + leve cost-out per dipartimento). Se KNW-Han-06 non è ancora popolata, Han usa pattern di settore + dichiara esplicitamente la non-popolazione.

### Step 4 — Quick-win 30gg

Tra le 5 leve, Han identifica quella con il miglior rapporto **ROI dimostrabile / time-to-deploy / rischio**. È pensata come "pilot pagante" per agganciare il cliente.

### Step 5 — Dual verdict commerciale

Output finale di Han con doppio verdict:

**SOLO-fit?** Y / N
- Se Y: ticket SOLO consigliato (cash mensile + % equity + % revshare), motivazione, milestone iniziali
- Se N: motivazione (es. "PMI consolidata con team completo, founder non solo, equity non disponibile")

**Consulting-fit?** Y / N
- Se Y: tier consigliato (Assessment / Pilot 90gg / Scale 6+ mesi), prezzo proposto, eventuale advisor stake o WFE su parte
- Se N: motivazione (es. "no cassa, no runway sufficiente per sostenere retainer")

**Verdict finale Han:** raccomandazione operativa in 3 righe massime + next step concreto.

---

## Output template

```markdown
# P&L Snapshot — [Cliente]
*Periodo: [X] · Settore: [Y] · Headcount: [N] · Ricavi: €[Z]*

## 1. Diagnosi
[Voci dominanti, benchmark, salute, red flag — max 10 righe]

## 2. Top 5 leve di cost-out via AI

| # | Intervento | Dipartimento | Saving annuo | Stack | Payback | Difficoltà |
|---|---|---|---|---|---|---|
| 1 | ... | ... | €... | ... | ...m | ... |
| ... | | | | | | |

### Dettaglio per leva
[Per ogni leva: descrizione, KPI, costi LLM, time-to-deploy]

## 3. Quick-win 30gg
**[Nome intervento]** — [perché è il quick-win, ROI stimato, deliverable]

## 4. Verdict commerciale

**SOLO-fit:** [Y/N] — [motivazione]
[Se Y: ticket proposto cash + equity + revshare]

**Consulting-fit:** [Y/N] — [motivazione]
[Se Y: tier proposto + prezzo]

## 5. Verdict Han
[3 righe operative + next step]
```

---

## Output secondari (opzionali su richiesta)

- Esportazione `.docx` per condivisione cliente (formato pulito, senza note interne)
- Esportazione `.xlsx` con simulazione saving su 12-24-36 mesi
- One-pager AI Readiness Assessment derivato dal P&L

---

## Error handling

- **Nessun P&L fornito** → Han chiede file o testo strutturato. Niente analisi senza input.
- **P&L incompleto** (mancano OPEX dettagliate) → Han segnala limitazione, procede su voci disponibili, dichiara coverage parziale.
- **Settore sconosciuto / no benchmark disponibile** → Han salta lo step "scostamento benchmark", procede su altri step.
- **KNW-Han-06 non popolata** → Han usa pattern di settore generici e dichiara: "Knowledge KNW-Han-06 non ancora popolata. Output basato su pattern di settore — qualità migliorerà quando popoliamo la KNW."

---

## What NOT to do

- ❌ Mai generare numeri di saving senza basarli su voci del P&L reali. Se è una stima, dichiararlo.
- ❌ Mai dichiarare SOLO-fit positivo se il cliente non ha founder solo o non c'è equity disponibile.
- ❌ Mai dichiarare Consulting-fit positivo se il cliente non ha cassa per pagare il retainer minimo.
- ❌ Mai promettere ROI senza KPI di misurazione e baseline.
- ❌ Mai inventare leve di cost-out non supportate da pattern noti — meglio dire "non vedo leve evidenti, serve discovery più profonda".
- ❌ Mai bypassare il dual verdict — è il valore commerciale della skill.

---

## Versioning

v0.1.0 — scaffolding iniziale. Knowledge KNW-Han-06 da popolare prima del primo uso reale.
v1.0.0 (target) — KNW-Han-06 popolata + 3 P&L reali processati come calibrazione.

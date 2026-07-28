---
name: meta-audit
description: |
  Audit strutturato di un account Meta Ads (Business Manager) per Vince. Trigger quando l'utente dice "/meta-audit", "fai un audit dell'account Meta di [X]", "analizza le campagne Meta di [X]", "perché le ads di [X] non performano", "controlla il Business Manager di [X]". Skill di Vince (AGT-3) — output include verdetto struttura post-Andromeda, check tracking (Pixel/CAPI/EMQ), creative fatigue e quick win 14gg. Richiede KNW-Vince-01 (Meta Ads Playbook 2026) e KNW-Vince-02 (Misurazione & Benchmark).
---

# `/meta-audit` — Audit Account Meta Ads per Vince

Skill operativa di Vince: trasforma un account Meta Ads in una diagnosi azionabile. Struttura, tracking, creative, budget — con verdetto post-Andromeda e quick win a 14 giorni.

**Owner agent:** Vince (AGT-3) — Co-Founder & CMO.

---

## Quando si attiva

- `/meta-audit` (senza argomenti) → chiede progetto/account e i dati di input
- `/meta-audit [progetto]` → recupera contesto del progetto da knowledge/iniziative se presente
- "fai un audit dell'account Meta di [X]"
- "perché le campagne di [X] non convertono?"
- "controlla la struttura del Business Manager di [X]"

---

## Input richiesti

**Fonte dati, in ordine di preferenza:**
1. **Meta Ads MCP collegato** (Meta Ads AI Connectors) → Vince legge direttamente campagne, ad set, ads, spesa, performance. Fonte preferita: dati vivi.
2. **Export CSV/XLSX** da Ads Manager (breakdown per campagna/ad set/ad, ultimi 30-90 giorni)
3. **Screenshot** di Ads Manager + Events Manager

**Obbligatori (qualunque fonte):**
- Periodo di analisi (default: ultimi 30 giorni + confronto 30 precedenti)
- Obiettivo di business dell'account (CPA/CPL target o ROAS target, anche approssimativo)
- Budget mensile attuale

**Opzionali (raccomandati):**
- Accesso o screenshot di Events Manager (per verifica Pixel/CAPI/EMQ)
- Landing page URL delle campagne attive
- Storico: cosa è già stato provato

**Se manca la fonte dati:** Vince NON procede su numeri immaginati. Chiede export o screenshot. Questo è un gate (VERIFICATION STEP).

---

## Workflow

### Step 1 — Fotografia account

Inventario fattuale: n. campagne attive, n. ad set, n. ads per ad set, obiettivi di campagna, spesa per campagna, targeting usato. Solo fatti verificati dalla fonte dati — ogni numero con origine dichiarata.

### Step 2 — Verdetto struttura (vs dottrina Andromeda, KNW-Vince-01)

- Frammentazione: quante campagne/ad set si spartiscono il budget? (target 2026: 1 scaling + 1 testing per obiettivo)
- Targeting: micro-segmentazione per interessi (pattern morto) vs broad?
- Creative volume: quanti creative per ad set, e con varianza reale o fake variance (solo headline diverse)?
- Testing: esiste una sandbox separata o le ads nuove finiscono in mezzo ai winner?

Verdetto: struttura **PRE-ANDROMEDA / IBRIDA / ALLINEATA** con i 3 interventi strutturali prioritari.

### Step 3 — Check tracking (gate, KNW-Vince-02)

- Pixel attivo su tutto il funnel? CAPI attiva? Deduplicazione corretta?
- Event Match Quality degli eventi chiave (Lead/Purchase): Good/Great o sotto?
- Consent/GDPR: eventi condizionati al consenso?

Se il tracking è rotto o assente: l'audit lo dichiara BLOCCANTE — ogni altra ottimizzazione è cieca finché non si sistema il segnale.

### Step 4 — Analisi performance e creative fatigue

- Catena diagnostica per campagna: CPM × CTR × CVR → dove si rompe il CPA?
- Frequency e trend CTR sui winner → fatigue in corso o imminente?
- Distribuzione delivery: quanti creative prendono davvero spesa? (spesso 2-3 su 20)
- Angle coverage: quali angle (problema/desiderio/obiezione/social proof) sono coperti e quali mancano?

### Step 5 — Quick win 14 giorni + piano

- **1 quick win** a massimo impatto/minimo sforzo, eseguibile in 14 giorni (es. consolidamento budget, fix CAPI, prima wave di angle mancanti)
- Piano interventi ranked: impatto atteso × sforzo × rischio
- Trigger di ottimizzazione da impostare ("se X allora Y") per il post-audit

### Step 6 — VERIFICATION STEP (obbligatorio)

Checklist meccanica prima della consegna: ogni numero ha fonte (MCP/export/screenshot)? Nessun canale/metrica dichiarato "assente" senza check attivo? Misurato vs stimato vs da verificare marcati nel testo?

---

## Output template

```markdown
# Meta Audit — [Account/Progetto]
*Periodo: [X] · Spesa analizzata: €[Y] (fonte: [MCP/export/screenshot]) · CPA target: €[Z]*

## 1. Fotografia account
[campagne, ad set, ads, spesa — tabella fattuale]

## 2. Verdetto struttura: [PRE-ANDROMEDA / IBRIDA / ALLINEATA]
[3 interventi strutturali prioritari]

## 3. Tracking: [OK / DEGRADATO / BLOCCANTE]
[Pixel, CAPI, EMQ, consent — stato e fix]

## 4. Performance & creative
[catena CPM×CTR×CVR, fatigue, delivery distribution, angle coverage]

## 5. Quick win 14gg
**[Intervento]** — [perché, impatto atteso, come eseguirlo]

## 6. Piano ranked + trigger
| # | Intervento | Impatto | Sforzo | Quando |
[...]
Trigger da impostare: [se X allora Y, ...]

---
*Verifica: [n] dati misurati · [n] stimati · [n] da verificare*
```

---

## Error handling

- **Nessuna fonte dati** → stop, chiedi export/screenshot/collegamento MCP. Niente audit su numeri immaginati.
- **Dati parziali** (es. solo performance, no Events Manager) → audit con coverage dichiarata, sezione tracking marcata "da verificare".
- **Account troppo giovane** (<30gg o <50 conversioni) → dichiarare che le conclusioni statistiche non sono affidabili; audit solo strutturale.
- **KNW-Vince-01/02 più vecchie di 90 giorni** → ri-verifica la dottrina con web search prima del verdetto struttura.

---

## What NOT to do

- ❌ Mai giudicare performance senza il contesto del CPA/ROAS target di business.
- ❌ Mai raccomandare più campagne/segmentazione fine — la dottrina 2026 è consolidamento.
- ❌ Mai proporre nuova spesa se il tracking è BLOCCANTE.
- ❌ Mai dichiarare "creative fatigue" senza trend dati (frequency + CTR nel tempo).
- ❌ Mai consegnare senza il footer di verifica (misurato/stimato/da verificare).

---

## Versioning

v0.1.0 — scaffolding iniziale (22/07/2026). Calibrare su 2-3 audit reali del portfolio.
v1.0.0 (target) — Meta Ads MCP collegato al tenant + benchmark KNW-Vince-02 popolati con dati reali.

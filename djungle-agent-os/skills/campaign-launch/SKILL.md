---
name: campaign-launch
description: |
  Da brief a struttura campagna Meta completa, pronta per Business Manager, per Vince. Trigger quando l'utente dice "/campaign-launch", "lanciamo una campagna per [X]", "prepara le ads di [X]", "struttura una campagna Meta per [X]", "portiamo [X] in advertising". Skill di Vince (AGT-3) — output: struttura campagne post-Andromeda con naming, targeting, budget, creative matrix per angle e copy pronti all'uso, più checklist tracking pre-lancio. Richiede KNW-Vince-01 (Meta Ads Playbook 2026) e KNW-Vince-02 (Misurazione & Benchmark).
---

# `/campaign-launch` — Launch Kit Campagna Meta per Vince

Skill esecutiva di Vince: trasforma un brief di progetto in un launch kit completo che Alessandro può mettere live in Business Manager (o far eseguire via Meta Ads MCP) senza altri passaggi.

**Owner agent:** Vince (AGT-3) — Co-Founder & CMO.

---

## Quando si attiva

- `/campaign-launch` (senza argomenti) → chiede il brief minimo
- `/campaign-launch [progetto]` → recupera missione e contesto da knowledge/iniziative
- "lanciamo una campagna per [X]"
- "prepara le ads di [X]"
- "portiamo [X] su Meta"

---

## Input richiesti

**Obbligatori:**
- Progetto e offerta esatta (cosa vendiamo, a che prezzo, con quale promessa)
- Il "perché" del progetto (Step 0 di Vince — se manca, Vince lo chiede PRIMA di tutto)
- Obiettivo campagna (lead / vendita / traffico qualificato) e CPA/CPL target anche approssimativo
- Budget mensile disponibile
- Landing page esistente (URL) o da creare

**Opzionali (raccomandati):**
- Materiale che ha già convertito (email, copy, testimonianze, obiezioni note)
- Asset creativi disponibili (foto, video, UGC)
- Stato tracking (Pixel/CAPI già attivi?)

**Se manca il "perché" o l'offerta:** stop. Senza missione chiara nessuna campagna ha senso (vincolo #1 di Vince).

---

## Workflow

### Step 1 — Missione & angle mining

- Articola il valore profondo del progetto in 2-3 righe (la verità, non il claim).
- Estrai gli ANGLE dalla realtà del progetto: obiezioni note (ogni obiezione = un angle), desideri, problemi, prove sociali. Se esiste una KNW di progetto (es. KNW-Vince-03 per belloemeglio), è la prima fonte.
- Ricerca rapida: competitor in Meta Ad Library + trend recenti della nicchia (web search). Cosa gira ORA in Italia in questo settore.

### Step 2 — Struttura campagne (dottrina KNW-Vince-01)

- **1 Scaling Campaign** (obiettivo conversione) — parte vuota o con gli asset già validati
- **1 Testing Campaign** (sandbox) — dove nasce tutto
- Targeting: broad. Sotto €200/giorno: un solo ad set broad per campagna.
- Naming convention: `[PROGETTO]_[SCALE|TEST]_[OBIETTIVO]_[MMYY]` per campagne; `[ANGLE]_[FORMATO]_[Vn]` per ads.
- Budget split iniziale: 100% testing al lancio (non ci sono ancora winner) → poi 80/20 scaling/testing a regime.

### Step 3 — Creative matrix

Matrice ANGLE × FORMATO. Minimo al lancio: 4 angle × 2-3 formati (statico, video breve, UGC-style) = 8-12 creative REALMENTE diversi. Vietata la fake variance (stesse creatività con headline diversa).

Per ogni cella della matrice:
- Hook (primi 3 secondi / prima riga)
- Visual brief per designer o generazione AI
- Copy completo: Primary text (2 varianti) | Headline (3 varianti) | CTA
- Il copy parte dal valore vero — mai promettere oltre quello che il prodotto mantiene

### Step 4 — Landing & coerenza funnel

- Check coerenza message-match: l'angle dell'ad deve continuare nella landing (headline speculare).
- Se la landing non esiste: struttura sezione per sezione (Hero → Problem → Solution → Social Proof → CTA → FAQ) con copy.
- CRO minimi: una sola CTA, social proof sopra la piega, obiezioni gestite in FAQ.

### Step 5 — Checklist pre-lancio (gate, KNW-Vince-02)

- [ ] Pixel su tutte le pagine del funnel
- [ ] CAPI attiva + deduplicazione event_id
- [ ] Event Match Quality ≥ Good sugli eventi chiave
- [ ] Consent/GDPR conforme (Italia-first)
- [ ] UTM su tutti i link
- [ ] CPA/CPL target scritto e condiviso

**Nessun lancio con checklist incompleta.** Tracking prima del budget.

### Step 6 — Regole di gestione post-lancio

- Trigger scritti: kill (2-3× CPA target speso senza conversioni), promozione (winner validato → scaling), refresh (frequency/CTR trend).
- Non toccare budget >20-30%/giorno (learning phase).
- Calendario: review a 7gg (solo segnali grossi), decisioni a 14gg, wave creative successiva pronta al giorno 10.
- Se Meta Ads MCP è collegato: proporre l'esecuzione diretta della struttura via connector, con conferma di Alessandro prima di ogni write.

### Step 7 — VERIFICATION STEP (obbligatorio)

Ogni benchmark citato ha fonte e data; le proiezioni sono marcate come stime con range; la checklist tracking è verificata o marcata "da verificare con accesso a Events Manager".

---

## Output template

```markdown
# Launch Kit — [Progetto] su Meta
*Obiettivo: [lead/vendita] · CPA target: €[X] (fonte: [dichiarato/stimato]) · Budget: €[Y]/mese*

## 1. Il perché (l'anima della campagna)
[2-3 righe di verità del progetto]

## 2. Struttura campagne
[SCALE + TEST, ad set, targeting, budget split, naming]

## 3. Creative matrix
| Angle | Formato | Hook | Headline (3) | Primary (2) | CTA |
[8-12 righe]

## 4. Landing
[check message-match o struttura completa]

## 5. Checklist pre-lancio
[gate tracking — stato per voce]

## 6. Regole post-lancio
[trigger kill/promote/refresh + calendario]

---
*Stime marcate con ~ e range. Benchmark: fonte e data inline.*
```

---

## Error handling

- **Manca il "perché" o l'offerta** → stop, torna allo Step 0 di Vince. Chiedi.
- **Budget non dichiarato** → proponi 2 scenari (minimo sensato per validare + scenario pieno) e chiedi conferma.
- **Tracking assente** → il kit esce comunque MA con il gate marcato bloccante e le istruzioni di setup Pixel+CAPI come primo task.
- **Nessun asset creativo** → creative matrix con brief di produzione (anche AI-gen) e stima tempi.
- **KNW-Vince-01/02 più vecchie di 90 giorni** → ri-verifica dottrina con web search prima di strutturare.

---

## What NOT to do

- ❌ Mai strutture pre-Andromeda: molte campagne, micro-targeting, 3-5 ads. Consolidamento + broad + creative volume.
- ❌ Mai fake variance nella creative matrix.
- ❌ Mai proporre il lancio con checklist tracking incompleta.
- ❌ Mai copy che promette più di quello che il prodotto mantiene.
- ❌ Mai scarcity finta, urgency artificiale, dark pattern.
- ❌ Mai un solo approccio — almeno 2 opzioni di budget/scenario con pro/contro.

---

## Versioning

v0.1.0 — scaffolding iniziale (22/07/2026). Primo uso reale candidato: belloemeglio (angle già pronti in KNW-Vince-03).
v1.0.0 (target) — 1 campagna reale lanciata e gestita con questo kit + trigger calibrati sui dati veri.

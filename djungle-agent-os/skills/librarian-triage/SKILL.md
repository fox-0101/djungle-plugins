---
name: librarian-triage
description: |
  Triage conversazionale della coda della verità: alert del Librarian E fatti in review dello Scribe, un item alla volta, verdetto in linguaggio naturale (anche dettato), preview del delta, conferma, avanti. Batch massimo 5, cursore persistito, ripresa da dove si era. Trigger SOLO con "/librarian-triage" o frasi qualificate: "triage del librarian", "cosa ha trovato il librarian", "discrepanze di oggi", "giro del mattino". REGOLA DI INSTRADAMENTO (ADR-008c §3.2): "triage" nudo e le frasi sul lavoro di sviluppo ("triagea il backlog", "smaltiamo l'inbox") appartengono a /triage, che esiste da prima; se la richiesta è ambigua ("facciamo triage" senza contesto) chiedi, una riga, una volta: "Coda di sviluppo o discrepanze del Librarian?" — mai procedere su un'assunzione. v4.25.0+.
---

# /librarian-triage — Truth-Setting Interface (v4.25.0, ADR-008c)

> **Sessione (ADR-014b / B9).** Passa `session_id` a ogni chiamata. Recupero e
> formato del marcatore: `skills/_shared/session-threading.md`.

Il Librarian trova discrepanze; questa skill le porta a verdetto. L'unità di
interazione è **un alert, un verdetto**: si presenta UNA segnalazione, l'utente
risponde come parla (spesso dettando dal telefono), si mostra cosa succederebbe,
si applica solo dopo il sì, si passa alla successiva.

## Instradamento (§3.2 — da rispettare PRIMA di tutto)

- "triage" nudo, "triagea il backlog", "smaltiamo l'inbox", "cosa c'è in coda
  di sviluppo" → **`/triage`** (coda di sviluppo, skill di Doc). Non è questa.
- "/librarian-triage", "triage del librarian", "cosa ha trovato il librarian",
  "discrepanze di oggi", "giro del mattino" → questa skill.
- Ambiguo ("facciamo triage" e basta) → **chiedi, una riga, una volta**:
  *"Coda di sviluppo o discrepanze del Librarian?"*. Le due code hanno effetti
  di scrittura diversi: un instradamento indovinato male costa più della
  domanda.

## Il giro

```
1. get_triage_queue({ session_id, batch_size: 5 })
   → { triage_session_id, resumed, pending_alerts, pending_review, items[] }
   Ogni item ha kind: "alert" oppure "review_fact" (§6.3: una sola coda).
2. Presenta l'item 1 di N (vedi formato). UNO SOLO.
3. L'utente risponde in linguaggio naturale.
4. interpret_verdict({ alert_id: item.id, verdict_text, item_kind: item.kind })
   → { intent, confidence, params, preview } oppure needs_disambiguation
5. Mostra la preview e chiedi conferma.
6. Al sì: apply_triage_action({ alert_id: item.id, item_kind: item.kind,
   intent, params, verdict_text, via: "conversational",
   triage_session_id, session_id })
7. Item successivo. A fine batch: riepilogo di cosa è stato applicato.
```

Se `resumed: true`, dillo: *"Riprendo da dove eravamo: fatto X di N."* Il
cursore vive sul server (`get_triage_progress({ triage_session_id })`), non in
questa chat: la skill interrotta al terzo di cinque riparte dal terzo.

### Formato di presentazione (un item per messaggio)

Alert (`kind: "alert"`):

```
⚠️ 2 di 5 — warning · drift_loop_old · tour-in-vespa
Password OVH (info@ e booking@) non ruotate da 35+ giorni
Il Librarian suggerisce: ruotare le credenziali e registrare la data.
Vista 3 volte dal 10/08.

Che si fa? (è vero / falso / correggi con… / passa a <agente> / dopo / archivia l'iniziativa)
```

**Se l'item porta `siblings`, aggiungili PRIMA della domanda**, una riga per
fratello e non di più:

```
⚠️ 2 di 5 — warning · drift_stale · agent-os-platform
Il digest continua a produrre in inglese su sessioni italiane
Vista 4 volte dal 12/08.

Stesso soggetto, altre 2 aperte: contradiction_sota (critical) · insight_pattern (info)

Che si fa? (è vero / falso / correggi con… / passa a <agente> / dopo / archivia l'iniziativa)
```

I fratelli sono gli alert aperti **sullo stesso soggetto in famiglie diverse**
(ADR-008c rev. 5 §5.1). Non sono doppioni e non si agganciano: pongono domande
diverse e vogliono verdetti diversi. Servono perché tu risponda sapendo cosa
c'è intorno, e perché — se il verdetto vale anche per loro — tu possa dirlo e
smaltirli di seguito invece che a giorni di distanza.

Fatto in review (`kind: "review_fact"` — vocabolario RIDOTTO, arriva in
`allowed_intents`):

```
📋 4 di 5 — fatto in review · decision · high · djungle-bridge
"Il fondo chiude il primo closing a 30M entro Q4"
Estratto da una sessione e rimasto in coda per mancanza di scope.

Lo applico alla SOTA? (sì, applica / no, scarta / dopo)
```

### I sei verdetti (vocabolario chiuso, §2.1)

| L'utente dice | Intent | Effetto |
|---|---|---|
| "sì, è vero", "confermo", "applica" | `confirm_acknowledge` | chiude l'alert come confermato |
| "no, falso", "ignora" | `dismiss` | chiude come falso/irrilevante |
| "lo stage è closed_won", "il fondo è 50M" | `apply_correction` | UPDATE mirato alla sezione SOTA + chiude |
| "passa a Iron che lo gestisce" | `open_handoff` | crea l'handoff verso l'agente + chiude |
| "dopo", "salta", "non ora" | `defer` | fuori dal batch, rientra fra 7 giorni |
| "quell'iniziativa è morta, archivia" | `archive_initiative` | archivia + chiude gli alert collegati |

`apply_correction` vuole in `params` anche `section_name` + `content_md`
(l'interprete propone `correction_text`: componi tu la sezione giusta leggendo
la SOTA con `get_sota_section` e falla vedere nella preview). `open_handoff`
vuole `from_agent` e `to_agents` (risolvi il nome fatto dall'utente con
`list_agents`). Entrambi vogliono `session_id` dentro `params`.

Sui **fatti in review** valgono SOLO tre verdetti (§6.3, T13): accettare
(`confirm_acknowledge` → il fatto va nella SOTA), scartare (`dismiss`),
rimandare (`defer`). Le altre azioni sono rifiutate dal server: non provarle.

### needs_disambiguation

`interpret_verdict` risponde `needs_disambiguation` quando la confidence è
sotto soglia, il verdetto è ambiguo fra due azioni, o chiede qualcosa fuori
dalle sei (operazioni di massa, "cancella tutto"). In quel caso **chiedi di
riformulare** — nessuna scrittura è avvenuta e nessuna deve avvenire. Le
richieste fuori vocabolario si rifiutano dicendo il perché: sei azioni, non di
più, è un guardrail e non un limite tecnico.

## Regole non negoziabili

- ❌ **I fratelli sono contesto, non item.** Si nominano in una riga sotto
  l'alert corrente, mai presentati come una seconda lista da smaltire, e non
  contano nel batch di 5.
- ❌ **Mai una lista o tabella riepilogativa degli alert.** La lista è
  precisamente ciò che oggi non viene consumato. Un alert per messaggio.
- ❌ **Mai scrivere senza preview confermata.** `interpret_verdict` non scrive;
  `apply_triage_action` è l'unico che scrive, e si chiama solo dopo il sì.
- ❌ **Mai azioni dedotte dal parlato fuori dal vocabolario.** Niente SQL,
  niente testo libero eseguito.
- ❌ **Mai più di 5 alert per sessione**, anche con 89 pendenti: il batch di
  domani esiste apposta.
- ❌ **Niente misure di stile qui**: quelle vivono in `get_style_conformance`
  (vista, non coda) e si guardano quando si lavora su un prompt.

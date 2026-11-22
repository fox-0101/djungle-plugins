---
name: salva
description: |
  Salva i fatti della conversazione nella memoria di Agent OS SENZA chiudere la sessione. Trigger quando l'utente dice "salva", "/salva", "salva adesso", "salvalo", o tocca "Salva tutto" / "Fammi scegliere" nel popup Salva proposto dall'agente. Per salvare E chiudere ("salva e chiudi", "/wb", "chiudi sessione") usa la skill writeback. Salva anche i documenti consegnati nella sessione (ADR-047). Plugin 4.47.0+, server 4.90.0+ per i documenti.
---

# /salva — salva adesso, la sessione resta aperta (plugin 4.41.0)

Fuori dalla scheda Code (Cowork, Chat, claude.ai web) i turni della
conversazione non arrivano al server da soli: quello che non si salva, la
memoria non lo vede. Questa skill salva subito e lascia la sessione aperta.

Gli agenti con il modulo **MOD-salva** propongono il salvataggio da soli, con
un popup, quando nella conversazione ci sono novità (una decisione, una data,
un impegno). Le soglie, i freni e il formato del popup stanno nel modulo, non
qui: questa skill è la parte che si attiva quando l'utente lo chiede a voce o
tocca il popup.

## Passi

1. **Sessione.** Il `session_id` viene dall'ultimo marcatore `agentos-session`
   nel transcript (vedi `skills/_shared/session-threading.md`); l'`agent_id`
   dalla sessione (es. `AGT-8`). Senza marcatore: «nessuna sessione attiva:
   apri con `/invoke <agente>` e ripeti». Niente salvataggi senza sessione.

1b. **Documenti della sessione (plugin 4.47.0, server ≥ 4.90.0, ADR-047).**
   Un documento consegnato alla persona (un report, una proposta, una pagina
   HTML, un deck) si registra **alla consegna**, non qui. Due strade
   (plugin 4.48.0, server ≥ 4.91.0):
   - **testo** (HTML, markdown, testo semplice):
     `save_document({session_id, title, content, type})`. Lo carica il server
     nel Drive collegato al workspace: non serve un connettore Drive.
   - **binari** (PDF, pptx, xlsx), sessioni personali, o se il server risponde
     che Drive non è collegato o abilitato: file su Drive col connettore Drive
     del client, poi `save_document({session_id, title, drive_url})`. Senza
     connettore, riporta alla persona il motivo che il server dà (chi deve
     collegare Drive, e dove) e consegna il documento in chat come sempre.
   Per aggiornare un documento già caricato dal server:
   `save_document({session_id, code, content, expected_version})` con la
   `version` letta da `get_document`. Se la risposta è un conflitto, un altro
   client l'ha cambiato: rileggi, non riprovare alla cieca.
   Il server gli dà un codice `DOC-NNNN` e lo tiene **da confermare**.
   Al salvataggio la persona decide quali tenere:
   - `get_document({session_id})` elenca i documenti della sessione. Quelli con
     `status: "da_confermare"` entrano **nello stesso popup dei fatti**, una
     voce ciascuno: «Documento: <titolo>» con il codice nella descrizione.
   - «Salva tutto» li tiene tutti. Con «Fammi scegliere» valgono solo quelli
     spuntati. Senza popup (l'utente ha scritto «salva»): tutti i documenti da
     confermare, e dillo nella riga d'esito.
   - Niente documenti da confermare → questo passo non esiste, il popup è
     quello di sempre.
   Un documento che la persona non tiene resta da confermare: non si lega
   all'iniziativa e non viaggia con handoff e ripresa. Non si archivia da solo.

2. **Cosa salvare.**
   - **«salva», «/salva», «Salva tutto»** → i turni dall'ultimo salvataggio,
     testo integrale, role `user` / `agent`.
   - **«Fammi scegliere»** → un solo turno
     `{role: "user", content: "Confermo da salvare:\n- …\n- …"}` con le sole
     novità scelte nel popup multiSelect.

3. **Salva** con `digest_turn({session_id, agent_id, transcript_delta})`.
   Il server scarta i turni già digeriti per questa sessione: rimandarli non
   duplica niente, quindi nel dubbio manda tutto.
   Con documenti tenuti dalla persona (passo 1b) aggiungi
   `confirmed_documents: ["DOC-0003", …]`: si confermano nella stessa chiamata,
   anche se di fatti nuovi non ce ne sono. La risposta porta `documents`:
   `confermati` (con l'iniziativa a cui si sono legati), `da_confermare` (quelli
   rimasti) e, se serve, `nota`.

3b. **Se Fox chiede dove salvare** (risposta con `dialog_required` e
   `dialog_payload.kind === 'workspace'`, server ≥ 4.77.0). Fox non è sicuro
   che la conversazione sia sul workspace della sessione: i fatti sono
   **trattenuti** nel buffer (`buffer_id`, `in_attesa_workspace`) e non sono in
   memoria. Popup con `dialog_payload.question` e le opzioni
   `dialog_payload.tenants[]` nell'ordine del server, etichetta `Workspace`;
   poi `scribe_commit({buffer_id, workspace_confermato: <slug scelto>, domanda_id: <dialog_payload.domanda_id>})`.
   Senza `domanda_id` (server ≥ 4.80.0) la scelta non vale come risposta
   dell'utente e la domanda torna.
   - Stesso workspace della sessione → i fatti si applicano: l'esito è quello
     di `scribe_commit` (`applied`, `initiatives_touched`).
   - Un altro → la risposta porta `scartato` e `sessione_corretta`. Emetti il
     marcatore nuovo (`skills/_shared/session-threading.md`, regola 7) e rifai
     subito il passo 3 col `session_id` nuovo e **tutti** i turni della
     conversazione: nella sessione nuova non sono mai stati digeriti, e il
     workspace è già confermato.
   Nessuna risposta dell'utente → niente: i fatti trattenuti decadono da soli,
   e il prossimo «salva» rifà la domanda.
   **Documenti:** finché il workspace non è confermato il server non conferma
   nemmeno i documenti (`documents.nota` lo dice). Se l'utente conferma lo
   stesso workspace, confermali subito dopo con
   `save_document({session_id, code, confirmed: true})`, uno per documento. Se
   ne sceglie un altro restano nel workspace in cui sono nati, da confermare:
   dillo in una riga.

4. **Esito, una riga**, con i numeri della risposta:
   `Salvato: <auto_committed> in <initiatives_touched>, <queued_for_review> da rivedere`,
   più `<memorized_to_agent> nella memoria di <agente>` se > 0.
   Con documenti confermati aggiungi `· documenti: DOC-0003 «<titolo>»`, e
   `(senza iniziativa)` se `initiative_slug` è null: il documento è tenuto ma
   non compare nel desk di nessuna iniziativa.
   - `skipped: "already_digested"` → «Era già salvato.»
   - `skipped: "extract_failed"` con `motivo` (server ≥ 4.83.0, BKL-0166) →
     riporta il `motivo` in una riga. Se `causa` è `credito_esaurito`, `chiave_rifiutata` o `servizio_sospeso`
     l'estrazione è ferma per tutti: **non** proporre «salva e chiudi», che
     fallirebbe uguale, e non aggiungere dettagli al motivo. Con le altre
     cause proponi «salva e chiudi» (`/wb`) se il motivo dice che riprovare basta.
   - `skipped` di altro tipo, o un errore → dillo in una riga e proponi
     «salva e chiudi» (`/wb`), che rilegge il transcript intero.

5. **Non chiudere la sessione.** La chiude il server per inattività, oppure
   l'utente con «salva e chiudi» / `/wb`.

## Cosa NON fa

- ❌ Non chiude la sessione e non scrive summary o memory_logs: quello è `/wb`.
- ❌ Non propone il popup da sola: lo fa il modulo MOD-salva dell'agente.
- ❌ Non dice "writeback" all'utente: la parola è "salva".
- ❌ Non passa in `confirmed_documents` un documento che la persona non ha
  tenuto, e non registra come documento un file di lavoro: valgono i soli
  deliverable.

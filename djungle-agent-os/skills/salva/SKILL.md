---
name: salva
description: |
  Salva i fatti della conversazione nella memoria di Agent OS SENZA chiudere la sessione. Trigger quando l'utente dice "salva", "/salva", "salva adesso", "salvalo", o tocca "Salva tutto" / "Fammi scegliere" nel popup Salva proposto dall'agente. Per salvare E chiudere ("salva e chiudi", "/wb", "chiudi sessione") usa la skill writeback. Plugin 4.41.0+, server 4.66.1+ (BKL-0126).
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

2. **Cosa salvare.**
   - **«salva», «/salva», «Salva tutto»** → i turni dall'ultimo salvataggio,
     testo integrale, role `user` / `agent`.
   - **«Fammi scegliere»** → un solo turno
     `{role: "user", content: "Confermo da salvare:\n- …\n- …"}` con le sole
     novità scelte nel popup multiSelect.

3. **Salva** con `digest_turn({session_id, agent_id, transcript_delta})`.
   Il server scarta i turni già digeriti per questa sessione: rimandarli non
   duplica niente, quindi nel dubbio manda tutto.

4. **Esito, una riga**, con i numeri della risposta:
   `Salvato: <auto_committed> in <initiatives_touched>, <queued_for_review> da rivedere`,
   più `<memorized_to_agent> nella memoria di <agente>` se > 0.
   - `skipped: "already_digested"` → «Era già salvato.»
   - `skipped` di altro tipo, o un errore → dillo in una riga e proponi
     «salva e chiudi» (`/wb`), che rilegge il transcript intero.

5. **Non chiudere la sessione.** La chiude il server per inattività, oppure
   l'utente con «salva e chiudi» / `/wb`.

## Cosa NON fa

- ❌ Non chiude la sessione e non scrive summary o memory_logs: quello è `/wb`.
- ❌ Non propone il popup da sola: lo fa il modulo MOD-salva dell'agente.
- ❌ Non dice "writeback" all'utente: la parola è "salva".

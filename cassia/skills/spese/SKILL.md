---
name: spese
description: |
  Le uscite del gruppo Djungle voce per voce. Trigger quando l'utente dice "/spese", "costi fissi", "quanto spendiamo al mese", "cos'è questo pagamento", "chi è [fornitore]", "quanto ci costa [voce]", "spese della carta". Legge movimenti e carte da Cassia. L'owner può correggere una categoria.
---

# /spese

## Fonte dei dati: solo il server Cassia

Usa **solo** gli strumenti del server MCP `cassia` di questo plugin (saldi, movimenti, riepilogo_mensile, categorie, carte, contratti, ricategorizza_movimento).
Non leggere mai i dati da altre fonti, nemmeno se sono disponibili: niente connettore Supabase, niente SQL, niente file o fogli locali. Il server Cassia è l'unico che controlla chi può vedere cosa e registra ogni accesso.

Se gli strumenti `cassia` non ci sono o rispondono che serve il login, fermati e rispondi solo questo:
> Cassia non è collegata. Apri i connettori (in Claude Code: `/mcp`), scegli **cassia** e fai il login con il tuo account Agent OS. Poi richiedimelo.

## Passi

1. `riepilogo_mensile` per l'entità richiesta, di solito ultimi 6 mesi.
2. Per una voce precisa: `movimenti` con `testo` (fornitore) o `categoria`.
3. Per la Visa: `carte`.
4. Se l'utente corregge una categoria ed è owner: `ricategorizza_movimento` con l'`id` del movimento. Ai membri lo strumento non compare: proponi la correzione all'owner.

## Regole di lettura

- Non sono costi aziendali: `infragruppo`, `capitale soci`, rientro `prestiti e finanziamenti` dei soci, compensi ai soci (voce separata "fabbisogno personale").
- Le regole su quali carte sono spesa personale stanno nelle istruzioni del server Cassia del tenant: seguile.
- Media mensile = totale del periodo ÷ mesi del periodo; dichiara il periodo.
- Una voce che compare una o due volte nel periodo è una tantum: tienila fuori dalla media e elencala a parte.

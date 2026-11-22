---
name: spese
description: |
  Le uscite del gruppo Djungle voce per voce. Trigger quando l'utente dice "/spese", "costi fissi", "quanto spendiamo al mese", "cos'è questo pagamento", "chi è [fornitore]", "quanto ci costa [voce]", "spese della carta". Legge movimenti e carte da Cassia. L'owner può correggere una categoria.
---

# /spese

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

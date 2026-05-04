# Djungle Agent OS

Connetti Claude ai tuoi agenti AI. Ogni agente ha la sua personalità, le sue competenze, la sua memoria — e migliora ad ogni sessione.

## Come funziona

Questo plugin collega Claude al sistema Agent OS di Djungle tramite un server MCP dedicato. Non serve accesso a Notion — tutto passa attraverso il server.

## Skill disponibili

### Invoke
Attiva un agente dicendo "invoca [nome]" o "attiva [nome]". Claude diventa quell'agente — con il suo tono, le sue competenze e i suoi vincoli.

**Esempi:**
- "invoca Lora"
- "attiva Dean"
- "fammi parlare con Iron"
- "quali agenti ho?"

### Writeback
Chiudi una sessione e salva tutto. Dici "writeback" o "salva sessione" e il sistema analizza la conversazione, estrae decisioni, learnings, feedback, e li salva.

**Esempi:**
- "writeback"
- "wb"
- "salva sessione"

## Setup (zero terminale)

1. **Installa il plugin** dal marketplace `fox-0101/djungle-plugins` su Claude Desktop / Cowork.
2. **Apri Customize → Plugin personali → Djungle agent os → Connettori → Installa** sul connettore `djungle-agent-os`.
3. Il browser si apre sulla pagina di login Djungle. Inserisci la tua email aziendale.
4. Apri la mail "Il tuo link di accesso a Djungle Agent OS" e clicca il pulsante.
5. Sei loggato. Torna su Claude e dì "attiva Dean" per provare.

L'autenticazione avviene via magic link: niente password, niente API key da copiare. Il token resta valido finché non fai logout o non scade (~30 giorni con refresh automatico).

## Requisiti

- **Account Djungle attivo** — l'email che usi al login deve essere registrata da Djungle Startup Studio come membro di un tenant.
- Se non hai ancora un account, contattaci.

## Troubleshooting

- **"Nessuna membership attiva"** dopo il login → la tua email non è registrata. Contatta Djungle.
- **Email non arriva** → controlla spam. L'invio passa per `noreply@djungle.io` via Resend.
- **Pagina login dice "Sessione scaduta"** → il flow OAuth ha un TTL di 15 minuti. Ricomincia dall'install connettore.
- **`attiva [nome]` non triggera** → controlla che il plugin sia attivo: Customize → Plugin personali → Djungle agent os → status verde.
- **Server in errore** → `curl https://agent-os-v2-git-main-alessandronasi1984-8052s-projects.vercel.app/health` deve tornare `{"ok":true,...}`.

## Versione

v3.0.0 — OAuth 2.1 + magic link (zero env vars). Vedi [CHANGELOG](https://github.com/fox-0101/djungle-plugins/releases) per lo storico.

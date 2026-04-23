# Djungle Agent OS

Connetti Claude ai tuoi agenti AI. Ogni agente ha la sua personalita, le sue competenze, la sua memoria — e migliora ad ogni sessione.

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

## Requisiti

- **Claude con Cowork** — Il plugin funziona su Claude desktop con Cowork attivo
- **Credenziali Djungle** — Una API key (identifica il tuo tenant) + uno User ID (identifica te come membro del tenant). Entrambe vengono fornite quando attivi l'accesso agli agenti.

## Setup

1. Installa il plugin su Claude Cowork
2. Esporta le due variabili d'ambiente nel tuo shell **prima** di avviare Claude:

   ```bash
   export DJUNGLE_API_KEY="<la tua API key>"
   export DJUNGLE_USER_ID="<il tuo User ID, UUID>"
   ```

   Oppure aggiungile in modo permanente al tuo `~/.zshrc` / `~/.bashrc`.
3. Avvia Claude Cowork e dici "invoca [nome agente]". Sei operativo.

## Troubleshooting

- **"401 Unauthorized" / "Invalid API key"** — Le env vars non sono settate o il token è vecchio. Controlla `echo $DJUNGLE_API_KEY` in un terminale e assicurati che Claude sia stato lanciato dopo l'export.
- **"Agent not found"** — Nome sbagliato. Di' "quali agenti ho?" per la lista.
- **Nessuna risposta / timeout** — Controllo salute del server: `curl https://agent-os-v2-git-main-alessandronasi1984-8052s-projects.vercel.app/mcp/health` deve tornare `{"ok":true,...}`.

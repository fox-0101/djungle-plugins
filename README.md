# Djungle Plugins — marketplace

Marketplace privato dei plugin Claude Code del gruppo Djungle / FNX Holding. Contiene plugin e skill che collegano Claude al sistema Agent OS su Notion e ai servizi operativi.

## Installazione (clienti)

Aggiungi il marketplace una sola volta. Claude Code controllerà gli aggiornamenti al launch.

```
/plugin marketplace add fox-0101/djungle-plugins
/plugin install djungle-agent-os
```

Poi setta le tue credenziali in `~/.zshrc` / `~/.bashrc`:

```bash
export DJUNGLE_API_KEY="<la tua API key del tenant>"
export DJUNGLE_USER_ID="<il tuo User ID, UUID>"
```

Riavvia la shell → avvia Claude Cowork → dì "attiva Dean" (o l'agente che preferisci).

## Aggiornamenti

Al prossimo launch di Claude Cowork, il marketplace viene ri-fetchato automaticamente. Se c'è una nuova versione del plugin, viene proposta l'installazione.

Forzare un refresh manuale:

```
/plugin marketplace update djungle-plugins
```

## Plugin disponibili

### `djungle-agent-os` (v2.0.0)

Connette Claude al server MCP multi-tenant di Djungle.

**Skills:**
- `invoke` — attiva un agente per nome (Dean, Lora, Vince, Spacey, Iron, Set, Focus, Doc, Bookey)
- `writeback` — chiude la sessione salvando summary, learnings, decisioni, memory logs

**Tool MCP esposti (13):** `list_agents`, `get_agent`, `invoke_agent`, `write_memory_log`, `list_memory_logs`, `create_session`, `close_session`, `create_handoff`, `list_pending_handoffs`, `acknowledge_handoff`, `write_tenant_knowledge`, `list_tenant_knowledge`.

## Supporto

Apri un issue su questo repo oppure contatta Djungle Startup Studio.

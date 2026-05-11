---
name: marketplace
description: |
  Browse the public Agent OS marketplace cross-tenant. Trigger when the user says "/marketplace", "/marketplace search <query>", "/marketplace top", "/marketplace report <slug>", "fammi vedere il marketplace", "agenti pubblici", "cosa offre il marketplace", "cerca agente <X>", "segnala agente <X>". Read-only su discovery, write su report flow. Per invocare un agente trovato, usa /invoke <name>. v3.5.0+ · report flow v4.1.0+.
---

# /marketplace — Public agents discovery (v4.1.0)

Esplora gli agenti pubblici di tutti i tenant del sistema. Read-only. Non installa nulla — gli agenti public sono direttamente invocabili con `/invoke <name>`.

## Sub-commands

### `/marketplace` o `/marketplace top`

Top 10 agenti più invocati ultimi 30 giorni (verified Djungle prima, poi community). Usa `list_marketplace_agents({badge: "all", limit: 10})`.

Output:

```
🌐 Marketplace Agent OS — Top 10 agenti pubblici

VERIFIED (Djungle):
  1. ⭐ Doc          Chief AI Architect          347 invocazioni
  2. ⭐ Iron         COO                         189 invocazioni
  3. ⭐ Vince        CMO                         156 invocazioni
  4. ⭐ Lora         CPO Challenger              132 invocazioni
  5. ⭐ Set          Board Strategist            89  invocazioni
  6. ⭐ Han          Co-Founder Agentico         67  invocazioni
  7. ⭐ Dean         Growth Strategist           54  invocazioni

COMMUNITY:
  8.    Cassia       Cybersecurity Auditor       23  invocazioni  · acme-corp
  9.    Foglio       Tax Advisor IT              17  invocazioni  · studio-rossi
 10.    Felix        Customer Success Coach      12  invocazioni  · saas-x

Per usarne uno: /invoke <name>
Per cercare: /marketplace search <query>
```

Annotazioni:
- ⭐ = `badge=verified` (owner=Djungle, IP "core")
- senza ⭐ = `badge=community` (third-party tenants)
- nessuna icona "is_own" perché il marketplace mostra il cross-tenant — i tuoi agenti li vedi con `/agent list`

### `/marketplace search <query>`

Ricerca testuale ilike su `name`, `role`, `short_description`. Usa `list_marketplace_agents({query: "<q>"})`.

```
/marketplace search security
```

Output:

```
🌐 Marketplace — risultati per "security" (3):

  · Cassia       Cybersecurity Auditor      community · acme-corp · 23 invocazioni
  · Sentinel     Security Operations Lead   community · cyberco   · 8  invocazioni
  · Doc          Chief AI Architect         ⭐ verified · djungle  · 347 invocazioni
                 (matched on long_description)
```

### `/marketplace verified`

Filtra solo `badge=verified`. Equivalente a `list_marketplace_agents({badge: "verified"})`.

### `/marketplace community`

Filtra solo agenti pubblici di terzi (esclusi i Djungle).

### `/marketplace report <slug> <reason> [--details="..."]` (v4.1.0)

Segnala un agente community per abuse. Usalo solo per spam, contenuti inappropriati o agenti che non funzionano. Lo staff Djungle revisiona entro 7 giorni.

Reason validi: `spam` · `inappropriate` · `not_working` · `other`.

```
/marketplace report cassia spam --details="prompt pubblicitario non funzionale"
```

Chiama `report_agent({slug, reason, details})`. **Bloccato self-report**: non puoi segnalare i tuoi agenti (il tool ritorna error "cannot report your own agent").

Output:
```
✓ Report inviato per cassia.
  Reason: spam
  Status: pending
  Tracking: rep_a8f3b2…

Lo staff Djungle revisionerà entro 7 giorni.
Possibili azioni: dismiss · mark_reviewed · unpublish (forza visibility=private).
```

Da UI portal: link diretto in `/dashboard/marketplace/<slug>` (form inline).

## Important behavior

- **Sempre read-only.** Non chiama `invoke_agent`, `create_agent`, `publish_agent`. Solo discovery.
- **Esclude system_prompt.** La view `agents_catalog` non include il prompt — protegge l'IP del publisher. Il prompt viene servito solo al `invoke_agent` runtime tramite RLS.
- **Cross-tenant ma sicuro.** Quando invochi un agente di un altro tenant, RLS garantisce che il tool eseguito veda SOLO i tuoi dati (sessions, memory, initiatives del tuo tenant). Il publisher non vede mai il tuo data.
- **Invoke count globale.** Il `invoke_count` mostrato è cumulato cross-tenant. Per le tue stats interne usa `/agent stats <slug>`.

## Use cases

### A — Onboarding cliente nuovo

```
Utente: "ho appena attivato Agent OS, cosa c'è?"
→ /marketplace top
→ vede gli 8 verified Djungle, capisce che può iniziare con quelli
→ /invoke Doc
```

### B — Cerco agente per dominio specifico

```
/marketplace search legal
→ trova "Foglio Tax Advisor IT" community
→ /invoke foglio
→ Foglio risponde, audit log mostra owner=studio-rossi consumer=djungle
```

### C — Pubblicazione propria

Non parte di /marketplace, ma flusso correlato:

```
/agent create il-mio-agente "Mio Agente" "Custom Role" "<prompt>" --visibility=public --status=active
→ creato con visibility=public
→ ora appare nel marketplace community per tutti i tenant
```

## Cosa NON fa

- ❌ Non installa / clona agenti — sono già usabili via `/invoke`
- ❌ Non scarica system_prompt — IP protetto del publisher
- ❌ Non rating / review — TBD v5
- ❌ Non publish — quello è in `/agent publish`
- ❌ Non filtra per tenant specifico — `badge` resta l'unico filter cross-tenant

## Edge case — Pagination

Il limit max è 50 per chiamata. Per browsare oltre: paginare client-side (memorizza l'ultimo invoke_count visto e cerca quelli sotto). UI marketplace con paginazione completa è live nel portal v4.1 a `/dashboard/marketplace`.

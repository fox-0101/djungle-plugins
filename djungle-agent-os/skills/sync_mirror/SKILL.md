---
name: sync_mirror
description: |
  Reconstruct the local filesystem mirror of the Djungle Agent OS tenant context. Trigger when the user says "/sync_mirror", "sync mirror", "ricostruisci il mirror", "scarica gli handoff", "rigenera ~/djungle-context", or asks to repopulate the local handoff folder. This skill calls `sync_local_mirror` MCP tool, receives the list of files that should exist on disk, and writes them under `~/[tenant_slug]-context/`.
---

# Sync Mirror — DB → filesystem reconciliation (v3.1.0)

Rebuild the local mirror of the Agent OS context from the database. Use cases:
- New machine: rebuild the entire `~/[tenant_slug]-context/` from scratch.
- Filesystem corrupted or accidentally deleted: repair.
- Drift detection: see which local files have diverged from DB content.

DB is canonical. Filesystem is best-effort mirror. Never sync the other direction (filesystem → DB) — that's a different operation (not in v3.1.0).

## Trigger conditions

- `/sync_mirror`
- "ricostruisci il mirror locale"
- "scarica gli handoff sul disco"
- "il mio `~/djungle-context/` è vuoto, riempilo"
- After `/handoff` if the file write failed (auto-suggest `/sync_mirror`)

## Step-by-step

### 1. Check filesystem availability

If you have no filesystem tool (running on mobile/web), tell the user:

> Sync mirror richiede filesystem access. Su mobile/web il database è canonical e i tool MCP funzionano lo stesso — il mirror locale serve solo se vuoi ispezionare i file da editor di testo. Apri Claude Code o Cowork desktop per usare questa skill.

Stop here.

### 2. Call `sync_local_mirror`

Default: only `handoffs` (the only type in v3.1.0). Future versions will add `decisions`, `theses`.

```
sync_local_mirror({
  types: ["handoffs"],
  overwrite_existing: false   // default: never overwrite divergent local files
})
```

Response:
- `tenant_slug`: tenant identifier for the path
- `base_path_hint`: `~/[tenant_slug]-context/` (resolve `~` to user home)
- `overwrite_existing`: hint passed through
- `files`: array of `{ type, record_id, code, file_path, content_hash, content }`
- `scanned`: total files in scope

### 3. Bootstrap directory

If `~/[tenant_slug]-context/` doesn't exist:

1. Create `~/[tenant_slug]-context/` with subdirs:
   - `handoffs/`
   - `decisions/` (placeholder, empty until v3.2.0)
   - `theses/` (placeholder, empty until v3.2.0)
   - `librarian-reports/` (placeholder, v3.4.0+)
   - `inbox/` (placeholder, v3.4.0+)
   - `archive/` (placeholder)
2. Write `~/[tenant_slug]-context/README.md`:

   ```
   # [Tenant Slug] Context

   This is the local mirror of your Agent OS context.
   Files are synchronized from the database — DB is canonical.

   - handoffs/             — messages between agents
   - decisions/            — ADRs (v3.2.0+)
   - theses/               — strategic models (v3.2.0+)
   - inbox/                — quick captures (v3.4.0+)
   - librarian-reports/    — consolidation outputs (v3.4.0+)
   - archive/              — archived items

   You can read and edit these files. The database remains the source
   of truth — if you delete a file, run `/sync_mirror` to rebuild.
   ```

No `git init`, no `.gitignore` — just folders + readme.

### 4. Write each file

For each `file` in `response.files`:

1. Compute the absolute path: `${base_path}/${file.file_path}` (e.g. `~/djungle-context/handoffs/2026-05-12-1430-vince-to-lora-pitch.md`).
2. Check if the file already exists on disk:
   - **Doesn't exist** → write `file.content`. Increment `written` counter.
   - **Exists, hash matches** → skip (`unchanged`).
   - **Exists, hash differs** → DRIFT. **Do NOT overwrite** unless `overwrite_existing: true`. Add to `drift_files` list.
3. Use `file.content_hash` as expected hash; compute SHA-256 of local file content for the comparison.

### 5. Report

Show a concise summary:

```
Sync mirror — tenant [tenant_slug]
Scanned:     N files in DB
Written:     M new files
Unchanged:   K files (hash matches)
Drift:       D files have local edits diverging from DB
             [...elenco file in drift]
```

If `drift_files.length > 0`, suggest:

> Hai N file editati a mano che divergono dal DB. Usa `/sync_mirror overwrite_existing=true` per sovrascriverli (perdi le modifiche locali) oppure ignorali e modifica il record DB direttamente per allineare.

### 6. Force overwrite mode

If user says "/sync_mirror force" or "sovrascrivi anche i miei", call again with `overwrite_existing: true`. Confirm before destruction:

> Stai per sovrascrivere D file con la versione del DB. Le modifiche locali saranno perse. Confermi?

## Error handling

- **No filesystem access** → tell user (see step 1).
- **Permission denied** on home directory → tell user to check permissions of `~`. No retry.
- **Disk full** → stop, report.
- **Hash mismatch on file just written** → likely race or write error; log warning but don't fail the whole sync.
- **401 from server** → OAuth session expired; tell user to disconnect+reconnect connector.

## What NOT to do

- ❌ Don't write outside `~/[tenant_slug]-context/`.
- ❌ Don't create `.git` or any version control infrastructure.
- ❌ Don't modify file timestamps to match DB — keep filesystem natural.
- ❌ Don't fail the entire sync if one file fails — continue with the others, report at the end.
- ❌ Don't sync filesystem → DB direction. That's a separate operation, not in v3.1.0.

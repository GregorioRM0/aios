# aios/sales

> Lead generation, proposals, CRM, and brand monitoring.

Install this bundle if you sell something: you look for buyers, write proposals, keep a pipeline, or track how your brand is talked about.

## Agents

| Agent | What it does |
|---|---|
| [[lead-generator]] | Find buyers for a named offering: ICP card first, signals from connected sources only, dedup against your pipeline, cited fit/pain/reach/timing scores, a ranked lead sheet, and unsent drafts in your voice for the top few |
| [[proposal-writer]] | Draft tailored proposals from project notes and the offerings and pricing your vault documents, as a Google Doc, HTML-to-PDF or slides |
| [[crm-updater]] | Sync deal updates from meetings, notes, mail and chat into the pipeline `USER.md` names (any CRM, a sheet, or a note) |
| [[brand-monitor]] | Weekly scan of mentions, competitor moves and industry news, surfaced as one structured digest |

**One shared source of truth.** All four agents read the same ICP card, `vault/00 - notes/context/ventures/{venture}/{venture}_icp.md` (who buys, the offer, the pain, the buying trigger, disqualifiers). `lead-generator` proposes it once and saves it on your yes. The flow: `lead-generator` (who to approach) → `proposal-writer` (what to offer them) → `crm-updater` (record where it stands), with `brand-monitor` feeding public signals back to `lead-generator`. All four cite their sources, keep unknowns as *unknown*, and stage everything for you; nothing is sent.

## When to install

- You want buyers found and qualified before you spend time on them
- You write proposals often and want voice and format consistency
- Your pipeline needs ongoing updates from what actually happened
- You want a weekly competitor and brand pulse without doing the scanning yourself

## Dependencies

- **Google Workspace MCP** (bundled): mail drafts, calendar, contacts, documents
- **Slack MCP** (bundled), optional: contact search and alerts
- **Your pipeline**: name it in `USER.md` § Sources (a CRM through its MCP, a sheet, or a vault note); `crm-updater` needs it, `lead-generator` uses it to dedup
- **`/aios:prospect`** is the inward partner of `lead-generator`: it finds offerings you have not named; `lead-generator` finds buyers for one you have

See [[../_index|top-level agents registry]] for the full agent vocabulary.

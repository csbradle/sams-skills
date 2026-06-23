# CONTEXT_MASTER.md template

This is the file `brain-kit lonestar bootstrap` parses (parser: `brain_kit/adapters/_lonestar_bootstrap.py`). Author it in the **local working dir** from the user's Phase-0 answers + research. **Never commit it** — it holds deal data (rule #10).

The parser is **best-effort**: missing sections produce empty lists/strings, never errors. Headings are matched loosely (whitespace/case/dash-insensitive). Only the section *shapes* below are recognized.

> **Slug note:** the project slug is NOT read from this file. The bootstrap CLI hardcodes `project_slug: "lonestar"` in its JSON output — patch it in the JSON before `apply` (see SKILL.md Phase 1). The project-level `aliases:` are also NOT written by `apply`; add them to `Projects/<slug>/index.md` by hand after apply.

---

```markdown
# <Deal Name> — CONTEXT_MASTER

## Deal Overview

<One-to-few paragraphs: what the deal is, the thesis, the stage, the structure.
Becomes Projects/<slug>/index.md "## Deal context" + the summary.>

## The Parties

### <Org Name> (<Alias> / <Alias>)
- **What they are**: <one line — becomes the org description>
- **Side**: <counterparty | advisor to us | advisor to them | our side | portco>
- **Role**: <what they do on this deal>
- **<Any key fact>**: <value>

### <Another Org> (<Alias>)
- **What they are**: ...
- **Side**: ...

## The Deal Narrative — Two Versions

### For LPs (External Narrative)
<Optional. The approved external story. Becomes artifacts/lp-narrative-draft.md.
LEAVE EMPTY to skip the LP draft — onboarding usually skips this.>

### Internal Reality
<The unvarnished take — risks, real read on the deal. Becomes opinions.md
(visibility: personal).>

### People
- **<Full Name>**: <org, role, and the user's relationship/read — one line each>
- **<Full Name>**: ...

### Glossary Terms
- **<Term>**: <definition — project-scoped>
- **<Term>**: ...
```

---

## Parser rules that matter when authoring

- **Org aliases** come from the parenthetical after the `###` name, split on ` / ` (e.g. `### Ultimate Knowledge Institute (UKI / Jedi)` → aliases `["UKI", "Jedi"]`). Keep it a clean ` / `-separated list, not prose.
- **Org `description`** is lifted from the `- **What they are**:` (or `- **What they were**:`) bullet. Always include it.
- **People** accept either bullet shape (`- **Name**: notes`) or one-per-line prose (`Name = notes` / `Name - notes`). Prefer bullets. Use **full names** — a first-name-only entry triggers a slug-collision risk and a warning.
- **Glossary** same two shapes as People.
- The narrative H3s must read exactly `For LPs (External Narrative)` and `Internal Reality` (loose-matched) to land in the right files.

# CONTEXT_MASTER.md template (v2)

The file `brain-kit lonestar bootstrap <path> --slug <slug>` parses (parser:
`brain_kit/adapters/_lonestar_bootstrap.py`). Author it in the **local working dir** from the
Stage-1 answers + research. **Never commit it** — it holds deal data (rule #10).

The parser is **best-effort**: missing sections produce empty lists/strings, never errors.
Headings are matched loosely (whitespace/case/dash-insensitive). Only the section *shapes*
below are recognized by bootstrap; the sections marked **[skill-authored]** are IGNORED by
bootstrap — the skill writes them onto `Projects/<slug>/index.md` post-apply (merge-not-replace,
diff first). Since v0.7.0: `--slug` sets the project slug (no JSON patching) and
`## Codename & Aliases` propagates through apply (no hand-alias step).

---

```markdown
# <Deal Name> — CONTEXT_MASTER

## Deal Overview

<One-to-few paragraphs: what the deal is, the thesis, the stage, the structure.
Becomes Projects/<slug>/index.md "## Deal context" + the summary.>

## Codename & Aliases

- **Aliases**: <Real Deal Name> / <Codename> / <Other Name>
- **Deal-unique aliases**: <Codename>

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
LEAVE EMPTY to skip — onboarding usually skips this.>

### Internal Reality
<The unvarnished take — risks, real read on the deal. Becomes opinions.md
(visibility: personal).>

### People
- **<Full Name>**: <org, role, and the user's relationship/read — one line each>

### Glossary Terms
- **<Term>**: <definition — project-scoped>

## Deal Type [skill-authored — bootstrap ignores]
<buyside | sellside | portco | watching>  → frontmatter `deal_type:`

## Deal Timeline [skill-authored — bootstrap ignores]
<Dated financing/M&A events, one per line: date — kind (tuck_in_close / rescue_financing /
equity_round / recapitalization / the standard kinds) — orgs + roles — one-line note.
→ frontmatter `milestones:` + a "## Deal timeline" body section.
Cap table: POINTER to the authoritative doc + one-line summary — never a maintained ledger.
Topology: tuck-ins/refis/rescues live INSIDE this project; own project only if run as a full
separate deal process.>

## Workstreams [skill-authored — bootstrap ignores]
<The deal's workstreams as the user names them (e.g. QoE / Legal-SPA / market work / lender;
portco workstreams are bespoke). → deal_update: workstreams list in Stage 2.>

## Financial Sources [skill-authored — bootstrap ignores; feeds Stage 5]
<Where the underwriting model, budget, and recurring actuals live: file + exact version for
UW; sender + folder + cadence for recurring packages; the canonical cash-forecast source.>
```

---

## Parser rules that matter when authoring

- **Codename & Aliases**: bullets `- **Aliases**:` and `- **Deal-unique aliases**:`, values
  ` / `-separated. Deal-unique aliases are auto-included in the plain aliases list. Keep every
  alias ≥3 chars and not a substring of another deal's names.
- **Org aliases** come from the parenthetical after the `###` name, split on ` / `
  (e.g. `### Ultimate Knowledge Institute (UKI / Jedi)` → `["UKI", "Jedi"]`). A clean
  ` / `-separated list, not prose.
- **Org `description`** is lifted from the `- **What they are**:` (or `- **What they were**:`)
  bullet. Always include it.
- **People** accept bullets (`- **Name**: notes`) or one-per-line prose (`Name = notes`).
  Prefer bullets. Use **full names** — first-name-only risks a slug collision (warned).
- **Glossary** same two shapes as People.
- The narrative H3s must read exactly `For LPs (External Narrative)` and `Internal Reality`
  (loose-matched) to land in the right files.

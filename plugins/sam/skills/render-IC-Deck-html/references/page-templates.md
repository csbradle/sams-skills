# HTML/CSS page templates for IC decks

Loaded on demand by the Pass 2 renderer when it needs a tactical pattern. Covers the recurring page shapes (analytical table + commentary, bridge waterfall, advisor read, pipeline, appendix divider, TBU callout).

## Base shell

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{{deal}} IC Update — {{date}}</title>
  <style>
    :root {
      --twc-navy: #0a2540;
      --twc-blue: #3a6ea5;
      --twc-grey-text: #1f2937;
      --twc-grey-muted: #6b7280;
      --twc-grey-line: #e5e7eb;
      --twc-bg: #ffffff;
      --twc-yellow-callout-bg: #fef3c7;
      --twc-yellow-callout-border: #f59e0b;
    }
    @page { size: 16in 9in; margin: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
      color: var(--twc-grey-text);
      background: var(--twc-bg);
      margin: 0;
      font-size: 18px;
      line-height: 1.5;
    }
    .slide {
      width: 1920px;
      height: 1080px;
      padding: 56px 72px;
      box-sizing: border-box;
      page-break-after: always;
      position: relative;
    }
    .slide h1.header {
      font-size: 32px;
      font-weight: 600;
      color: var(--twc-navy);
      margin: 0 0 6px 0;
    }
    .slide .subheader {
      font-size: 20px;
      font-weight: 500;
      color: var(--twc-blue);
      margin: 0 0 32px 0;
      line-height: 1.4;
    }
    .slide .page-num {
      position: absolute;
      bottom: 24px;
      right: 36px;
      font-size: 14px;
      color: var(--twc-grey-muted);
    }
    /* Tables */
    table.analytical {
      width: 100%;
      border-collapse: collapse;
      font-size: 15px;
    }
    table.analytical th,
    table.analytical td {
      padding: 10px 12px;
      border-bottom: 1px solid var(--twc-grey-line);
      text-align: left;
    }
    table.analytical th {
      background: var(--twc-navy);
      color: white;
      font-weight: 600;
    }
    table.analytical td.num { text-align: right; font-variant-numeric: tabular-nums; }
    table.analytical tr.total { font-weight: 600; background: #f9fafb; }
    /* Commentary co-location (per §5) */
    .commentary {
      margin-top: 24px;
      padding: 16px 20px;
      background: #f9fafb;
      border-left: 4px solid var(--twc-blue);
      font-size: 16px;
    }
    .commentary h3 {
      margin: 0 0 8px 0;
      font-size: 14px;
      text-transform: uppercase;
      color: var(--twc-grey-muted);
      letter-spacing: 0.5px;
    }
    /* TBU callout (per §8) */
    .tbu-callout {
      margin-top: 16px;
      padding: 12px 18px;
      background: var(--twc-yellow-callout-bg);
      border: 2px solid var(--twc-yellow-callout-border);
      border-radius: 4px;
      font-size: 15px;
      font-weight: 500;
    }
    .tbu-callout::before {
      content: "TBU: ";
      font-weight: 700;
    }
    /* Appendix divider (per §7) */
    .appendix-divider {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100%;
    }
    .appendix-divider h1 {
      font-size: 120px;
      font-weight: 700;
      letter-spacing: 8px;
      color: var(--twc-navy);
      margin: 0;
    }
    .appendix-divider .index {
      margin-top: 32px;
      font-size: 20px;
      color: var(--twc-grey-muted);
    }
  </style>
</head>
<body>
  <!-- slides go here -->
</body>
</html>
```

## Analytical page (table + co-located commentary)

```html
<section class="slide">
  <h1 class="header">{{header}}</h1>
  <p class="subheader">{{punchline}}</p>

  <table class="analytical">
    <thead>
      <tr><th>{{row-header}}</th><th class="num">{{col1}}</th><th class="num">{{col2}}</th>...</tr>
    </thead>
    <tbody>
      <tr><td>{{row1}}</td><td class="num">{{cell}}</td>...</tr>
      <!-- ... -->
      <tr class="total"><td>Total</td><td class="num">{{total}}</td>...</tr>
    </tbody>
  </table>

  <div class="commentary">
    <h3>What to look at</h3>
    <p>{{spoon-feed commentary — what we learned, what mgmt told us, what it means for the thesis}}</p>
  </div>

  <!-- optional TBU callout if confounded -->
  <div class="tbu-callout">redo excluding {{event}} to show normalized {{metric}}</div>

  <span class="page-num">{{N}}</span>
</section>
```

## Margin bridge page (rows = drivers, cols = periods — per v03 reuse fidelity)

```html
<section class="slide">
  <h1 class="header">{{header}}</h1>
  <p class="subheader">{{punchline — driver attribution}}</p>

  <table class="analytical">
    <thead>
      <tr>
        <th>Line ($Ks, Quarterly RR)</th>
        <th class="num">Q3-25 RR</th>
        <th class="num">Q1-26 RR</th>
        <th class="num">Δ $K</th>
        <th class="num">pp Impact</th>
      </tr>
    </thead>
    <tbody>
      <tr><td>Mgmt Wages</td><td class="num">...</td>...</tr>
      <tr><td>Gross Margin</td><td class="num">...</td>...</tr>
      <tr><td>Software & Rent</td><td class="num">...</td>...</tr>
      <tr><td>Leasing/Sales</td><td class="num">...</td>...</tr>
      <tr><td>Other</td><td class="num">...</td>...</tr>
      <tr class="total"><td>Final Q1-26 RR</td><td class="num">...</td>...</tr>
    </tbody>
  </table>

  <div class="commentary">
    <h3>Bucket-by-bucket (mgmt 5/15)</h3>
    <ul>
      <li><strong>Mgmt Wages cut (+16pp):</strong> ...</li>
      <li><strong>Gross Margin (+12pp):</strong> ...</li>
      <li><strong>Software & Rent (-2pp):</strong> ...</li>
      <li><strong>Leasing/Sales reinvestment (-6pp):</strong> ...</li>
    </ul>
  </div>

  <span class="page-num">{{N}}</span>
</section>
```

**Hard rule from v03 retro:** rows = drivers, cols = periods. Do NOT rotate. Commentary on SAME page as output.

## Advisor read page (rows = advisor)

```html
<section class="slide">
  <h1 class="header">{{header}}</h1>
  <p class="subheader">{{punchline — strongest convergence + main callouts}}</p>

  <table class="analytical">
    <thead>
      <tr>
        <th style="width: 22%">Advisor</th>
        <th style="width: 22%">Background</th>
        <th>Perspectives (with key callouts)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Kevin Ortner</strong><br><em>ex-CEO Renters Warehouse</em></td>
        <td>18 yrs RW; built to $50M. Engaged, consulting agreement executed.</td>
        <td><ul><li>{{quote/observation}}</li><li>{{quote/observation}}</li></ul></td>
      </tr>
      <tr>
        <td><strong>Rob Greybar</strong><br><em>former Vacasa CEO</em></td>
        <td>De-averaged markets at scale; familiar with PM playbook portability.</td>
        <td><ul><li>{{quote/observation}}</li></ul></td>
      </tr>
    </tbody>
  </table>

  <div class="commentary">
    <h3>Convergence</h3>
    <p>{{the strongest converging signal from advisor reads}}</p>
    <h3>Main callouts</h3>
    <p>{{the main pushback or risk advisors flag}}</p>
  </div>

  <span class="page-num">{{N}}</span>
</section>
```

**Hard rule from v03 retro:** ONLY external advisors actively engaged. NOT founders (Andrew, Kash). NOT intro sources who declined (Chris Laurence). NOT counsel/counterparties.

## M&A pipeline page (rows = target, with substantial commentary)

```html
<section class="slide">
  <h1 class="header">{{header}}</h1>
  <p class="subheader">{{punchline — total doors / rev / blended entry mult}}</p>

  <table class="analytical">
    <thead>
      <tr>
        <th>Target</th><th>Market</th>
        <th class="num">Doors</th><th class="num">Rev</th>
        <th class="num">EBITDA</th><th class="num">Margin</th>
        <th class="num">Entry x</th><th class="num">Post-Syn x</th>
        <th>Status / Notes</th>
      </tr>
    </thead>
    <tbody>
      <!-- one row per target — real data from MD, no placeholders -->
    </tbody>
  </table>

  <div class="commentary">
    <h3>Read-across (from latest mgmt session)</h3>
    <ul>
      <li>{{per-deal color mgmt gave us — Windermere, Memphis pairing, CB bolt-on, etc.}}</li>
      <li>{{integration runway constraint, deal clustering, anchor logic}}</li>
    </ul>
  </div>

  <span class="page-num">{{N}}</span>
</section>
```

**Hard rule from v03 retro:** Pipeline page must include commentary citing per-target detail from mgmt calls. "Just a table" is wrong.

## Appendix divider page

```html
<section class="slide">
  <div class="appendix-divider">
    <h1>APPENDIX</h1>
    <p class="index">A1 cap table · A2 Windermere · A3 legacy doors</p>
  </div>
</section>
```

No header, no subheader, no page number. The slide IS the divider.

## Cover page

```html
<section class="slide" style="background: var(--twc-navy); color: white; display: flex; flex-direction: column; justify-content: center; padding-left: 120px;">
  <p style="font-size: 18px; color: #94a3b8; letter-spacing: 4px; text-transform: uppercase; margin: 0;">True Wind Capital · Investment Committee</p>
  <h1 style="font-size: 72px; font-weight: 700; margin: 24px 0 16px 0; line-height: 1.1;">{{deal name}} — {{type}}</h1>
  <p style="font-size: 28px; color: #cbd5e1; margin: 0;">{{cover date}}</p>
</section>
```

## Common pitfalls (from v03 retro)

1. **Sub-letter pages.** Anytime tempted to write `<section class="slide" id="page-3b">`, STOP. Use the next sequential number, or 2-row same-page layout.
2. **Subheader as description.** "Status of due diligence workstreams" is wrong. "Round 2 VDR live; BluePoint in books; Proxet kickoff complete" is right.
3. **Two narrow columns with 13px font.** Single column 17–18px or split slides.
4. **Quarterly P&L columns when annual fits.** Default annual + LTM; quarterly only if quarterly trend IS the story.
5. **Commentary on a different page than the output.** Always co-locate; use 2-row layout if needed.
6. **No TBU callout on a confounded analysis.** Yellow box, named event, named normalization.
7. **Missing appendix divider.** Always include before A1.
8. **Internal vendor names (QuickBooks, Campfire) anywhere.** Strip per audience-register filter.

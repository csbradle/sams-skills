# run_lint_regression.ps1 -- Stage-1 regression suite for lint_deck.ps1
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File run_lint_regression.ps1
# Exit 0 = all pass. Re-run after ANY edit to lint_deck.ps1 or slop-lint.md.
# Cases encode the 2026-06-11 /review findings (multi-class mask bypass, UTF-16 fail-open,
# attribute/entity/split-tag gap evasion, unclosed-span suppression, hash laundering,
# ledger-path fail-open, empty-deck fail-open, ReconcileMd silent no-op, comma-vs-plus
# pattern-array collapse). All fixture data is FAKE.

$ErrorActionPreference = "Stop"
$lint = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\lint_deck.ps1"
$tmp = Join-Path $env:TEMP "lint-regress-$PID"
New-Item -ItemType Directory -Force $tmp | Out-Null
$enc = New-Object Text.UTF8Encoding $false
$script:fails = 0

function RunLint([string[]]$args2) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $lint @args2 2>$null
    $code = $LASTEXITCODE
    try { $j = ($out | Out-String | ConvertFrom-Json) } catch { $j = $null }
    [pscustomobject]@{ exit = $code; gaps = @($j.gap_tags).Count; orph = @($j.orphan_numbers).Count }
}
function Check([string]$name, $r, [int]$wantExit, [int]$minGaps, [int]$minOrph) {
    $ok = ($r.exit -eq $wantExit) -and ($r.gaps -ge $minGaps) -and ($r.orph -ge $minOrph)
    if (-not $ok) { $script:fails++ }
    "{0} {1} (exit={2} gaps={3} orph={4})" -f ($(if ($ok) { "PASS" } else { "FAIL" }), $name, $r.exit, $r.gaps, $r.orph)
}

# fixtures
[IO.File]::WriteAllText("$tmp\c1.html", '<html><body><section class="slide"><div class="gap fn">[needs source] $4.2M</div></section></body></html>', $enc)
[IO.File]::WriteAllBytes("$tmp\c2.html", [Text.Encoding]::Unicode.GetBytes('<html><body>[needs source] TBD $9.9M</body></html>'))
[IO.File]::WriteAllText("$tmp\h2.html", '<html><body><img alt="[needs source] margin chart"><p>hello</p></body></html>', $enc)
[IO.File]::WriteAllText("$tmp\h3.html", '<html><body><p>[needs <b></b>source] and [needs&nbsp;source]</p></body></html>', $enc)
[IO.File]::WriteAllText("$tmp\ledger.json", '{"claims":[{"id":"s1-c001","value":"$5M","status":"checked"}]}', $enc)
[IO.File]::WriteAllText("$tmp\h4.html", ('<html><body><span data-claim="s1-c001">sourced' + ('x' * 700) + '<p>$99.9M and 73%</p></body></html>'), $enc)
[IO.File]::WriteAllText("$tmp\empty.html", '', $enc)
[IO.File]::WriteAllText("$tmp\clean.html", '<html><body><p>clean deck</p></body></html>', $enc)
[IO.File]::WriteAllText("$tmp\tbuok.html", '<html><body><div class="tbu">TBU: redo excluding the churn event</div><p>fine</p></body></html>', $enc)

Check "T2 multi-class (gap+fn) still blocks" (RunLint @("-DeckPath", "$tmp\c1.html")) 1 1 0
Check "T3 UTF-16 no-BOM fails closed" (RunLint @("-DeckPath", "$tmp\c2.html")) 2 0 0
Check "T4 gap tag in alt attribute" (RunLint @("-DeckPath", "$tmp\h2.html")) 1 1 0
Check "T5 tag-split + nbsp entity (2 tags)" (RunLint @("-DeckPath", "$tmp\h3.html")) 1 2 0
Check "T6 unclosed span does not suppress orphans" (RunLint @("-DeckPath", "$tmp\h4.html", "-LedgerPath", "$tmp\ledger.json")) 1 0 2
Check "T7 empty deck fails closed" (RunLint @("-DeckPath", "$tmp\empty.html")) 2 0 0
Check "T8 bad ledger path fails closed" (RunLint @("-DeckPath", "$tmp\clean.html", "-LedgerPath", "$tmp\nope.json")) 2 0 0
Check "T11 legit .tbu callout passes clean" (RunLint @("-DeckPath", "$tmp\tbuok.html")) 0 0 0
Check "T9a clean deck baselines" (RunLint @("-DeckPath", "$tmp\clean.html", "-UpdateHash")) 0 0 0
[IO.File]::WriteAllText("$tmp\clean.html", '<html><body><p>clean deck EDITED [needs source]</p></body></html>', $enc)
Check "T9b hand-edit drifts + gap" (RunLint @("-DeckPath", "$tmp\clean.html", "-UpdateHash")) 1 1 0
Check "T9c re-run does NOT launder drift" (RunLint @("-DeckPath", "$tmp\clean.html", "-UpdateHash")) 1 1 0
[IO.File]::WriteAllText("$tmp\clean.html", '<html><body><p>clean deck EDITED</p></body></html>', $enc)
Check "T9d AcceptDrift after fix" (RunLint @("-DeckPath", "$tmp\clean.html", "-AcceptDrift")) 0 0 0
Check "T9e steady state" (RunLint @("-DeckPath", "$tmp\clean.html", "-UpdateHash")) 0 0 0
Check "T10 ReconcileMd w/o ledger fails closed" (RunLint @("-DeckPath", "$tmp\clean.html", "-ReconcileMd", "-MdPath", "$tmp\clean.html")) 2 0 0

# codex-round fixtures (2026-06-11 round 2)
[IO.File]::WriteAllText("$tmp\x1.html", '<html><body><p>[needs&#32;source] and lore&#109; and T&#66;D</p></body></html>', $enc)
Check "X1 numeric-entity gap evasion" (RunLint @("-DeckPath", "$tmp\x1.html")) 1 1 0
[IO.File]::WriteAllText("$tmp\x2.html", '<html><body><span data-claim="s1-c001">$500M</span></body></html>', $enc)
Check "X2 value drift vs ledger blocks" (RunLint @("-DeckPath", "$tmp\x2.html", "-LedgerPath", "$tmp\ledger.json")) 1 0 0
[IO.File]::WriteAllText("$tmp\x3.html", '<html><body><!-- data-claim="s1-c001" --><p>text</p></body></html>', $enc)
Check "X3 comment data-claim does not satisfy presence" (RunLint @("-DeckPath", "$tmp\x3.html", "-LedgerPath", "$tmp\ledger.json")) 1 0 0
[IO.File]::WriteAllText("$tmp\dupledger.json", '{"claims":[{"id":"s1-c001","value":"$5M","status":"checked"},{"id":"s1-c001","value":"$6M","status":"tbu"}]}', $enc)
[IO.File]::WriteAllText("$tmp\x4.html", '<html><body><span data-claim="s1-c001">$5M</span></body></html>', $enc)
Check "X4 duplicate ledger ids block" (RunLint @("-DeckPath", "$tmp\x4.html", "-LedgerPath", "$tmp\dupledger.json")) 1 0 0
# X5: AcceptDrift must NOT re-baseline past other blockers
[IO.File]::WriteAllText("$tmp\x5.html", '<html><body><p>clean</p></body></html>', $enc)
RunLint @("-DeckPath", "$tmp\x5.html", "-UpdateHash") | Out-Null
[IO.File]::WriteAllText("$tmp\x5.html", '<html><body><p>edited [needs source]</p></body></html>', $enc)
Check "X5a AcceptDrift w/ other blockers still exits 1" (RunLint @("-DeckPath", "$tmp\x5.html", "-AcceptDrift")) 1 1 0
Check "X5b ...and did not re-baseline (still drifts)" (RunLint @("-DeckPath", "$tmp\x5.html", "-UpdateHash")) 1 1 0
[IO.File]::WriteAllText("$tmp\x5.html", '<html><body><p>edited clean</p></body></html>', $enc)
Check "X5c AcceptDrift on otherwise-clean run passes" (RunLint @("-DeckPath", "$tmp\x5.html", "-AcceptDrift")) 0 0 0
# X6: span keeping ledger value passes (no false drift)
[IO.File]::WriteAllText("$tmp\x6.html", '<html><body><span data-claim="s1-c001">$5M</span></body></html>', $enc)
Check "X6 matching span value passes" (RunLint @("-DeckPath", "$tmp\x6.html", "-LedgerPath", "$tmp\ledger.json")) 0 0 0

Remove-Item -Recurse -Force $tmp -Confirm:$false -ErrorAction SilentlyContinue
if ($script:fails -gt 0) { "RESULT: $($script:fails) FAILURES"; exit 1 } else { "RESULT: all pass"; exit 0 }

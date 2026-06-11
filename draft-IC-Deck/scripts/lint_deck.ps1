# lint_deck.ps1 — deterministic deck hygiene gate (Stage 1)
# PS 5.1-safe. Run via: powershell.exe -NoProfile -ExecutionPolicy Bypass -File lint_deck.ps1 -DeckPath <html> [-LedgerPath <json>] [-ReconcileMd -MdPath <md>] [-UpdateHash]
# Output: single JSON object on stdout. Exit 0 = pass, 1 = blocking findings, 2 = script/input error (FAIL CLOSED).
#
# Stage-1 profile: gap-tags BLOCK; slop + orphan numbers FLAG; ledger checks activate only when -LedgerPath exists.
# Standards (per plan R6): explicit UTF-8 reads, ConvertTo-Json -Depth 10, single-string regex (never line-mode).

param(
    [Parameter(Mandatory = $true)][string]$DeckPath,
    [string]$LedgerPath = "",
    [switch]$ReconcileMd,
    [string]$MdPath = "",
    [switch]$UpdateHash
)

$ErrorActionPreference = "Stop"
$result = [ordered]@{
    deck_path          = $DeckPath
    profile            = "stage1-lexical"
    gap_tags           = @()
    orphan_numbers     = @()
    orphan_soft        = @()
    slop_hits          = @()
    ledger_mismatches  = @()
    md_reconcile       = @()
    hash_drift         = $false
    pass               = $true
    blocking_findings  = 0
    flag_findings      = 0
    error              = $null
}

function Read-Utf8([string]$p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Write-Utf8([string]$p, [string]$s) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($p, $s, $enc)
}

try {
    if (-not (Test-Path -LiteralPath $DeckPath)) { throw "deck not found: $DeckPath" }
    $html = Read-Utf8 $DeckPath

    # ---- Zone masking -------------------------------------------------------
    # Replace excluded zones with spaces (preserves offsets for line reporting).
    # Zones: <style>/<script> blocks, HTML comments, footer/page-num/eyebrow/source-line/tbu
    # elements (single-level tags), and tag attributes themselves.
    $masked = $html
    $zonePatterns = @(
        '(?is)<style\b.*?</style>',
        '(?is)<script\b.*?</script>',
        '(?s)<!--.*?-->',
        # single-level excluded elements by class token (no nested same-tag support; deck templates keep these flat)
        '(?is)<(\w+)\b[^>]*class="[^"]*\b(?:tbu|fn|foot|footer|page-num|pg|eyebrow|conf|source-line|src)\b[^"]*"[^>]*>.*?</\1>'
    )
    foreach ($zp in $zonePatterns) {
        $masked = [regex]::Replace($masked, $zp, { param($m) ' ' * $m.Value.Length })
    }
    # Mask all tag innards (attributes/CSS values) so numeric attribute values never count as claims.
    $maskedText = [regex]::Replace($masked, '(?s)<[^>]*>', { param($m) ' ' * $m.Value.Length })

    function LineOf([string]$s, [int]$idx) { ([regex]::Matches($s.Substring(0, [Math]::Min($idx, $s.Length)), "`n")).Count + 1 }

    # ---- 1. Gap-tags (BLOCK, all profiles) ----------------------------------
    # Scan masked-but-with-tbu? No: gap tags are blocking even outside masked zones,
    # EXCEPT inside legitimate .tbu callouts — which the zone mask already removed.
    $gapPatterns = @('\[needs source', '\[Commentary TBU', '\[TBU', '\[cite', '\[source:', '\bTBD\b', '\bXX%', '\blorem\b')
    foreach ($gp in $gapPatterns) {
        foreach ($m in [regex]::Matches($maskedText, $gp, 'IgnoreCase')) {
            $result.gap_tags += [ordered]@{ pattern = $gp; line = (LineOf $html $m.Index); text = $m.Value }
        }
    }
    # Literal standalone "TBU" outside tbu-classed markup (word boundary, not part of a bracket tag already caught)
    foreach ($m in [regex]::Matches($maskedText, '(?<!\[)\bTBU\b')) {
        $result.gap_tags += [ordered]@{ pattern = 'bare-TBU-outside-callout'; line = (LineOf $html $m.Index); text = 'TBU' }
    }

    # ---- 2. Unit-bearing numbers (Stage 1: FLAG; full profile w/ ledger: BLOCK) ----
    $numPattern = '(?x)
        \$[\d,]+(?:\.\d+)?\s*(?:[MKB]n?|million|billion)?   # dollars
      | \b\d+(?:\.\d+)?\s*%                                  # percents
      | \b\d+(?:\.\d+)?x\b                                   # multiples
      | \b\d+(?:\.\d+)?\s*bps\b                              # bps
      | \b[\d,]{4,}\+?\s*(?:doors|customers|FTEs|wells|seats|users)\b'
    $hasLedger = ($LedgerPath -ne "" -and (Test-Path -LiteralPath $LedgerPath))
    foreach ($m in [regex]::Matches($maskedText, $numPattern)) {
        $val = $m.Value.Trim()
        if ($val -match '^\d{4}$') { continue } # bare year
        # claim-span check: is this number inside a data-claim span? Look back in RAW html
        # for the nearest opening tag containing data-claim before this index and not yet closed.
        $before = $html.Substring(0, [Math]::Min($m.Index, $html.Length))
        $openSpan = [regex]::Match($before, '(?s)<span\b[^>]*data-claim="[^"]+"[^>]*>(?:(?!</span>).)*$')
        if (-not $openSpan.Success) {
            $entry = [ordered]@{ value = $val; line = (LineOf $html $m.Index) }
            if ($hasLedger) { $result.orphan_numbers += $entry } else { $result.orphan_soft += $entry }
        }
    }

    # ---- 3. Ledger 1:1 (only when a ledger exists) --------------------------
    if ($hasLedger) {
        $result.profile = "full"
        $ledgerRaw = Read-Utf8 $LedgerPath
        $ledger = $ledgerRaw | ConvertFrom-Json
        $ledgerIds = @{}
        foreach ($c in @($ledger.claims)) { if ($c.status -ne 'dropped') { $ledgerIds[$c.id] = $c } }
        $htmlIds = @{}
        foreach ($m in [regex]::Matches($html, 'data-claim="([^"]+)"')) { $htmlIds[$m.Groups[1].Value] = $true }
        foreach ($id in $htmlIds.Keys) {
            $baseId = ($id -split '-title$|-takeaway$')[0]
            if (-not $ledgerIds.ContainsKey($id) -and -not $ledgerIds.ContainsKey($baseId)) {
                $result.ledger_mismatches += [ordered]@{ kind = 'html-id-not-in-ledger'; id = $id }
            }
        }
        foreach ($id in $ledgerIds.Keys) {
            if (-not $htmlIds.ContainsKey($id) -and $ledgerIds[$id].status -ne 'tbu') {
                $result.ledger_mismatches += [ordered]@{ kind = 'ledger-id-not-in-html'; id = $id }
            }
        }
    }

    # ---- 4. Slop phrases (FLAG only) — list read from slop-lint.md ----------
    $slopFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'references\slop-lint.md'
    if (Test-Path -LiteralPath $slopFile) {
        $slopDoc = Read-Utf8 $slopFile
        $phrases = @()
        foreach ($lm in [regex]::Matches($slopDoc, '(?m)^- (.+)$')) {
            $p = $lm.Groups[1].Value.Trim()
            if ($p -match '\(' ) { $p = ($p -split '\(')[0].Trim() } # strip parenthetical notes
            if ($p.Length -ge 3 -and $p -notmatch '^(only|best|first|biggest)$') { $phrases += $p } # bare superlatives need citation context — skip in mechanical pass
        }
        $phrases = $phrases | Sort-Object -Unique
        foreach ($p in $phrases) {
            $esc = [regex]::Escape($p)
            foreach ($m in [regex]::Matches($maskedText, "(?i)\b$esc\b")) {
                # context exclusion: "leverage" near financial terms
                if ($p -ieq 'leverage') {
                    $ctx = $maskedText.Substring([Math]::Max(0, $m.Index - 40), [Math]::Min(80, $maskedText.Length - [Math]::Max(0, $m.Index - 40)))
                    if ($ctx -match '(?i)debt|net|gross|turns|ratio|covenant|\dx') { continue }
                }
                $result.slop_hits += [ordered]@{ phrase = $p; line = (LineOf $html $m.Index) }
            }
        }
        # structural slop: em-dash triads + arrow chains in prose
        # NOTE: \uXXXX escapes (not literal chars) — PS 5.1 reads BOM-less .ps1 as ANSI and mojibakes literals.
        foreach ($m in [regex]::Matches($maskedText, '\w+\s+—\s+\w+\s+—\s+\w+')) {
            $result.slop_hits += [ordered]@{ phrase = 'em-dash-chained-triad'; line = (LineOf $html $m.Index) }
        }
        foreach ($m in [regex]::Matches($maskedText, '\S+\s*→\s*\S+\s*→\s*\S+')) {
            $result.slop_hits += [ordered]@{ phrase = 'arrow-chain-in-prose'; line = (LineOf $html $m.Index) }
        }
    }

    # ---- 5. MD reconcile mode (Stage 2 grows this; safe no-op without tags) --
    if ($ReconcileMd) {
        if ($MdPath -eq "" -or -not (Test-Path -LiteralPath $MdPath)) { throw "ReconcileMd requires -MdPath pointing at the context MD" }
        $md = Read-Utf8 $MdPath
        # Only inside "### Page N" blocks: find tagged values **<value>** [sNN-cNNN] and untagged unit-bearing numbers
        $pageBlocks = [regex]::Matches($md, '(?ms)^### Page .*?(?=^### |^## |\z)')
        foreach ($pb in $pageBlocks) {
            $block = $pb.Value
            if ($hasLedger) {
                foreach ($tm in [regex]::Matches($block, '\*\*([^*]+)\*\*\s*\[(s\d+-c\d+|c\d+)\]')) {
                    $mdVal = $tm.Groups[1].Value.Trim(); $id = $tm.Groups[2].Value
                    $entry = $ledgerIds[$id]
                    if ($null -ne $entry -and $entry.value -ne $mdVal -and $entry.display -ne $mdVal) {
                        $result.md_reconcile += [ordered]@{ kind = 'md-value-differs-from-ledger'; id = $id; md = $mdVal; ledger = $entry.value }
                    }
                    if ($null -eq $entry) {
                        $result.md_reconcile += [ordered]@{ kind = 'md-tag-unknown-id'; id = $id; md = $mdVal }
                    }
                }
                # untagged unit-bearing numbers inside page blocks
                $stripped = [regex]::Replace($block, '\*\*([^*]+)\*\*\s*\[(s\d+-c\d+|c\d+)\]', ' ')
                $stripped = [regex]::Replace($stripped, '(?m)^Source:.*$', ' ')
                foreach ($nm in [regex]::Matches($stripped, $numPattern)) {
                    if ($nm.Value.Trim() -match '^\d{4}$') { continue }
                    $result.md_reconcile += [ordered]@{ kind = 'untagged-number-in-md'; value = $nm.Value.Trim() }
                }
            }
        }
    }

    # ---- 6. Deck hash (hand-edit detection) ----------------------------------
    $hashFile = "$DeckPath.lastcheck.sha256"
    $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($html))).Replace('-', '')
    if (Test-Path -LiteralPath $hashFile) {
        $prev = (Read-Utf8 $hashFile).Trim()
        if ($prev -ne $sha) { $result.hash_drift = $true }
    }
    if ($UpdateHash) { Write-Utf8 $hashFile $sha }

    # ---- Verdict --------------------------------------------------------------
    $result.blocking_findings = @($result.gap_tags).Count + @($result.orphan_numbers).Count + @($result.ledger_mismatches).Count + @($result.md_reconcile | Where-Object { $_.kind -ne 'untagged-number-in-md' -or $hasLedger }).Count
    $result.flag_findings = @($result.orphan_soft).Count + @($result.slop_hits).Count
    if ($result.hash_drift) { $result.blocking_findings++ }
    $result.pass = ($result.blocking_findings -eq 0)

    $result | ConvertTo-Json -Depth 10
    if ($result.pass) { exit 0 } else { exit 1 }
}
catch {
    # FAIL CLOSED: a crashed lint never passes a deck.
    $result.pass = $false
    $result.error = $_.Exception.Message
    $result | ConvertTo-Json -Depth 10
    exit 2
}

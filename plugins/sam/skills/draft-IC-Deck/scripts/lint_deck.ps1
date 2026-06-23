# lint_deck.ps1 -- deterministic deck hygiene gate (Stage 1, v2 post-review)
# PS 5.1-safe. Run via: powershell.exe -NoProfile -ExecutionPolicy Bypass -File lint_deck.ps1 -DeckPath <html> [-LedgerPath <json>] [-ReconcileMd -MdPath <md>] [-UpdateHash] [-AcceptDrift]
# Output: single JSON object on stdout. Exit 0 = pass, 1 = blocking findings, 2 = script/input error (FAIL CLOSED).
#
# v2 review fixes (2026-06-11): UTF-16/encoding sniff (fail closed); gap-tag scan no longer honors
# zone masks except .tbu (multi-class bypass killed); attribute + entity/NBSP/split-tag gap detection;
# orphan lookback bounded to 600 chars (unclosed-span suppression killed); -LedgerPath that doesn't
# resolve = exit 2 (was silent downgrade); empty/non-HTML deck = exit 2; -ReconcileMd without ledger
# = exit 2; baseline hashes live under %LOCALAPPDATA%\deck-lint (not next to the deck -- Dropbox sync
# safety) and are written ONLY on pass (or -AcceptDrift after a user waiver); quoted-text excluded
# from slop scan; slop list parsing scoped to phrase sections; em-dash/arrow built from [char] codes
# (no BOM dependency).

param(
    [Parameter(Mandatory = $true)][string]$DeckPath,
    [string]$LedgerPath = "",
    [switch]$ReconcileMd,
    [string]$MdPath = "",
    [switch]$UpdateHash,
    [switch]$AcceptDrift
)

$ErrorActionPreference = "Stop"
$result = [ordered]@{
    deck_path          = $DeckPath
    profile            = "stage1-lexical"
    gap_tags           = @()
    orphan_numbers     = @()
    orphan_soft        = @()
    slop_hits          = @()
    slop_check         = "ok"
    ledger_mismatches  = @()
    md_reconcile       = @()
    hash_drift         = $false
    drift_accepted     = $false
    pass               = $true
    blocking_findings  = 0
    flag_findings      = 0
    error              = $null
}

function Write-Utf8([string]$p, [string]$s) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($p, $s, $enc)
}

# Encoding-sniffing read: honors UTF-8/UTF-16 BOMs; rejects BOM-less UTF-16 (NUL density)
# instead of silently scanning mojibake (review finding C2 -- a wrong-encoding read must
# fail CLOSED, not pass a deck full of invisible gap tags).
function Read-DeckText([string]$p) {
    $bytes = [IO.File]::ReadAllBytes($p)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    if ($bytes.Length -gt 0) {
        $sampleLen = [Math]::Min(4096, $bytes.Length)
        $nuls = 0
        for ($i = 0; $i -lt $sampleLen; $i++) { if ($bytes[$i] -eq 0) { $nuls++ } }
        if (($nuls / $sampleLen) -gt 0.05) {
            throw "file looks like UTF-16 without a BOM (high NUL density) -- refusing to scan mojibake: $p"
        }
    }
    return [Text.Encoding]::UTF8.GetString($bytes)
}

try {
    if (-not (Test-Path -LiteralPath $DeckPath)) { throw "deck not found: $DeckPath" }
    # A passed-but-unresolvable ledger path must NOT silently downgrade the gate to stage1.
    if ($LedgerPath -ne "" -and -not (Test-Path -LiteralPath $LedgerPath)) { throw "ledger not found (a path typo here would silently disable the full gate): $LedgerPath" }
    if ($ReconcileMd -and ($MdPath -eq "" -or -not (Test-Path -LiteralPath $MdPath))) { throw "ReconcileMd requires -MdPath pointing at the context MD" }
    if ($ReconcileMd -and $LedgerPath -eq "") { throw "ReconcileMd requires -LedgerPath (no ledger = nothing to reconcile against)" }

    $html = Read-DeckText $DeckPath
    if ($html.Trim().Length -eq 0 -or $html -notmatch '(?i)<(html|body|section)\b') {
        throw "deck file is empty or not HTML (truncated Pass-2 write?): $DeckPath"
    }

    $nbsp = [char]0x00A0
    $emDash = [char]0x2014
    $arrow = [char]0x2192

    function MaskMatches([string]$s, [string]$pattern) {
        [regex]::Replace($s, $pattern, { param($m) ' ' * $m.Value.Length })
    }
    function LineOf([string]$s, [int]$idx) { ([regex]::Matches($s.Substring(0, [Math]::Min($idx, $s.Length)), "`n")).Count + 1 }

    # ---- Layered masking -----------------------------------------------------
    $maskedBase = $html
    foreach ($zp in @('(?is)<style\b.*?</style>', '(?is)<script\b.*?</script>', '(?s)<!--.*?-->')) {
        $maskedBase = MaskMatches $maskedBase $zp
    }
    # GAP SCAN LAYER: only legitimate .tbu callouts are exempt. Footers/footnotes/etc are
    # NOT exempt -- a [needs source] in a footnote is still a shipped gap (review finding C1:
    # broad class-token masking let class="gap fn" smuggle gap tags past the gate).
    $gapLayer = MaskMatches $maskedBase '(?is)<(\w+)\b[^>]*class="[^"]*\btbu\b[^"]*"[^>]*>.*?</\1>'

    # Scan A -- offset-preserving, whitespace/entity tolerant, INCLUDES attribute text
    # (tags are not stripped here, so alt="[needs source]" is caught -- review H2).
    $ws = "(?:\s|$nbsp|&nbsp;)+"
    # NOTE: parens around the concatenation are load-bearing -- PS comma binds tighter
    # than +, so without them the whole array collapses into one junk pattern.
    $gapPatternsA = @(
        ("\[needs$ws" + "source"),
        ("\[Commentary$ws" + "TBU"),
        '\[TBU', '\[cite', '\[source:', '\bTBD\b', '\bXX%', '\blorem\b'
    )
    foreach ($gp in $gapPatternsA) {
        foreach ($m in [regex]::Matches($gapLayer, $gp, 'IgnoreCase')) {
            $result.gap_tags += [ordered]@{ pattern = 'gap-tag'; line = (LineOf $html $m.Index); text = $m.Value }
        }
    }
    # Scan B -- normalized catch-all: strips ALL tags to nothing and collapses whitespace,
    # so "[needs <b></b>source]" and entity-split variants are caught (review H3).
    $gapNorm = [regex]::Replace($gapLayer, '(?s)<[^>]*>', '')
    # Decode numeric character references so &#32; / &#x6D; style encoding cannot hide a tag (codex #1).
    $gapNorm = [regex]::Replace($gapNorm, '&#(\d+);', { param($m) [string][char][int]$m.Groups[1].Value })
    $gapNorm = [regex]::Replace($gapNorm, '&#[xX]([0-9a-fA-F]+);', { param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
    $gapNorm = $gapNorm.Replace('&nbsp;', ' ').Replace([string]$nbsp, ' ')
    $gapNorm = [regex]::Replace($gapNorm, '\s+', ' ')
    $normPatterns = @('\[needs source', '\[Commentary TBU')
    foreach ($gp in $normPatterns) {
        $normCount = [regex]::Matches($gapNorm, $gp, 'IgnoreCase').Count
        $aCount = @($result.gap_tags | Where-Object { (($_.text -replace '\s+', ' ').Replace([string]$nbsp,' ').Replace('&nbsp;',' ')) -imatch $gp.Replace('\[','\[') }).Count
        if ($normCount -gt $aCount) {
            for ($k = 0; $k -lt ($normCount - $aCount); $k++) {
                $result.gap_tags += [ordered]@{ pattern = 'gap-tag-normalized (tag-split or entity evasion)'; line = 0; text = $gp.Replace('\[','[') }
            }
        }
    }
    # Bare standalone TBU outside .tbu markup (text content only):
    $textOnly = MaskMatches $gapLayer '(?s)<[^>]*>'
    foreach ($m in [regex]::Matches($textOnly, '(?<!\[)\bTBU\b')) {
        $result.gap_tags += [ordered]@{ pattern = 'bare-TBU-outside-callout'; line = (LineOf $html $m.Index); text = 'TBU' }
    }

    # CONTENT LAYER (numbers + slop): full zone exclusions apply -- footer page numbers and
    # source-line figures are not deck claims.
    $contentLayer = MaskMatches $maskedBase '(?is)<(\w+)\b[^>]*class="[^"]*\b(?:tbu|fn|foot|footer|page-num|pg|eyebrow|conf|source-line|src)\b[^"]*"[^>]*>.*?</\1>'
    $maskedText = MaskMatches $contentLayer '(?s)<[^>]*>'

    # ---- Unit-bearing numbers (stage1: FLAG; full profile: BLOCK) -------------
    $numPattern = '(?x)
        \$[\d,]+(?:\.\d+)?\s*(?:[MKB]n?|million|billion)?
      | \b\d+(?:\.\d+)?\s*%
      | \b\d+(?:\.\d+)?x\b
      | \b\d+(?:\.\d+)?\s*bps\b
      | \b[\d,]{4,}\+?\s*(?:doors|customers|FTEs|wells|seats|users)\b'
    $hasLedger = ($LedgerPath -ne "")
    foreach ($m in [regex]::Matches($maskedText, $numPattern)) {
        $val = $m.Value.Trim()
        if ($val -match '^\d{4}$') { continue }
        # Bounded lookback (600 chars): one unclosed data-claim span must not mark the whole
        # rest of the deck as sourced (review H4). Claim spans are short by contract.
        $start = [Math]::Max(0, $m.Index - 600)
        $before = $html.Substring($start, [Math]::Min($m.Index, $html.Length) - $start)
        $openSpan = [regex]::Match($before, '(?s)<span\b[^>]*data-claim="[^"]+"[^>]*>(?:(?!</span>).)*$')
        if (-not $openSpan.Success) {
            $entry = [ordered]@{ value = $val; line = (LineOf $html $m.Index) }
            if ($hasLedger) { $result.orphan_numbers += $entry } else { $result.orphan_soft += $entry }
        }
    }

    # ---- Ledger 1:1 (full profile) --------------------------------------------
    $ledgerIds = @{}
    if ($hasLedger) {
        $result.profile = "full"
        $ledger = (Read-DeckText $LedgerPath) | ConvertFrom-Json
        if ($null -eq $ledger.claims) { throw "ledger has no 'claims' array: $LedgerPath" }
        foreach ($c in @($ledger.claims)) {
            if ($c.status -ne 'dropped') {
                # Duplicate IDs are a blocking defect, not last-write-wins (codex #5).
                if ($ledgerIds.ContainsKey($c.id)) { $result.ledger_mismatches += [ordered]@{ kind = 'duplicate-ledger-id'; id = $c.id } }
                $ledgerIds[$c.id] = $c
            }
        }
        # Scan the masked text (comments/scripts removed) so a data-claim inside an HTML
        # comment cannot satisfy presence checks (codex #4).
        $htmlIds = @{}
        foreach ($m in [regex]::Matches($maskedBase, 'data-claim="([^"]+)"')) { $htmlIds[$m.Groups[1].Value] = $true }
        # VALUE-DRIFT CHECK (codex #3 — pulled forward from Stage 2): the rendered text inside
        # each data-claim span must equal the ledger's display/value verbatim. A span keeping
        # its ID while its number changes is exactly the tamper class the ledger exists to stop.
        foreach ($sm in [regex]::Matches($maskedBase, '(?s)<span\b[^>]*data-claim="([^"]+)"[^>]*>(.*?)</span>')) {
            $cid = $sm.Groups[1].Value
            $inner = [regex]::Replace($sm.Groups[2].Value, '(?s)<[^>]*>', '').Trim()
            $entry = $ledgerIds[$cid]
            if ($null -ne $entry) {
                $disp = if ($null -ne $entry.display) { [string]$entry.display } else { [string]$entry.value }
                if ($inner -ne $disp -and $inner -ne [string]$entry.value) {
                    $result.ledger_mismatches += [ordered]@{ kind = 'value-drift'; id = $cid; rendered = $inner; ledger = $disp }
                }
            }
        }
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

    # ---- Slop phrases (FLAG only) ----------------------------------------------
    # Honest mechanical contract (v2): literal phrases from the two phrase sections of
    # slop-lint.md; quoted text and financial-leverage context excluded. NOT mechanical
    # (agent-rubric territory, stated in slop-lint.md): citation-aware superlatives
    # (only/best/first/biggest skipped here), three-adjective pileups.
    $slopFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'references\slop-lint.md'
    if (-not (Test-Path -LiteralPath $slopFile)) {
        $result.slop_check = "skipped - slop-lint.md not found"
    }
    else {
        $slopDoc = Read-DeckText $slopFile
        $phraseBlock = [regex]::Match($slopDoc, '(?ms)^## Salesy.*?(?=^## Structural)').Value
        if ($phraseBlock.Length -eq 0) { $result.slop_check = "skipped - phrase sections not found in slop-lint.md" }
        $phrases = @()
        foreach ($lm in [regex]::Matches($phraseBlock, '(?m)^- (.+)$')) {
            $p = $lm.Groups[1].Value.Trim()
            if ($p -match '\(') { $p = ($p -split '\(')[0].Trim() }
            if ($p.Length -ge 3 -and $p -notmatch '^(only|best|first|biggest)$') { $phrases += $p }
        }
        $phrases = $phrases | Sort-Object -Unique
        # Quoted text is excluded -- the quote is the quote.
        $slopText = MaskMatches $maskedText '"[^"\r\n]{2,300}"'
        foreach ($p in $phrases) {
            $esc = [regex]::Escape($p)
            foreach ($m in [regex]::Matches($slopText, "(?i)\b$esc\b")) {
                if ($p -ieq 'leverage') {
                    $cs = [Math]::Max(0, $m.Index - 40)
                    $ctx = $slopText.Substring($cs, [Math]::Min(80, $slopText.Length - $cs))
                    if ($ctx -match '(?i)debt|net|gross|turns|ratio|covenant|\dx') { continue }
                }
                $result.slop_hits += [ordered]@{ phrase = $p; line = (LineOf $html $m.Index) }
            }
        }
        # Structural slop, BOM-independent (chars composed from code points -- a BOM-less
        # re-save of this file can no longer break these patterns):
        $triad = "\w+\s+$emDash\s+\w+\s+$emDash\s+\w+"
        $chain = "\S+\s*$arrow\s*\S+\s*$arrow\s*\S+"
        foreach ($m in [regex]::Matches($slopText, $triad)) { $result.slop_hits += [ordered]@{ phrase = 'em-dash-chained-triad'; line = (LineOf $html $m.Index) } }
        foreach ($m in [regex]::Matches($slopText, $chain)) { $result.slop_hits += [ordered]@{ phrase = 'arrow-chain-in-prose'; line = (LineOf $html $m.Index) } }
    }

    # ---- MD reconcile (requires ledger; guarded above) --------------------------
    if ($ReconcileMd) {
        $md = Read-DeckText $MdPath
        $pageBlocks = [regex]::Matches($md, '(?ms)^### Page .*?(?=^### |^## |\z)')
        foreach ($pb in $pageBlocks) {
            $block = $pb.Value
            foreach ($tm in [regex]::Matches($block, '\*\*([^*]+)\*\*\s*\[(s\d+-c\d+|c\d+)\]')) {
                $mdVal = $tm.Groups[1].Value.Trim(); $id = $tm.Groups[2].Value
                $entry = $ledgerIds[$id]
                if ($null -eq $entry) {
                    $result.md_reconcile += [ordered]@{ kind = 'md-tag-unknown-id'; id = $id; md = $mdVal }
                }
                elseif ($entry.value -ne $mdVal -and $entry.display -ne $mdVal) {
                    $result.md_reconcile += [ordered]@{ kind = 'md-value-differs-from-ledger'; id = $id; md = $mdVal; ledger = $entry.value }
                }
            }
            $stripped = [regex]::Replace($block, '\*\*([^*]+)\*\*\s*\[(s\d+-c\d+|c\d+)\]', ' ')
            $stripped = [regex]::Replace($stripped, '(?m)^Source:.*$', ' ')
            foreach ($nm in [regex]::Matches($stripped, $numPattern)) {
                if ($nm.Value.Trim() -match '^\d{4}$') { continue }
                $result.md_reconcile += [ordered]@{ kind = 'untagged-number-in-md'; value = $nm.Value.Trim() }
            }
        }
    }

    # ---- Deck hash (hand-edit detection) -----------------------------------------
    # Baselines live OUTSIDE the deck folder (review M1: a .sha256 next to a Dropbox-synced
    # deck arrives out of order on the other machine -- false drift / false clean). Keyed by
    # lowercase absolute path hash, per machine, under %LOCALAPPDATA%.
    $hashDir = Join-Path $env:LOCALAPPDATA 'deck-lint'
    if (-not (Test-Path -LiteralPath $hashDir)) { New-Item -ItemType Directory -Path $hashDir -Force | Out-Null }
    $resolved = (Resolve-Path -LiteralPath $DeckPath).Path.ToLowerInvariant()
    $pathKey = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($resolved))).Replace('-', '').Substring(0, 32)
    $hashFile = Join-Path $hashDir "$pathKey.sha256"
    $legacyHashFile = "$DeckPath.lastcheck.sha256"
    # Hash RAW BYTES, not decoded text — encoding-only edits must also count as drift (codex #8).
    $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($DeckPath))).Replace('-', '')
    $baseline = $null
    if (Test-Path -LiteralPath $hashFile) { $baseline = (Read-DeckText $hashFile).Trim() }
    elseif (Test-Path -LiteralPath $legacyHashFile) { $baseline = (Read-DeckText $legacyHashFile).Trim() }
    if ($null -ne $baseline -and $baseline -ne $sha) {
        if ($AcceptDrift) { $result.drift_accepted = $true } else { $result.hash_drift = $true }
    }

    # ---- Verdict -------------------------------------------------------------------
    $result.blocking_findings = @($result.gap_tags).Count + @($result.orphan_numbers).Count + @($result.ledger_mismatches).Count + @($result.md_reconcile).Count
    if ($result.hash_drift) { $result.blocking_findings++ }
    $result.flag_findings = @($result.orphan_soft).Count + @($result.slop_hits).Count
    $result.pass = ($result.blocking_findings -eq 0)

    # Baseline writes: ONLY when the run is otherwise clean. -AcceptDrift waives drift alone;
    # it must not re-baseline past OTHER blocking findings (codex #6), and a failing run must
    # never re-baseline -- that would launder hand-edit evidence on retry (review H5/T2).
    if (($UpdateHash -or $AcceptDrift) -and $result.pass) {
        Write-Utf8 $hashFile $sha
        if (Test-Path -LiteralPath $legacyHashFile) { Remove-Item -LiteralPath $legacyHashFile -Force -Confirm:$false }
    }

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

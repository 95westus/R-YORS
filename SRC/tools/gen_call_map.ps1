param(
    [string]$Src = "..",
    [string]$Out = "DOC/GUIDES/CALL_MAP.md",
    [int]$MaxStashEdges = 180,
    [int]$MaxTestEdges = 180
)

$ErrorActionPreference = "Stop"

function Get-RelPath {
    param([string]$Root, [string]$Path)
    $full = (Resolve-Path $Path).Path
    if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($Root.Length + 1).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function Get-Prefix {
    param([string]$Name)
    if ($Name -match '^([A-Z0-9]+)_') { return $matches[1] }
    if ($Name -match '^([A-Z0-9]+)$') { return $matches[1] }
    return 'MISC'
}

function Get-Lane {
    param([string]$FileRel)
    $u = $FileRel.ToUpperInvariant()
    if ($u.StartsWith('SRC/STASH/')) { return 'STASH' }
    if ($u.StartsWith('SRC/TEST/')) { return 'TEST' }
    if ($u.StartsWith('SRC/SESH/')) { return 'SESH' }
    return 'OTHER'
}

function Get-NodeId {
    param([string]$Name)
    return ('N_' + ($Name -replace '[^A-Za-z0-9_]', '_'))
}

function Add-MapSection {
    param(
        [ref]$LinesRef,
        [string]$Title,
        [array]$Rows,
        [int]$MaxEdges
    )

    $lines = $LinesRef.Value
    $rowsLocal = @($Rows | Sort-Object -Property @{Expression = 'Count'; Descending = $true}, Source, Target)
    $selected = @($rowsLocal | Select-Object -First $MaxEdges)

    $lines += "### $Title"
    $lines += ''
    if ($selected.Count -eq 0) {
        $lines += 'No edges found.'
        $lines += ''
        $LinesRef.Value = $lines
        return
    }

    $nodeSet = @{}
    foreach ($r in $selected) {
        $nodeSet[$r.Source] = $true
        $nodeSet[$r.Target] = $true
    }

    $lines += '```mermaid'
    $lines += 'flowchart LR'
    foreach ($n in ($nodeSet.Keys | Sort-Object)) {
        $lines += ('    {0}[{1}]' -f (Get-NodeId $n), $n)
    }
    foreach ($r in $selected) {
        $lines += ('    {0} -->|{1}| {2}' -f (Get-NodeId $r.Source), $r.Count, (Get-NodeId $r.Target))
    }
    $lines += '```'
    if ($rowsLocal.Count -gt $selected.Count) {
        $lines += ''
        $lines += ('_Showing top {0} of {1} edges._' -f $selected.Count, $rowsLocal.Count)
    }
    $lines += ''

    $LinesRef.Value = $lines
}

$repoRoot = (Resolve-Path $Src).Path
$outPath = Join-Path $repoRoot $Out
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$roots = @(
    (Join-Path $repoRoot 'SRC/STASH'),
    (Join-Path $repoRoot 'SRC/TEST'),
    (Join-Path $repoRoot 'SRC/SESH')
)

$files = @()
foreach ($r in $roots) {
    if (Test-Path $r) {
        $files += @(Get-ChildItem -Path $r -Recurse -File -Filter '*.asm' | Sort-Object FullName)
    }
}

$routineHeaderPattern = '^\s*;\s*ROUTINE:\s*(.+?)(?:\s+\[HASH:([0-9A-F]+)\])?\s*$'
$labelPattern = '^\s*([A-Z][A-Z0-9_]+):'
$callPattern = '^\s*(?:\S+:\s*)?(JSR|JMP)\s+([A-Z][A-Z0-9_]+)\b'

$routineSet = @{}
$edges = @()

foreach ($f in $files) {
    $fileRel = Get-RelPath -Root $repoRoot -Path $f.FullName
    $lane = Get-Lane $fileRel
    $current = @()

    foreach ($raw in (Get-Content -LiteralPath $f.FullName)) {
        $line = ($raw -split ';', 2)[0]

        if ($line -match $routineHeaderPattern) {
            $current = @()
            $namesRaw = $matches[1].Trim()
            foreach ($token in ($namesRaw -split '\s*/\s*')) {
                $name = $token.Trim()
                if ($name) {
                    $current += $name
                    $routineSet[$name] = $true
                }
            }
            continue
        }

        if ($line -match $labelPattern) {
            $label = $matches[1]
            $current = @($label)
            $routineSet[$label] = $true
        }

        if ($current.Count -gt 0 -and $line -match $callPattern) {
            $callee = $matches[2]
            foreach ($src in $current) {
                if ($src -eq $callee) { continue }
                $edges += [pscustomobject]@{
                    Source = $src
                    Target = $callee
                    File = $fileRel
                    Lane = $lane
                }
            }
        }
    }
}

$edgeRows = @(
    $edges |
    Group-Object Source, Target |
    ForEach-Object {
        [pscustomobject]@{
            Source = $_.Group[0].Source
            Target = $_.Group[0].Target
            Count = $_.Count
            SourceLane = $_.Group[0].Lane
        }
    }
)

$prefixCounts = @{}
foreach ($e in $edges) {
    $sp = Get-Prefix $e.Source
    $tp = Get-Prefix $e.Target
    $k = "$sp->$tp"
    if (-not $prefixCounts.ContainsKey($k)) { $prefixCounts[$k] = 0 }
    $prefixCounts[$k]++
}

$prefixRows = @(
    $prefixCounts.Keys |
    ForEach-Object {
        $parts = $_ -split '->', 2
        [pscustomobject]@{
            SourcePrefix = $parts[0]
            TargetPrefix = $parts[1]
            Count = $prefixCounts[$_]
        }
    } |
    Sort-Object -Property @{Expression = 'Count'; Descending = $true}, SourcePrefix, TargetPrefix
)

$stashRows = @($edgeRows | Where-Object SourceLane -eq 'STASH')
$testRows = @($edgeRows | Where-Object SourceLane -eq 'TEST')

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$lines = @()

$lines += '# R-YORS Call Map'
$lines += ''
$lines += ('Generated from source scan on {0}.' -f $stamp)
$lines += ''
$lines += '## Scope'
$lines += '- SRC/STASH/LIB/**/*.asm'
$lines += '- SRC/STASH/*.asm'
$lines += '- SRC/TEST/*.asm'
$lines += '- SRC/SESH/*.asm'
$lines += ''
$lines += '## Summary'
$lines += ('- Files scanned: {0}' -f $files.Count)
$lines += ('- Routines/labels discovered: {0}' -f $routineSet.Count)
$lines += ('- Unique call edges: {0}' -f $edgeRows.Count)
$lines += ('- Raw call sites (JSR/JMP): {0}' -f $edges.Count)
$lines += ''

$lines += '## Prefix-Level Call Map'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
$prefixNodes = @{}
foreach ($p in $prefixRows) {
    $prefixNodes[$p.SourcePrefix] = $true
    $prefixNodes[$p.TargetPrefix] = $true
}
foreach ($n in ($prefixNodes.Keys | Sort-Object)) {
    $lines += ('    P_{0}[{0}]' -f $n)
}
foreach ($p in $prefixRows) {
    $lines += ('    P_{0} -->|{1}| P_{2}' -f $p.SourcePrefix, $p.Count, $p.TargetPrefix)
}
$lines += '```'
$lines += ''

Add-MapSection -LinesRef ([ref]$lines) -Title 'STASH Routine Call Map' -Rows $stashRows -MaxEdges $MaxStashEdges
Add-MapSection -LinesRef ([ref]$lines) -Title 'TEST Routine Call Map' -Rows $testRows -MaxEdges $MaxTestEdges

$lines += '## Notes'
$lines += '- Edges are extracted from JSR and JMP instructions.'
$lines += '- Source context is inferred from the nearest ROUTINE block or uppercase label.'
$lines += '- STASH and TEST maps are filtered by source file lane.'

Set-Content -LiteralPath $outPath -Value $lines -Encoding ascii
Write-Output ('Wrote call map: {0}' -f $outPath)

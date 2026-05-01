param(
    [string]$Src = ".",
    [string]$OutDir = "."
)

$ErrorActionPreference = "Stop"

function Get-RelPath {
    param([string]$Root, [string]$Path)
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($Root.Length + 1).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function Get-Prefix {
    param([string]$Name)
    if ($Name -match '^([A-Za-z0-9]+)_') { return $matches[1].ToUpperInvariant() }
    if ($Name -match '^([A-Za-z0-9]+)$') { return $matches[1].ToUpperInvariant() }
    return 'LOCAL'
}

function Mermaid-Id {
    param([string]$Name)
    return 'N_' + ($Name -replace '[^A-Za-z0-9_]', '_')
}

function Write-Doc {
    param(
        [string]$Name,
        [string[]]$Lines
    )
    $path = Join-Path $outRoot $Name
    [System.IO.File]::WriteAllLines($path, $Lines, [System.Text.Encoding]::ASCII)
}

$root = (Resolve-Path -LiteralPath $Src).Path
$outRoot = (Resolve-Path -LiteralPath $OutDir).Path

$scanRoots = @('STASH', 'SESH', 'TEST') |
    ForEach-Object { Join-Path $root $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

$files = @(
    $scanRoots |
    ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Recurse -File |
            Where-Object { @('.asm', '.inc') -contains $_.Extension.ToLowerInvariant() }
    } |
    Sort-Object FullName
)

$routinePattern = '^\s*;\s*ROUTINE:\s*(.+?)(?:\s+\[HASH:([0-9A-Fa-f]{8})\])?\s*$'
$purposePattern = '^\s*;\s*PURPOSE:\s*(.*)$'
$inPattern = '^\s*;\s*IN\s*:\s*(.*)$'
$outPattern = '^\s*;\s*OUT:\s*(.*)$'
$tagsPattern = '^\s*;\s*TAGS:\s*(.*)$'
$xdefPattern = '^\s*XDEF\s+([A-Za-z_][A-Za-z0-9_]*)\b'
$xrefPattern = '^\s*XREF\s+([A-Za-z_][A-Za-z0-9_]*)\b'
$labelPattern = '^\s*([A-Za-z_][A-Za-z0-9_]*):'
$callPattern = '^\s*(?:[A-Za-z_?][A-Za-z0-9_?]*:\s*)?(JSR|JMP)\s+([A-Za-z_?][A-Za-z0-9_?]*)\b'

$routines = New-Object System.Collections.Generic.List[object]
$xdefs = New-Object System.Collections.Generic.List[object]
$xrefs = New-Object System.Collections.Generic.List[object]
$edges = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $rel = Get-RelPath -Root $root -Path $file.FullName
    $lines = Get-Content -LiteralPath $file.FullName
    $current = $null
    $lastRoutineRefs = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNo = $i + 1

        if ($line -match $routinePattern) {
            $namesRaw = $matches[1].Trim()
            $hash = $matches[2]
            $names = @($namesRaw -split '\s*/\s*' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
            if ($names.Count -eq 0) { $names = @($namesRaw) }
            $current = $names[0]
            $lastRoutineRefs = @()
            foreach ($name in $names) {
                $obj = [pscustomobject]@{
                    Name = $name
                    Hash = $hash
                    File = $rel
                    Line = $lineNo
                    Purpose = ''
                    In = ''
                    Out = ''
                    Tags = ''
                }
                $routines.Add($obj)
                $lastRoutineRefs += $obj
            }
            continue
        }

        if ($lastRoutineRefs.Count -gt 0) {
            if ($line -match $purposePattern) {
                foreach ($r in $lastRoutineRefs) { $r.Purpose = $matches[1].Trim() }
                continue
            }
            if ($line -match $inPattern) {
                foreach ($r in $lastRoutineRefs) { $r.In = $matches[1].Trim() }
                continue
            }
            if ($line -match $outPattern) {
                foreach ($r in $lastRoutineRefs) { $r.Out = $matches[1].Trim() }
                continue
            }
            if ($line -match $tagsPattern) {
                foreach ($r in $lastRoutineRefs) { $r.Tags = $matches[1].Trim() }
                continue
            }
            if ($line -notmatch '^\s*;') {
                $lastRoutineRefs = @()
            }
        }

        if ($line -match $xdefPattern) {
            $xdefs.Add([pscustomobject]@{ Name = $matches[1]; File = $rel; Line = $lineNo })
        }
        if ($line -match $xrefPattern) {
            $xrefs.Add([pscustomobject]@{ Name = $matches[1]; File = $rel; Line = $lineNo })
        }
        if ($line -match $labelPattern -and $matches[1] -notmatch '^\?') {
            $current = $matches[1]
        }
        if ($current -and $line -match $callPattern) {
            $target = $matches[2]
            if ($target -ne $current) {
                $edges.Add([pscustomobject]@{
                    Source = $current
                    Target = $target
                    Op = $matches[1]
                    File = $rel
                    Line = $lineNo
                })
            }
        }
    }
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$edgeGroups = @(
    $edges |
    Group-Object Source, Target |
    ForEach-Object {
        [pscustomobject]@{
            Source = $_.Group[0].Source
            Target = $_.Group[0].Target
            Count = $_.Count
        }
    } |
    Sort-Object -Property @{Expression='Count';Descending=$true}, Source, Target
)

$header = @(
    '<!-- AUTO-GENERATED by SRC/tools/gen_docs.ps1. Do not hand-edit. -->',
    '',
    "Generated: $stamp",
    ''
)

$lines = @('# R-YORS Call Order') + $header
$lines += '## Files'
$lines += ''
foreach ($fileGroup in ($routines | Group-Object File | Sort-Object Name)) {
    $lines += "### $($fileGroup.Name)"
    $lines += ''
    foreach ($r in ($fileGroup.Group | Sort-Object Line)) {
        $h = if ($r.Hash) { " [HASH:$($r.Hash)]" } else { '' }
        $lines += ('- `{0}`{1} line {2}' -f $r.Name, $h, $r.Line)
    }
    $lines += ''
}
Write-Doc -Name 'CALL_ORDER.md' -Lines $lines

$lines = @('# R-YORS Routine Contracts') + $header
foreach ($r in ($routines | Sort-Object File, Line, Name)) {
    $lines += '```text'
    $lines += "name:     $($r.Name)"
    $lines += "hash:     $($r.Hash)"
    $lines += "source:   $($r.File):$($r.Line)"
    if ($r.Tags) { $lines += "tags:     $($r.Tags)" }
    if ($r.Purpose) { $lines += "purpose:  $($r.Purpose)" }
    if ($r.In) { $lines += "in:       $($r.In)" }
    if ($r.Out) { $lines += "out:      $($r.Out)" }
    $lines += '```'
    $lines += ''
}
Write-Doc -Name 'ROUTINE_CONTRACTS.md' -Lines $lines

$lines = @('# R-YORS Routine Tree') + $header
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in ($edgeGroups | Select-Object -First 220)) {
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Id $edge.Source), $edge.Source, $edge.Count, (Mermaid-Id $edge.Target), $edge.Target)
}
$lines += '```'
Write-Doc -Name 'ROUTINE_TREE.md' -Lines $lines

$prefixRows = @(
    $edgeGroups |
    ForEach-Object {
        [pscustomobject]@{
            Source = Get-Prefix $_.Source
            Target = Get-Prefix $_.Target
            Count = $_.Count
        }
    } |
    Group-Object Source, Target |
    ForEach-Object {
        [pscustomobject]@{
            Source = $_.Group[0].Source
            Target = $_.Group[0].Target
            Count = ($_.Group | Measure-Object Count -Sum).Sum
        }
    } |
    Sort-Object -Property @{Expression='Count';Descending=$true}, Source, Target
)

$lines = @('# R-YORS Routine Class Diagram') + $header
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($prefixRows | Select-Object -First 120)) {
    $lines += ('    P_{0}[{0}] -->|{1}| P_{2}[{2}]' -f $row.Source, $row.Count, $row.Target)
}
$lines += '```'
Write-Doc -Name 'ROUTINE_CLASS_DIAGRAM.md' -Lines $lines

$lines = @('# R-YORS Routine Graph Insights') + $header
$lines += '## Summary'
$lines += ''
$lines += "- Source files scanned: $($files.Count)"
$lines += "- Routine headers: $($routines.Count)"
$lines += "- XDEF declarations: $($xdefs.Count)"
$lines += "- XREF declarations: $($xrefs.Count)"
$lines += "- Raw direct call sites: $($edges.Count)"
$lines += "- Unique direct edges: $($edgeGroups.Count)"
$lines += ''
$lines += '## Hot Callees'
$lines += ''
foreach ($g in ($edges | Group-Object Target | Sort-Object -Property @{Expression='Count';Descending=$true}, Name | Select-Object -First 40)) {
    $lines += ('- `{0}`: {1}' -f $g.Name, $g.Count)
}
$lines += ''
$lines += '## Busy Callers'
$lines += ''
foreach ($g in ($edges | Group-Object Source | Sort-Object -Property @{Expression='Count';Descending=$true}, Name | Select-Object -First 40)) {
    $lines += ('- `{0}`: {1}' -f $g.Name, $g.Count)
}
Write-Doc -Name 'ROUTINE_GRAPH_INSIGHTS.md' -Lines $lines

$lines = @('# R-YORS Routine Components') + $header
$lines += '## Prefix Components'
$lines += ''
foreach ($g in ($routines | Group-Object { Get-Prefix $_.Name } | Sort-Object -Property @{Expression='Count';Descending=$true}, Name)) {
    $lines += ('- `{0}`: {1} routine headers' -f $g.Name, $g.Count)
}
$lines += ''
$lines += '## Exported Symbols By Prefix'
$lines += ''
foreach ($g in ($xdefs | Group-Object { Get-Prefix $_.Name } | Sort-Object -Property @{Expression='Count';Descending=$true}, Name)) {
    $lines += ('- `{0}`: {1} XDEF' -f $g.Name, $g.Count)
}
$lines += ''
$lines += '## Imported Symbols By Prefix'
$lines += ''
foreach ($g in ($xrefs | Group-Object { Get-Prefix $_.Name } | Sort-Object -Property @{Expression='Count';Descending=$true}, Name)) {
    $lines += ('- `{0}`: {1} XREF' -f $g.Name, $g.Count)
}
Write-Doc -Name 'ROUTINE_COMPONENTS.md' -Lines $lines

Write-Output ("Generated docs in {0}" -f $outRoot)

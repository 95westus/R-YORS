param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutPath,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$DisplaySource,

    [string]$ReadableMap = ''
)

$ErrorActionPreference = "Stop"

$sourceFull = (Resolve-Path -LiteralPath $SourcePath).Path
$outFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)
$lines = Get-Content -LiteralPath $sourceFull

$labelPattern = '^\s*([A-Za-z_?][A-Za-z0-9_?]*):'
$callPattern = '^\s*(?:[A-Za-z_?][A-Za-z0-9_?]*:\s*)?(JSR|JMP)\s+([A-Za-z_?][A-Za-z0-9_?]*)\b'

$globalLabels = [ordered]@{}
$allLabels = [ordered]@{}
$edges = New-Object System.Collections.Generic.List[object]
$currentGlobal = $null

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $lineNo = $i + 1

    if ($line -match $labelPattern) {
        $label = $matches[1]
        $allLabels[$label] = $true
        if (-not $label.StartsWith('?')) {
            $globalLabels[$label] = $true
            $currentGlobal = $label
        }
    }

    if ($currentGlobal -and $line -match $callPattern) {
        $edges.Add([pscustomobject]@{
            Source = $currentGlobal
            Op = $matches[1].ToUpperInvariant()
            Target = $matches[2]
            Line = $lineNo
            Index = $edges.Count
        })
    }
}

$uniqueEdges = @(
    $edges |
    Group-Object Source, Op, Target |
    ForEach-Object {
        [pscustomobject]@{
            Source = $_.Group[0].Source
            Op = $_.Group[0].Op
            Target = $_.Group[0].Target
            FirstIndex = ($_.Group | Measure-Object Index -Minimum).Minimum
        }
    } |
    Sort-Object Source, FirstIndex
)

$externalTargets = @(
    $edges |
    Select-Object -ExpandProperty Target -Unique |
    Where-Object { -not $allLabels.Contains($_) } |
    Sort-Object
)

$out = New-Object System.Collections.Generic.List[string]
$out.Add("# $Title")
$out.Add('')
$out.Add("Generated-style edge dump for ``$DisplaySource``.")
$out.Add('')
if ($ReadableMap) {
    $out.Add('For the readable subsystem/capability view, see')
    $out.Add("$ReadableMap.")
    $out.Add('')
}
$out.Add('Scope: direct `JSR target` and `JMP target` edges only. Relative branches, fallthrough, data labels, indirect calls, and computed jumps are not included. Source is the nearest preceding global label.')
$out.Add('')
$out.Add('## Summary')
$out.Add('')
$out.Add('```text')
$out.Add(('source file:     {0}' -f $DisplaySource))
$out.Add(('global labels:   {0}' -f $globalLabels.Count))
$out.Add(('raw call sites:  {0}' -f $edges.Count))
$out.Add(('unique edges:    {0}' -f $uniqueEdges.Count))
$out.Add(('external targets:{0}' -f $externalTargets.Count))
$out.Add('```')
$out.Add('')
$out.Add('## External Targets')
$out.Add('')
$out.Add('These targets are not labels in this source file; most are `XREF` providers from sibling ROM modules.')
$out.Add('')
$out.Add('```text')
foreach ($target in $externalTargets) {
    $out.Add($target)
}
$out.Add('```')
$out.Add('')
$out.Add('## Unique Direct Edges By Source Label')
$out.Add('')
$out.Add('Each block is one source label. Indented lines are outgoing direct edges.')
$out.Add('Blank lines are source-level breaks; they do not imply call depth.')
$out.Add('')
$out.Add('```text')
foreach ($group in ($uniqueEdges | Group-Object Source | Sort-Object Name)) {
    $out.Add($group.Name)
    foreach ($edge in ($group.Group | Sort-Object FirstIndex)) {
        $out.Add(('    {0} {1}' -f $edge.Op, $edge.Target))
    }
    $out.Add('')
}
$out.Add('```')
$out.Add('')
$out.Add('## Raw Direct Edge Sites By Source Label')
$out.Add('')
$out.Add('Each line is a direct call/jump site with source line number.')
$out.Add('')
$out.Add('```text')
foreach ($group in ($edges | Group-Object Source | Sort-Object Name)) {
    $out.Add($group.Name)
    foreach ($edge in ($group.Group | Sort-Object Line, Index)) {
        $out.Add(('    {0,5}  {1} {2}' -f $edge.Line, $edge.Op, $edge.Target))
    }
    $out.Add('')
}
$out.Add('```')

$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
[System.IO.File]::WriteAllLines($outFull, $out, [System.Text.Encoding]::ASCII)
Write-Host ("Generated {0}" -f $outFull)

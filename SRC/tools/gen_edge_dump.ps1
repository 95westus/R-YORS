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

function Get-EdgeFamily {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return 'ENTRY / unprefixed'
    }

    $parts = @($Name.ToUpperInvariant() -split '_')
    if ($parts.Count -lt 2) {
        return 'ENTRY / unprefixed'
    }

    if ($parts[0] -eq 'STR8' -and $parts[1] -eq 'CMD' -and $parts.Count -ge 3) {
        return "STR8 CMD / $($parts[2])"
    }

    if ($parts[0] -in @(
        'ASM',
        'CMD',
        'DBG',
        'HIM',
        'HREC',
        'MON',
        'RJOIN',
        'STR8',
        'STR8W',
        'THE'
    )) {
        return "$($parts[0]) / $($parts[1])"
    }

    return $parts[0]
}

function Escape-MermaidLabel {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    $text = $Value -replace '"', "'"
    $text = $text -replace '\[', '('
    $text = $text -replace '\]', ')'
    return $text
}

function Add-MermaidEdgeAtlas {
    param(
        [System.Collections.Generic.List[string]]$Output,
        [object[]]$Rows,
        [string]$AtlasLabel,
        [int]$MaxEdges = 12,
        [int]$MaxFamilies = 12
    )

    $items = @($Rows)
    $Output.Add('## Mermaid Direct-Edge Atlas')
    $Output.Add('')
    if ($items.Count -eq 0) {
        $Output.Add('No direct edges were found in the current source.')
        $Output.Add('')
        return
    }

    $groups = @(
        $items |
        Group-Object -Property { Get-EdgeFamily $_.Source } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Rows = @($_.Group | Sort-Object Source, FirstIndex, Op, Target)
                Count = $_.Count
            }
        } |
        Sort-Object Name
    )

    $Output.Add(
        "Every unique direct edge is present in this atlas. Source routines are " +
        "grouped by command/subsystem stem, then split into independent Mermaid " +
        "panels of at most $MaxEdges edges. The text sections below remain the " +
        'complete audit-oriented evidence.'
    )
    $Output.Add('')

    $overviewCount = [int][Math]::Ceiling(
        $groups.Count / [double]$MaxFamilies
    )
    for ($overview = 0; $overview -lt $overviewCount; $overview++) {
        $overviewGroups = @(
            $groups |
            Select-Object -Skip ($overview * $MaxFamilies) -First $MaxFamilies
        )
        if ($overviewCount -gt 1) {
            $Output.Add(
                "### Family Overview (part $($overview + 1) of $overviewCount)"
            )
            $Output.Add('')
        } else {
            $Output.Add('### Family Overview')
            $Output.Add('')
        }

        $Output.Add('```mermaid')
        $Output.Add('flowchart TD')
        $rootId = "EDGE_ATLAS_ROOT_$overview"
        $rootLabel = Escape-MermaidLabel (
            "$AtlasLabel<br/>$($items.Count) unique edges"
        )
        for ($groupIndex = 0; $groupIndex -lt $overviewGroups.Count; $groupIndex++) {
            $group = $overviewGroups[$groupIndex]
            $familyId = "EDGE_FAMILY_${overview}_$groupIndex"
            $panelCount = [int][Math]::Ceiling(
                $group.Count / [double]$MaxEdges
            )
            $edgeWord = if ($group.Count -eq 1) { 'edge' } else { 'edges' }
            $panelWord = if ($panelCount -eq 1) { 'panel' } else { 'panels' }
            $familyLabel = Escape-MermaidLabel (
                "$($group.Name)<br/>$($group.Count) $edgeWord / " +
                "$panelCount $panelWord"
            )
            $Output.Add(
                ('    {0}["{1}"] --> {2}["{3}"]' -f
                    $rootId,
                    $rootLabel,
                    $familyId,
                    $familyLabel)
            )
        }
        $Output.Add('```')
        $Output.Add('')
    }

    $Output.Add('### Family Detail')
    $Output.Add('')
    foreach ($group in $groups) {
        $Output.Add("#### $($group.Name)")
        $Output.Add('')
        $partCount = [int][Math]::Ceiling(
            $group.Count / [double]$MaxEdges
        )
        for ($part = 0; $part -lt $partCount; $part++) {
            $partRows = @(
                $group.Rows |
                Select-Object -Skip ($part * $MaxEdges) -First $MaxEdges
            )
            if ($partCount -gt 1) {
                $firstSource = $partRows[0].Source
                $lastSource = $partRows[$partRows.Count - 1].Source
                $Output.Add(
                    "Panel $($part + 1) of ${partCount}: " +
                    "``$firstSource`` through ``$lastSource``."
                )
                $Output.Add('')
            }

            $Output.Add('```mermaid')
            $Output.Add('flowchart LR')
            $nodeIds = @{}
            $nextNodeId = 0
            foreach ($edge in $partRows) {
                foreach ($name in @($edge.Source, $edge.Target)) {
                    if (-not $nodeIds.ContainsKey($name)) {
                        $nodeIds[$name] = "N$nextNodeId"
                        $nextNodeId++
                    }
                }
                $sourceId = $nodeIds[$edge.Source]
                $targetId = $nodeIds[$edge.Target]
                $sourceLabel = Escape-MermaidLabel $edge.Source
                $targetLabel = Escape-MermaidLabel $edge.Target
                $opLabel = Escape-MermaidLabel $edge.Op
                $Output.Add(
                    ('    {0}["{1}"] -->|{2}| {3}["{4}"]' -f
                        $sourceId,
                        $sourceLabel,
                        $opLabel,
                        $targetId,
                        $targetLabel)
                )
            }
            $Output.Add('```')
            $Output.Add('')
        }
    }
}

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
Add-MermaidEdgeAtlas `
    -Output $out `
    -Rows $uniqueEdges `
    -AtlasLabel $Title `
    -MaxEdges 12 `
    -MaxFamilies 12
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

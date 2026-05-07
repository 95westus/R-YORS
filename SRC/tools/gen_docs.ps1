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

function Get-DocPath {
    param([string]$Path)
    if ($Path -match '^TEST/apps/himon/(.+)$') { return "HIMON/$($matches[1])" }
    if ($Path -match '^TEST/apps/str8/(.+)$') { return "STR8/$($matches[1])" }
    if ($Path -eq 'TEST/ftdi-backend-debug.asm') { return 'ROM/ftdi-backend-debug.asm' }
    if ($Path -match '^TEST/ftdi/(.+)$') { return "ROM/ftdi/$($matches[1])" }
    if ($Path -match '^TEST/dev/(.+)$') { return "ROM/dev/$($matches[1])" }
    if ($Path -match '^TEST/util/(.+)$') { return "ROM/util/$($matches[1])" }
    return $Path
}

function Get-Prefix {
    param([string]$Name)
    $prefix = 'LOCAL'
    if ($Name -match '^([A-Za-z0-9]+)_') { $prefix = $matches[1].ToUpperInvariant() }
    elseif ($Name -match '^([A-Za-z0-9]+)$') { $prefix = $matches[1].ToUpperInvariant() }
    if ($prefix -eq 'HIMONIA') { return 'HIMON' }
    if ($prefix -eq 'START') { return 'HIMON' }
    if ($prefix -eq 'MAIN') { return 'HIMON' }
    if ($prefix -eq 'L') { return 'LOAD' }
    return $prefix
}

function Get-DisplayName {
    param([string]$Name)
    if ($Name -match '^HIMONIA_ABI_(.+)$') { return "HIMON_FIXED_$($matches[1])" }
    return $Name
}

function Test-HashInvolvedName {
    param([string]$Name)
    $display = Get-DisplayName $Name
    if ($display -match '^CMD_HASH') { return $true }
    if ($display -match '^FNV1A_') { return $true }
    if ($display -match '^MATH_.*HASH') { return $true }
    if ($display -in @('CMD_DISPATCH_HASH', 'CMD_SAVE_HASH', 'MON_PRINT_HASH')) { return $true }
    return $false
}

function Mermaid-Id {
    param([string]$Name)
    return 'N_' + ($Name -replace '[^A-Za-z0-9_]', '_')
}

function Mermaid-Prefix-Id {
    param([string]$Name)
    return 'P_' + ($Name -replace '[^A-Za-z0-9_]', '_')
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

$operationalSourceSpecs = @(
    'STASH/ftdi/*.asm',
    'SESH/ftdi/*.asm',
    'TEST/ftdi-backend-debug.asm',
    'TEST/ftdi/*.asm',
    'TEST/dev/*.asm',
    'TEST/util/*.asm',
    'TEST/apps/himon/himon.asm',
    'TEST/apps/himon/*.inc',
    'TEST/apps/himon/fnv1a-fold.asm',
    'TEST/apps/str8/str8.asm'
)

$excludedOperationalSources = @(
    'TEST/util/util-test.asm',
    'TEST/apps/himon/fnv1a-hbstr.asm'
)

$fileMap = @{}
foreach ($spec in $operationalSourceSpecs) {
    $dirPart = [System.IO.Path]::GetDirectoryName($spec)
    $namePart = [System.IO.Path]::GetFileName($spec)
    $dir = Join-Path $root $dirPart
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $matches = @(Get-ChildItem -LiteralPath $dir -Filter $namePart -File -ErrorAction SilentlyContinue)
    foreach ($file in $matches) {
        $rel = Get-RelPath -Root $root -Path $file.FullName
        if ($excludedOperationalSources -notcontains $rel) {
            $fileMap[$file.FullName] = $file
        }
    }
}

$files = @($fileMap.Values | Sort-Object FullName)

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
$labels = New-Object System.Collections.Generic.List[object]
$xdefs = New-Object System.Collections.Generic.List[object]
$xrefs = New-Object System.Collections.Generic.List[object]
$edges = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $rel = Get-DocPath -Path (Get-RelPath -Root $root -Path $file.FullName)
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
            $labels.Add([pscustomobject]@{ Name = $current; File = $rel; Line = $lineNo })
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

$himonTreeEdges = @(
    $edges |
    Where-Object {
        $_.File -eq 'HIMON/himon.asm' -or
        $_.File -like 'HIMON/*.inc'
    } |
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
    '',
    'Scope: operational HIMON/STR8 source plus ROM support; excludes harnesses, proof apps, games, ACIA/PIA, and local generated-language images.',
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

$lines = @('# R-YORS HIMON Routine Tree') + $header
$lines += 'Tree scope: current HIMON source only (`HIMON/himon.asm` and HIMON include files).'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in ($himonTreeEdges | Select-Object -First 220)) {
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Id (Get-DisplayName $edge.Source)), (Get-DisplayName $edge.Source), $edge.Count, (Mermaid-Id (Get-DisplayName $edge.Target)), (Get-DisplayName $edge.Target))
}
$lines += '```'
Write-Doc -Name 'HIMON_ROUTINE_TREE.md' -Lines $lines

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
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Prefix-Id $row.Source), $row.Source, $row.Count, (Mermaid-Prefix-Id $row.Target), $row.Target)
}
$lines += '```'
Write-Doc -Name 'ROUTINE_CLASS_DIAGRAM.md' -Lines $lines

$prefixRoutineCounts = @{}
foreach ($g in ($routines | Group-Object { Get-Prefix $_.Name })) {
    $prefixRoutineCounts[$g.Name] = $g.Count
}

$lines = @('# R-YORS Routine Prefix Map') + $header
$lines += 'Prefix map over the operational source set. Node counts are routine headers; edge counts are direct `JSR`/`JMP` sites grouped by prefix.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($prefixRows | Select-Object -First 160)) {
    $sourceCount = if ($prefixRoutineCounts.ContainsKey($row.Source)) { $prefixRoutineCounts[$row.Source] } else { 0 }
    $targetCount = if ($prefixRoutineCounts.ContainsKey($row.Target)) { $prefixRoutineCounts[$row.Target] } else { 0 }
    $lines += ('    {0}["{1}<br/>{2} routines"] -->|{3}| {4}["{5}<br/>{6} routines"]' -f (Mermaid-Prefix-Id $row.Source), $row.Source, $sourceCount, $row.Count, (Mermaid-Prefix-Id $row.Target), $row.Target, $targetCount)
}
$lines += '```'
Write-Doc -Name 'ROUTINE_PREFIX_MAP.md' -Lines $lines

$himonEdges = @(
    $edges |
    Where-Object {
        $_.File -eq 'HIMON/himon.asm' -or
        $_.File -like 'HIMON/*.inc'
    }
)

$himonPrefixRows = @(
    $himonEdges |
    ForEach-Object {
        [pscustomobject]@{
            Source = Get-Prefix $_.Source
            Target = Get-Prefix $_.Target
            Count = 1
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

$lines = @('# R-YORS HIMON Support Map') + $header
$lines += 'HIMON-only dependency map. This rolls current compatibility labels into HIMON and shows which support layers the monitor leans on.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($himonPrefixRows | Select-Object -First 120)) {
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Prefix-Id $row.Source), $row.Source, $row.Count, (Mermaid-Prefix-Id $row.Target), $row.Target)
}
$lines += '```'
Write-Doc -Name 'HIMON_SUPPORT_MAP.md' -Lines $lines

$himonCommandPrefixes = @('HIMON', 'MON', 'CMD', 'CMDP', 'LOAD', 'ASM', 'DIS', 'DBG', 'FNV1A', 'MATH')
$himonCommandEdges = @(
    $himonTreeEdges |
    Where-Object {
        $himonCommandPrefixes -contains (Get-Prefix $_.Source) -or
        $himonCommandPrefixes -contains (Get-Prefix $_.Target)
    } |
    Select-Object -First 180
)

$lines = @('# R-YORS HIMON Command Map') + $header
$lines += 'HIMON command/debug/load/ASM call map, limited to direct edges and compacted for readability.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in $himonCommandEdges) {
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Id (Get-DisplayName $edge.Source)), (Get-DisplayName $edge.Source), $edge.Count, (Mermaid-Id (Get-DisplayName $edge.Target)), (Get-DisplayName $edge.Target))
}
$lines += '```'
Write-Doc -Name 'HIMON_COMMAND_MAP.md' -Lines $lines

$hashSourceFiles = @('HIMON/himon.asm', 'HIMON/fnv1a-fold.asm')
$hashEdges = @(
    $edges |
    Where-Object {
        $hashSourceFiles -contains $_.File -and
        ((Test-HashInvolvedName $_.Source) -or (Test-HashInvolvedName $_.Target))
    } |
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

$hashLabels = @(
    $labels |
    Where-Object {
        $hashSourceFiles -contains $_.File -and (Test-HashInvolvedName $_.Name)
    } |
    Sort-Object File, Line, Name
)

$hashRoutineHeaders = @(
    $routines |
    Where-Object {
        $hashSourceFiles -contains $_.File -and (Test-HashInvolvedName $_.Name)
    } |
    Sort-Object File, Line, Name
)

$hashEdgeNodeNames = @($hashEdges | ForEach-Object { $_.Source; $_.Target } | Sort-Object -Unique)
$hashIsolatedLabels = @($hashLabels | Where-Object { $hashEdgeNodeNames -notcontains $_.Name })
$hashAllLabelNames = @($hashLabels | ForEach-Object { $_.Name } | Sort-Object -Unique)

$lines = @('# R-YORS Hash Routine Map') + $header
$lines += 'Scope: current source-derived hash path. This includes `CMD_HASH*`, `FNV1A_*`, `MATH_*HASH*`, `MON_PRINT_HASH`, `CMD_SAVE_HASH`, and `CMD_DISPATCH_HASH` labels plus their direct call neighbors. Routine header `[HASH:...]` IDs alone do not make a routine part of this map.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in ($hashEdges | Select-Object -First 180)) {
    $lines += ('    {0}[{1}] -->|{2}| {3}[{4}]' -f (Mermaid-Id (Get-DisplayName $edge.Source)), (Get-DisplayName $edge.Source), $edge.Count, (Mermaid-Id (Get-DisplayName $edge.Target)), (Get-DisplayName $edge.Target))
}
foreach ($label in $hashIsolatedLabels) {
    $lines += ('    {0}[{1}]' -f (Mermaid-Id (Get-DisplayName $label.Name)), (Get-DisplayName $label.Name))
}
$lines += '```'
$lines += ''
$lines += '## Hash Labels'
$lines += ''
foreach ($label in $hashLabels) {
    $lines += ('- `{0}`: {1}:{2}' -f (Get-DisplayName $label.Name), $label.File, $label.Line)
}
$lines += ''
$lines += '## Routine Headers'
$lines += ''
foreach ($r in $hashRoutineHeaders) {
    $h = if ($r.Hash) { " [HASH:$($r.Hash)]" } else { '' }
    $purpose = if ($r.Purpose) { " - $($r.Purpose)" } else { '' }
    $lines += ('- `{0}`{1}: {2}:{3}{4}' -f (Get-DisplayName $r.Name), $h, $r.File, $r.Line, $purpose)
}
if ($hashRoutineHeaders.Count -eq 0) {
    $lines += '- None found in current source scope.'
}
$lines += ''
$lines += '## Direct Edges'
$lines += ''
foreach ($edge in $hashEdges) {
    $lines += ('- `{0}` -> `{1}`: {2}' -f (Get-DisplayName $edge.Source), (Get-DisplayName $edge.Target), $edge.Count)
}
if ($hashEdges.Count -eq 0) {
    $lines += '- None found in current source scope.'
}
Write-Doc -Name 'HASH_ROUTINE_MAP.md' -Lines $lines

$cmdFlowNames = @(
    'MAIN_LOOP',
    'MAIN_HAVE_LINE',
    'CMD_HASH_TOKEN',
    'CMD_HASH_TOKEN_LOOP',
    'CMD_HASH_TOKEN_DONE',
    'FNV1A_INIT',
    'FNV1A_UPDATE_A',
    'CMD_SAVE_HASH',
    'CMD_DISPATCH_HASH',
    'CMD_DISPATCH_SCAN_LOOP',
    'CMD_HASH_SCAN_INIT',
    'CMD_HASH_SCAN_NEXT_RECORD',
    'CMD_HASH_SCAN_END',
    'CMD_HASH_IS_RECORD',
    'CMD_HASH_RECORD_MATCH',
    'CMD_HASH_RECORD_IS_EXEC',
    'CMD_HASH_RECORD_ENTRY',
    'CMD_SAVE_ENTRY',
    'CMD_EXEC_ADDR',
    'CMD_CALL_ADDR',
    'CMD_DISPATCH_SCAN_NEXT',
    'CMD_DISPATCH_SCAN_MISS',
    'MON_PRINT_HASH',
    'MON_PRINT_RET_AND_REGS',
    'CMD_UNKNOWN'
)

$cmdFlowLabels = @()
foreach ($name in $cmdFlowNames) {
    $hit = $labels |
        Where-Object { $_.File -eq 'HIMON/himon.asm' -and $_.Name -eq $name } |
        Select-Object -First 1
    if ($hit) {
        $cmdFlowLabels += $hit
    } else {
        $cmdFlowLabels += [pscustomobject]@{ Name = $name; File = 'HIMON/himon.asm'; Line = '' }
    }
}

function Format-CmdFlow-Node {
    param(
        [string]$Name,
        [string]$Text
    )
    $line = (
        $cmdFlowLabels |
        Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1
    ).Line
    if ($line) { return ('{0}<br/>{1}:{2}' -f $Text, $Name, $line) }
    return ('{0}<br/>{1}' -f $Text, $Name)
}

$lines = @('# R-YORS Command Flow Map') + $header
$lines += 'Scope: current HIMON command dispatch/resolve/run/return flow. This is a source-derived guide map for the hashed command path in `HIMON/himon.asm`, not a full call graph of every command body.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart TD'
$lines += ('    LOOP["{0}"] --> READ["read prompt line<br/>HIM_READ_LINE_ECHO_UPPER"]' -f (Format-CmdFlow-Node 'MAIN_LOOP' 'prompt and wait'))
$lines += ('    READ --> HAVE["{0}"]' -f (Format-CmdFlow-Node 'MAIN_HAVE_LINE' 'line accepted'))
$lines += '    READ -->|abort or empty| LOOP'
$lines += ('    HAVE --> PREP["set CMDP_PTR to CMD_BUF<br/>skip spaces / peek token"]')
$lines += ('    PREP --> HASH["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_TOKEN' 'hash command token'))
$lines += ('    HASH --> FNVINIT["{0}"]' -f (Format-CmdFlow-Node 'FNV1A_INIT' 'seed FNV-1a'))
$lines += ('    HASH --> HASHLOOP["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_TOKEN_LOOP' 'walk token bytes'))
$lines += ('    HASHLOOP --> UPDATE["{0}"]' -f (Format-CmdFlow-Node 'FNV1A_UPDATE_A' 'update hash with byte'))
$lines += '    UPDATE --> HASHLOOP'
$lines += ('    HASHLOOP --> DONE["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_TOKEN_DONE' 'restore token pointer'))
$lines += ('    DONE --> SAVEHASH["{0}"]' -f (Format-CmdFlow-Node 'CMD_SAVE_HASH' 'save hash to exec state'))
$lines += ('    SAVEHASH --> DISPATCH["{0}"]' -f (Format-CmdFlow-Node 'CMD_DISPATCH_HASH' 'dispatch by hash'))
$lines += ('    DISPATCH --> SCANINIT["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_SCAN_INIT' 'start catalog scan'))
$lines += ('    SCANINIT --> SCANLOOP["{0}"]' -f (Format-CmdFlow-Node 'CMD_DISPATCH_SCAN_LOOP' 'scan records'))
$lines += ('    SCANLOOP --> NEXTREC["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_SCAN_NEXT_RECORD' 'find next FNV record'))
$lines += ('    NEXTREC --> ENDCHK["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_SCAN_END' 'check scan limit'))
$lines += ('    NEXTREC --> ISREC["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_IS_RECORD' 'test FNV signature'))
$lines += ('    NEXTREC -->|none| MISS["{0}"]' -f (Format-CmdFlow-Node 'CMD_DISPATCH_SCAN_MISS' 'no record found'))
$lines += ('    ISREC --> MATCH["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_RECORD_MATCH' 'compare hash0..3'))
$lines += ('    MATCH -->|no| ADV["{0}"]' -f (Format-CmdFlow-Node 'CMD_DISPATCH_SCAN_NEXT' 'advance scan'))
$lines += ('    ADV --> SCANLOOP')
$lines += ('    MATCH -->|yes| EXECOK["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_RECORD_IS_EXEC' 'kind is executable?'))
$lines += '    EXECOK -->|no| ADV'
$lines += ('    EXECOK -->|yes| ENTRY["{0}"]' -f (Format-CmdFlow-Node 'CMD_HASH_RECORD_ENTRY' 'entry = record+8'))
$lines += ('    ENTRY --> SAVEENTRY["{0}"]' -f (Format-CmdFlow-Node 'CMD_SAVE_ENTRY' 'save entry'))
$lines += ('    SAVEENTRY --> RUN["{0}"]' -f (Format-CmdFlow-Node 'CMD_EXEC_ADDR' 'run command and capture return'))
$lines += ('    RUN --> CALL["{0}"]' -f (Format-CmdFlow-Node 'CMD_CALL_ADDR' 'jump indirect to command'))
$lines += '    CALL --> BODY["command body<br/>CMD_D / CMD_L / CMD_A / ..."]'
$lines += '    BODY -->|RTS| RUN'
$lines += ('    RUN --> RETPRINT["{0}"]' -f (Format-CmdFlow-Node 'MON_PRINT_RET_AND_REGS' 'print return/register state'))
$lines += '    RETPRINT --> LOOP'
$lines += ('    MISS --> PRHASH["{0}"]' -f (Format-CmdFlow-Node 'MON_PRINT_HASH' 'print unresolved hash'))
$lines += '    PRHASH --> LOOP'
$lines += '```'
$lines += ''
$lines += '## Return Contract'
$lines += ''
$lines += '- The resolved command entry is the current inline HIMON command body at `record+8` for `kind=$00` records.'
$lines += '- `CMD_EXEC_ADDR` calls `CMD_CALL_ADDR`; `CMD_CALL_ADDR` performs `JMP (CMDP_ADDR_LO)` into the command body.'
$lines += '- The command body returns with `RTS`, landing back inside `CMD_EXEC_ADDR` after the original `JSR CMD_CALL_ADDR`.'
$lines += '- `CMD_EXEC_ADDR` captures A/X/Y/P/S and the saved command entry, calls `MON_PRINT_RET_AND_REGS`, then returns to `CMD_DISPATCH_HASH`, which jumps back to `MAIN_LOOP`.'
$lines += '- If the scan misses, HIMON prints the unresolved hash and returns to `MAIN_LOOP` without entering `CMD_UNKNOWN`.'
$lines += ''
$lines += '## Source Labels'
$lines += ''
foreach ($label in $cmdFlowLabels) {
    if ($label.Line) {
        $lines += ('- `{0}`: {1}:{2}' -f (Get-DisplayName $label.Name), $label.File, $label.Line)
    } else {
        $lines += ('- `{0}`: not present in current source scope' -f (Get-DisplayName $label.Name))
    }
}
Write-Doc -Name 'CMD_FLOW_MAP.md' -Lines $lines

$interruptNames = @(
    'START',
    'SYS_INIT',
    'SYS_VEC_INIT',
    'SYS_VEC_ENTRY_RESET',
    'SYS_VEC_ENTRY_NMI',
    'SYS_VEC_ENTRY_IRQ_MASTER',
    'SYS_VEC_IRQ_MASTER_NONBRK',
    'SYS_VEC_SET_RESET_XY',
    'SYS_VEC_SET_NMI_XY',
    'SYS_VEC_SET_IRQ_BRK_XY',
    'SYS_VEC_SET_IRQ_NONBRK_XY',
    'SYS_VEC_DEFAULT_RESET',
    'SYS_VEC_DEFAULT_NMI',
    'SYS_VEC_DEFAULT_IRQ_BRK',
    'SYS_VEC_DEFAULT_IRQ_NONBRK',
    'MON_REENTER',
    'MON_START_INIT',
    'MON_NMI_TRAP',
    'MON_BRK_TRAP',
    'MON_BRK_TRAP_NORMAL',
    'MON_IRQ_TRAP',
    'MON_CTX_RESUME_RTI',
    'DBG_HANDLE_BRK',
    'DBG_HANDLE_BRK_HIT',
    'DBG_HANDLE_BRK_NONE',
    'DBG_STEP_ONCE',
    'CMD_X',
    'CMD_S'
)

$interruptLabelFiles = @(
    'HIMON/himon.asm',
    'HIMON/himon-debug.inc',
    'ROM/dev/dev-adapter-core.asm',
    'ROM/dev/dev-adapter-vectors.asm'
)

$interruptLabels = @()
foreach ($name in $interruptNames) {
    $hit = $labels |
        Where-Object { $interruptLabelFiles -contains $_.File -and $_.Name -eq $name } |
        Select-Object -First 1
    if ($hit) {
        $interruptLabels += $hit
    } else {
        $interruptLabels += [pscustomobject]@{ Name = $name; File = ''; Line = '' }
    }
}

function Format-Interrupt-Node {
    param(
        [string]$Name,
        [string]$Text
    )
    $hit = $interruptLabels |
        Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1
    if ($hit -and $hit.Line) { return ('{0}<br/>{1}:{2}' -f $Text, $Name, $hit.Line) }
    return ('{0}<br/>{1}' -f $Text, $Name)
}

$interruptRoutineHeaders = @(
    $routines |
    Where-Object {
        $interruptLabelFiles -contains $_.File -and
        (
            $_.Name -like 'SYS_VEC_*' -or
            $_.Name -in @('SYS_INIT')
        )
    } |
    Sort-Object File, Line, Name
)

$lines = @('# R-YORS Interrupt Vector Map') + $header
$lines += 'Scope: current source-derived interrupt, vector trampoline, trap, resume, and on-the-fly vector patching map. This describes current HIMON plus the SYS vector layer; future STR8 vector ownership is design direction, not the current ROM behavior.'
$lines += ''
$lines += '## Current Hardware Vector Policy'
$lines += ''
$lines += '```text'
$lines += '$FFFA-$FFFB  NMI      -> SYS_VEC_ENTRY_NMI'
$lines += '$FFFC-$FFFD  RESET    -> START'
$lines += '$FFFE-$FFFF  IRQ/BRK  -> SYS_VEC_ENTRY_IRQ_MASTER'
$lines += ''
$lines += '$7EF8-$7EF9  VEC_RESET target cell'
$lines += '$7EFA-$7EFB  VEC_NMI target cell'
$lines += '$7EFC-$7EFD  VEC_IRQ_BRK target cell'
$lines += '$7EFE-$7EFF  VEC_IRQ_NONBRK target cell'
$lines += '```'
$lines += ''
$lines += '## Flow'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart TD'
$lines += '    RESETV["$FFFC-$FFFD<br/>RESET vector"] --> STARTN["' + (Format-Interrupt-Node 'START' 'current ROM reset entry') + '"]'
$lines += '    STARTN --> INIT["' + (Format-Interrupt-Node 'MON_START_INIT' 'monitor init / re-entry setup') + '"]'
$lines += '    INIT --> SYSINIT["' + (Format-Interrupt-Node 'SYS_INIT' 'system init') + '"]'
$lines += '    SYSINIT --> VECINIT["' + (Format-Interrupt-Node 'SYS_VEC_INIT' 'seed safe RAM vector defaults') + '"]'
$lines += '    VECINIT --> DEFNMI["' + (Format-Interrupt-Node 'SYS_VEC_DEFAULT_NMI' 'default NMI snapshot then RTI') + '"]'
$lines += '    VECINIT --> DEFBRK["' + (Format-Interrupt-Node 'SYS_VEC_DEFAULT_IRQ_BRK' 'default BRK RTI') + '"]'
$lines += '    VECINIT --> DEFIRQ["' + (Format-Interrupt-Node 'SYS_VEC_DEFAULT_IRQ_NONBRK' 'default IRQ RTI') + '"]'
$lines += ''
$lines += '    INIT --> SETNMI["' + (Format-Interrupt-Node 'SYS_VEC_SET_NMI_XY' 'patch NMI RAM vector') + '"]'
$lines += '    INIT --> SETBRK["' + (Format-Interrupt-Node 'SYS_VEC_SET_IRQ_BRK_XY' 'patch BRK RAM vector') + '"]'
$lines += '    INIT --> SETIRQ["' + (Format-Interrupt-Node 'SYS_VEC_SET_IRQ_NONBRK_XY' 'patch IRQ RAM vector') + '"]'
$lines += '    SETNMI --> VECNMI["$7EFA-$7EFB<br/>VEC_NMI = MON_NMI_TRAP"]'
$lines += '    SETBRK --> VECBRK["$7EFC-$7EFD<br/>VEC_IRQ_BRK = MON_BRK_TRAP"]'
$lines += '    SETIRQ --> VECIRQ["$7EFE-$7EFF<br/>VEC_IRQ_NONBRK = MON_IRQ_TRAP"]'
$lines += ''
$lines += '    NMIV["$FFFA-$FFFB<br/>NMI vector"] --> NMIENTRY["' + (Format-Interrupt-Node 'SYS_VEC_ENTRY_NMI' 'NMI trampoline') + '"]'
$lines += '    NMIENTRY --> VECNMI'
$lines += '    VECNMI --> NMITRAP["' + (Format-Interrupt-Node 'MON_NMI_TRAP' 'save NMI context') + '"]'
$lines += '    NMITRAP --> REENTER["' + (Format-Interrupt-Node 'MON_REENTER' 'reset stack and re-enter monitor') + '"]'
$lines += '    REENTER --> INIT'
$lines += ''
$lines += '    IRQV["$FFFE-$FFFF<br/>IRQ/BRK vector"] --> IRQMASTER["' + (Format-Interrupt-Node 'SYS_VEC_ENTRY_IRQ_MASTER' 'IRQ master trampoline') + '"]'
$lines += '    IRQMASTER --> SPLIT["inspect stacked P bit 4<br/>BRK flag?"]'
$lines += '    SPLIT -->|BRK| VECBRK'
$lines += '    SPLIT -->|IRQ| VECIRQ'
$lines += '    VECBRK --> BRKTRAP["' + (Format-Interrupt-Node 'MON_BRK_TRAP' 'save BRK context') + '"]'
$lines += '    BRKTRAP --> DBGBRK["' + (Format-Interrupt-Node 'DBG_HANDLE_BRK' 'breakpoint / step handler') + '"]'
$lines += '    DBGBRK -->|breakpoint hit| REENTER'
$lines += '    DBGBRK -->|plain BRK| BRKNORMAL["' + (Format-Interrupt-Node 'MON_BRK_TRAP_NORMAL' 'capture BRK signature') + '"]'
$lines += '    BRKNORMAL --> REENTER'
$lines += '    VECIRQ --> IRQTRAP["' + (Format-Interrupt-Node 'MON_IRQ_TRAP' 'current IRQ owner') + '"]'
$lines += '    IRQTRAP --> RTIIRQ["RTI"]'
$lines += ''
$lines += '    CMDX["' + (Format-Interrupt-Node 'CMD_X' 'resume command') + '"] --> RESUME["' + (Format-Interrupt-Node 'MON_CTX_RESUME_RTI' 'rebuild stack frame') + '"]'
$lines += '    CMDS["' + (Format-Interrupt-Node 'CMD_S' 'single-step command') + '"] --> STEP["' + (Format-Interrupt-Node 'DBG_STEP_ONCE' 'patch temporary BRK') + '"]'
$lines += '    STEP --> RESUME'
$lines += '    RESUME --> RTIRES["RTI to trapped context"]'
$lines += '```'
$lines += ''
$lines += '## On-The-Fly Patch Contract'
$lines += ''
$lines += '- `SYS_VEC_SET_*_XY` takes `X/Y = target low/high` and patches the matching RAM vector cell.'
$lines += '- The patch routines use `PHP`, `SEI`, write low/high bytes, then `PLP`; this makes the write atomic against normal IRQ arrival and restores the caller flags.'
$lines += '- `SEI` does not mask NMI. Do not patch the NMI target while an NMI can be asserted unless the board/system policy makes that safe.'
$lines += '- `SYS_VEC_ENTRY_IRQ_MASTER` preserves interrupted A/X while it checks stacked status bit 4 to split BRK from non-BRK IRQ.'
$lines += '- Current HIMON installs `MON_NMI_TRAP`, `MON_BRK_TRAP`, and `MON_IRQ_TRAP` during `MON_START_INIT` after `SYS_INIT` seeds safe defaults.'
$lines += '- Current non-BRK IRQ handling is intentionally tiny: `MON_IRQ_TRAP` just `RTI`s until a real IRQ owner patches the non-BRK vector.'
$lines += ''
$lines += '## Source Labels'
$lines += ''
foreach ($label in $interruptLabels) {
    if ($label.Line) {
        $lines += ('- `{0}`: {1}:{2}' -f (Get-DisplayName $label.Name), $label.File, $label.Line)
    } else {
        $lines += ('- `{0}`: not present in current source scope' -f (Get-DisplayName $label.Name))
    }
}
$lines += ''
$lines += '## Routine Headers'
$lines += ''
foreach ($r in $interruptRoutineHeaders) {
    $h = if ($r.Hash) { " [HASH:$($r.Hash)]" } else { '' }
    $purpose = if ($r.Purpose) { " - $($r.Purpose)" } else { '' }
    $lines += ('- `{0}`{1}: {2}:{3}{4}' -f (Get-DisplayName $r.Name), $h, $r.File, $r.Line, $purpose)
}
if ($interruptRoutineHeaders.Count -eq 0) {
    $lines += '- None found in current source scope.'
}
Write-Doc -Name 'INTERRUPT_VECTOR_MAP.md' -Lines $lines

$lines = @('# R-YORS Map Of Maps') + $header
$lines += 'Scope: atlas for map-shaped R-YORS documentation. Guide maps are hand-maintained design/navigation maps; generated maps are source-derived and refreshed by `make -C SRC docs`.'
$lines += ''
$lines += '## Quick Choice'
$lines += ''
$lines += '| Need | Open | Why |'
$lines += '| --- | --- | --- |'
$lines += '| Start reading | [DOC/INDEX.md](../INDEX.md), [GUIDES/INDEX.md](../GUIDES/INDEX.md), [GUIDES/TOC.md](../GUIDES/TOC.md) | Entry points and reading order. |'
$lines += '| See where documents fit | [GUIDES/MAP.md](../GUIDES/MAP.md) | Hand-maintained guide/system map. |'
$lines += '| Check vocabulary before naming something | [GUIDES/GLOSSARY.md](../GUIDES/GLOSSARY.md) | Project terminology contract. |'
$lines += '| Check settled calls | [GUIDES/DECISIONS.md](../GUIDES/DECISIONS.md) | Decisions that should not reopen accidentally. |'
$lines += '| Explore unsettled design thinking | [GUIDES/QCC.md](../GUIDES/QCC.md) | Questions, Comments, Concerns index. |'
$lines += '| Understand memory and flash ranges | [GUIDES/MEMORY_MAP.md](../GUIDES/MEMORY_MAP.md) | Current RAM/ROM/flash ownership. |'
$lines += '| Understand hash meanings | [GUIDES/HASH_MAP.md](../GUIDES/HASH_MAP.md) | Hash concepts, widths, records, and catalog direction. |'
$lines += '| Understand HIMON subsystems | [GUIDES/HIMON_MAP.md](../GUIDES/HIMON_MAP.md) | Curated monitor capability and subsystem maps. |'
$lines += '| Understand command dispatch flow | [CMD_FLOW_MAP.md](./CMD_FLOW_MAP.md) | Prompt, hash, resolve, run, return. |'
$lines += '| Understand interrupts and vector patching | [INTERRUPT_VECTOR_MAP.md](./INTERRUPT_VECTOR_MAP.md) | Reset/NMI/IRQ/BRK trampolines, RAM vectors, traps, and `RTI` resume. |'
$lines += '| See hash-involved source labels | [HASH_ROUTINE_MAP.md](./HASH_ROUTINE_MAP.md) | `CMD_HASH*`, `FNV1A_*`, and related edges. |'
$lines += '| See command/debug/load/ASM calls | [HIMON_COMMAND_MAP.md](./HIMON_COMMAND_MAP.md) | Compact source-derived HIMON command map. |'
$lines += '| See whole HIMON call tree | [HIMON_ROUTINE_TREE.md](./HIMON_ROUTINE_TREE.md) | Current HIMON source-only direct edge tree. |'
$lines += '| See support-layer dependencies | [HIMON_SUPPORT_MAP.md](./HIMON_SUPPORT_MAP.md) | HIMON-only prefix dependency map. |'
$lines += '| See all operational prefix groups | [ROUTINE_PREFIX_MAP.md](./ROUTINE_PREFIX_MAP.md) | Operational source prefix map with counts. |'
$lines += '| See class-level call shape | [ROUTINE_CLASS_DIAGRAM.md](./ROUTINE_CLASS_DIAGRAM.md) | Compact prefix/class edge diagram. |'
$lines += '| See routine inventory and contracts | [CALL_ORDER.md](./CALL_ORDER.md), [ROUTINE_CONTRACTS.md](./ROUTINE_CONTRACTS.md) | Source order and routine contracts. |'
$lines += '| See graph statistics | [ROUTINE_GRAPH_INSIGHTS.md](./ROUTINE_GRAPH_INSIGHTS.md), [ROUTINE_COMPONENTS.md](./ROUTINE_COMPONENTS.md) | Hot callees, busy callers, component counts. |'
$lines += ''
$lines += '## Map Families'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart TD'
$lines += '    MOM[MAP_OF_MAPS] --> ENTRY[DOC/INDEX]'
$lines += '    ENTRY --> GIDX[GUIDES/INDEX]'
$lines += '    GIDX --> TOC[GUIDES/TOC]'
$lines += '    GIDX --> GMAP[GUIDES/MAP]'
$lines += ''
$lines += '    MOM --> GUIDE[Hand-maintained guide maps]'
$lines += '    GUIDE --> GMAP'
$lines += '    GUIDE --> GLOSS[GUIDES/GLOSSARY]'
$lines += '    GUIDE --> DEC[GUIDES/DECISIONS]'
$lines += '    GUIDE --> QCC[GUIDES/QCC]'
$lines += '    GUIDE --> MEM[GUIDES/MEMORY_MAP]'
$lines += '    GUIDE --> HASH[GUIDES/HASH_MAP]'
$lines += '    GUIDE --> HIMON[GUIDES/HIMON_MAP]'
$lines += '    GUIDE --> STR8[GUIDES/STR8]'
$lines += '    GUIDE --> ASM[GUIDES/HASHED_ASM]'
$lines += ''
$lines += '    MOM --> GEN[Generated source maps]'
$lines += '    GEN --> CALL[CALL_ORDER]'
$lines += '    GEN --> CONTRACTS[ROUTINE_CONTRACTS]'
$lines += '    GEN --> TREE[HIMON_ROUTINE_TREE]'
$lines += '    GEN --> FLOW[CMD_FLOW_MAP]'
$lines += '    GEN --> IVEC[INTERRUPT_VECTOR_MAP]'
$lines += '    GEN --> HRASH[HASH_ROUTINE_MAP]'
$lines += '    GEN --> HCOMMAND[HIMON_COMMAND_MAP]'
$lines += '    GEN --> HSUPPORT[HIMON_SUPPORT_MAP]'
$lines += '    GEN --> PREFIX[ROUTINE_PREFIX_MAP]'
$lines += '    GEN --> CLASS[ROUTINE_CLASS_DIAGRAM]'
$lines += '    GEN --> INSIGHTS[ROUTINE_GRAPH_INSIGHTS]'
$lines += '    GEN --> COMPONENTS[ROUTINE_COMPONENTS]'
$lines += ''
$lines += '    HASH --> HRASH'
$lines += '    HIMON --> FLOW'
$lines += '    HIMON --> IVEC'
$lines += '    MEM --> IVEC'
$lines += '    HIMON --> HCOMMAND'
$lines += '    FLOW --> HRASH'
$lines += '    TREE --> HCOMMAND'
$lines += '    PREFIX --> CLASS'
$lines += '    COMPONENTS --> PREFIX'
$lines += '```'
$lines += ''
$lines += '## Freshness'
$lines += ''
$lines += '- Generated maps are refreshed by `make -C SRC docs`.'
$lines += '- Individual generated maps can be refreshed with targets such as `make -C SRC cmd-flow-map`, `make -C SRC hash-routine-map`, or `make -C SRC routine-prefix-map`.'
$lines += '- Guide maps are design/reference documents. They should be updated when terminology, policy, or document roles change.'
$lines += ''
$lines += '## Boundaries'
$lines += ''
$lines += '- Generated source maps use the operational HIMON/STR8 source set and ROM support code.'
$lines += '- Legacy demos, harnesses, games, ACIA/PIA, and local generated-language images stay out of generated operational maps.'
$lines += '- A map may mention a compatibility label when the source still uses it, but map-facing vocabulary should prefer current HIMON/STR8/R-YORS terms.'
Write-Doc -Name 'MAP_OF_MAPS.md' -Lines $lines

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

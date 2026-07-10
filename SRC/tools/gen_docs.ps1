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
    if ($Path -eq 'TESTS/ftdi-backend-debug.asm') { return 'ROM/ftdi-backend-debug.asm' }
    if ($Path -match '^LIB/ftdi/(.+)$') { return "ROM/ftdi/$($matches[1])" }
    if ($Path -match '^LIB/dev/(.+)$') { return "ROM/dev/$($matches[1])" }
    if ($Path -match '^LIB/util/(.+)$') { return "ROM/util/$($matches[1])" }
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

function Mermaid-WordTree-Id {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return 'RW_ROOT' }
    return 'RW_' + ($Path -replace '[^A-Za-z0-9_]', '_')
}

function Get-RoutineWords {
    param([string]$Name)
    $display = Get-DisplayName $Name
    return @($display -split '_' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToUpperInvariant() })
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
    'LIB/ftdi/*.asm',
    'LIB/dev/*.asm',
    'LIB/util/*.asm',
    'TESTS/ftdi-backend-debug.asm',
    'HIMON/himon.asm',
    'HIMON/*.inc',
    'HIMON/fnv1a-fold.asm',
    'STR8/str8.asm',
    'STR8/str8-worker.asm'
)

$excludedOperationalSources = @(
    'LIB/util/util-test.asm',
    'HIMON/fnv1a-hbstr-6000.asm'
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
$instructionPattern = '^\s*(?:[A-Za-z_?][A-Za-z0-9_?]*:\s*)?([A-Za-z]{2,4})\b(?:\s+([^;]+))?'

$stackTrackedOps = @('PHA', 'PHP', 'PHX', 'PHY', 'PLA', 'PLP', 'PLX', 'PLY', 'JSR', 'JMP', 'BRK', 'TXS')

$routines = New-Object System.Collections.Generic.List[object]
$labels = New-Object System.Collections.Generic.List[object]
$xdefs = New-Object System.Collections.Generic.List[object]
$xrefs = New-Object System.Collections.Generic.List[object]
$edges = New-Object System.Collections.Generic.List[object]
$stackEvents = New-Object System.Collections.Generic.List[object]

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

        if ($current -and $line -match $instructionPattern) {
            $op = $matches[1].ToUpperInvariant()
            if ($stackTrackedOps -contains $op) {
                $operand = ''
                if ($matches.Count -gt 2) { $operand = $matches[2].Trim() }
                $target = ''
                if ($op -in @('JSR', 'JMP') -and $operand -match '^([A-Za-z_?][A-Za-z0-9_?]*)\b') {
                    $target = $matches[1]
                }
                $stackEvents.Add([pscustomobject]@{
                    Routine = $current
                    Op = $op
                    Target = $target
                    Operand = $operand
                    File = $rel
                    Line = $lineNo
                })
            }
        }
    }
}

$stamp = Get-Date -Format 'yyyy-MM-ddTHH:mmK'
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

function New-StackKey {
    param([string]$File, [string]$Name)
    return "$File::$Name"
}

function Get-StackFileFromKey {
    param([string]$Key)
    $parts = $Key -split '::', 2
    return $parts[0]
}

function Get-StackNameFromKey {
    param([string]$Key)
    $parts = $Key -split '::', 2
    if ($parts.Count -gt 1) { return $parts[1] }
    return $Key
}

function New-StackScopeSet {
    param([object[]]$Files)
    $set = @{}
    foreach ($file in ($Files | Sort-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($file)) {
            $set[$file] = $true
        }
    }
    return $set
}

function Join-StackPath {
    param(
        [object[]]$Path,
        [int]$MaxNodes = 18
    )
    $items = @($Path | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($items.Count -gt $MaxNodes) {
        $items = @($items | Select-Object -First $MaxNodes) + @('...')
    }
    return ($items -join ' -> ')
}

function Escape-MdCell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value -replace '\|', '\|')
}

function Format-StackPathCell {
    param([object[]]$Path)
    return '`' + (Escape-MdCell (Join-StackPath -Path $Path)) + '`'
}

function Escape-MermaidLabel {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    $text = $Value -replace '"', "'"
    $text = $text -replace '\[', '('
    $text = $text -replace '\]', ')'
    return $text
}

function Get-StackMermaidNodeId {
    param(
        [string]$Group,
        [string]$Label,
        [hashtable]$NodeIds,
        [hashtable]$UsedIds
    )
    if ($NodeIds.ContainsKey($Label)) {
        return $NodeIds[$Label]
    }

    $base = ($Label.ToUpperInvariant() -replace '[^A-Z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($base)) { $base = 'NODE' }
    if ($base.Length -gt 44) { $base = $base.Substring(0, 44) }

    $candidate = "SD_${Group}_${base}"
    $suffix = 2
    while ($UsedIds.ContainsKey($candidate)) {
        $candidate = "SD_${Group}_${base}_${suffix}"
        $suffix += 1
    }

    $NodeIds[$Label] = $candidate
    $UsedIds[$candidate] = $true
    return $candidate
}

function Get-StackMermaidMapLines {
    param(
        [string]$Group,
        [object[]]$Rows,
        [int]$MaxNodes = 10,
        [int]$MaxEdges = 20
    )

    $lines = @()
    $nodeDepth = @{}
    $edgeDepth = @{}
    $edgeCount = @{}
    $edgeFrom = @{}
    $edgeTo = @{}

    foreach ($row in $Rows) {
        $title = ('{0} {1}' -f $row.Command, $row.Entry).Trim()
        $pathItems = @($row.Path | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $shownItems = @($pathItems | Select-Object -First $MaxNodes)
        $items = @($title) + @($shownItems)
        if ($pathItems.Count -gt $shownItems.Count) {
            $items += '...'
        }

        foreach ($item in $items) {
            $label = [string]$item
            if (-not $nodeDepth.ContainsKey($label) -or $row.Bytes -gt $nodeDepth[$label]) {
                $nodeDepth[$label] = $row.Bytes
            }
        }

        for ($i = 0; $i -lt ($items.Count - 1); $i++) {
            $from = [string]$items[$i]
            $to = [string]$items[$i + 1]
            $key = "$from`t$to"
            $edgeFrom[$key] = $from
            $edgeTo[$key] = $to
            if (-not $edgeDepth.ContainsKey($key) -or $row.Bytes -gt $edgeDepth[$key]) {
                $edgeDepth[$key] = $row.Bytes
            }
            if (-not $edgeCount.ContainsKey($key)) { $edgeCount[$key] = 0 }
            $edgeCount[$key] += 1
        }
    }

    $nodeIds = @{}
    $usedIds = @{}
    foreach ($key in ($edgeDepth.Keys | Sort-Object -Property @{Expression={$edgeDepth[$_]};Descending=$true}, @{Expression={$edgeCount[$_]};Descending=$true}, @{Expression={$edgeFrom[$_]}}, @{Expression={$edgeTo[$_]}} | Select-Object -First $MaxEdges)) {
        $from = $edgeFrom[$key]
        $to = $edgeTo[$key]
        $fromId = Get-StackMermaidNodeId -Group $Group -Label $from -NodeIds $nodeIds -UsedIds $usedIds
        $toId = Get-StackMermaidNodeId -Group $Group -Label $to -NodeIds $nodeIds -UsedIds $usedIds
        $fromLabel = Escape-MermaidLabel ("{0}<br/>max {1} bytes" -f $from, $nodeDepth[$from])
        $toLabel = Escape-MermaidLabel ("{0}<br/>max {1} bytes" -f $to, $nodeDepth[$to])
        $lines += ('    {0}["{1}"] -->|{2}| {3}["{4}"]' -f $fromId, $fromLabel, $edgeDepth[$key], $toId, $toLabel)
    }

    return $lines
}

$labelByKey = @{}
$labelsByName = @{}
foreach ($label in $labels) {
    $key = New-StackKey -File $label.File -Name $label.Name
    if (-not $labelByKey.ContainsKey($key)) {
        $labelByKey[$key] = $label
    }
    if (-not $labelsByName.ContainsKey($label.Name)) {
        $labelsByName[$label.Name] = @()
    }
    $labelsByName[$label.Name] = @($labelsByName[$label.Name]) + @($label)
}

$labelNameCounts = @{}
foreach ($group in ($labels | Group-Object Name)) {
    $labelNameCounts[$group.Name] = $group.Count
}

$stackEventsByKey = @{}
foreach ($event in $stackEvents) {
    $key = New-StackKey -File $event.File -Name $event.Routine
    if (-not $stackEventsByKey.ContainsKey($key)) {
        $stackEventsByKey[$key] = @()
    }
    $stackEventsByKey[$key] = @($stackEventsByKey[$key]) + @($event)
}

function Format-StackNode {
    param([string]$Key)
    $file = Get-StackFileFromKey $Key
    $name = Get-StackNameFromKey $Key
    if ($labelNameCounts.ContainsKey($name) -and $labelNameCounts[$name] -gt 1) {
        return "${file}:$name"
    }
    return $name
}

function Resolve-StackTargetKey {
    param(
        [string]$SourceFile,
        [string]$Target,
        [hashtable]$ScopeSet
    )
    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    if ($Target.StartsWith('?')) { return $null }

    if ($Target -eq 'STR8_WORKER_RUN' -and $ScopeSet.ContainsKey('STR8/str8-worker.asm')) {
        $workerKey = New-StackKey -File 'STR8/str8-worker.asm' -Name 'START'
        if ($labelByKey.ContainsKey($workerKey) -or $stackEventsByKey.ContainsKey($workerKey)) {
            return $workerKey
        }
    }

    $sameFileKey = New-StackKey -File $SourceFile -Name $Target
    if ($ScopeSet.ContainsKey($SourceFile) -and ($labelByKey.ContainsKey($sameFileKey) -or $stackEventsByKey.ContainsKey($sameFileKey))) {
        return $sameFileKey
    }

    if ($labelsByName.ContainsKey($Target)) {
        $candidates = @($labelsByName[$Target] | Where-Object { $ScopeSet.ContainsKey($_.File) })
        if ($candidates.Count -eq 1) {
            return (New-StackKey -File $candidates[0].File -Name $candidates[0].Name)
        }
    }

    return $null
}

function Get-StackAnalysis {
    param(
        [string]$Key,
        [hashtable]$ScopeSet,
        [hashtable]$Cache,
        [string[]]$Visiting
    )

    $file = Get-StackFileFromKey $Key
    if (-not $ScopeSet.ContainsKey($file)) {
        return [pscustomobject]@{ Depth = 0; Path = @(); Unresolved = 0 }
    }
    if ($Cache.ContainsKey($Key)) {
        return $Cache[$Key]
    }
    if ($Visiting -contains $Key) {
        return [pscustomobject]@{ Depth = 0; Path = @((Format-StackNode $Key), 'cycle-cut'); Unresolved = 0 }
    }

    $events = @()
    if ($stackEventsByKey.ContainsKey($Key)) {
        $events = @($stackEventsByKey[$Key] | Sort-Object Line)
    }

    $display = Format-StackNode $Key
    $currentDepth = 0
    $maxDepth = 0
    $maxPath = @($display)
    $unresolved = 0
    $nextVisiting = @($Visiting) + @($Key)

    foreach ($event in $events) {
        switch ($event.Op) {
            { $_ -in @('PHA', 'PHP', 'PHX', 'PHY') } {
                $currentDepth += 1
                if ($currentDepth -gt $maxDepth) {
                    $maxDepth = $currentDepth
                    $maxPath = @($display, ("{0} {1}:{2}" -f $event.Op, $event.File, $event.Line))
                }
                continue
            }
            { $_ -in @('PLA', 'PLP', 'PLX', 'PLY') } {
                $currentDepth -= 1
                if ($currentDepth -lt 0) { $currentDepth = 0 }
                continue
            }
            'TXS' {
                $currentDepth = 0
                continue
            }
            'BRK' {
                $candidateDepth = $currentDepth + 3
                if ($candidateDepth -gt $maxDepth) {
                    $maxDepth = $candidateDepth
                    $maxPath = @($display, ("BRK frame {0}:{1}" -f $event.File, $event.Line))
                }
                continue
            }
            'JSR' {
                $targetKey = Resolve-StackTargetKey -SourceFile $event.File -Target $event.Target -ScopeSet $ScopeSet
                if ($targetKey) {
                    $child = Get-StackAnalysis -Key $targetKey -ScopeSet $ScopeSet -Cache $Cache -Visiting $nextVisiting
                    $unresolved += $child.Unresolved
                    $candidateDepth = $currentDepth + 2 + $child.Depth
                    if ($candidateDepth -gt $maxDepth) {
                        $maxDepth = $candidateDepth
                        $maxPath = @($display) + @($child.Path)
                    }
                } else {
                    $unresolved += 1
                    $candidateDepth = $currentDepth + 2
                    if ($candidateDepth -gt $maxDepth) {
                        $maxDepth = $candidateDepth
                        $targetName = if ($event.Target) { $event.Target } else { $event.Operand }
                        $maxPath = @($display, ("JSR {0} unresolved" -f $targetName))
                    }
                }
                continue
            }
            'JMP' {
                $targetKey = Resolve-StackTargetKey -SourceFile $event.File -Target $event.Target -ScopeSet $ScopeSet
                if ($targetKey -and $targetKey -ne $Key) {
                    $child = Get-StackAnalysis -Key $targetKey -ScopeSet $ScopeSet -Cache $Cache -Visiting $nextVisiting
                    $unresolved += $child.Unresolved
                    $candidateDepth = $currentDepth + $child.Depth
                    if ($candidateDepth -gt $maxDepth) {
                        $maxDepth = $candidateDepth
                        $maxPath = @($display) + @($child.Path)
                    }
                }
                continue
            }
        }
    }

    $result = [pscustomobject]@{
        Depth = $maxDepth
        Path = $maxPath
        Unresolved = $unresolved
    }
    $Cache[$Key] = $result
    return $result
}

function Get-StackRow {
    param(
        [string]$Scope,
        [hashtable]$ScopeSet,
        [hashtable]$Cache,
        [string]$Name,
        [string]$File,
        [string]$Kind,
        [int]$BaseBytes = 0,
        [object[]]$BasePath = @()
    )
    $key = New-StackKey -File $File -Name $Name
    $analysis = Get-StackAnalysis -Key $key -ScopeSet $ScopeSet -Cache $Cache -Visiting @()
    $label = $null
    if ($labelByKey.ContainsKey($key)) { $label = $labelByKey[$key] }
    $path = @($BasePath) + @($analysis.Path)
    return [pscustomobject]@{
        Scope = $Scope
        Kind = $Kind
        Name = $Name
        File = $File
        Line = if ($label) { $label.Line } else { '' }
        Bytes = $BaseBytes + $analysis.Depth
        Path = $path
        Unresolved = $analysis.Unresolved
    }
}

function Get-HimonCommandToken {
    param([string]$Entry)
    if ($Entry -eq 'CMD_HELP') { return '?' }
    if ($Entry -eq 'CMD_HASH_INFO') { return '#' }
    if ($Entry -match '^CMD_([A-Z0-9])(?:_|$)') { return $matches[1] }
    return $Entry
}

$sourcePathByDocPath = @{}
foreach ($file in $files) {
    $docPath = Get-DocPath -Path (Get-RelPath -Root $root -Path $file.FullName)
    $sourcePathByDocPath[$docPath] = $file.FullName
}

$himonCommandRows = New-Object System.Collections.Generic.List[object]
foreach ($docPath in ($sourcePathByDocPath.Keys | Where-Object { $_ -eq 'HIMON/himon.asm' -or $_ -like 'HIMON/*.inc' } | Sort-Object)) {
    $sourcePath = $sourcePathByDocPath[$docPath]
    $sourceLines = Get-Content -LiteralPath $sourcePath
    $pendingFnv = $null
    for ($i = 0; $i -lt $sourceLines.Count; $i++) {
        $line = $sourceLines[$i]
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)_FNV:\s*$') {
            $pendingFnv = [pscustomobject]@{
                Name = $matches[1]
                File = $docPath
                Line = $i + 1
                Token = ''
                Hash = ''
                SawRecord = $false
                EntryHint = ''
                EntryLiteral = $false
                PayloadWords = 0
            }
            continue
        }
        if ($pendingFnv -and $line -match "\bDB\b.*'F'\s*,\s*'N'\s*,\s*CMD_FNV_SIG2") {
            $pendingFnv.SawRecord = $true
        }
        if ($pendingFnv -and $line -match ';\s*(\S+)\s+\$([0-9A-Fa-f]{8})\s+EXEC') {
            $pendingFnv.Token = $matches[1]
            $pendingFnv.Hash = $matches[2].ToUpperInvariant()
            continue
        }
        if ($pendingFnv -and $line -match '^\s*DW\s+(.+?)\s*(?:;.*)?$') {
            if ($pendingFnv.PayloadWords -eq 0) {
                $entryOperand = $matches[1].Trim()
                if ($entryOperand -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                    $pendingFnv.EntryHint = $entryOperand
                } else {
                    $pendingFnv.EntryLiteral = $true
                }
            }
            $pendingFnv.PayloadWords++
            continue
        }
        if ($pendingFnv -and $line -match '^\s*([A-Za-z_][A-Za-z0-9_]*):') {
            $entry = $matches[1]
            if ($entry -notlike '*_FNV' -and $pendingFnv.SawRecord) {
                if ($pendingFnv.EntryLiteral -or
                    (-not [string]::IsNullOrWhiteSpace($pendingFnv.EntryHint) -and $entry -ne $pendingFnv.EntryHint)) {
                    $pendingFnv = $null
                    continue
                }
                $token = $pendingFnv.Token
                if ([string]::IsNullOrWhiteSpace($token)) {
                    $token = Get-HimonCommandToken -Entry $entry
                }
                $himonCommandRows.Add([pscustomobject]@{
                    Command = $token
                    Entry = $entry
                    Hash = $pendingFnv.Hash
                    File = $docPath
                    Line = $i + 1
                })
                $pendingFnv = $null
            } elseif ($entry -notlike '*_FNV') {
                $pendingFnv = $null
            }
            continue
        }
        if ($pendingFnv -and $line -notmatch '^\s*(;|$)' -and $line -notmatch '^\s*(DB|DW)\b') {
            $pendingFnv = $null
        }
    }
}

$allStackDocFiles = @(
    @($labels | ForEach-Object { $_.File }) +
    @($stackEvents | ForEach-Object { $_.File })
) | Sort-Object -Unique
$himonStackScope = New-StackScopeSet -Files @($allStackDocFiles | Where-Object { $_ -notlike 'STR8/*' })
$str8StackScope = New-StackScopeSet -Files @($allStackDocFiles | Where-Object { $_ -notlike 'HIMON/*' })
$himonStackCache = @{}
$str8StackCache = @{}

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
    $lines += if ($r.Hash) { "hash:     $($r.Hash)" } else { 'hash:' }
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
$lines += 'Renderable graph is capped to the strongest 40 direct edges. Use `DOC/GUIDES/HIMON/HIMON_EDGE_DUMP.md` for the full edge listing.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in ($himonTreeEdges | Select-Object -First 40)) {
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
$lines += 'Renderable graph is capped to the strongest 40 prefix edges. Use `ROUTINE_GRAPH_INSIGHTS.md` and the raw edge dumps for the complete graph.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($prefixRows | Select-Object -First 40)) {
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
$lines += 'Renderable graph is capped to the strongest 40 prefix edges.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($prefixRows | Select-Object -First 40)) {
    $sourceCount = if ($prefixRoutineCounts.ContainsKey($row.Source)) { $prefixRoutineCounts[$row.Source] } else { 0 }
    $targetCount = if ($prefixRoutineCounts.ContainsKey($row.Target)) { $prefixRoutineCounts[$row.Target] } else { 0 }
    $lines += ('    {0}["{1}<br/>{2} routines"] -->|{3}| {4}["{5}<br/>{6} routines"]' -f (Mermaid-Prefix-Id $row.Source), $row.Source, $sourceCount, $row.Count, (Mermaid-Prefix-Id $row.Target), $row.Target, $targetCount)
}
$lines += '```'
Write-Doc -Name 'ROUTINE_PREFIX_MAP.md' -Lines $lines

$routineWordNameSet = @{}
foreach ($r in $routines) {
    $routineWordNameSet[(Get-DisplayName $r.Name)] = $true
}
foreach ($edge in $edges) {
    $routineWordNameSet[(Get-DisplayName $edge.Source)] = $true
    $routineWordNameSet[(Get-DisplayName $edge.Target)] = $true
}

$routineWordNames = @(
    $routineWordNameSet.Keys |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\?' } |
    Sort-Object
)

$wordPathCounts = @{}
$wordPathDepths = @{}
$wordPathParents = @{}
$wordPathToken = @{}
$wordPathExamples = @{}
$maxWordTreeDepth = 4

foreach ($name in $routineWordNames) {
    $tokens = @(Get-RoutineWords $name)
    if ($tokens.Count -eq 0) { continue }
    $depthLimit = [Math]::Min($maxWordTreeDepth, $tokens.Count)
    for ($depth = 1; $depth -le $depthLimit; $depth++) {
        $path = ($tokens[0..($depth - 1)] -join '_')
        $parent = ''
        if ($depth -gt 1) {
            $parent = ($tokens[0..($depth - 2)] -join '_')
        }
        if (-not $wordPathCounts.ContainsKey($path)) {
            $wordPathCounts[$path] = 0
            $wordPathDepths[$path] = $depth
            $wordPathParents[$path] = $parent
            $wordPathToken[$path] = $tokens[$depth - 1]
            $wordPathExamples[$path] = @()
        }
        $wordPathCounts[$path] += 1
        if (@($wordPathExamples[$path]).Count -lt 5) {
            $wordPathExamples[$path] = @($wordPathExamples[$path]) + @($name)
        }
    }
}

$wordPathRows = @(
    $wordPathCounts.Keys |
    ForEach-Object {
        [pscustomobject]@{
            Path = $_
            Parent = $wordPathParents[$_]
            Token = $wordPathToken[$_]
            Depth = $wordPathDepths[$_]
            Count = $wordPathCounts[$_]
            Examples = @($wordPathExamples[$_])
        }
    }
)

$selectedWordPaths = @{}
$wordPathCandidates = @(
    $wordPathRows |
    Where-Object { $_.Depth -eq 1 -or $_.Count -ge 2 } |
    Sort-Object -Property Depth, @{Expression='Count';Descending=$true}, Path |
    Select-Object -First 40
)

foreach ($row in $wordPathCandidates) {
    $parts = @($row.Path -split '_')
    for ($depth = 1; $depth -le $parts.Count; $depth++) {
        $ancestor = ($parts[0..($depth - 1)] -join '_')
        $selectedWordPaths[$ancestor] = $true
    }
}

$lines = @('# R-YORS Routine Word Tree') + $header
$lines += 'Hierarchy over callable-ish source symbols, split on `_`. Symbols come from routine headers and direct `JSR`/`JMP` source/target names in the operational source set.'
$lines += ''
$lines += 'The Mermaid graph is capped to the strongest 40 name branches so it stays renderable. Edges are name containment, not call edges.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart TD'
$lines += ('    RW_ROOT["ROUTINES<br/>{0} symbols"]' -f $routineWordNames.Count)
for ($depth = 1; $depth -le $maxWordTreeDepth; $depth++) {
    foreach ($row in ($wordPathRows | Where-Object { $_.Depth -eq $depth -and $selectedWordPaths.ContainsKey($_.Path) } | Sort-Object -Property Parent, @{Expression='Count';Descending=$true}, Token)) {
        $parentId = if ([string]::IsNullOrWhiteSpace($row.Parent)) { 'RW_ROOT' } else { Mermaid-WordTree-Id $row.Parent }
        $nodeId = Mermaid-WordTree-Id $row.Path
        $label = Escape-MermaidLabel ("{0}<br/>{1}" -f $row.Token, $row.Count)
        $lines += ('    {0} --> {1}["{2}"]' -f $parentId, $nodeId, $label)
    }
}
$lines += '```'
$lines += ''
$lines += '## Largest Branches'
$lines += ''
$lines += '| Path | Symbols | Examples |'
$lines += '| --- | ---: | --- |'
foreach ($row in ($wordPathRows | Where-Object { $_.Depth -gt 1 } | Sort-Object -Property @{Expression='Count';Descending=$true}, Depth, Path | Select-Object -First 40)) {
    $examples = (@($row.Examples) | ForEach-Object { '`' + $_ + '`' }) -join ', '
    $lines += ('| `{0}` | {1} | {2} |' -f $row.Path, $row.Count, $examples)
}
Write-Doc -Name 'ROUTINE_WORD_TREE.md' -Lines $lines

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
$lines += 'Renderable graph is capped to the strongest 40 prefix edges.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($row in ($himonPrefixRows | Select-Object -First 40)) {
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
    Select-Object -First 40
)

$lines = @('# R-YORS HIMON Command Map') + $header
$lines += 'HIMON command/debug/load/ASM call map, limited to direct edges and compacted for readability. Renderable graph is capped to the strongest 40 command-surface edges; use `DOC/GUIDES/HIMON/HIMON_EDGE_DUMP.md` for the full edge listing.'
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
$lines += 'Renderable graph is capped to the strongest 40 hash-path edges; the Direct Edges section below lists the complete source-derived set.'
$lines += ''
$lines += '```mermaid'
$lines += 'flowchart LR'
foreach ($edge in ($hashEdges | Select-Object -First 40)) {
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
$lines += '    CALL --> BODY["command body<br/>CMD_D / CMD_L / CMD_Q / ..."]'
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
    'MON_NMI_TRAP_DEBOUNCE',
    'MON_NMI_DEBOUNCE_DELAY',
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
    'CMD_N'
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
$lines += '    SETNMI --> VECNMI["$7EFA-$7EFB<br/>VEC_NMI = MON_NMI_TRAP_DEBOUNCE"]'
$lines += '    SETBRK --> VECBRK["$7EFC-$7EFD<br/>VEC_IRQ_BRK = MON_BRK_TRAP"]'
$lines += '    SETIRQ --> VECIRQ["$7EFE-$7EFF<br/>VEC_IRQ_NONBRK = MON_IRQ_TRAP"]'
$lines += ''
$lines += '    NMIV["$FFFA-$FFFB<br/>NMI vector"] --> NMIENTRY["' + (Format-Interrupt-Node 'SYS_VEC_ENTRY_NMI' 'NMI trampoline') + '"]'
$lines += '    NMIENTRY --> VECNMI'
$lines += '    VECNMI --> NMITRAP["' + (Format-Interrupt-Node 'MON_NMI_TRAP_DEBOUNCE' 'debounce then save NMI context') + '"]'
$lines += '    NMITRAP -->|bounce| RTINMI["RTI"]'
$lines += '    NMITRAP --> REENTER["' + (Format-Interrupt-Node 'MON_REENTER' 'reset stack and re-enter monitor') + '"]'
$lines += '    NMIBASE["' + (Format-Interrupt-Node 'MON_NMI_TRAP' 'baseline NMI context path') + '"] --> REENTER'
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
$lines += '    CMDN["' + (Format-Interrupt-Node 'CMD_N' 'single-step command') + '"] --> STEP["' + (Format-Interrupt-Node 'DBG_STEP_ONCE' 'patch temporary BRK') + '"]'
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
$lines += '- Current HIMON installs `MON_NMI_TRAP_DEBOUNCE`, `MON_BRK_TRAP`, and `MON_IRQ_TRAP` during `MON_START_INIT` after `SYS_INIT` seeds safe defaults. `MON_NMI_TRAP` remains the baseline non-debounced NMI path.'
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

function Get-OwnedStackRows {
    param(
        [string]$Scope,
        [hashtable]$ScopeSet,
        [hashtable]$Cache,
        [string]$FilePrefix,
        [int]$Limit
    )
    $rows = @()
    foreach ($key in ($stackEventsByKey.Keys | Sort-Object)) {
        $file = Get-StackFileFromKey $key
        if ($file -notlike "$FilePrefix*") { continue }
        $name = Get-StackNameFromKey $key
        $rows += Get-StackRow -Scope $Scope -ScopeSet $ScopeSet -Cache $Cache -Name $name -File $file -Kind 'routine'
    }
    return @($rows | Sort-Object -Property @{Expression='Bytes';Descending=$true}, Name, File | Select-Object -First $Limit)
}

$stackRootRows = @()
$stackRootRows += Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name 'START' -File 'HIMON/himon.asm' -Kind 'reset entry'
$stackRootRows += Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name 'MAIN_LOOP' -File 'HIMON/himon.asm' -Kind 'main loop'
$stackRootRows += Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name 'CMD_DISPATCH_HASH' -File 'HIMON/himon.asm' -Kind 'hash dispatcher'
$stackRootRows += Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name 'MON_NMI_TRAP_DEBOUNCE' -File 'HIMON/himon.asm' -Kind 'NMI trap body'
$stackRootRows += Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name 'MON_BRK_TRAP' -File 'HIMON/himon.asm' -Kind 'BRK trap body'
$stackRootRows += Get-StackRow -Scope 'STR8' -ScopeSet $str8StackScope -Cache $str8StackCache -Name 'START' -File 'STR8/str8.asm' -Kind 'reset entry'
$stackRootRows += Get-StackRow -Scope 'STR8' -ScopeSet $str8StackScope -Cache $str8StackCache -Name 'STR8_CMD_LOOP' -File 'STR8/str8.asm' -Kind 'command loop'
$stackRootRows += Get-StackRow -Scope 'STR8' -ScopeSet $str8StackScope -Cache $str8StackCache -Name 'START' -File 'STR8/str8-worker.asm' -Kind 'RAM worker entry'

function Get-HimonCommandRelatedKeys {
    param(
        [string]$Command,
        [string]$Entry
    )
    $exactNames = @($Entry)
    $startPrefixes = @("${Entry}_")

    if ($Command -match '^[A-Z0-9]$') {
        $usage = "CMD_USAGE_$Command"
        $exactNames += $usage
        $startPrefixes += $usage
    }
    if ($Entry -eq 'CMD_HASH_INFO') {
        $exactNames += 'CMD_HASH_LIST'
        $startPrefixes += 'CMD_HASH_LIST_'
    }

    $keys = @()
    foreach ($label in ($labels | Where-Object { $_.File -like 'HIMON/*' })) {
        $include = $false
        foreach ($name in $exactNames) {
            if ($label.Name -eq $name) {
                $include = $true
                break
            }
        }
        if (-not $include) {
            foreach ($prefix in $startPrefixes) {
                if ($label.Name.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                    $include = $true
                    break
                }
            }
        }
        if ($include) {
                $keys += (New-StackKey -File $label.File -Name $label.Name)
        }
    }
    return @($keys | Sort-Object -Unique)
}

function Get-BestStackRowForKeys {
    param(
        [string]$Scope,
        [hashtable]$ScopeSet,
        [hashtable]$Cache,
        [string[]]$Keys
    )
    $best = $null
    foreach ($key in ($Keys | Sort-Object -Unique)) {
        $file = Get-StackFileFromKey $key
        $name = Get-StackNameFromKey $key
        $row = Get-StackRow -Scope $Scope -ScopeSet $ScopeSet -Cache $Cache -Name $name -File $file -Kind 'command-label'
        if ($null -eq $best -or $row.Bytes -gt $best.Bytes) {
            $best = $row
        }
    }
    return $best
}

$himonCommandDepthRows = @()
foreach ($cmd in ($himonCommandRows | Sort-Object File, Line, Entry)) {
    $relatedKeys = Get-HimonCommandRelatedKeys -Command $cmd.Command -Entry $cmd.Entry
    $row = Get-BestStackRowForKeys -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Keys $relatedKeys
    if ($null -eq $row) {
        $row = Get-StackRow -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -Name $cmd.Entry -File $cmd.File -Kind 'command'
    }
    $himonCommandDepthRows += [pscustomobject]@{
        Command = $cmd.Command
        Entry = $cmd.Entry
        Hash = $cmd.Hash
        Source = ("{0}:{1}" -f $cmd.File, $cmd.Line)
        Bytes = 4 + $row.Bytes
        Path = @('CMD_DISPATCH_HASH', 'JSR CMD_EXEC_ADDR', 'JSR CMD_CALL_ADDR') + @($row.Path)
    }
}

$str8CommandDefs = @(
    [pscustomobject]@{ Command = '?'; Entry = 'STR8_CMD_ID'; Meaning = 'ID/state' }
    [pscustomobject]@{ Command = 'B'; Entry = 'STR8_CMD_BACKUP'; Meaning = 'backup rotation' }
    [pscustomobject]@{ Command = 'E'; Entry = 'STR8_CMD_ENROLL_B0'; Meaning = 'enroll bank 0' }
    [pscustomobject]@{ Command = 'G'; Entry = 'STR8_CMD_G_HIMON'; Meaning = 'go HIMON' }
    [pscustomobject]@{ Command = 'M'; Entry = 'STR8_CMD_M'; Meaning = 'flash map' }
    [pscustomobject]@{ Command = 'R'; Entry = 'STR8_CMD_RESET'; Meaning = 'reset vector' }
    [pscustomobject]@{ Command = 'U'; Entry = 'STR8_CMD_UPDATE_HIMON'; Meaning = 'update HIMON C000-EFFF' }
    [pscustomobject]@{ Command = '0/1/2'; Entry = 'STR8_CMD_RESTORE_A'; Meaning = 'restore selected bank' }
)

$str8CommandDepthRows = @()
foreach ($cmd in $str8CommandDefs) {
    $row = Get-StackRow -Scope 'STR8' -ScopeSet $str8StackScope -Cache $str8StackCache -Name $cmd.Entry -File 'STR8/str8.asm' -Kind 'command' -BaseBytes 2 -BasePath @('STR8_CMD_LOOP', 'JSR STR8_DISPATCH_A')
    $str8CommandDepthRows += [pscustomobject]@{
        Command = $cmd.Command
        Entry = $cmd.Entry
        Meaning = $cmd.Meaning
        Source = if ($row.Line) { ("{0}:{1}" -f $row.File, $row.Line) } else { $row.File }
        Bytes = $row.Bytes
        Path = $row.Path
    }
}

$himonOwnedStackRows = Get-OwnedStackRows -Scope 'HIMON' -ScopeSet $himonStackScope -Cache $himonStackCache -FilePrefix 'HIMON/' -Limit 30
$str8OwnedStackRows = Get-OwnedStackRows -Scope 'STR8' -ScopeSet $str8StackScope -Cache $str8StackCache -FilePrefix 'STR8/' -Limit 30

$lines = @('# R-YORS Stack Depth Map') + $header
$lines += 'Source-derived stack high-water map for current HIMON and STR8 paths. It is meant to answer: how deep does stack usage go, and which command/routine path gets there?'
$lines += ''
$lines += '## Counting Rules'
$lines += ''
$lines += '- Counts each active `JSR` return address as 2 bytes.'
$lines += '- Counts explicit 65C02 pushes `PHA`, `PHP`, `PHX`, and `PHY` as 1 byte each; matching pulls reduce the current explicit depth.'
$lines += '- Counts `BRK` as a 3-byte hardware frame at the instruction site.'
$lines += '- Treats direct `JMP label` as a tail path with no extra return address.'
$lines += '- Uses static, branch-insensitive paths; command rows choose the deepest related command label so split bodies such as `CMD_L_*` are included.'
$lines += '- Does not add the hardware NMI/IRQ entry frame to trap rows; those rows start at the handler label. Indirect `JMP (...)` targets and unresolved external targets are not expanded.'
$lines += ''
$lines += '## Command Stack Map'
$lines += ''
$lines += 'Renderable Mermaid node/edge map of command stack paths, capped to the deepest 20 route edges per HIMON/STR8 subgraph. Node labels show the highest stack depth seen on any command path that touches that node; edge labels show the highest stack depth seen on that route. The tables below remain the exact byte/source reference.'
$lines += ''
$lines += '```mermaid'
$lines += '%%{init: {"theme": "base", "themeVariables": {"background": "#000000", "mainBkg": "#000000", "primaryColor": "#000000", "primaryBorderColor": "#d8d8d8", "primaryTextColor": "#ffffff", "lineColor": "#ffffff", "secondaryColor": "#000000", "tertiaryColor": "#000000", "clusterBkg": "#000000", "clusterBorder": "#999999", "edgeLabelBackground": "#000000"}}}%%'
$lines += 'flowchart LR'
$lines += '    classDef default fill:#000000,stroke:#d8d8d8,color:#ffffff;'
$lines += '    subgraph HSTACK["HIMON command stack paths"]'
$lines += Get-StackMermaidMapLines -Group 'HIMON' -Rows ($himonCommandDepthRows | Sort-Object -Property @{Expression='Bytes';Descending=$true}, Command, Entry)
$lines += '    end'
$lines += '    subgraph SSTACK["STR8 command stack paths"]'
$lines += Get-StackMermaidMapLines -Group 'STR8' -Rows ($str8CommandDepthRows | Sort-Object -Property @{Expression='Bytes';Descending=$true}, Command, Entry)
$lines += '    end'
$lines += '    style HSTACK fill:#000000,stroke:#999999,color:#ffffff'
$lines += '    style SSTACK fill:#000000,stroke:#999999,color:#ffffff'
$lines += '```'
$lines += ''
$lines += '## Application Entries'
$lines += ''
$lines += '| Scope | Entry | Source | Bytes | Deepest path |'
$lines += '| --- | --- | --- | ---: | --- |'
foreach ($row in ($stackRootRows | Sort-Object Scope, @{Expression='Bytes';Descending=$true}, Kind)) {
    $source = if ($row.Line) { ("{0}:{1}" -f $row.File, $row.Line) } else { $row.File }
    $entry = ('{0} `{1}`' -f $row.Kind, $row.Name)
    $lines += ('| {0} | {1} | `{2}` | {3} | {4} |' -f $row.Scope, (Escape-MdCell $entry), $source, $row.Bytes, (Format-StackPathCell $row.Path))
}

$lines += ''
$lines += '## HIMON Command/FNV Entries'
$lines += ''
$lines += 'Bytes include the hashed command return chain: `CMD_DISPATCH_HASH -> JSR CMD_EXEC_ADDR -> JSR CMD_CALL_ADDR -> command body`.'
$lines += ''
$lines += '| Command | Entry | Source | Bytes | Deepest path |'
$lines += '| --- | --- | --- | ---: | --- |'
foreach ($row in ($himonCommandDepthRows | Sort-Object -Property @{Expression='Bytes';Descending=$true}, Command, Entry)) {
    $hashText = if ($row.Hash) { " hash=$($row.Hash)" } else { '' }
    $entry = ('`{0}`{1}' -f $row.Entry, $hashText)
    $lines += ('| `{0}` | {1} | `{2}` | {3} | {4} |' -f (Escape-MdCell $row.Command), (Escape-MdCell $entry), $row.Source, $row.Bytes, (Format-StackPathCell $row.Path))
}

$lines += ''
$lines += '## STR8 Commands'
$lines += ''
$lines += 'Bytes include the command-loop dispatch return: `STR8_CMD_LOOP -> JSR STR8_DISPATCH_A -> command body`. The resident ROM path resolves `STR8_WORKER_RUN` to the RAM worker entry at `STR8/str8-worker.asm:START`.'
$lines += ''
$lines += '| Command | Entry | Meaning | Source | Bytes | Deepest path |'
$lines += '| --- | --- | --- | --- | ---: | --- |'
foreach ($row in ($str8CommandDepthRows | Sort-Object -Property @{Expression='Bytes';Descending=$true}, Command)) {
    $lines += ('| `{0}` | `{1}` | {2} | `{3}` | {4} | {5} |' -f (Escape-MdCell $row.Command), $row.Entry, (Escape-MdCell $row.Meaning), $row.Source, $row.Bytes, (Format-StackPathCell $row.Path))
}

$lines += ''
$lines += '## Deepest HIMON-Owned Routines'
$lines += ''
$lines += '| Routine | Source | Bytes | Deepest path |'
$lines += '| --- | --- | ---: | --- |'
foreach ($row in $himonOwnedStackRows) {
    $source = if ($row.Line) { ("{0}:{1}" -f $row.File, $row.Line) } else { $row.File }
    $lines += ('| `{0}` | `{1}` | {2} | {3} |' -f $row.Name, $source, $row.Bytes, (Format-StackPathCell $row.Path))
}

$lines += ''
$lines += '## Deepest STR8-Owned Routines'
$lines += ''
$lines += '| Routine | Source | Bytes | Deepest path |'
$lines += '| --- | --- | ---: | --- |'
foreach ($row in $str8OwnedStackRows) {
    $source = if ($row.Line) { ("{0}:{1}" -f $row.File, $row.Line) } else { $row.File }
    $lines += ('| `{0}` | `{1}` | {2} | {3} |' -f $row.Name, $source, $row.Bytes, (Format-StackPathCell $row.Path))
}

Write-Doc -Name 'STACK_DEPTH_MAP.md' -Lines $lines

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
$lines += '| Explore unsettled design thinking | [GUIDES/QCC.md](../GUIDES/QCC/INDEX.md) | Questions, Comments, Concerns index. |'
$lines += '| Understand memory and flash ranges | [GUIDES/MEMORY_MAP.md](../GUIDES/MEMORY/MEMORY_MAP.md) | Current RAM/ROM/flash ownership. |'
$lines += '| Understand hash meanings | [GUIDES/HASH_MAP.md](../GUIDES/HASH/HASH_MAP.md) | Hash concepts, widths, records, and catalog direction. |'
$lines += '| Understand HIMON subsystems | [GUIDES/HIMON_MAP.md](../GUIDES/HIMON/HIMON_MAP.md) | Curated monitor capability and subsystem maps. |'
$lines += '| Understand command dispatch flow | [CMD_FLOW_MAP.md](./CMD_FLOW_MAP.md) | Prompt, hash, resolve, run, return. |'
$lines += '| Check stack depth by command/routine | [STACK_DEPTH_MAP.md](./STACK_DEPTH_MAP.md) | Source-derived HIMON and STR8 stack high-water paths. |'
$lines += '| Understand interrupts and vector patching | [INTERRUPT_VECTOR_MAP.md](./INTERRUPT_VECTOR_MAP.md) | Reset/NMI/IRQ/BRK trampolines, RAM vectors, traps, and `RTI` resume. |'
$lines += '| See hash-involved source labels | [HASH_ROUTINE_MAP.md](./HASH_ROUTINE_MAP.md) | `CMD_HASH*`, `FNV1A_*`, and related edges. |'
$lines += '| See command/debug/load/ASM calls | [HIMON_COMMAND_MAP.md](./HIMON_COMMAND_MAP.md) | Compact source-derived HIMON command map. |'
$lines += '| See whole HIMON call tree | [HIMON_ROUTINE_TREE.md](./HIMON_ROUTINE_TREE.md) | Current HIMON source-only direct edge tree. |'
$lines += '| See support-layer dependencies | [HIMON_SUPPORT_MAP.md](./HIMON_SUPPORT_MAP.md) | HIMON-only prefix dependency map. |'
$lines += '| See all operational prefix groups | [ROUTINE_PREFIX_MAP.md](./ROUTINE_PREFIX_MAP.md) | Operational source prefix map with counts. |'
$lines += '| See underscore-word routine hierarchy | [ROUTINE_WORD_TREE.md](./ROUTINE_WORD_TREE.md) | Callable-ish symbols grouped by name words between `_`. |'
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
$lines += '    GUIDE --> MEM[GUIDES/MEMORY/MEMORY_MAP]'
$lines += '    GUIDE --> HASH[GUIDES/HASH/HASH_MAP]'
$lines += '    GUIDE --> HIMON[GUIDES/HIMON/HIMON_MAP]'
$lines += '    GUIDE --> STR8[GUIDES/STR8/STR8]'
$lines += '    GUIDE --> ASM[GUIDES/ASM/HASHED_ASM]'
$lines += ''
$lines += '    MOM --> GEN[Generated source maps]'
$lines += '    GEN --> CALL[CALL_ORDER]'
$lines += '    GEN --> CONTRACTS[ROUTINE_CONTRACTS]'
$lines += '    GEN --> TREE[HIMON_ROUTINE_TREE]'
$lines += '    GEN --> FLOW[CMD_FLOW_MAP]'
$lines += '    GEN --> STACK[STACK_DEPTH_MAP]'
$lines += '    GEN --> IVEC[INTERRUPT_VECTOR_MAP]'
$lines += '    GEN --> HRASH[HASH_ROUTINE_MAP]'
$lines += '    GEN --> HCOMMAND[HIMON_COMMAND_MAP]'
$lines += '    GEN --> HSUPPORT[HIMON_SUPPORT_MAP]'
$lines += '    GEN --> PREFIX[ROUTINE_PREFIX_MAP]'
$lines += '    GEN --> WORDTREE[ROUTINE_WORD_TREE]'
$lines += '    GEN --> CLASS[ROUTINE_CLASS_DIAGRAM]'
$lines += '    GEN --> INSIGHTS[ROUTINE_GRAPH_INSIGHTS]'
$lines += '    GEN --> COMPONENTS[ROUTINE_COMPONENTS]'
$lines += ''
$lines += '    HASH --> HRASH'
$lines += '    HIMON --> FLOW'
$lines += '    HIMON --> IVEC'
$lines += '    HIMON --> STACK'
$lines += '    STR8 --> STACK'
$lines += '    MEM --> IVEC'
$lines += '    HIMON --> HCOMMAND'
$lines += '    FLOW --> HRASH'
$lines += '    TREE --> HCOMMAND'
$lines += '    PREFIX --> CLASS'
$lines += '    PREFIX --> WORDTREE'
$lines += '    COMPONENTS --> PREFIX'
$lines += '```'
$lines += ''
$lines += '## Freshness'
$lines += ''
$lines += '- Generated maps are refreshed by `make -C SRC docs`.'
$lines += '- Individual generated maps can be refreshed with targets such as `make -C SRC stack-depth-map`, `make -C SRC cmd-flow-map`, `make -C SRC hash-routine-map`, `make -C SRC routine-prefix-map`, or `make -C SRC routine-word-tree`.'
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

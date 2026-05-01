param(
    [string]$Src = ".",
    [bool]$FailOnCollision = $true
)

$ErrorActionPreference = "Stop"

function Get-RelPath {
    param(
        [string]$Root,
        [string]$Path
    )

    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($Root.Length + 1).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function Get-RoutineHash {
    param(
        [string]$RelPath,
        [string]$RoutineNamesRaw
    )

    $nameTokens = @()
    foreach ($token in ($RoutineNamesRaw -split '\s*/\s*')) {
        $name = $token.Trim()
        if ($name) {
            $nameTokens += $name.ToUpperInvariant()
        }
    }

    if ($nameTokens.Count -eq 0) {
        $nameTokens = @($RoutineNamesRaw.Trim().ToUpperInvariant())
    }

    # HASH algorithm: 32-bit FNV-1a over canonical routine text.
    # If a legacy ROUTINE header lists multiple names, the first name is the
    # primary hash identity. Split the header when each alias needs its own
    # exact [HASH:XXXXXXXX] line.
    [UInt64]$hash = 2166136261
    foreach ($b in [System.Text.Encoding]::ASCII.GetBytes($nameTokens[0])) {
        $hash = ((($hash -bxor [UInt64]$b) * [UInt64]16777619) -band [UInt64]4294967295)
    }

    return ('{0:X8}' -f $hash)
}

$repoRoot = (Resolve-Path -LiteralPath $Src).Path
$scanRoots = if (Test-Path -LiteralPath (Join-Path $repoRoot 'STASH')) {
    @(
        (Join-Path $repoRoot 'STASH'),
        (Join-Path $repoRoot 'TEST'),
        (Join-Path $repoRoot 'SESH')
    )
} else {
    @(
        (Join-Path $repoRoot 'SRC/STASH'),
        (Join-Path $repoRoot 'SRC/TEST'),
        (Join-Path $repoRoot 'SRC/SESH')
    )
}

$files = @()
foreach ($root in $scanRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }

    $files += @(
        Get-ChildItem -Path $root -Recurse -File |
        Where-Object { @('.asm', '.inc') -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object FullName
    )
}

$routineHeaderPattern = '^(\s*;\s*ROUTINE:\s*)(.+?)(?:\s+\[HASH:([0-9A-Fa-f]{8})\])?\s*$'
$filesChanged = 0
$headersSeen = 0
$hashIndex = @{}

foreach ($file in $files) {
    $raw = [System.IO.File]::ReadAllText($file.FullName)
    if ($null -eq $raw) {
        continue
    }

    $relPath = Get-RelPath -Root $repoRoot -Path $file.FullName
    $newline = if ($raw.Contains("`r`n")) { "`r`n" } elseif ($raw.Contains("`n")) { "`n" } elseif ($raw.Contains("`r")) { "`r" } else { [Environment]::NewLine }
    $lines = [System.Text.RegularExpressions.Regex]::Split($raw, "`r`n|`n|`r")
    $fileChanged = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -notmatch $routineHeaderPattern) {
            continue
        }

        $headersSeen++
        $prefix = $matches[1]
        $namesRaw = $matches[2].Trim()
        $hash = Get-RoutineHash -RelPath $relPath -RoutineNamesRaw $namesRaw
        if (-not $hashIndex.ContainsKey($hash)) {
            $hashIndex[$hash] = @()
        }
        $hashIndex[$hash] += [pscustomobject]@{
            Path = $relPath
            Line = ($i + 1)
            Routine = $namesRaw
        }
        $updated = "$prefix$namesRaw  [HASH:$hash]"
        if ($updated -ne $line) {
            $lines[$i] = $updated
            $fileChanged = $true
        }
    }

    if ($fileChanged) {
        [System.IO.File]::WriteAllText($file.FullName, ([string]::Join($newline, $lines)), [System.Text.Encoding]::ASCII)
        $filesChanged++
    }
}

$collisions = @(
    $hashIndex.GetEnumerator() |
    Where-Object { $_.Value.Count -gt 1 } |
    Sort-Object Name
)

Write-Output ("Scanned files: {0}" -f $files.Count)
Write-Output ("Routine headers: {0}" -f $headersSeen)
Write-Output ("Files updated: {0}" -f $filesChanged)
Write-Output ("HASH collisions: {0}" -f $collisions.Count)

if ($collisions.Count -gt 0) {
    foreach ($entry in $collisions) {
        Write-Output ("COLLISION [HASH:{0}] occurrences={1}" -f $entry.Key, $entry.Value.Count)
        foreach ($item in @($entry.Value | Sort-Object Path, Line)) {
            Write-Output ("  - {0}:{1} ROUTINE: {2}" -f $item.Path, $item.Line, $item.Routine)
        }
    }

    if ($FailOnCollision) {
        throw ("HASH collision check failed: {0} duplicate hash value(s)." -f $collisions.Count)
    }
}

param(
    [string]$SourcePath = `
        "../DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a",
    [string]$MutationWorkerS19Path = `
        "BUILD/s19/str8-mutation-worker-0200.s19",
    [int]$WorkerStart = 0x0200,
    [int]$WorkerEnd = 0x042A,
    [int]$ImageAddress = 0x3000
)

$ErrorActionPreference = 'Stop'

function Fail-Embed([string]$Message) {
    throw "STR8 bank-maint worker embed: $Message"
}

function Read-S19Memory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Embed "missing mutation worker $Path"
    }

    [byte[]]$memory = New-Object byte[] 65536
    [bool[]]$seen = New-Object bool[] 65536
    foreach ($rawLine in [System.IO.File]::ReadAllLines(
        (Resolve-Path -LiteralPath $Path).Path
    )) {
        $line = $rawLine.Trim()
        if (-not $line.StartsWith('S1')) {
            continue
        }
        if ($line -notmatch '^S1[0-9A-Fa-f]+$') {
            Fail-Embed "malformed S1 record"
        }
        $count = [Convert]::ToInt32($line.Substring(2, 2), 16)
        if ($line.Length -ne (4 + (2 * $count))) {
            Fail-Embed "S1 byte count does not match record length"
        }
        $sum = $count
        for ($index = 0; $index -lt $count; $index++) {
            $sum += [Convert]::ToInt32(
                $line.Substring(4 + (2 * $index), 2),
                16
            )
        }
        if (($sum -band 0xFF) -ne 0xFF) {
            Fail-Embed "S1 checksum mismatch"
        }
        $address = [Convert]::ToInt32($line.Substring(4, 4), 16)
        $dataLength = $count - 3
        for ($index = 0; $index -lt $dataLength; $index++) {
            $target = $address + $index
            if ($target -lt 0 -or $target -ge $memory.Length) {
                Fail-Embed "S1 address is outside 16-bit memory"
            }
            if ($seen[$target]) {
                Fail-Embed ('duplicate S1 byte at ${0:X4}' -f $target)
            }
            $memory[$target] = [Convert]::ToByte(
                $line.Substring(8 + (2 * $index), 2),
                16
            )
            $seen[$target] = $true
        }
    }

    for ($address = $WorkerStart; $address -le $WorkerEnd; $address++) {
        if (-not $seen[$address]) {
            Fail-Embed ('missing worker byte at ${0:X4}' -f $address)
        }
    }
    for ($address = 0; $address -lt $seen.Length; $address++) {
        if ($seen[$address] -and (
            $address -lt $WorkerStart -or $address -gt $WorkerEnd
        )) {
            Fail-Embed ('unexpected worker byte at ${0:X4}' -f $address)
        }
    }

    return $memory
}

if ($WorkerEnd -lt $WorkerStart) {
    Fail-Embed 'worker range is reversed'
}
if (-not (Test-Path -LiteralPath $SourcePath)) {
    Fail-Embed "missing source $SourcePath"
}

$beginMarker = '; BEGIN GENERATED STR8 MUTATION WORKER'
$endMarker = '; END GENERATED STR8 MUTATION WORKER'
$sourceFile = (Resolve-Path -LiteralPath $SourcePath).Path
$lines = [System.IO.File]::ReadAllLines($sourceFile)
$beginIndexes = @(
    0..($lines.Count - 1) | Where-Object { $lines[$_] -eq $beginMarker }
)
$endIndexes = @(
    0..($lines.Count - 1) | Where-Object { $lines[$_] -eq $endMarker }
)
if ($beginIndexes.Count -ne 1 -or $endIndexes.Count -ne 1) {
    Fail-Embed 'source must contain one generated-worker marker pair'
}
$beginIndex = $beginIndexes[0]
$endIndex = $endIndexes[0]
if ($endIndex -le $beginIndex) {
    Fail-Embed 'generated-worker markers are reversed'
}

[byte[]]$memory = Read-S19Memory $MutationWorkerS19Path
$generated = [System.Collections.Generic.List[string]]::new()
$generated.Add(('        ORG ${0:X4}' -f $ImageAddress))
for ($address = $WorkerStart; $address -le $WorkerEnd; $address += 8) {
    $last = [Math]::Min($address + 7, $WorkerEnd)
    $tokens = for ($cursor = $address; $cursor -le $last; $cursor++) {
        '${0:X2}' -f $memory[$cursor]
    }
    $generated.Add('        DB ' + ($tokens -join ','))
}

$updated = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -le $beginIndex; $index++) {
    $updated.Add($lines[$index])
}
$updated.AddRange($generated)
for ($index = $endIndex; $index -lt $lines.Count; $index++) {
    $updated.Add($lines[$index])
}

$oldText = [string]::Join([Environment]::NewLine, $lines)
$newText = [string]::Join([Environment]::NewLine, $updated)
if ($newText -ne $oldText) {
    [System.IO.File]::WriteAllLines(
        $sourceFile,
        $updated,
        [System.Text.Encoding]::ASCII
    )
}

$size = $WorkerEnd - $WorkerStart + 1
Write-Host (
    'STR8 BANK MAINT WORKER = ${0:X4}-${1:X4}; {2} bytes at ${3:X4}' -f `
        $WorkerStart, $WorkerEnd, $size, $ImageAddress
)

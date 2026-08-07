param(
    [string]$MutationWorkerS19Path = "BUILD/s19/str8-mutation-worker-0200.s19",
    [string]$PayloadS19Path = "BUILD/s19/himon-str8-v1-install.s19",
    [string]$WorkerEqPath = "STR8/str8-worker-eq.inc",
    [string]$BadWorkerS19Path = "BUILD/s19/str8-v1-i-bad-worker-id.s19",
    [string]$InterruptS19Path = "BUILD/s19/str8-v1-i-interrupt-after-start.s19"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EquValue {
    param([string]$Path, [string]$Name)

    $pattern = '^\s*' + [Regex]::Escape($Name) + '\s+EQU\s+(.+?)\s*$'
    $match = Select-String -LiteralPath $Path -Pattern $pattern | Select-Object -First 1
    if (-not $match) { throw "Missing literal constant $Name in $Path" }
    $value = $match.Matches[0].Groups[1].Value.Trim()
    if ($value -match '^\$([0-9A-Fa-f]+)$') { return [Convert]::ToInt32($Matches[1], 16) }
    if ($value -match "^'(.)'$" ) { return [int][char]$Matches[1] }
    throw "Unsupported literal constant $Name`: $value"
}

function Read-S19 {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing S19: $Path" }
    $records = New-Object System.Collections.Generic.List[object]
    $lineNumber = 0
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $lineNumber++
        $line = $raw.Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -notmatch '^S([019])([0-9A-Fa-f]+)$') {
            throw "${Path}:$lineNumber unsupported or malformed record: $line"
        }
        $type = [int]$Matches[1]
        $hex = $Matches[2]
        if (($hex.Length -band 1) -ne 0 -or $hex.Length -lt 8) {
            throw "${Path}:$lineNumber malformed record length"
        }
        $count = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        if ($line.Length -ne (4 + (2 * $count))) {
            throw "${Path}:$lineNumber count/length mismatch"
        }
        $sum = 0
        for ($offset = 0; $offset -lt $hex.Length; $offset += 2) {
            $sum += [Convert]::ToInt32($hex.Substring($offset, 2), 16)
        }
        if (($sum -band 0xFF) -ne 0xFF) {
            throw "${Path}:$lineNumber checksum failure"
        }
        $address = [Convert]::ToInt32($hex.Substring(2, 4), 16)
        $dataLength = $count - 3
        [byte[]]$data = New-Object byte[] ([Math]::Max(0, $dataLength))
        for ($i = 0; $i -lt $dataLength; $i++) {
            $data[$i] = [Convert]::ToByte($hex.Substring(6 + (2 * $i), 2), 16)
        }
        $records.Add([pscustomobject]@{
            Type = $type
            Address = $address
            Data = $data
            Line = $line.ToUpperInvariant()
        })
    }
    return $records.ToArray()
}

function New-S1Line {
    param([int]$Address, [byte[]]$Data)

    if ($Data.Length -le 0 -or $Data.Length -gt 252) {
        throw "S1 data length must be 1-252 bytes"
    }
    $count = $Data.Length + 3
    $sum = $count + (($Address -shr 8) -band 0xFF) + ($Address -band 0xFF)
    $dataHex = New-Object System.Text.StringBuilder
    foreach ($value in $Data) {
        $sum += $value
        [void]$dataHex.Append($value.ToString('X2'))
    }
    $checksum = ($sum -bxor 0xFF) -band 0xFF
    return ('S1{0:X2}{1:X4}{2}{3:X2}' -f $count, $Address, $dataHex.ToString(), $checksum)
}

function Assert-DenseS1 {
    param([object[]]$Records, [int]$Start, [int]$EndExclusive, [string]$Name)

    $expected = $Start
    foreach ($record in $Records) {
        if ($record.Type -ne 1) { continue }
        if ($record.Address -ne $expected -or $record.Data.Length -le 0) {
            throw ('{0} is not dense at ${1:X4}' -f $Name, $expected)
        }
        $expected += $record.Data.Length
    }
    if ($expected -ne $EndExclusive) {
        throw ('{0} ends at ${1:X4}; expected ${2:X4}' -f $Name, $expected, $EndExclusive)
    }
}

function Write-AsciiLines {
    param([string]$Path, [string[]]$Lines)

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllLines($Path, $Lines, [System.Text.Encoding]::ASCII)
}

$workerStart = Get-EquValue $WorkerEqPath 'STR8_JUMP_WORKER_START'
$mutationEnd = Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_END'
$mutationSig = Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG'
$mutationSig0 = Get-EquValue $WorkerEqPath 'STR8_MUTATION_WORKER_SIG0'

$workerRecords = Read-S19 $MutationWorkerS19Path
$payloadRecords = Read-S19 $PayloadS19Path
$workerS1 = @($workerRecords | Where-Object Type -eq 1)
$workerS9 = @($workerRecords | Where-Object Type -eq 9)
$payloadS0 = @($payloadRecords | Where-Object Type -eq 0)
$payloadS1 = @($payloadRecords | Where-Object Type -eq 1)

if (@($workerRecords | Where-Object Type -eq 0).Count -ne 0 -or $workerS9.Count -ne 1) {
    throw 'Mutation worker must have S1 data, one S9, and no S0'
}
if ($workerS9[0].Address -ne $workerStart) {
    throw ('Mutation-worker S9 is ${0:X4}; expected ${1:X4}' -f $workerS9[0].Address, $workerStart)
}
Assert-DenseS1 $workerRecords $workerStart $mutationEnd 'Mutation worker'
if ($payloadS1.Count -eq 0 -or $payloadS1[0].Address -ne 0x8000) {
    throw 'Payload must begin with a nonempty S1 record at $8000'
}
if (($payloadS1[0].Address + $payloadS1[0].Data.Length) -ge 0x9000) {
    throw 'First payload record must not complete the first 4K sector'
}

$badWorkerLines = New-Object System.Collections.Generic.List[string]
foreach ($record in $payloadS0) { $badWorkerLines.Add($record.Line) }
$mutationCount = 0
foreach ($record in $workerS1) {
    [byte[]]$data = $record.Data.Clone()
    if ($mutationSig -ge $record.Address -and $mutationSig -lt ($record.Address + $data.Length)) {
        $offset = $mutationSig - $record.Address
        if ($data[$offset] -ne $mutationSig0) {
            throw ('Mutation-worker signature byte at ${0:X4} is not the expected value' -f $mutationSig)
        }
        $data[$offset] = $data[$offset] -bxor 0x01
        $mutationCount++
    }
    $badWorkerLines.Add((New-S1Line $record.Address $data))
}
if ($mutationCount -ne 1) { throw 'Bad-worker stream did not mutate exactly one identity byte' }
Write-AsciiLines $BadWorkerS19Path $badWorkerLines.ToArray()

$interruptLines = New-Object System.Collections.Generic.List[string]
foreach ($record in $payloadS0) { $interruptLines.Add($record.Line) }
foreach ($record in $workerS1) { $interruptLines.Add($record.Line) }
$interruptLines.Add($payloadS1[0].Line)
Write-AsciiLines $InterruptS19Path $interruptLines.ToArray()

$badCheck = Read-S19 $BadWorkerS19Path
$interruptCheck = Read-S19 $InterruptS19Path
if (@($badCheck | Where-Object Type -eq 9).Count -ne 0 -or
    @($interruptCheck | Where-Object Type -eq 9).Count -ne 0) {
    throw 'Negative streams must not contain S9 records'
}
Assert-DenseS1 $badCheck $workerStart $mutationEnd 'Bad-worker artifact'
$badData = @($badCheck | Where-Object Type -eq 1)
$differenceCount = 0
$differenceAddress = -1
for ($recordIndex = 0; $recordIndex -lt $workerS1.Count; $recordIndex++) {
    if ($badData[$recordIndex].Address -ne $workerS1[$recordIndex].Address -or
        $badData[$recordIndex].Data.Length -ne $workerS1[$recordIndex].Data.Length) {
        throw 'Bad-worker artifact changed worker record geometry'
    }
    for ($byteIndex = 0; $byteIndex -lt $workerS1[$recordIndex].Data.Length; $byteIndex++) {
        if ($badData[$recordIndex].Data[$byteIndex] -ne $workerS1[$recordIndex].Data[$byteIndex]) {
            $differenceCount++
            $differenceAddress = $badData[$recordIndex].Address + $byteIndex
        }
    }
}
if ($differenceCount -ne 1 -or $differenceAddress -ne $mutationSig) {
    throw 'Bad-worker artifact must differ only at the first identity byte'
}
$interruptData = @($interruptCheck | Where-Object Type -eq 1)
$interruptWorker = $interruptData[0..($workerS1.Count - 1)]
Assert-DenseS1 $interruptWorker $workerStart $mutationEnd 'Interruption artifact worker'
for ($recordIndex = 0; $recordIndex -lt $workerS1.Count; $recordIndex++) {
    if ($interruptWorker[$recordIndex].Line -cne $workerS1[$recordIndex].Line) {
        throw 'Interruption artifact mutation worker is not byte-exact'
    }
}
if ($interruptData.Count -ne ($workerS1.Count + 1) -or
    $interruptData[-1].Address -ne 0x8000 -or
    $interruptData[-1].Line -cne $payloadS1[0].Line) {
    throw 'Interruption artifact must end after the exact first payload S1 record'
}

$badHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $BadWorkerS19Path).Hash
$interruptHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $InterruptS19Path).Hash
Write-Host ('BAD WORKER STREAM       = {0}; records={1}; no S9' -f $BadWorkerS19Path, $badCheck.Count)
Write-Host ('BAD WORKER SHA-256      = {0}' -f $badHash)
Write-Host ('INTERRUPT STREAM        = {0}; records={1}; last=${2:X4}+${3:X2}; no S9' -f `
    $InterruptS19Path, $interruptCheck.Count, $payloadS1[0].Address, $payloadS1[0].Data.Length)
Write-Host ('INTERRUPT SHA-256       = {0}' -f $interruptHash)

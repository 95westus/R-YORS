param(
    [string]$ConstantsPath = "STR8/str8-directory-eq.inc",
    [string]$BinPath = "BUILD/bin/himon-str8-v1-layout-preview.bin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EquValue([string]$Name) {
    $pattern = '^\s*' + [Regex]::Escape($Name) + '\s+EQU\s+\$([0-9A-Fa-f]+)\s*$'
    $match = Select-String -Path $ConstantsPath -Pattern $pattern | Select-Object -First 1
    if (-not $match) {
        throw "Constant $Name not found in $ConstantsPath"
    }
    return [Convert]::ToInt32($match.Matches[0].Groups[1].Value, 16)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

$dirBase = Get-EquValue "STR8_DIR_BASE"
$dirEnd = Get-EquValue "STR8_DIR_END"
$recordSize = Get-EquValue "STR8_DIR_RECORD_SIZE"
$recordCount = Get-EquValue "STR8_DIR_RECORD_COUNT"
$offType = Get-EquValue "STR8_DIR_TYPE"
$offReserved = Get-EquValue "STR8_DIR_RESERVED"
$reservedLength = Get-EquValue "STR8_DIR_RESERVED_LEN"
$offDescription = Get-EquValue "STR8_DIR_DESCRIPTION"
$descriptionLength = Get-EquValue "STR8_DIR_DESCRIPTION_LEN"
$offSeal = Get-EquValue "STR8_DIR_SEAL"
$offEntryLo = Get-EquValue "STR8_DIR_ENTRY_LO"
$offEntryHi = Get-EquValue "STR8_DIR_ENTRY_HI"
$offJournal = Get-EquValue "STR8_DIR_JOURNAL"
$journalLength = Get-EquValue "STR8_DIR_JOURNAL_LEN"
$emptyByte = Get-EquValue "STR8_DIR_EMPTY_BYTE"
$sealValue = Get-EquValue "STR8_DIR_SEAL_VALUE"
$bank3 = Get-EquValue "STR8_DIR_BANK3"
$bank3EntryMinHi = Get-EquValue "STR8_DIR_BANK3_ENTRY_MIN_HI"
$bank3EntryMaxHi = Get-EquValue "STR8_DIR_BANK3_ENTRY_MAX_HI"
$pairComplete = Get-EquValue "STR8_DIR_PAIR_COMPLETE"
$pairIllegal = Get-EquValue "STR8_DIR_PAIR_ILLEGAL"
$pairStarted = Get-EquValue "STR8_DIR_PAIR_STARTED"
$pairUnused = Get-EquValue "STR8_DIR_PAIR_UNUSED"
$pairNone = Get-EquValue "STR8_DIR_PAIR_NONE"
$journalInvalid = Get-EquValue "STR8_DIR_JOURNAL_INVALID"
$journalFresh = Get-EquValue "STR8_DIR_JOURNAL_FRESH"
$journalStarted = Get-EquValue "STR8_DIR_JOURNAL_STARTED"
$journalComplete = Get-EquValue "STR8_DIR_JOURNAL_COMPLETE"
$journalFull = Get-EquValue "STR8_DIR_JOURNAL_FULL"
$recordInvalid = Get-EquValue "STR8_DIR_RECORD_INVALID"
$recordEmpty = Get-EquValue "STR8_DIR_RECORD_EMPTY"
$recordIncomplete = Get-EquValue "STR8_DIR_RECORD_INCOMPLETE"
$recordComplete = Get-EquValue "STR8_DIR_RECORD_COMPLETE"

Assert-True ($dirBase -eq 0xFFB0) "Directory base must be FFB0"
Assert-True ($dirEnd -eq 0xFFEF) "Directory end must be FFEF"
Assert-True ($recordSize -eq 0x10 -and $recordCount -eq 4) "Directory must contain four 16-byte records"
Assert-True (($dirBase + ($recordSize * $recordCount) - 1) -eq $dirEnd) "Directory span does not match its record geometry"
Assert-True ($offType -eq 0 -and $offReserved -eq 1 -and $reservedLength -eq 3) "TYPE/RESERVED layout mismatch"
Assert-True ($offDescription -eq 4 -and $descriptionLength -eq 5) "DESCRIPTION layout mismatch"
Assert-True ($offSeal -eq 9 -and $offEntryLo -eq 0x0A -and $offEntryHi -eq 0x0B) "SEAL/ENTRY layout mismatch"
Assert-True ($offJournal -eq 0x0C -and $journalLength -eq 4) "JOURNAL layout mismatch"
Assert-True ($bank3 -eq 3 -and $bank3EntryMinHi -eq 0x80 -and $bank3EntryMaxHi -eq 0xEF) "Bank-3 LOCAL ENTRY policy mismatch"
Assert-True ($pairComplete -eq 0 -and $pairIllegal -eq 1 -and $pairStarted -eq 2 -and $pairUnused -eq 3) "Journal pair encoding mismatch"

function New-Journal([int]$Completed, [bool]$Started) {
    if ($Completed -lt 0 -or $Completed -gt 16 -or ($Started -and $Completed -ge 16)) {
        throw "Invalid journal fixture request completed=$Completed started=$Started"
    }
    [int[]]$pairs = @(3) * 16
    for ($i = 0; $i -lt $Completed; $i++) {
        $pairs[$i] = 0
    }
    if ($Started) {
        $pairs[$Completed] = 2
    }
    return Convert-PairsToJournal $pairs
}

function Convert-PairsToJournal([int[]]$Pairs) {
    Assert-True ($Pairs.Count -eq 16) "Journal fixture must contain 16 pairs"
    [byte[]]$bytes = New-Object byte[] 4
    for ($i = 0; $i -lt 16; $i++) {
        $byteIndex = [Math]::Floor($i / 4)
        $shift = ($i % 4) * 2
        $bytes[$byteIndex] = [byte]($bytes[$byteIndex] -bor (($Pairs[$i] -band 3) -shl $shift))
    }
    return $bytes
}

function Get-JournalResult([byte[]]$Bytes) {
    if ($Bytes.Length -ne 4) {
        throw "Journal must be exactly four bytes"
    }
    $completed = 0
    $openState = 0
    $nextPair = 0
    for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
        $pair = ($Bytes[[Math]::Floor($pairIndex / 4)] -shr (($pairIndex % 4) * 2)) -band 3
        if ($openState -eq 0) {
            switch ($pair) {
                0 { $completed++; continue }
                1 { return [pscustomobject]@{ State = $journalInvalid; Pair = $pairNone } }
                2 { $openState = $journalStarted; $nextPair = $pairIndex; continue }
                3 {
                    $openState = $(if ($completed -eq 0) { $journalFresh } else { $journalComplete })
                    $nextPair = $pairIndex
                    continue
                }
            }
        } elseif ($pair -ne 3) {
            return [pscustomobject]@{ State = $journalInvalid; Pair = $pairNone }
        }
    }
    if ($openState -eq 0) {
        return [pscustomobject]@{ State = $journalFull; Pair = $pairNone }
    }
    return [pscustomobject]@{ State = $openState; Pair = $nextPair }
}

function Test-DescriptionByte([int]$Value) {
    return (($Value -ge [byte][char]'A' -and $Value -le [byte][char]'Z') -or
        ($Value -ge [byte][char]'0' -and $Value -le [byte][char]'9') -or
        $Value -eq [byte][char]'-' -or $Value -eq [byte][char]'_' -or $Value -eq [byte][char]'.')
}

function Get-RecordResult([int]$Bank, [byte[]]$Record) {
    if ($Bank -lt 0 -or $Bank -ge $recordCount -or $Record.Length -ne $recordSize) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "geometry" }
    }
    $nonEmpty = @($Record | Where-Object { $_ -ne $emptyByte }).Count
    if ($nonEmpty -eq 0) {
        return [pscustomobject]@{ State = $recordEmpty; Pair = 0; Reason = "empty" }
    }
    for ($i = 0; $i -lt $reservedLength; $i++) {
        if ($Record[$offReserved + $i] -ne $emptyByte) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "reserved" }
        }
    }
    for ($i = 0; $i -lt $descriptionLength; $i++) {
        if (-not (Test-DescriptionByte $Record[$offDescription + $i])) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "description" }
        }
    }
    if ($Record[$offSeal] -ne $sealValue) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "seal" }
    }
    $entry = ([int]$Record[$offEntryLo]) -bor (([int]$Record[$offEntryHi]) -shl 8)
    if ($Bank -lt 3) {
        if ($entry -ne 0xFFFF) {
            return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "entry" }
        }
    } elseif ($entry -ne 0xFFFF -and ($entry -lt 0x8000 -or $entry -gt 0xEFFF)) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "entry" }
    }
    [byte[]]$journal = $Record[$offJournal..($offJournal + $journalLength - 1)]
    $journalResult = Get-JournalResult $journal
    if ($journalResult.State -eq $journalInvalid -or $journalResult.State -eq $journalFresh) {
        return [pscustomobject]@{ State = $recordInvalid; Pair = $pairNone; Reason = "journal" }
    }
    if ($journalResult.State -eq $journalStarted) {
        return [pscustomobject]@{ State = $recordIncomplete; Pair = $journalResult.Pair; Reason = "started" }
    }
    return [pscustomobject]@{ State = $recordComplete; Pair = $journalResult.Pair; Reason = "complete" }
}

function New-Record([int]$Bank, [string]$Description, [int]$Entry, [byte[]]$Journal) {
    [byte[]]$record = New-Object byte[] $recordSize
    for ($i = 0; $i -lt $record.Length; $i++) {
        $record[$i] = $emptyByte
    }
    $record[$offType] = 0x5A
    [byte[]]$descriptionBytes = [System.Text.Encoding]::ASCII.GetBytes($Description)
    Assert-True ($descriptionBytes.Length -eq $descriptionLength) "Description fixture must be exactly five bytes"
    [Array]::Copy($descriptionBytes, 0, $record, $offDescription, $descriptionLength)
    $record[$offSeal] = $sealValue
    $record[$offEntryLo] = [byte]($Entry -band 0xFF)
    $record[$offEntryHi] = [byte](($Entry -shr 8) -band 0xFF)
    [Array]::Copy($Journal, 0, $record, $offJournal, $journalLength)
    return $record
}

$legalJournalCases = 0
$result = Get-JournalResult (New-Journal 0 $false)
Assert-True ($result.State -eq $journalFresh -and $result.Pair -eq 0) "Fresh journal rejected"
$legalJournalCases++
for ($completed = 0; $completed -lt 16; $completed++) {
    $result = Get-JournalResult (New-Journal $completed $true)
    Assert-True ($result.State -eq $journalStarted -and $result.Pair -eq $completed) "Started journal $completed rejected"
    $legalJournalCases++
}
for ($completed = 1; $completed -lt 16; $completed++) {
    $result = Get-JournalResult (New-Journal $completed $false)
    Assert-True ($result.State -eq $journalComplete -and $result.Pair -eq $completed) "Complete journal $completed rejected"
    $legalJournalCases++
}
$result = Get-JournalResult (New-Journal 16 $false)
Assert-True ($result.State -eq $journalFull -and $result.Pair -eq $pairNone) "Full journal rejected"
$legalJournalCases++

$illegalJournalCases = 0
for ($pairIndex = 0; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 1
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Illegal 01 pair $pairIndex accepted"
    $illegalJournalCases++
}
for ($pairIndex = 1; $pairIndex -lt 16; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 0
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Journal hole at pair $pairIndex accepted"
    $illegalJournalCases++
}
for ($pairIndex = 0; $pairIndex -lt 15; $pairIndex++) {
    [int[]]$pairs = @(3) * 16
    $pairs[$pairIndex] = 2
    $pairs[$pairIndex + 1] = 0
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Completion after START at pair $pairIndex accepted"
    $illegalJournalCases++
    $pairs[$pairIndex + 1] = 2
    $result = Get-JournalResult (Convert-PairsToJournal $pairs)
    Assert-True ($result.State -eq $journalInvalid) "Second START after pair $pairIndex accepted"
    $illegalJournalCases++
}

$recordCases = 0
for ($bank = 0; $bank -lt 3; $bank++) {
    $record = New-Record $bank "STR8N" 0xFFFF (New-Journal 1 $false)
    $result = Get-RecordResult $bank $record
    Assert-True ($result.State -eq $recordComplete -and $result.Pair -eq 1) ("Bank {0} complete record rejected: state={1} pair={2} reason={3}" -f $bank, $result.State, $result.Pair, $result.Reason)
    $recordCases++
}
foreach ($entry in @(0x8000, 0xEFFF, 0xFFFF)) {
    $record = New-Record 3 "A0-_." $entry (New-Journal 1 $false)
    $result = Get-RecordResult 3 $record
    Assert-True ($result.State -eq $recordComplete) ("Bank 3 entry {0:X4} rejected" -f $entry)
    $recordCases++
}
$record = New-Record 3 "STR8N" 0x8000 (New-Journal 5 $true)
$result = Get-RecordResult 3 $record
Assert-True ($result.State -eq $recordIncomplete -and $result.Pair -eq 5) "Incomplete record rejected"
$recordCases++
$record = New-Record 0 "STR8N" 0xFFFF (New-Journal 16 $false)
$result = Get-RecordResult 0 $record
Assert-True ($result.State -eq $recordComplete -and $result.Pair -eq $pairNone) "Exhausted complete record rejected"
$recordCases++

$goodRecord = New-Record 0 "STR8N" 0xFFFF (New-Journal 1 $false)
for ($i = 0; $i -lt $reservedLength; $i++) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offReserved + $i] = 0xFE
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) "Programmed reserved byte accepted"
    $recordCases++
}
foreach ($badCharacter in @([byte][char]'a', [byte][char]' ', [byte][char]'/', 0x7F, 0xFF)) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offDescription] = $badCharacter
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bad description byte {0:X2} accepted" -f $badCharacter)
    $recordCases++
}
foreach ($badSeal in @(0xFF, 0xFC, 0xA5, 0x00)) {
    [byte[]]$bad = $goodRecord.Clone()
    $bad[$offSeal] = $badSeal
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bad seal {0:X2} accepted" -f $badSeal)
    $recordCases++
}
foreach ($entry in @(0x0000, 0x8000, 0xFFFE)) {
    $bad = New-Record 0 "STR8N" $entry (New-Journal 1 $false)
    Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) ("Bank 0 entry {0:X4} accepted" -f $entry)
    $recordCases++
}
foreach ($entry in @(0x7FFF, 0xF000, 0xFF00)) {
    $bad = New-Record 3 "STR8N" $entry (New-Journal 1 $false)
    Assert-True ((Get-RecordResult 3 $bad).State -eq $recordInvalid) ("Bank 3 entry {0:X4} accepted" -f $entry)
    $recordCases++
}
$bad = New-Record 0 "STR8N" 0xFFFF (New-Journal 0 $false)
Assert-True ((Get-RecordResult 0 $bad).State -eq $recordInvalid) "Sealed record with fresh journal accepted"
$recordCases++
[byte[]]$partial = New-Object byte[] $recordSize
for ($i = 0; $i -lt $partial.Length; $i++) { $partial[$i] = $emptyByte }
[Array]::Copy((New-Journal 0 $true), 0, $partial, $offJournal, $journalLength)
Assert-True ((Get-RecordResult 0 $partial).State -eq $recordInvalid) "Partial first-install descriptor accepted"
$recordCases++

if (-not (Test-Path -LiteralPath $BinPath)) {
    throw "V1 preview BIN not found: $BinPath"
}
[byte[]]$bin = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $BinPath).Path)
Assert-True ($bin.Length -eq 0x8000) "V1 preview BIN must be exactly 32K"
for ($bank = 0; $bank -lt $recordCount; $bank++) {
    $offset = ($dirBase - 0x8000) + ($bank * $recordSize)
    [byte[]]$record = $bin[$offset..($offset + $recordSize - 1)]
    $result = Get-RecordResult $bank $record
    Assert-True ($result.State -eq $recordEmpty -and $result.Pair -eq 0) "Preview Bank $bank record is not exactly empty"
}

Write-Host ("STR8 V1 DIRECTORY       = {0:X4}-{1:X4}; {2} x `${3:X}-byte records" -f $dirBase, $dirEnd, $recordCount, $recordSize)
Write-Host ("LEGAL JOURNAL FIXTURES  = {0}" -f $legalJournalCases)
Write-Host ("ILLEGAL JOURNAL FIXTURES= {0}" -f $illegalJournalCases)
Write-Host ("RECORD FIXTURES         = {0}" -f $recordCases)
Write-Host ("PREVIEW EMPTY RECORDS   = {0}" -f $recordCount)
Write-Host "STR8 V1 DIRECTORY CHECK = PASS"

param(
    [string]$HimonMapPath = "BUILD/map/himon-rom-c000.map",
    [string]$HimonS19Path = "BUILD/s19/himon-rom-c000.s19",
    [string]$Str8MapPath = "BUILD/map/str8-f000.map",
    [string]$Str8S19Path = "BUILD/s19/str8-f000.s19",
    [string]$WorkerMapPath = "BUILD/map/str8-worker-0200.map",
    [string]$WorkerS19Path = "BUILD/s19/str8-worker-0200.s19",
    [string]$AsmMapPath = "",
    [string]$AsmS19Path = "",
    [string]$ApPackageBinPath = "",
    [int]$ApPackageAddress = 0,
    [int]$ApPackageLimit = 0xC000,
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin",
    [switch]$V1LayoutPreview,
    [switch]$V1Flashable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($V1LayoutPreview -and $V1Flashable) {
    throw "V1LayoutPreview and V1Flashable are mutually exclusive"
}

function Resolve-ArtifactPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return $Path
    }

    $alt = $Path.Replace("\s19\", "\map\").Replace("/s19/", "/map/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    $alt = $Path.Replace("\map\", "\s19\").Replace("/map/", "/s19/")
    if (Test-Path -LiteralPath $alt) {
        return $alt
    }

    throw "Required file not found: $Path"
}

function Get-SymbolAddress {
    param(
        [Parameter(Mandatory = $true)][string]$MapPath,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = "^\s*([0-9A-Fa-f]{8})\s+$([Regex]::Escape($Name))$"
    $line = Select-String -Path $MapPath -Pattern $pattern | Select-Object -First 1
    if (-not $line) {
        throw "Missing symbol '$Name' in $MapPath"
    }
    return [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
}

function Read-HexByte {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$Offset
    )

    return [Convert]::ToByte($Text.Substring($Offset, 2), 16)
}

function Import-S19IntoImage {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Image,
        [Parameter(Mandatory = $true)][int]$BankOffset
    )

    foreach ($rawLine in Get-Content -Path $Path) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if (-not $line.StartsWith("S")) {
            throw "Bad S-record in ${Path}: $line"
        }

        $type = $line.Substring(1, 1)
        if ($type -notin @("1", "2", "3")) {
            continue
        }

        $count = Read-HexByte -Text $line -Offset 2
        $addrBytes = @{ "1" = 2; "2" = 3; "3" = 4 }[$type]
        $expectedChars = 4 + ($count * 2)
        if ($line.Length -lt $expectedChars) {
            throw "Short S-record in ${Path}: $line"
        }

        $sum = $count
        $addr = 0
        $pos = 4
        for ($i = 0; $i -lt $addrBytes; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $addr = (($addr -shl 8) -bor $b)
            $pos += 2
        }

        $dataCount = $count - $addrBytes - 1
        for ($i = 0; $i -lt $dataCount; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $absolute = $addr + $i
            if ($absolute -ge 0x8000 -and $absolute -lt 0x10000) {
                $offset = $BankOffset + ($absolute - 0x8000)
                if ($Image[$offset] -ne 0xFF -and $Image[$offset] -ne $b) {
                    throw ("Conflicting bytes at {0:X4}: existing {1:X2}, new {2:X2} from {3}" -f $absolute, $Image[$offset], $b, $Path)
                }
                $Image[$offset] = $b
            }
            $pos += 2
        }

        $checksum = Read-HexByte -Text $line -Offset $pos
        $sum += $checksum
        if (($sum -band 0xFF) -ne 0xFF) {
            throw "Checksum failure in ${Path}: $line"
        }
    }
}

function Import-S19RelocatedIntoImage {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Image,
        [Parameter(Mandatory = $true)][int]$BankOffset,
        [Parameter(Mandatory = $true)][int]$RunStart,
        [Parameter(Mandatory = $true)][int]$StoreStart,
        [Parameter(Mandatory = $true)][int]$StoreSize
    )

    [bool[]]$seen = New-Object bool[] $StoreSize
    foreach ($rawLine in Get-Content -Path $Path) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0) {
            continue
        }
        if (-not $line.StartsWith("S")) {
            throw "Bad S-record in ${Path}: $line"
        }

        $type = $line.Substring(1, 1)
        if ($type -notin @("1", "2", "3")) {
            continue
        }

        $count = Read-HexByte -Text $line -Offset 2
        $addrBytes = @{ "1" = 2; "2" = 3; "3" = 4 }[$type]
        $expectedChars = 4 + ($count * 2)
        if ($line.Length -lt $expectedChars) {
            throw "Short S-record in ${Path}: $line"
        }

        $sum = $count
        $addr = 0
        $pos = 4
        for ($i = 0; $i -lt $addrBytes; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $addr = (($addr -shl 8) -bor $b)
            $pos += 2
        }

        $dataCount = $count - $addrBytes - 1
        for ($i = 0; $i -lt $dataCount; $i++) {
            $b = Read-HexByte -Text $line -Offset $pos
            $sum += $b
            $runAbsolute = $addr + $i
            $delta = $runAbsolute - $RunStart
            if ($delta -lt 0 -or $delta -ge $StoreSize) {
                throw ("Worker byte at run address {0:X4} is outside configured worker range {1:X4}+{2:X}" -f $runAbsolute, $RunStart, $StoreSize)
            }
            if ($seen[$delta]) {
                throw ("Duplicate worker byte at run address {0:X4} in {1}" -f $runAbsolute, $Path)
            }
            $seen[$delta] = $true
            $storeAbsolute = $StoreStart + $delta
            if ($storeAbsolute -lt 0x8000 -or $storeAbsolute -ge 0x10000) {
                throw ("Worker storage address {0:X4} is outside ROM bank image" -f $storeAbsolute)
            }
            $offset = $BankOffset + ($storeAbsolute - 0x8000)
            if ($Image[$offset] -ne 0xFF -and $Image[$offset] -ne $b) {
                throw ("Conflicting bytes at worker storage {0:X4}: existing {1:X2}, new {2:X2} from {3}" -f $storeAbsolute, $Image[$offset], $b, $Path)
            }
            $Image[$offset] = $b
            $pos += 2
        }

        $checksum = Read-HexByte -Text $line -Offset $pos
        $sum += $checksum
        if (($sum -band 0xFF) -ne 0xFF) {
            throw "Checksum failure in ${Path}: $line"
        }
    }
    for ($i = 0; $i -lt $seen.Length; $i++) {
        if (-not $seen[$i]) {
            throw ("Worker S19 is missing run address {0:X4}: {1}" -f ($RunStart + $i), $Path)
        }
    }
}

function Import-BinIntoImage {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Image,
        [Parameter(Mandatory = $true)][int]$BankOffset,
        [Parameter(Mandatory = $true)][int]$StoreStart
    )

    [byte[]]$payload = [System.IO.File]::ReadAllBytes($Path)
    if ($StoreStart -lt 0x8000 -or ($StoreStart + $payload.Length) -gt 0x10000) {
        throw ("Binary payload {0} at {1:X4}+{2:X} is outside ROM bank image" -f $Path, $StoreStart, $payload.Length)
    }

    for ($i = 0; $i -lt $payload.Length; $i++) {
        $absolute = $StoreStart + $i
        $offset = $BankOffset + ($absolute - 0x8000)
        $b = $payload[$i]
        if ($Image[$offset] -ne 0xFF -and $Image[$offset] -ne $b) {
            throw ("Conflicting bytes at {0:X4}: existing {1:X2}, new {2:X2} from {3}" -f $absolute, $Image[$offset], $b, $Path)
        }
        $Image[$offset] = $b
    }
}

function Get-ApPackageBodyBase {
    param([Parameter(Mandatory = $true)][byte[]]$Package)

    if ($Package.Length -lt 5 -or $Package[0] -ne [byte][char]'A' -or $Package[1] -ne [byte][char]'P') {
        throw "AP package header is missing"
    }

    $totalLength = [int]$Package[3] -bor ([int]$Package[4] -shl 8)
    if ($totalLength -ne $Package.Length) {
        throw ("AP package length field is {0:X4}; file length is {1:X4}" -f $totalLength, $Package.Length)
    }

    $pos = 5
    while ($pos -lt $Package.Length) {
        $tag = [char]$Package[$pos]
        if ($tag -eq 'B') {
            break
        }
        if (($pos + 1) -ge $Package.Length) {
            throw "AP package section is truncated"
        }
        $sectionLength = [int]$Package[$pos + 1]
        if (($pos + 2 + $sectionLength) -gt $Package.Length) {
            throw "AP package section extends beyond file length"
        }
        if ($tag -eq 'S') {
            if ($sectionLength -lt 0x0B) {
                throw "AP seal section is too short"
            }
            return ([int]$Package[$pos + 3] -bor ([int]$Package[$pos + 4] -shl 8))
        }
        $pos += 2 + $sectionLength
    }

    throw "AP package seal section not found"
}

function Set-VectorByte {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Image,
        [Parameter(Mandatory = $true)][int]$Offset,
        [Parameter(Mandatory = $true)][byte]$Value
    )

    if ($Image[$Offset] -ne 0xFF -and $Image[$Offset] -ne $Value) {
        throw ("Vector byte conflict at file offset {0:X4}: existing {1:X2}, new {2:X2}" -f $Offset, $Image[$Offset], $Value)
    }
    $Image[$Offset] = $Value
}

$HimonMapPath = Resolve-ArtifactPath -Path $HimonMapPath
$HimonS19Path = Resolve-ArtifactPath -Path $HimonS19Path
$Str8MapPath = Resolve-ArtifactPath -Path $Str8MapPath
$Str8S19Path = Resolve-ArtifactPath -Path $Str8S19Path
$WorkerMapPath = Resolve-ArtifactPath -Path $WorkerMapPath
$WorkerS19Path = Resolve-ArtifactPath -Path $WorkerS19Path
if ($AsmMapPath) {
    $AsmMapPath = Resolve-ArtifactPath -Path $AsmMapPath
}
if ($AsmS19Path) {
    $AsmS19Path = Resolve-ArtifactPath -Path $AsmS19Path
}
if ($ApPackageBinPath) {
    $ApPackageBinPath = Resolve-ArtifactPath -Path $ApPackageBinPath
}

$himonStart = Get-SymbolAddress -MapPath $HimonMapPath -Name "START"
$himonImageId = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIMON_IMAGE_ID"
$himonImageSig0 = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIMON_IMAGE_SIG0_VALUE"
$himonImageSig1 = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIMON_IMAGE_SIG1_VALUE"
$himonImageSig2 = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIMON_IMAGE_SIG2_VALUE"
$himonImageSig3 = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIMON_IMAGE_SIG3_VALUE"
$himonNmi = Get-SymbolAddress -MapPath $HimonMapPath -Name "SYS_VEC_ENTRY_NMI"
$himonIrq = Get-SymbolAddress -MapPath $HimonMapPath -Name "SYS_VEC_ENTRY_IRQ_MASTER"
$himonEnd = Get-SymbolAddress -MapPath $HimonMapPath -Name "_END_DATA"
$himonApImportLink = Get-SymbolAddress -MapPath $HimonMapPath -Name "HIM_AP_IMPORT_LINK"
$flashRamWorker = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_RAM_WORKER"
$flashWorkerCodeTrayBase = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_WORKER_CODE_TRAY_BASE"
$flashWorkerCodeTrayEnd = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_WORKER_CODE_TRAY_END"
$flashSectorMirrorBase = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_SECTOR_MIRROR_BASE"
$flashSectorMirrorEnd = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_SECTOR_MIRROR_END"
$flashTransientTrayBase = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_TRANSIENT_TRAY_BASE"
$flashTransientTrayEnd = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_TRANSIENT_TRAY_END"
$flashWorkerSize = Get-SymbolAddress -MapPath $HimonMapPath -Name "FLASH_WORKER_SIZE"
$himonBankJumpSig0 = Get-SymbolAddress -MapPath $HimonMapPath -Name "STR8_BANK_JUMP_SIG0"
$himonBankJumpSig1 = Get-SymbolAddress -MapPath $HimonMapPath -Name "STR8_BANK_JUMP_SIG1"
$himonBankLastJump = Get-SymbolAddress -MapPath $HimonMapPath -Name "STR8_BANK_LAST_JUMP"
$himonBankCount = Get-SymbolAddress -MapPath $HimonMapPath -Name "STR8_BANK_COUNT"

$str8Start = Get-SymbolAddress -MapPath $Str8MapPath -Name "START"
$str8WorkerService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RUN_WORKER_SERVICE"
$str8RetiredF006 = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RETIRED_F006"
$str8RecordService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_ENTRY"
$str8RecordServiceBody = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_BODY"
$str8RecordSignature = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_SIGNATURE"
$str8BankSelectService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_SELECT_SERVICE_ENTRY"
$str8BankSelectBody = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_SELECT_SERVICE_BODY"
$str8BankSelectRam = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_SELECT_RAM"
$str8RecordOp = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_OP"
$str8RecordExpected = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_EXPECTED"
$str8RecordDataBuffer = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_DATA_BUF"
$str8Nmi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_IVY_ENTRY_NMI"
$str8Irq = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_IVY_ENTRY_IRQ_MASTER"
$str8End = Get-SymbolAddress -MapPath $Str8MapPath -Name "_END_DATA"

$workerRunStart = Get-SymbolAddress -MapPath $WorkerMapPath -Name "START"
$workerBankSelectService = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8W_BANK_SELECT_SERVICE"
$workerRunEnd = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_WORKER_END"
$workerStateBase = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_STATE_BASE"
$workerStateEnd = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_STATE_END"
$workerJumpMode = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_COPY_MODE_JUMP_BANK"
$workerJumpBank = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_JUMP_BANK"
$workerJumpVecLo = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_JUMP_VEC_LO"
$workerJumpVecHi = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_JUMP_VEC_HI"
$workerJumpStatus = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_JUMP_STATUS"
$workerBankJumpSig0 = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_BANK_JUMP_SIG0"
$workerBankJumpSig1 = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_BANK_JUMP_SIG1"
$workerBankLastJump = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_BANK_LAST_JUMP"
$workerBankCount = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_BANK_COUNT"
$workerSize = $workerRunEnd - $workerRunStart
$legacyWorkerStoreEndExclusive = 0xFFF0
$legacyWorkerStoreStart = $legacyWorkerStoreEndExclusive - $workerSize
$legacyWorkerGapMin = 0x0200
$legacyWorkerGap = $legacyWorkerStoreStart - $str8End
$v1DirectoryStart = 0xFFB0
$v1DirectoryEndExclusive = 0xFFF0
$v1DirectorySize = 0x0040
$v1WorkerStoreEndExclusive = $v1DirectoryStart
$v1WorkerStoreStart = $v1WorkerStoreEndExclusive - $workerSize
$v1WorkerGapMin = 0x0040
$v1WorkerGap = $v1WorkerStoreStart - $str8End

if ($V1LayoutPreview -or $V1Flashable) {
    if ([System.IO.Path]::GetFileName($BinPath) -notmatch 'v1-layout-preview') {
        if ($V1LayoutPreview) {
            throw "V1 layout preview output name must contain 'v1-layout-preview'"
        }
    }
    $workerStoreEndExclusive = $v1WorkerStoreEndExclusive
    $workerStoreStart = $v1WorkerStoreStart
    $str8WorkerGapMin = $v1WorkerGapMin
    if ($V1Flashable) {
        $layoutMode = "V1 FLASHABLE"
    } else {
        $layoutMode = "V1 LAYOUT PREVIEW; NOT FLASHABLE"
    }
} else {
    $workerStoreEndExclusive = $legacyWorkerStoreEndExclusive
    $workerStoreStart = $legacyWorkerStoreStart
    $str8WorkerGapMin = $legacyWorkerGapMin
    $layoutMode = "LEGACY PROVEN IMAGE"
}
$workerStoreSize = $workerSize
$str8WorkerGap = $workerStoreStart - $str8End
$str8WorkerStoreLo = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_STORE_LO"
$str8WorkerStoreHi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_STORE_HI"
$str8WorkerCopyLenLo = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_COPY_LEN_LO"
$str8WorkerCopyLenHi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_COPY_LEN_HI"
$str8WorkerTraySize = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_TRAY_SIZE"
$str8WorkerTrayEnd = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_TRAY_END"
$str8StateBase = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_STATE_BASE"
$str8StateEnd = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_STATE_END"
$str8JumpMode = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_COPY_MODE_JUMP_BANK"
$str8JumpBank = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_JUMP_BANK"
$str8JumpVecLo = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_JUMP_VEC_LO"
$str8JumpVecHi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_JUMP_VEC_HI"
$str8JumpStatus = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_JUMP_STATUS"
$str8BankJumpSig0 = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_JUMP_SIG0"
$str8BankJumpSig1 = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_JUMP_SIG1"
$str8BankLastJump = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_LAST_JUMP"
$str8BankJumpSig0Value = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_JUMP_SIG0_VALUE"
$str8BankJumpSig1Value = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_JUMP_SIG1_VALUE"
$str8BankCount = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_COUNT"
$str8BankNone = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_BANK_NONE"
$str8WorkerStoreStart = (($str8WorkerStoreHi -band 0xFF) -shl 8) -bor ($str8WorkerStoreLo -band 0xFF)
$str8WorkerCopyLen = (($str8WorkerCopyLenHi -band 0xFF) -shl 8) -bor ($str8WorkerCopyLenLo -band 0xFF)
$asmBase = $null
$asmStart = $null
$asmEnd = $null
$apPackageStart = $null
$apPackageLength = 0
$apPackageBodyBase = $null

if ($AsmMapPath) {
    $asmBase = Get-SymbolAddress -MapPath $AsmMapPath -Name "_BEG_CODE"
    $asmStart = Get-SymbolAddress -MapPath $AsmMapPath -Name "START"
    $asmEnd = Get-SymbolAddress -MapPath $AsmMapPath -Name "_END_DATA"
}

if ($ApPackageBinPath) {
    [byte[]]$apPackageBytes = [System.IO.File]::ReadAllBytes($ApPackageBinPath)
    $apPackageLength = $apPackageBytes.Length
    $apPackageBodyBase = Get-ApPackageBodyBase -Package $apPackageBytes
    if ($ApPackageAddress -ne 0) {
        $apPackageStart = $ApPackageAddress
    } elseif ($asmEnd -ne $null) {
        $apPackageStart = $asmEnd
    } else {
        throw "AP package address was not supplied and ASM _END_DATA is unavailable"
    }
}

if ($himonStart -ne 0xC000) {
    throw ("HIMON START is {0:X4}; expected C000" -f $himonStart)
}
if ($himonImageId -ne 0xC003) {
    throw ("HIMON image identity is {0:X4}; expected stable marker C003" -f $himonImageId)
}
if ($himonEnd -gt 0xF000) {
    throw ("HIMON crosses STR8 sector at F000; _END_DATA={0:X4}" -f $himonEnd)
}
if ($himonApImportLink -lt $himonStart -or $himonApImportLink -ge $himonEnd) {
    throw ("HIMON AP import linker {0:X4} is outside HIMON {1:X4}-{2:X4}" -f $himonApImportLink, $himonStart, ($himonEnd - 1))
}
if ($str8Start -ne 0xF000) {
    throw ("STR8 START is {0:X4}; expected F000" -f $str8Start)
}
if ($str8WorkerService -ne 0xF003) {
    throw ("STR8 worker service is {0:X4}; expected stable entry F003" -f $str8WorkerService)
}
if ($str8RetiredF006 -ne 0xF006) {
    throw ("STR8 retired AP-link slot is {0:X4}; expected stable slot F006" -f $str8RetiredF006)
}
if ($str8RecordService -ne 0xF009) {
    throw ("STR8 record service is {0:X4}; expected stable entry F009" -f $str8RecordService)
}
if ($str8RecordSignature -ne 0xF00C) {
    throw ("STR8 record-service signature is {0:X4}; expected F00C" -f $str8RecordSignature)
}
if ($str8BankSelectService -ne 0xF010) {
    throw ("STR8 bank-select service is {0:X4}; expected stable entry F010" -f $str8BankSelectService)
}
if ($str8BankSelectRam -ne 0x0203 -or $workerBankSelectService -ne $str8BankSelectRam) {
    throw ("STR8 bank-select RAM entry is resident/worker {0:X4}/{1:X4}; expected 0203/0203" -f $str8BankSelectRam, $workerBankSelectService)
}
if ($str8RecordOp -ne 0x7E95 -or $str8RecordExpected -ne 0x7EA8) {
    throw ("STR8 record request/result block is {0:X4}-{1:X4}; expected 7E95-7EA8" -f $str8RecordOp, $str8RecordExpected)
}
if ($str8RecordDataBuffer -ne 0x7B00) {
    throw ("STR8 record data buffer is {0:X4}; expected 7B00" -f $str8RecordDataBuffer)
}
if ($str8Nmi -lt 0xF000 -or $str8Nmi -ge 0x10000) {
    throw ("STR8 IVY NMI entry is {0:X4}; expected F000-FFFF" -f $str8Nmi)
}
if ($str8Irq -lt 0xF000 -or $str8Irq -ge 0x10000) {
    throw ("STR8 IVY IRQ entry is {0:X4}; expected F000-FFFF" -f $str8Irq)
}
if (-not $V1LayoutPreview -and -not $V1Flashable) {
    if ($str8End -gt $legacyWorkerStoreStart) {
        throw ("STR8 crosses legacy worker storage at {0:X4}; _END_DATA={1:X4}" -f $legacyWorkerStoreStart, $str8End)
    }
    if ($legacyWorkerGap -lt $legacyWorkerGapMin) {
        throw ("STR8 legacy resident/worker gap is {0:X}; minimum is {1:X} ({2:X4}-{3:X4})" -f $legacyWorkerGap, $legacyWorkerGapMin, $str8End, ($legacyWorkerStoreStart - 1))
    }
}
if (($v1DirectoryEndExclusive - $v1DirectoryStart) -ne $v1DirectorySize) {
    throw ("STR8 V1 directory is {0:X4}-{1:X4}; expected exact size {2:X}" -f $v1DirectoryStart, ($v1DirectoryEndExclusive - 1), $v1DirectorySize)
}
if ($v1WorkerStoreEndExclusive -ne $v1DirectoryStart) {
    throw ("STR8 V1 worker ceiling is {0:X4}; expected directory start {1:X4}" -f $v1WorkerStoreEndExclusive, $v1DirectoryStart)
}
if ($v1DirectoryEndExclusive -ne 0xFFF0) {
    throw ("STR8 V1 directory end is {0:X4}; expected config start FFF0" -f $v1DirectoryEndExclusive)
}
if ($v1WorkerStoreStart -lt $str8End) {
    throw ("STR8 V1 resident crosses future worker storage at {0:X4}; _END_DATA={1:X4}" -f $v1WorkerStoreStart, $str8End)
}
if ($v1WorkerGap -lt $v1WorkerGapMin) {
    throw ("STR8 V1 resident/worker gap is {0:X}; minimum is {1:X} ({2:X4}-{3:X4})" -f $v1WorkerGap, $v1WorkerGapMin, $str8End, ($v1WorkerStoreStart - 1))
}
if ($str8End -gt $workerStoreStart) {
    throw ("STR8 crosses selected worker storage at {0:X4}; _END_DATA={1:X4}" -f $workerStoreStart, $str8End)
}
if ($str8WorkerGap -lt $str8WorkerGapMin) {
    throw ("STR8 selected resident/worker gap is {0:X}; minimum is {1:X} ({2:X4}-{3:X4})" -f $str8WorkerGap, $str8WorkerGapMin, $str8End, ($workerStoreStart - 1))
}
if ($workerRunStart -ne 0x0200) {
    throw ("STR8 worker START is {0:X4}; expected 0200" -f $workerRunStart)
}
if ($str8WorkerTraySize -ne 0x0800) {
    throw ("STR8 worker tray size is {0:X}; expected 800 for RAM tray 0200-09FF" -f $str8WorkerTraySize)
}
if ($str8WorkerTrayEnd -ne 0x09FF) {
    throw ("STR8 worker tray end is {0:X4}; expected 09FF" -f $str8WorkerTrayEnd)
}
if (($workerRunStart + $str8WorkerTraySize - 1) -ne $str8WorkerTrayEnd) {
    throw ("STR8 worker tray {0:X4}+{1:X} ends at {2:X4}; expected {3:X4}" -f $workerRunStart, $str8WorkerTraySize, ($workerRunStart + $str8WorkerTraySize - 1), $str8WorkerTrayEnd)
}
if ($str8StateBase -ne 0x1FE9) {
    throw ("STR8 state base is {0:X4}; expected 1FE9" -f $str8StateBase)
}
if ($str8StateEnd -ne 0x1FFF) {
    throw ("STR8 state end is {0:X4}; expected 1FFF" -f $str8StateEnd)
}
if ($workerStateBase -ne $str8StateBase -or $workerStateEnd -ne $str8StateEnd) {
    throw ("STR8 worker state board {0:X4}-{1:X4}; expected resident {2:X4}-{3:X4}" -f $workerStateBase, $workerStateEnd, $str8StateBase, $str8StateEnd)
}
if ($str8JumpMode -ne 0x08 -or $workerJumpMode -ne $str8JumpMode) {
    throw ("STR8 J mode resident/worker is {0:X2}/{1:X2}; expected 08/08" -f $str8JumpMode, $workerJumpMode)
}
if ($str8JumpBank -ne 0x1FF2 -or $str8JumpVecLo -ne 0x1FF3 -or $str8JumpVecHi -ne 0x1FF4 -or $str8JumpStatus -ne 0x1FF5) {
    throw ("STR8 J state is {0:X4}/{1:X4}/{2:X4}/{3:X4}; expected 1FF2/1FF3/1FF4/1FF5" -f $str8JumpBank, $str8JumpVecLo, $str8JumpVecHi, $str8JumpStatus)
}
if ($workerJumpBank -ne $str8JumpBank -or $workerJumpVecLo -ne $str8JumpVecLo -or $workerJumpVecHi -ne $str8JumpVecHi -or $workerJumpStatus -ne $str8JumpStatus) {
    throw ("STR8 worker J state {0:X4}/{1:X4}/{2:X4}/{3:X4} differs from resident" -f $workerJumpBank, $workerJumpVecLo, $workerJumpVecHi, $workerJumpStatus)
}
if ($str8BankJumpSig0 -ne 0x1FFD -or $str8BankJumpSig1 -ne 0x1FFE -or $str8BankLastJump -ne 0x1FFF) {
    throw ("STR8 Bank Jump Record is {0:X4}/{1:X4}/{2:X4}; expected 1FFD/1FFE/1FFF" -f $str8BankJumpSig0, $str8BankJumpSig1, $str8BankLastJump)
}
if ($str8BankJumpSig0Value -ne 0x42 -or $str8BankJumpSig1Value -ne 0x4A -or $str8BankNone -ne 0xFF) {
    throw ("STR8 Bank Jump Record values are {0:X2}/{1:X2}/{2:X2}; expected 42/4A/FF" -f $str8BankJumpSig0Value, $str8BankJumpSig1Value, $str8BankNone)
}
if ($str8BankCount -ne 0x04 -or $workerBankCount -ne $str8BankCount -or $himonBankCount -ne $str8BankCount) {
    throw ("Bank count STR8/worker/HIMON is {0:X2}/{1:X2}/{2:X2}; expected 04/04/04" -f $str8BankCount, $workerBankCount, $himonBankCount)
}
if ($workerBankJumpSig0 -ne $str8BankJumpSig0 -or $workerBankJumpSig1 -ne $str8BankJumpSig1 -or $workerBankLastJump -ne $str8BankLastJump) {
    throw ("STR8 worker Bank Jump Record {0:X4}/{1:X4}/{2:X4} differs from resident" -f $workerBankJumpSig0, $workerBankJumpSig1, $workerBankLastJump)
}
if ($himonBankJumpSig0 -ne $str8BankJumpSig0 -or $himonBankJumpSig1 -ne $str8BankJumpSig1 -or $himonBankLastJump -ne $str8BankLastJump) {
    throw ("HIMON Bank Jump Record {0:X4}/{1:X4}/{2:X4} differs from STR8" -f $himonBankJumpSig0, $himonBankJumpSig1, $himonBankLastJump)
}
if ($flashWorkerCodeTrayBase -ne $workerRunStart -or $flashWorkerCodeTrayEnd -ne $str8WorkerTrayEnd) {
    throw ("Flash worker code tray {0:X4}-{1:X4}; expected STR8 tray {2:X4}-{3:X4}" -f $flashWorkerCodeTrayBase, $flashWorkerCodeTrayEnd, $workerRunStart, $str8WorkerTrayEnd)
}
if ($flashRamWorker -lt $flashWorkerCodeTrayBase -or (($flashRamWorker + $flashWorkerSize - 1) -gt $flashWorkerCodeTrayEnd)) {
    throw ("Flash RAM worker {0:X4}+{1:X} does not fit in code tray {2:X4}-{3:X4}" -f $flashRamWorker, $flashWorkerSize, $flashWorkerCodeTrayBase, $flashWorkerCodeTrayEnd)
}
if ($flashSectorMirrorBase -ne 0x0A00 -or $flashSectorMirrorEnd -ne 0x19FF) {
    throw ("Flash sector mirror {0:X4}-{1:X4}; expected 0A00-19FF" -f $flashSectorMirrorBase, $flashSectorMirrorEnd)
}
if ($flashTransientTrayBase -ne $flashSectorMirrorBase -or $flashTransientTrayEnd -ne $flashSectorMirrorEnd) {
    throw ("Flash transient tray alias {0:X4}-{1:X4}; expected sector mirror {2:X4}-{3:X4}" -f $flashTransientTrayBase, $flashTransientTrayEnd, $flashSectorMirrorBase, $flashSectorMirrorEnd)
}
if ($workerSize -gt $str8WorkerTraySize) {
    throw ("STR8 worker size is {0:X}; exceeds RAM tray 0200-09FF size {1:X}" -f $workerSize, $str8WorkerTraySize)
}
if ($workerSize -le 0 -or $workerSize -gt $workerStoreSize) {
    throw ("STR8 worker size is {0:X}; expected 1..{1:X}" -f $workerSize, $workerStoreSize)
}
if (($workerStoreStart + $workerSize) -gt $workerStoreEndExclusive) {
    throw ("STR8 worker storage {0:X4}-{1:X4} crosses config/vector area" -f $workerStoreStart, ($workerStoreStart + $workerSize - 1))
}
if ($str8WorkerStoreStart -ne $workerStoreStart) {
    throw ("STR8 worker copy source constant is {0:X4}; expected {1:X4}. Update STR8_WORKER_STORE_LO/HI." -f $str8WorkerStoreStart, $workerStoreStart)
}
if ($str8WorkerCopyLen -ne $workerSize) {
    throw ("STR8 worker copy length constant is {0:X}; expected {1:X}. Update STR8_WORKER_COPY_LEN_LO/HI." -f $str8WorkerCopyLen, $workerSize)
}
if ($AsmS19Path -and -not $AsmMapPath) {
    throw "ASM S19 was supplied without an ASM map"
}
if ($AsmMapPath) {
    if ($asmBase -ne 0x8000) {
        throw ("ASM-F2 _BEG_CODE is {0:X4}; expected 8000" -f $asmBase)
    }
    if ($asmStart -lt $asmBase -or $asmStart -ge $asmEnd) {
        throw ("ASM-F2 START {0:X4} is outside occupied range {1:X4}-{2:X4}" -f $asmStart, $asmBase, $asmEnd)
    }
    if ($asmEnd -gt 0xC000) {
        throw ("ASM-F2 crosses HIMON sector at C000; _END_DATA={0:X4}" -f $asmEnd)
    }
}
if ($ApPackageBinPath) {
    if ($apPackageStart -lt 0x8000 -or ($apPackageStart + $apPackageLength) -gt $ApPackageLimit) {
        throw ("AP package at {0:X4}+{1:X} crosses limit {2:X4}" -f $apPackageStart, $apPackageLength, $ApPackageLimit)
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BinPath) | Out-Null

$bankOffset = 0
[byte[]]$bin = New-Object byte[] 32768
for ($i = 0; $i -lt $bin.Length; $i++) {
    $bin[$i] = 0xFF
}

if ($AsmS19Path) {
    Import-S19IntoImage -Path $AsmS19Path -Image $bin -BankOffset $bankOffset
}
if ($ApPackageBinPath) {
    Import-BinIntoImage -Path $ApPackageBinPath -Image $bin -BankOffset $bankOffset -StoreStart $apPackageStart
}
Import-S19IntoImage -Path $HimonS19Path -Image $bin -BankOffset $bankOffset
Import-S19RelocatedIntoImage -Path $WorkerS19Path -Image $bin -BankOffset $bankOffset -RunStart $workerRunStart -StoreStart $workerStoreStart -StoreSize $workerStoreSize
Import-S19IntoImage -Path $Str8S19Path -Image $bin -BankOffset $bankOffset

$himonImageIdOffset = $bankOffset + ($himonImageId - 0x8000)
[byte[]]$expectedHimonImageId = @(
    $himonImageSig0, $himonImageSig1, $himonImageSig2, $himonImageSig3
)
for ($i = 0; $i -lt $expectedHimonImageId.Length; $i++) {
    if ($bin[$himonImageIdOffset + $i] -ne $expectedHimonImageId[$i]) {
        throw ("HIMON image identity byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$himonImageIdOffset + $i], $expectedHimonImageId[$i])
    }
}

if ($V1LayoutPreview -or $V1Flashable) {
    for ($address = $v1DirectoryStart; $address -lt $v1DirectoryEndExclusive; $address++) {
        $offset = $bankOffset + ($address - 0x8000)
        if ($bin[$offset] -ne 0xFF) {
            throw ("V1 directory byte {0:X4} is {1:X2}; expected FF" -f $address, $bin[$offset])
        }
    }
}

[byte[]]$vectors = @(
    [byte]($str8Nmi -band 0xFF), [byte](($str8Nmi -shr 8) -band 0xFF),
    [byte]($str8Start -band 0xFF), [byte](($str8Start -shr 8) -band 0xFF),
    [byte]($str8Irq -band 0xFF), [byte](($str8Irq -shr 8) -band 0xFF)
)
for ($i = 0; $i -lt $vectors.Length; $i++) {
    Set-VectorByte -Image $bin -Offset ($bankOffset + 0x7FFA + $i) -Value $vectors[$i]
}

[System.IO.File]::WriteAllBytes($BinPath, $bin)

$bin = [System.IO.File]::ReadAllBytes($BinPath)
if ($bin.Length -ne 32768) {
    throw "Unexpected BIN size $($bin.Length); expected 32768 bytes for 8000-FFFF bank image"
}

$bankHead = $bin[$bankOffset..($bankOffset + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
$asmHead = $null
if ($asmBase -ne $null) {
    $asmHeadOffset = $bankOffset + ($asmBase - 0x8000)
    $asmHead = $bin[$asmHeadOffset..($asmHeadOffset + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
}
$apPackageHead = $null
if ($apPackageStart -ne $null) {
    $apHeadOffset = $bankOffset + ($apPackageStart - 0x8000)
    $apHeadEndOffset = $apHeadOffset + [Math]::Min(0x000F, $apPackageLength - 1)
    $apPackageHead = $bin[$apHeadOffset..$apHeadEndOffset] | ForEach-Object { "{0:X2}" -f $_ }
}
$workerHeadOffset = $bankOffset + ($workerStoreStart - 0x8000)
$workerHead = $bin[$workerHeadOffset..($workerHeadOffset + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
$himonHeadOffset = $bankOffset + ($himonStart - 0x8000)
$himonHead = $bin[$himonHeadOffset..($himonHeadOffset + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
$str8HeadOffset = $bankOffset + ($str8Start - 0x8000)
$str8Head = $bin[$str8HeadOffset..($str8HeadOffset + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
$resetHead = $bin[($bankOffset + ($str8Start - 0x8000))..($bankOffset + ($str8Start - 0x8000) + 0x000F)] | ForEach-Object { "{0:X2}" -f $_ }
$tail = $bin[($bankOffset + 0x7FFA)..($bankOffset + 0x7FFF)] | ForEach-Object { "{0:X2}" -f $_ }

$str8RetiredF006Offset = $bankOffset + ($str8RetiredF006 - 0x8000)
[byte[]]$expectedRetiredF006 = @(0x18, 0x60, 0xEA)
for ($i = 0; $i -lt $expectedRetiredF006.Length; $i++) {
    if ($bin[$str8RetiredF006Offset + $i] -ne $expectedRetiredF006[$i]) {
        throw ("STR8 retired F006 byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$str8RetiredF006Offset + $i], $expectedRetiredF006[$i])
    }
}

$str8RecordServiceOffset = $bankOffset + ($str8RecordService - 0x8000)
[byte[]]$expectedRecordHeader = @(
    0x4C,
    ($str8RecordServiceBody -band 0xFF),
    (($str8RecordServiceBody -shr 8) -band 0xFF),
    0x53, 0x52, 0x01, 0x07
)
for ($i = 0; $i -lt $expectedRecordHeader.Length; $i++) {
    if ($bin[$str8RecordServiceOffset + $i] -ne $expectedRecordHeader[$i]) {
        throw ("STR8 F009 record header byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$str8RecordServiceOffset + $i], $expectedRecordHeader[$i])
    }
}

$str8BankSelectServiceOffset = $bankOffset + ($str8BankSelectService - 0x8000)
[byte[]]$expectedBankSelectService = @(
    0x4C,
    ($str8BankSelectBody -band 0xFF),
    (($str8BankSelectBody -shr 8) -band 0xFF)
)
for ($i = 0; $i -lt $expectedBankSelectService.Length; $i++) {
    if ($bin[$str8BankSelectServiceOffset + $i] -ne $expectedBankSelectService[$i]) {
        throw ("STR8 F010 bank-select jump byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$str8BankSelectServiceOffset + $i], $expectedBankSelectService[$i])
    }
}

Write-Host ("HIMON START/NMI/IRQ/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $himonStart, $himonNmi, $himonIrq, $himonEnd)
Write-Host ("HIMON IMAGE ID           = {0:X4}; {1}" -f $himonImageId, (($expectedHimonImageId | ForEach-Object { "{0:X2}" -f $_ }) -join " "))
Write-Host ("LAYOUT MODE              = {0}" -f $layoutMode)
Write-Host ("HIMON AP IMPORT LINK     = {0:X4}" -f $himonApImportLink)
Write-Host ("STR8 START/NMI/IRQ/END  = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $str8Start, $str8Nmi, $str8Irq, $str8End)
Write-Host ("STR8 WORK/RETIRED AP     = {0:X4}/{1:X4}; F006=CLC RTS NOP" -f $str8WorkerService, $str8RetiredF006)
Write-Host ("STR8 RECORD ENTRY/BODY   = {0:X4}/{1:X4}; ABI 53 52 01 07" -f $str8RecordService, $str8RecordServiceBody)
Write-Host ("STR8 BANK SELECT ROM/RAM = {0:X4}/{1:X4}; A=00-03" -f $str8BankSelectService, $str8BankSelectRam)
Write-Host ("STR8 RECORD RAM          = {0:X4}-{1:X4}; DATA {2:X4}" -f $str8RecordOp, $str8RecordExpected, $str8RecordDataBuffer)
Write-Host ("BANK JUMP RECORD         = {0:X4}-{1:X4}; 42 4A bank/FF; banks 00-{2:X2}" -f $str8BankJumpSig0, $str8BankLastJump, ($str8BankCount - 1))
if ($asmBase -ne $null) {
    Write-Host ("ASM-F2 BASE/START/END  = {0:X4}/{1:X4}/{2:X4}" -f $asmBase, $asmStart, $asmEnd)
}
if ($apPackageStart -ne $null) {
    Write-Host ("AP REPORT STORE/LEN    = {0:X4}/{1:X}" -f $apPackageStart, $apPackageLength)
    Write-Host ("AP REPORT RUN          = AP `${0} `${1}" -f ("{0:X4}" -f $apPackageStart), ("{0:X4}" -f $apPackageBodyBase))
}
Write-Host ("WORKER RUN/STORE/SIZE   = {0:X4}/{1:X4}-{2:X4}/{3:X}" -f $workerRunStart, $workerStoreStart, ($workerStoreStart + $workerSize - 1), $workerSize)
Write-Host ("STR8 RES/WORKER GAP      = {0:X4}-{1:X4}/{2:X} (min {3:X})" -f $str8End, ($workerStoreStart - 1), $str8WorkerGap, $str8WorkerGapMin)
if ($V1LayoutPreview -or $V1Flashable) {
    $v1Label = $(if ($V1Flashable) { "V1 FLASHABLE" } else { "V1 PREVIEW" })
    Write-Host ("{0} WORKER       = {1:X4}-{2:X4}/{3:X} (emitted)" -f $v1Label, $v1WorkerStoreStart, ($v1WorkerStoreEndExclusive - 1), $workerSize)
    Write-Host ("{0} DIRECTORY    = {1:X4}-{2:X4}/{3:X} (all FF)" -f $v1Label, $v1DirectoryStart, ($v1DirectoryEndExclusive - 1), $v1DirectorySize)
} else {
    Write-Host ("V1 PREFLIGHT WORKER       = {0:X4}-{1:X4}/{2:X} (not emitted)" -f $v1WorkerStoreStart, ($v1WorkerStoreEndExclusive - 1), $workerSize)
    Write-Host ("V1 PREFLIGHT DIRECTORY    = {0:X4}-{1:X4}/{2:X} (not emitted)" -f $v1DirectoryStart, ($v1DirectoryEndExclusive - 1), $v1DirectorySize)
}
Write-Host ("V1 PREFLIGHT RESERVE      = {0:X4}-{1:X4}/{2:X} (min {3:X})" -f $str8End, ($v1WorkerStoreStart - 1), $v1WorkerGap, $v1WorkerGapMin)
Write-Host ("V1 PREFLIGHT CONFIG/VECT  = FFF0-FFFF unchanged")
if ($V1LayoutPreview) {
    Write-Host "V1 PREVIEW WARNING        = NO INSTALL S19, TOPWRITER, OR ROM IMAGE STAMP"
}
Write-Host ("Vectors NMI/RESET/IRQ   = {0:X4}/{1:X4}/{2:X4}" -f $str8Nmi, $str8Start, $str8Irq)
Write-Host ("Bank offset             = 0x{0:X5}" -f $bankOffset)
Write-Host ("Bank start @ 8000       = {0}" -f ($bankHead -join " "))
if ($asmHead -ne $null) {
    Write-Host ("ASM-F2 @ {0:X4}          = {1}" -f $asmBase, ($asmHead -join " "))
}
if ($apPackageHead -ne $null) {
    Write-Host ("AP REPORT @ {0:X4}       = {1}" -f $apPackageStart, ($apPackageHead -join " "))
}
Write-Host ("WORKER @ {0:X4}          = {1}" -f $workerStoreStart, ($workerHead -join " "))
Write-Host ("HIMON @ {0:X4}            = {1}" -f $himonStart, ($himonHead -join " "))
Write-Host ("STR8 @ {0:X4}            = {1}" -f $str8Start, ($str8Head -join " "))
Write-Host ("Reset head @ {0:X4}      = {1}" -f $str8Start, ($resetHead -join " "))
Write-Host ("Vectors FFFA-FFFF       = {0}" -f ($tail -join " "))
Write-Host ("BIN                     = {0}" -f $BinPath)

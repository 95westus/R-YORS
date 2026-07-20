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
    [string]$BinPath = "BUILD/bin/himon-str8-rom.bin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$str8Start = Get-SymbolAddress -MapPath $Str8MapPath -Name "START"
$str8WorkerService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RUN_WORKER_SERVICE"
$str8ApLinkService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_AP_IMPORT_LINK_SERVICE"
$str8ApLinkAdapter = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_AP_IMPORT_LINK_SERVICE_BODY"
$str8RecordService = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_ENTRY"
$str8RecordServiceBody = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_BODY"
$str8RecordSignature = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_RECORD_SERVICE_SIGNATURE"
$str8RecordOp = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_OP"
$str8RecordExpected = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_EXPECTED"
$str8RecordDataBuffer = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_REC_DATA_BUF"
$str8Nmi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_IVY_ENTRY_NMI"
$str8Irq = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_IVY_ENTRY_IRQ_MASTER"
$str8End = Get-SymbolAddress -MapPath $Str8MapPath -Name "_END_DATA"

$workerRunStart = Get-SymbolAddress -MapPath $WorkerMapPath -Name "START"
$workerRunEnd = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_WORKER_END"
$workerStateBase = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_STATE_BASE"
$workerStateEnd = Get-SymbolAddress -MapPath $WorkerMapPath -Name "STR8_STATE_END"
$workerSize = $workerRunEnd - $workerRunStart
$workerStoreEndExclusive = 0xFFF0
$workerStoreStart = $workerStoreEndExclusive - $workerSize
$workerStoreSize = $workerSize
$str8WorkerStoreLo = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_STORE_LO"
$str8WorkerStoreHi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_STORE_HI"
$str8WorkerCopyLenLo = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_COPY_LEN_LO"
$str8WorkerCopyLenHi = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_COPY_LEN_HI"
$str8WorkerTraySize = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_TRAY_SIZE"
$str8WorkerTrayEnd = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_WORKER_TRAY_END"
$str8StateBase = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_STATE_BASE"
$str8StateEnd = Get-SymbolAddress -MapPath $Str8MapPath -Name "STR8_STATE_END"
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
if ($str8ApLinkService -ne 0xF006) {
    throw ("STR8 AP link compatibility service is {0:X4}; expected stable entry F006" -f $str8ApLinkService)
}
if ($str8RecordService -ne 0xF009) {
    throw ("STR8 record service is {0:X4}; expected stable entry F009" -f $str8RecordService)
}
if ($str8RecordSignature -ne 0xF00C) {
    throw ("STR8 record-service signature is {0:X4}; expected F00C" -f $str8RecordSignature)
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
if ($str8End -gt $workerStoreStart) {
    throw ("STR8 crosses worker storage at {0:X4}; _END_DATA={1:X4}" -f $workerStoreStart, $str8End)
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

$str8ApServiceOffset = $bankOffset + ($str8ApLinkService - 0x8000)
[byte[]]$expectedApService = @(
    0x4C,
    ($str8ApLinkAdapter -band 0xFF),
    (($str8ApLinkAdapter -shr 8) -band 0xFF)
)
for ($i = 0; $i -lt $expectedApService.Length; $i++) {
    if ($bin[$str8ApServiceOffset + $i] -ne $expectedApService[$i]) {
        throw ("STR8 F006 compatibility jump byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$str8ApServiceOffset + $i], $expectedApService[$i])
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

$str8ApAdapterOffset = $bankOffset + ($str8ApLinkAdapter - 0x8000)
[byte[]]$expectedApAdapter = @(0xA9, 0x03, 0x8D, 0x2F, 0x7E, 0x6C, 0x2D, 0x7E)
for ($i = 0; $i -lt $expectedApAdapter.Length; $i++) {
    if ($bin[$str8ApAdapterOffset + $i] -ne $expectedApAdapter[$i]) {
        throw ("STR8 AP compatibility adapter byte {0} is {1:X2}; expected {2:X2}" -f $i, $bin[$str8ApAdapterOffset + $i], $expectedApAdapter[$i])
    }
}

Write-Host ("HIMON START/NMI/IRQ/END = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $himonStart, $himonNmi, $himonIrq, $himonEnd)
Write-Host ("HIMON AP IMPORT LINK     = {0:X4}" -f $himonApImportLink)
Write-Host ("STR8 START/NMI/IRQ/END  = {0:X4}/{1:X4}/{2:X4}/{3:X4}" -f $str8Start, $str8Nmi, $str8Irq, $str8End)
Write-Host ("STR8 SERVICES WORK/AP    = {0:X4}/{1:X4} -> {2:X4}" -f $str8WorkerService, $str8ApLinkService, $str8ApLinkAdapter)
Write-Host ("STR8 RECORD ENTRY/BODY   = {0:X4}/{1:X4}; ABI 53 52 01 07" -f $str8RecordService, $str8RecordServiceBody)
Write-Host ("STR8 RECORD RAM          = {0:X4}-{1:X4}; DATA {2:X4}" -f $str8RecordOp, $str8RecordExpected, $str8RecordDataBuffer)
if ($asmBase -ne $null) {
    Write-Host ("ASM-F2 BASE/START/END  = {0:X4}/{1:X4}/{2:X4}" -f $asmBase, $asmStart, $asmEnd)
}
if ($apPackageStart -ne $null) {
    Write-Host ("AP REPORT STORE/LEN    = {0:X4}/{1:X}" -f $apPackageStart, $apPackageLength)
    Write-Host ("AP REPORT RUN          = AP `${0} `${1}" -f ("{0:X4}" -f $apPackageStart), ("{0:X4}" -f $apPackageBodyBase))
}
Write-Host ("WORKER RUN/STORE/SIZE   = {0:X4}/{1:X4}-{2:X4}/{3:X}" -f $workerRunStart, $workerStoreStart, ($workerStoreStart + $workerSize - 1), $workerSize)
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

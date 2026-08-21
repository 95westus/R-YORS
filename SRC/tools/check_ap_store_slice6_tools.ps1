param(
    [string]$CatalogS19 = "BUILD/s19/ap-store-v1-slice6-catalog-tool-7000.s19",
    [string]$CatalogMap = "BUILD/s19/ap-store-v1-slice6-catalog-tool-7000.map",
    [string]$CatalogPackage = "BUILD/bin/ap-store-v1-slice6-catalog-tool-7000.ap.bin",
    [string]$CatalogCarrier = "BUILD/s19/ap-store-v1-slice6-catalog-tool-package-4000.s19",
    [string]$PlanS19 = "BUILD/s19/ap-store-v1-slice6-plan-tool-7000.s19",
    [string]$PlanMap = "BUILD/s19/ap-store-v1-slice6-plan-tool-7000.map",
    [string]$PlanPackage = "BUILD/bin/ap-store-v1-slice6-plan-tool-7000.ap.bin",
    [string]$PlanCarrier = "BUILD/s19/ap-store-v1-slice6-plan-tool-package-4000.s19",
    [string]$DeleteS19 = "BUILD/s19/ap-store-v1-slice6-delete-tool-7000.s19",
    [string]$DeleteMap = "BUILD/s19/ap-store-v1-slice6-delete-tool-7000.map",
    [string]$DeletePackage = "BUILD/bin/ap-store-v1-slice6-delete-tool-7000.ap.bin",
    [string]$DeleteCarrier = "BUILD/s19/ap-store-v1-slice6-delete-tool-package-4000.s19",
    [string]$ReaderSource = "ASM/ap-store-v1-slice6-reader.inc",
    [string]$DeleteSource = "ASM/ap-store-v1-slice6-delete.inc",
    [string]$NewestHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-newest-b1-o2-1a00.s19",
    [string]$DeleteHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-delete-b1-o2g1-1a00.s19",
    [string]$ConfirmHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19"
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "AP Store Slice 6 tool check: $Message" }
function U16([byte[]]$Bytes, [int]$Offset) { [int]$Bytes[$Offset] -bor ([int]$Bytes[$Offset + 1] -shl 8) }
function Slice([byte[]]$Bytes, [int]$Offset, [int]$Count) { [byte[]]$r = [byte[]]::new($Count); [Array]::Copy($Bytes, $Offset, $r, 0, $Count); $r }
function Equal([byte[]]$A, [byte[]]$B) { if ($A.Length -ne $B.Length) { return $false }; for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { return $false } }; return $true }
function Read-Map([string]$Path) { $h = @{}; foreach ($line in [IO.File]::ReadLines((Resolve-Path $Path))) { if ($line -match '^\s*([0-9A-Fa-f]{8})\s+(\S+)\s*$') { $h[$matches[2]] = [Convert]::ToInt32($matches[1], 16) } }; $h }
function Read-S19([string]$Path) {
    [byte[]]$memory = [byte[]]::new(65536); [bool[]]$present = [bool[]]::new(65536)
    foreach ($raw in [IO.File]::ReadLines((Resolve-Path $Path))) { $line = $raw.Trim(); if ($line.Length -lt 4 -or $line[0] -ne 'S') { continue }; $ab = switch ($line[1]) { '1' { 2 } '2' { 3 } '3' { 4 } default { 0 } }; if ($ab -eq 0) { continue }; $count = [Convert]::ToInt32($line.Substring(2, 2), 16); $address = [Convert]::ToInt32($line.Substring(4, $ab * 2), 16); $n = $count - $ab - 1; for ($i = 0; $i -lt $n; $i++) { $memory[$address + $i] = [Convert]::ToByte($line.Substring(4 + $ab * 2 + $i * 2, 2), 16); $present[$address + $i] = $true } }
    [pscustomobject]@{ Memory = $memory; Present = $present }
}
function Read-Ap([string]$Path) {
    [byte[]]$bytes = [IO.File]::ReadAllBytes((Resolve-Path $Path)); if ($bytes.Length -lt 5 -or $bytes[0] -ne 0x41 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 2 -or (U16 $bytes 3) -ne $bytes.Length) { Fail "$Path is not AP v2" }
    $sections = @{}; $at = 5; while ($at -lt $bytes.Length) { $tag = [string][char]$bytes[$at]; $n = U16 $bytes ($at + 1); if ($at + 3 + $n -gt $bytes.Length) { Fail "$Path section overflow" }; $sections[$tag] = Slice $bytes ($at + 3) $n; $at += 3 + $n }
    [pscustomobject]@{ Bytes = $bytes; Sections = $sections }
}
function Check-Image([string]$S19Path, [hashtable]$Map, [int]$Limit, [string]$Name) {
    if (-not $Map.ContainsKey('_END_DATA')) { Fail "$Name has no _END_DATA" }; $end = $Map['_END_DATA']; if ($end -gt $Limit) { Fail ('{0} crosses ${1:X4} at ${2:X4}' -f $Name, $Limit, $end) }
    $image = Read-S19 $S19Path; for ($at = 0x7000; $at -lt $end; $at++) { if (-not $image.Present[$at]) { Fail ('{0} gap at ${1:X4}' -f $Name, $at) } }
    [pscustomobject]@{ End = $end; Image = $image }
}
function Check-Entry($Image, [hashtable]$Map, [int]$Address, [string]$Label, [string]$Name) { if (-not $Map.ContainsKey($Label)) { Fail "$Name map lacks $Label" }; if ($Image.Memory[$Address] -ne 0x4C -or (U16 $Image.Memory ($Address + 1)) -ne $Map[$Label]) { Fail ('{0} entry ${1:X4} does not jump to {2}' -f $Name, $Address, $Label) } }
function Check-PackageAndCarrier([string]$PackagePath, [string]$CarrierPath, $Image, [int]$End, [string]$Name) {
    $ap = Read-Ap $PackagePath; [byte[]]$body = $ap.Sections['B']; if ($body.Length -ne ($End - 0x7000) -or -not (Equal $body (Slice $Image.Memory 0x7000 $body.Length))) { Fail "$Name AP BODY differs from linked image" }
    $carrier = Read-S19 $CarrierPath; for ($at = 0; $at -lt 65536; $at++) { $inside = $at -ge 0x4000 -and $at -lt (0x4000 + $ap.Bytes.Length); if ($carrier.Present[$at] -ne $inside) { Fail ('{0} carrier range mismatch at ${1:X4}' -f $Name, $at) }; if ($inside -and $carrier.Memory[$at] -ne $ap.Bytes[$at - 0x4000]) { Fail ('{0} carrier byte mismatch at ${1:X4}' -f $Name, $at) } }
}
function Check-Helper([string]$Path, [int]$Base, [byte[]]$Bytes, [string]$Name) { $helper = Read-S19 $Path; for ($at = 0; $at -lt 65536; $at++) { $inside = $at -ge $Base -and $at -lt ($Base + $Bytes.Length); if ($helper.Present[$at] -ne $inside) { Fail ('{0} range mismatch at ${1:X4}' -f $Name, $at) }; if ($inside -and $helper.Memory[$at] -ne $Bytes[$at - $Base]) { Fail ('{0} byte mismatch at ${1:X4}' -f $Name, $at) } } }

foreach ($path in @($CatalogS19, $CatalogMap, $CatalogPackage, $CatalogCarrier, $PlanS19, $PlanMap, $PlanPackage, $PlanCarrier, $DeleteS19, $DeleteMap, $DeletePackage, $DeleteCarrier, $ReaderSource, $DeleteSource, $NewestHelper, $DeleteHelper, $ConfirmHelper)) { if (-not (Test-Path -LiteralPath $path)) { Fail "missing $path" } }
$catalogMapData = Read-Map $CatalogMap; $planMapData = Read-Map $PlanMap; $deleteMapData = Read-Map $DeleteMap
$catalog = Check-Image $CatalogS19 $catalogMapData 0x7A00 'catalog'
$plan = Check-Image $PlanS19 $planMapData 0x7A00 'planner'
$delete = Check-Image $DeleteS19 $deleteMapData 0x7A00 'delete'
Check-Entry $catalog.Image $catalogMapData 0x7000 'APSD_LIST_BODY' 'catalog'; Check-Entry $catalog.Image $catalogMapData 0x7003 'APSD_VALIDATE_BODY' 'catalog'; Check-Entry $catalog.Image $catalogMapData 0x7006 'APSD_LOAD_BODY' 'catalog'
Check-Entry $plan.Image $planMapData 0x7003 'APSD_DELETE_PLAN_BODY' 'planner'
Check-Entry $delete.Image $deleteMapData 0x7003 'APSD_DELETE_EXECUTE_BODY' 'delete'
if ($plan.Image.Memory[0x7000] -ne 0x60 -or $plan.Image.Memory[0x7001] -ne 0xEA -or $plan.Image.Memory[0x7002] -ne 0xEA) { Fail 'planner safe entry is not RTS/NOP/NOP' }
if ($delete.Image.Memory[0x7000] -ne 0x60 -or $delete.Image.Memory[0x7001] -ne 0xEA -or $delete.Image.Memory[0x7002] -ne 0xEA) { Fail 'delete safe entry is not RTS/NOP/NOP' }
if ($catalogMapData.ContainsKey('APSD_EXEC_FLASH_BYTE')) { Fail 'read-only catalog contains flash mutation code' }
if ($planMapData.ContainsKey('APSD_EXEC_FLASH_BYTE')) { Fail 'read-only planner contains flash mutation code' }
if (-not $deleteMapData.ContainsKey('APSD_EXEC_FLASH_BYTE')) { Fail 'delete executor lacks flash byte-program routine' }
Check-PackageAndCarrier $CatalogPackage $CatalogCarrier $catalog.Image $catalog.End 'catalog'
Check-PackageAndCarrier $PlanPackage $PlanCarrier $plan.Image $plan.End 'planner'
Check-PackageAndCarrier $DeletePackage $DeleteCarrier $delete.Image $delete.End 'delete'
$reader = [IO.File]::ReadAllText((Resolve-Path $ReaderSource)); $writer = [IO.File]::ReadAllText((Resolve-Path $DeleteSource))
foreach ($needle in @('APSD_MODE_FIND', 'APSD_MODE_REPORT', 'APSC_STATUS_INCOMPLETE', 'APSC_STATUS_ALREADY_DELETED', 'APSD_TARGET_CRC_LO')) { if (-not $reader.Contains($needle)) { Fail "catalog lacks $needle" } }
foreach ($needle in @('#APS_RECORD_TOMBSTONE', '#APS_RECORD_COMMIT', '#$C5', '#$9D', '#$1C', '#$81', 'JSR             APSD_EXEC_COMPARE_ROW_CRC', 'JSR             APSD_EXEC_COMPARE_TARGET')) { if (-not $writer.Contains($needle)) { Fail "delete executor lacks $needle" } }
$headerAt = $writer.IndexOf('APSD_EXEC_BUILD_HEADER:'); $programAt = $writer.IndexOf('APSD_EXEC_PROGRAM:'); if ($headerAt -lt 0 -or $programAt -le $headerAt) { Fail 'delete header/program ordering is not inspectable' }
$program = $writer.Substring($programAt); if ($program.IndexOf('JSR             APSD_EXEC_PROGRAM_BYTES') -gt $program.IndexOf('LDA             #APS_RECORD_COMMIT')) { Fail 'commit is not programmed after the header' }
[byte[]]$requestPrefix = 0x9C,0x80,0x7C,0x9C,0x81,0x7C,0x9C,0x82,0x7C,0xA9,0x40,0x8D,0x83,0x7C,0xA9,0x01,0x8D,0x84,0x7C,0xA9,0x0A,0x8D,0x85,0x7C,0xA9,0x02,0x8D,0x86,0x7C,0x9C,0x87,0x7C
[byte[]]$newestBytes = $requestPrefix + @(0x9C,0x88,0x7C,0x9C,0x89,0x7C,0x9C,0x8A,0x7C,0x60)
[byte[]]$deleteBytes = $requestPrefix + @(0xA9,0x01,0x8D,0x88,0x7C,0x9C,0x89,0x7C,0x9C,0x8A,0x7C,0x60)
[byte[]]$confirmBytes = 0xA9,0xA5,0x8D,0x8A,0x7C,0x60
Check-Helper $NewestHelper 0x1A00 $newestBytes 'newest request'; Check-Helper $DeleteHelper 0x1A00 $deleteBytes 'delete request'; Check-Helper $ConfirmHelper 0x1A40 $confirmBytes 'delete confirmation'
Write-Host ('AP Store Slice 6 tools passed: reader=${0:X4}-${1:X4} ({2}) planner=${0:X4}-${3:X4} ({4}) delete=${0:X4}-${5:X4} ({6})' -f 0x7000, ($catalog.End - 1), ($catalog.End - 0x7000), ($plan.End - 1), ($plan.End - 0x7000), ($delete.End - 1), ($delete.End - 0x7000))
Write-Host 'AP Store Slice 6 policy: fixed read-only newest reader; fixed read-only counter/planner; separate CRC-rechecking 21-byte commit-last executor'

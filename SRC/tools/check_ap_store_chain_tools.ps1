param(
    [string]$InstallS19 = "BUILD/s19/ap-store-v1-chain-install-tool-7000.s19",
    [string]$InstallMap = "BUILD/s19/ap-store-v1-chain-install-tool-7000.map",
    [string]$InstallPackage = "BUILD/bin/ap-store-v1-chain-install-tool-7000.ap.bin",
    [string]$InstallCarrier = "BUILD/s19/ap-store-v1-chain-install-tool-package-4000.s19",
    [string]$ReaderS19 = "BUILD/s19/ap-store-v1-chain-reader-tool-7000.s19",
    [string]$ReaderMap = "BUILD/s19/ap-store-v1-chain-reader-tool-7000.map",
    [string]$ReaderPackage = "BUILD/bin/ap-store-v1-chain-reader-tool-7000.ap.bin",
    [string]$ReaderCarrier = "BUILD/s19/ap-store-v1-chain-reader-tool-package-4000.s19",
    [string]$MarkerPackage = "BUILD/bin/ap-store-v1-chain-marker-4000.ap.bin",
    [string]$MarkerCarrier = "BUILD/s19/ap-store-v1-chain-marker-package-3000.s19",
    [string]$SourcePath = "ASM/ap-store-v1-chain-tool.inc",
    [string]$ReaderSourcePath = "ASM/ap-store-v1-chain-reader.inc",
    [string]$ClaimHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-b1sb-1a00.s19",
    [string]$ChainHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-b1-o2g1-1a00.s19",
    [string]$ConfirmHelper = "../DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19"
)

$ErrorActionPreference='Stop'
function Fail([string]$Message){throw "AP Store chain tool check: $Message"}
function U16([byte[]]$B,[int]$O){[int]$B[$O]-bor([int]$B[$O+1]-shl 8)}
function Slice([byte[]]$B,[int]$O,[int]$N){[byte[]]$r=[byte[]]::new($N);[Array]::Copy($B,$O,$r,0,$N);$r}
function Equal([byte[]]$A,[byte[]]$B){if($A.Length-ne$B.Length){return $false};for($i=0;$i-lt$A.Length;$i++){if($A[$i]-ne$B[$i]){return $false}};return $true}
function Read-Map([string]$Path){$h=@{};foreach($line in [IO.File]::ReadLines((Resolve-Path $Path))){if($line-match'^\s*([0-9A-Fa-f]{8})\s+(\S+)\s*$'){$h[$matches[2]]=[Convert]::ToInt32($matches[1],16)}};$h}
function Read-S19([string]$Path){
    [byte[]]$m=[byte[]]::new(65536);[bool[]]$p=[bool[]]::new(65536)
    foreach($raw in [IO.File]::ReadLines((Resolve-Path $Path))){$line=$raw.Trim();if($line.Length-lt4-or$line[0]-ne'S'){continue};$ab=switch($line[1]){'1'{2}'2'{3}'3'{4}default{0}};if($ab-eq0){continue};$count=[Convert]::ToInt32($line.Substring(2,2),16);$addr=[Convert]::ToInt32($line.Substring(4,$ab*2),16);$n=$count-$ab-1;for($i=0;$i-lt$n;$i++){$m[$addr+$i]=[Convert]::ToByte($line.Substring(4+$ab*2+$i*2,2),16);$p[$addr+$i]=$true}}
    [pscustomobject]@{Memory=$m;Present=$p}
}
function Read-Ap([string]$Path){
    [byte[]]$p=[IO.File]::ReadAllBytes((Resolve-Path $Path));if($p.Length-lt5-or$p[0]-ne0x41-or$p[1]-ne0x50-or$p[2]-ne2-or(U16 $p 3)-ne$p.Length){Fail "$Path is not AP v2"};$sections=@{};$tags='';$at=5;while($at-lt$p.Length){$tag=[char]$p[$at];$n=U16 $p ($at+1);if($at+3+$n-gt$p.Length){Fail "$Path section overflow"};$tags+=$tag;$sections[[string]$tag]=Slice $p ($at+3) $n;$at+=3+$n};if($tags-ne'SREIB'){Fail "$Path section order $tags"};[pscustomobject]@{Bytes=$p;Sections=$sections}
}
function Check-Image([string]$S19,[hashtable]$Map,[array]$Entries,[string]$Name){
    if(-not$Map.ContainsKey('_END_DATA')){Fail "$Name missing _END_DATA"};$end=$Map['_END_DATA'];if($end-gt0x7A00){Fail ('{0} crosses $7A00 at ${1:X4}'-f$Name,$end)};$im=Read-S19 $S19;for($at=0;$at-lt65536;$at++){if($im.Present[$at]-and($at-lt0x7000-or$at-ge0x7A00)){Fail ('{0} byte outside tray at ${1:X4}'-f$Name,$at)}};for($at=0x7000;$at-lt$end;$at++){if(-not$im.Present[$at]){Fail ('{0} image gap at ${1:X4}'-f$Name,$at)}};foreach($e in $Entries){$at=$e[0];$target=$Map[$e[1]];if($im.Memory[$at]-ne0x4C-or(U16 $im.Memory ($at+1))-ne$target){Fail ('{0} entry ${1:X4} does not jump to {2}'-f$Name,$at,$e[1])}};[pscustomobject]@{End=$end;Image=$im}
}
function Check-Package([string]$Path,$Image,[int]$End,[string]$Name){$ap=Read-Ap $Path;[byte[]]$body=$ap.Sections['B'];if($body.Length-ne($End-0x7000)-or-not(Equal $body (Slice $Image.Memory 0x7000 $body.Length))){Fail "$Name BODY differs from linked S19"};$ap}
function Check-Carrier([string]$Path,[byte[]]$Bytes,[int]$Base,[string]$Name){$c=Read-S19 $Path;for($at=0;$at-lt65536;$at++){$inside=$at-ge$Base-and$at-lt($Base+$Bytes.Length);if($c.Present[$at]-ne$inside){Fail ('{0} carrier range mismatch at ${1:X4}'-f$Name,$at)};if($inside-and$c.Memory[$at]-ne$Bytes[$at-$Base]){Fail ('{0} carrier byte mismatch at ${1:X4}'-f$Name,$at)}}}
function Check-Helper([string]$Path,[int]$Base,[byte[]]$Bytes,[string]$Name){$h=Read-S19 $Path;for($at=0;$at-lt65536;$at++){$inside=$at-ge$Base-and$at-lt($Base+$Bytes.Length);if($h.Present[$at]-ne$inside){Fail ('{0} helper range mismatch at ${1:X4}'-f$Name,$at)};if($inside-and$h.Memory[$at]-ne$Bytes[$at-$Base]){Fail ('{0} helper byte mismatch at ${1:X4}'-f$Name,$at)}}}

foreach($p in @($InstallS19,$InstallMap,$InstallPackage,$InstallCarrier,$ReaderS19,$ReaderMap,$ReaderPackage,$ReaderCarrier,$MarkerPackage,$MarkerCarrier,$SourcePath,$ReaderSourcePath,$ClaimHelper,$ChainHelper,$ConfirmHelper)){if(-not(Test-Path -LiteralPath $p)){Fail "missing $p"}}
$im=Read-Map $InstallMap;$rm=Read-Map $ReaderMap
$ii=Check-Image $InstallS19 $im @(@(0x7000,'APSC_INSTALL_PLAN_BODY'),@(0x7003,'APSC_INSTALL_EXECUTE_BODY')) 'installer'
$ri=Check-Image $ReaderS19 $rm @(@(0x7000,'APSC_LIST_BODY'),@(0x7003,'APSC_VALIDATE_BODY'),@(0x7006,'APSC_LOAD_BODY')) 'reader'
if(-not$im.ContainsKey('APSC_FLASH_WRITE_BYTE')){Fail 'installer has no flash byte-program routine'}
if($rm.ContainsKey('APSC_FLASH_WRITE_BYTE')){Fail 'reader contains flash byte-program routine'}
$iap=Check-Package $InstallPackage $ii.Image $ii.End 'installer';$rap=Check-Package $ReaderPackage $ri.Image $ri.End 'reader'
Check-Carrier $InstallCarrier $iap.Bytes 0x4000 'installer';Check-Carrier $ReaderCarrier $rap.Bytes 0x4000 'reader'
$marker=Read-Ap $MarkerPackage;if($marker.Bytes.Length-ne4096-or$marker.Sections['B'].Length-ne4050){Fail 'marker is not an exact 4096-byte AP with 4050-byte BODY'}
[byte[]]$prefix=0xA9,0xC5,0x8D,0x01,0x1A,0xA9,0xAC,0x38,0x60;if(-not(Equal (Slice $marker.Sections['B'] 0 9) $prefix)){Fail 'marker execution prefix changed'}
Check-Carrier $MarkerCarrier $marker.Bytes 0x3000 'marker'
[byte[]]$claim=0xA9,0x01,0x8D,0x00,0x7C,0x8D,0x01,0x7C,0xA9,0x0B,0x8D,0x02,0x7C,0x9C,0x03,0x7C,0x60
[byte[]]$request=0xA9,0x00,0x8D,0x80,0x7C,0xA9,0x30,0x8D,0x81,0x7C,0xA9,0x00,0x8D,0x82,0x7C,0xA9,0x40,0x8D,0x83,0x7C,0xA9,0x01,0x8D,0x84,0x7C,0xA9,0x0A,0x8D,0x85,0x7C,0xA9,0x02,0x8D,0x86,0x7C,0x9C,0x87,0x7C,0xA9,0x01,0x8D,0x88,0x7C,0x9C,0x89,0x7C,0x9C,0x8A,0x7C,0x60
[byte[]]$confirm=0xA9,0xA5,0x8D,0x8A,0x7C,0x60
Check-Helper $ClaimHelper 0x1A00 $claim 'CLAIM B1:B';Check-Helper $ChainHelper 0x1A00 $request 'chain request';Check-Helper $ConfirmHelper 0x1A40 $confirm 'chain confirmation'
$source=[IO.File]::ReadAllText((Resolve-Path $SourcePath));$reader=[IO.File]::ReadAllText((Resolve-Path $ReaderSourcePath))
$plan=$source.Substring($source.IndexOf('APSC_INSTALL_PLAN_BODY:'),$source.IndexOf('APSC_INSTALL_EXECUTE_BODY:')-$source.IndexOf('APSC_INSTALL_PLAN_BODY:'))
if($plan.Contains('APSC_FLASH_WRITE_BYTE')-or$plan.Contains('APSC_PROGRAM_ROW')){Fail 'PLAN directly reaches mutation code'}
$exec=$source.Substring($source.IndexOf('APSC_INSTALL_EXECUTE_BODY:'))
foreach($needle in @('STZ             APSC_CONFIRM','JSR             APSC_PARSE_SOURCE','JSR             APSC_SCAN_SECTOR','JSR             APSC_PROGRAM_ROW')){if(-not$exec.Contains($needle)){Fail "EXECUTE lacks $needle"}}
foreach($needle in @('JSR             APSC_SORT_ROWS','JSR             APSC_VALIDATE_CHAIN','JSR             APSC_RECONSTRUCT','JSR             APSC_PARSE_BUFFER')){if(-not$reader.Contains($needle)){Fail "reader lacks $needle"}}
Write-Host ('AP Store Slice 5 tools passed: installer=${0:X4}-${1:X4} ({2}) reader=${0:X4}-${3:X4} ({4}) marker={5}' -f 0x7000,($ii.End-1),($ii.End-0x7000),($ri.End-1),($ri.End-0x7000),$marker.Bytes.Length)
Write-Host 'AP Store Slice 5 policy: read-only PLAN; source/request/CRC recheck; header-payload-commit; bank-wide sorted reconstruction; AP-v2 validate before load'

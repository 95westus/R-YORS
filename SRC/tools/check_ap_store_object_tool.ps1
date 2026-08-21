param(
    [string]$ContractPath = "ASM/ap-store-v1.inc",
    [string]$WorkerContractPath = "ASM/ap-store-v1-worker.inc",
    [string]$SourcePath = "PROOFS/ap-store-v1-sector-tool.asm",
    [string]$S19Path = "BUILD/s19/ap-store-v1-object-tool-7000.s19",
    [string]$MapPath = "BUILD/s19/ap-store-v1-object-tool-7000.map",
    [string]$ToolPackagePath = "BUILD/bin/ap-store-v1-object-tool-7000.ap.bin",
    [string]$ToolCarrierPath = "BUILD/s19/ap-store-v1-object-tool-package-3000.s19",
    [string]$PackagePath = "BUILD/bin/ap-store-v1-marker-3000.ap.bin",
    [string]$PackageCarrierPath = "BUILD/s19/ap-store-v1-marker-package-3000.s19"
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "AP Store object tool check: $Message" }
function Slice([byte[]]$B,[int]$O,[int]$N){[byte[]]$r=[byte[]]::new($N);[Array]::Copy($B,$O,$r,0,$N);$r}
function Equal([byte[]]$A,[byte[]]$B){if($A.Length-ne$B.Length){return $false};for($i=0;$i-lt$A.Length;$i++){if($A[$i]-ne$B[$i]){return $false}};return $true}
function Put16([byte[]]$B,[int]$O,[int]$V){$B[$O]=[byte]($V-band 255);$B[$O+1]=[byte](($V-shr 8)-band 255)}
function Get16([byte[]]$B,[int]$O){[int]$B[$O]-bor([int]$B[$O+1]-shl 8)}
function Put32([byte[]]$B,[int]$O,[uint32]$V){0..3|ForEach-Object{$B[$O+$_]=[byte](([uint64]$V-shr(8*$_))-band 255)}}
function Get32([byte[]]$B,[int]$O){[uint32](([uint64]$B[$O])-bor([uint64]$B[$O+1]-shl 8)-bor([uint64]$B[$O+2]-shl 16)-bor([uint64]$B[$O+3]-shl 24))}
function Fnv32([byte[]]$B){[uint64]$h=2166136261;foreach($v in $B){$h=(($h-bxor[uint64]$v)*[uint64]16777619)-band[uint64]4294967295};[uint32]$h}
function Crc16([byte[]]$B){[int]$c=0xFFFF;foreach($v in $B){$c=$c-bxor([int]$v-shl 8);for($i=0;$i-lt 8;$i++){$c=if($c-band 0x8000){(($c-shl 1)-bxor 0x1021)-band 0xFFFF}else{($c-shl 1)-band 0xFFFF}}};$c}

foreach($p in @($ContractPath,$WorkerContractPath,$SourcePath,$S19Path,$MapPath,$ToolPackagePath,$ToolCarrierPath,$PackagePath,$PackageCarrierPath)){if(-not(Test-Path -LiteralPath $p)){Fail "missing $p"}}
$contract=[IO.File]::ReadAllText((Resolve-Path $ContractPath))
$worker=[IO.File]::ReadAllText((Resolve-Path $WorkerContractPath))
function Equ([string]$Text,[string]$Name){$m=[regex]::Match($Text,'(?m)^'+[regex]::Escape($Name)+'\s+EQU\s+\$([0-9A-Fa-f]+)\s*$');if(-not$m.Success){Fail "missing $Name"};[Convert]::ToInt32($m.Groups[1].Value,16)}
$mapSymbols=@{}
foreach($line in [IO.File]::ReadLines($MapPath)){if($line-match'^\s*([0-9A-Fa-f]{8})\s+(\S+)\s*$'){$mapSymbols[$matches[2]]=[Convert]::ToInt32($matches[1],16)}}
function Sym([string]$Name){if(-not$mapSymbols.ContainsKey($Name)){Fail "map symbol $Name is missing"};[int]$mapSymbols[$Name]}
function Read-S19([string]$Path) {
    [byte[]]$memory=[byte[]]::new(0x10000);[bool[]]$present=[bool[]]::new(0x10000)
    foreach($raw in [IO.File]::ReadLines($Path)){
        $line=$raw.Trim();if($line.Length-lt4-or$line[0]-ne'S'){continue}
        $addressBytes=switch($line[1]){'1'{2}'2'{3}'3'{4}default{0}};if($addressBytes-eq0){continue}
        $count=[Convert]::ToInt32($line.Substring(2,2),16);$address=[Convert]::ToInt32($line.Substring(4,2*$addressBytes),16);$dataBytes=$count-$addressBytes-1
        for($i=0;$i-lt$dataBytes;$i++){$at=$address+$i;if($at-lt0-or$at-ge0x10000){Fail ('S19 address ${0:X}'-f$at)};$memory[$at]=[Convert]::ToByte($line.Substring(4+2*$addressBytes+2*$i,2),16);$present[$at]=$true}
    }
    [pscustomobject]@{Memory=$memory;Present=$present}
}
function Pack40([string]$Name){$codes=@{};for($i=0;$i-lt26;$i++){$codes[[char]([int][char]'A'+$i)]=$i+1};for($i=0;$i-lt10;$i++){$codes[[char]([int][char]'0'+$i)]=$i+27};$codes[[char]'_']=37;$codes[[char]'?']=38;$codes[[char]'.']=39;$u=$Name.ToUpperInvariant();[byte[]]$r=[byte[]]::new(([Math]::Ceiling($u.Length/3.0))*2);$o=0;for($at=0;$at-lt$u.Length;$at+=3){$a=$codes[$u[$at]];$b=if($at+1-lt$u.Length){$codes[$u[$at+1]]}else{0};$c=if($at+2-lt$u.Length){$codes[$u[$at+2]]}else{0};$v=(($a*40)+$b)*40+$c;$r[$o++]=[byte]($v-band255);$r[$o++]=[byte](($v-shr8)-band255)};$r}
foreach($pair in @(
    @('APS_RECORD_HEADER_BYTES',20),@('APS_RECORD_TRAILER_BYTES',1),
    @('APSO_LIST_ENTRY',0x7000),@('APSO_INSTALL_PREPARE_ENTRY',0x7003),
    @('APSO_INSTALL_EXECUTE_ENTRY',0x7006),@('APSO_VALIDATE_ENTRY',0x7009),
    @('APSO_LOAD_ENTRY',0x700C),@('APSO_CARD_BASE',0x7C30),
    @('APSO_SECTOR_BUFFER',0x2000),@('APSO_PACKAGE_BUFFER',0x0A00)
)){
    $text=if($pair[0]-like'APS_RECORD*'){$contract}else{$worker}
    if((Equ $text $pair[0])-ne$pair[1]){Fail "$($pair[0]) changed"}
}

function Test-Ap([byte[]]$P){
    if($P.Length-lt 5-or$P.Length-gt 4096-or$P[0]-ne[byte][char]'A'-or$P[1]-ne[byte][char]'P'-or$P[2]-ne 2-or(Get16 $P 3)-ne$P.Length){return $false}
    $tags='';$sections=@{};$at=5
    while($at-lt$P.Length){if($at+3-gt$P.Length){return $false};$tag=[char]$P[$at];$n=Get16 $P ($at+1);if($at+3+$n-gt$P.Length){return $false};$tags+=$tag;$sections[[string]$tag]=Slice $P ($at+3) $n;$at+=3+$n}
    if($tags-ne'SREIB'-or$sections['S'].Length-ne 11-or$sections['B'].Length-eq 0){return $false}
    $seal=$sections['S'];if((Get16 $seal 5)-ne$sections['B'].Length-or(Get32 $seal 7)-ne(Fnv32 $sections['B'])){return $false}
    return $true
}

$expectedEntries=@(@(0x7000,'APSO_LIST_BODY'),@(0x7003,'APSO_INSTALL_PREPARE_BODY'),@(0x7006,'APSO_INSTALL_EXECUTE_BODY'),@(0x7009,'APSO_VALIDATE_BODY'),@(0x700C,'APSO_LOAD_BODY'))
$endData=Sym '_END_DATA';if($endData-gt0x7A00){Fail ('linked object tool crosses HIMON command buffer: ${0:X4}'-f$endData)}
$image=Read-S19 $S19Path
for($at=0;$at-lt0x10000;$at++){if($image.Present[$at]-and($at-lt0x7000-or$at-ge0x7A00)){Fail ('object S19 byte outside safe transient tray at ${0:X4}'-f$at)}}
for($at=0x7000;$at-lt$endData;$at++){if(-not$image.Present[$at]){Fail ('object S19 image gap at ${0:X4}'-f$at)}}
foreach($entry in $expectedEntries){$at=$entry[0];$target=Sym $entry[1];if($image.Memory[$at]-ne0x4C-or$image.Memory[$at+1]-ne($target-band255)-or$image.Memory[$at+2]-ne(($target-shr8)-band255)){Fail ("entry stub at `${0:X4} does not JMP {1}"-f$at,$entry[1])}}
if($mapSymbols.ContainsKey('APSW_FLASH_ERASE')-or$mapSymbols.ContainsKey('APSW_MUTATE_SECTOR')){Fail 'object image contains Slice 3 erase/format path'}
if(-not$mapSymbols.ContainsKey('APSW_FLASH_WRITE_BYTE')){Fail 'object image lacks append byte-program path'}

$source=[IO.File]::ReadAllText((Resolve-Path $SourcePath))
function Routine([string]$First,[string]$Next){$a=$source.IndexOf($First);$b=$source.IndexOf($Next,$a+1);if($a-lt0-or$b-le$a){Fail "source routine boundary $First/$Next"};$source.Substring($a,$b-$a)}
$prepareSource=Routine 'APSO_INSTALL_PREPARE_BODY:' 'APSO_INSTALL_EXECUTE_BODY:'
if($prepareSource.IndexOf('JSR             APSO_VALIDATE_SOURCE')-gt$prepareSource.IndexOf('JSR             APSO_STAGE_AND_INSPECT')-or$prepareSource.Contains('APSO_PROGRAM_RECORD')){Fail 'PREPARE is not parse-first/read-only'}
$executeSource=Routine 'APSO_INSTALL_EXECUTE_BODY:' 'APSO_VALIDATE_BODY:'
if($executeSource.IndexOf('STZ             APSO_CONFIRM')-gt$executeSource.IndexOf('JSR             APSO_VALIDATE_SOURCE')-or$executeSource.IndexOf('JSR             APSO_VALIDATE_SOURCE')-gt$executeSource.IndexOf('JSR             APSO_PROGRAM_RECORD')){Fail 'EXECUTE confirmation/parse/program order changed'}
$listSource=Routine 'APSO_LIST_BODY:' 'APSO_INSTALL_PREPARE_BODY:'
$validateSource=Routine 'APSO_VALIDATE_BODY:' 'APSO_LOAD_BODY:'
if($listSource.Contains('APSO_PROGRAM_RECORD')-or$validateSource.Contains('APSO_PROGRAM_RECORD')){Fail 'LIST/VALIDATE reaches append directly'}
foreach($handler in @(@('APSO_NOT_MANAGED:','APSO_NOT_CONFIRMED:'),@('APSO_NOT_CONFIRMED:','APSO_MEDIA_CHANGED:'),@('APSO_MEDIA_CHANGED:','APSO_AP_INVALID:'),@('APSO_AP_INVALID:','APSO_RETURN_ERROR:'))){if(-not(Routine $handler[0] $handler[1]).Contains('JMP             APSO_RETURN_ERROR')){Fail "$($handler[0]) does not return status in A"}}

[byte[]]$toolPackage=[IO.File]::ReadAllBytes((Resolve-Path $ToolPackagePath));if(-not(Test-Ap $toolPackage)){Fail 'APOBJ tool package rejected'}
function Test-Carrier([string]$Path,[byte[]]$Expected,[string]$Name){
    $carrier=Read-S19 $Path
    for($at=0;$at-lt0x10000;$at++){
        $inside=$at-ge0x3000-and$at-lt(0x3000+$Expected.Length)
        if($carrier.Present[$at]-ne$inside){Fail ('{0} carrier range mismatch at ${1:X4}'-f$Name,$at)}
        if($inside-and$carrier.Memory[$at]-ne$Expected[$at-0x3000]){Fail ('{0} carrier differs at ${1:X4}'-f$Name,$at)}
    }
}
Test-Carrier $ToolCarrierPath $toolPackage 'APOBJ'
$toolSections=@{};$at=5;while($at-lt$toolPackage.Length){$tag=[char]$toolPackage[$at];$n=Get16 $toolPackage ($at+1);$toolSections[[string]$tag]=Slice $toolPackage ($at+3) $n;$at+=3+$n}
[byte[]]$toolBody=$toolSections['B'];if($toolBody.Length-ne($endData-0x7000)-or-not(Equal $toolBody (Slice $image.Memory 0x7000 $toolBody.Length))){Fail 'APOBJ BODY differs from linked S19'}
[byte[]]$export=$toolSections['E'];[byte[]]$name=[Text.Encoding]::ASCII.GetBytes('APOBJ');[byte[]]$packedName=Pack40 'APOBJ';if($export.Length-ne(9+$packedName.Length)-or$export[0]-ne1-or$export[1]-ne0x81-or(Get16 $export 2)-ne0-or(Get32 $export 4)-ne(Fnv32 $name)-or$export[8]-ne$name.Length-or-not(Equal (Slice $export 9 $packedName.Length) $packedName)){Fail 'APOBJ entry export changed'}

function New-Sector([int]$Bank=1,[int]$Sector=8,[int]$Generation=2){
    [byte[]]$b=[byte[]]::new(4096);for($i=0;$i-lt$b.Length;$i++){$b[$i]=0xFF}
    $b[0]=[byte][char]'A';$b[1]=[byte][char]'S';$b[2]=[byte][char]'1';$b[3]=[byte](($Bank-shl 4)-bor$Sector);Put16 $b 4 $Generation;Put32 $b 6 (Fnv32 (Slice $b 0 6));$b[15]=0xFE;$b
}
function Test-Sector([byte[]]$B,[int]$Bank,[int]$Sector){
    if($B.Length-ne4096-or$B[0]-ne[byte][char]'A'-or$B[1]-ne[byte][char]'S'-or$B[2]-ne[byte][char]'1'-or$B[3]-ne(($Bank-shl 4)-bor$Sector)-or$B[15]-ne0xFE){return $false}
    for($i=10;$i-le14;$i++){if($B[$i]-ne0xFF){return $false}}
    (Get32 $B 6)-eq(Fnv32 (Slice $B 0 6))
}
function New-RecordHeader([int]$Object,[int]$Generation,[byte[]]$Payload){
    [byte[]]$h=[byte[]]::new(20);for($i=0;$i-lt20;$i++){$h[$i]=0xFF}
    $h[0]=[byte][char]'A';$h[1]=[byte][char]'R';$h[2]=1;$h[3]=1;$h[4]=3;$h[5]=0xFF
    Put16 $h 6 $Object;Put16 $h 8 $Generation;Put16 $h 10 0;Put16 $h 12 $Payload.Length;Put32 $h 14 (Fnv32 $Payload);Put16 $h 18 (Crc16 (Slice $h 0 18));$h
}
function Read-Log([byte[]]$Media){
    $rows=@();$at=16
    while($at-lt4096-and$Media[$at]-ne0xFF){
        if($at+20-ge4096){return [pscustomobject]@{Status='CORRUPT';Rows=$rows;Tail=$at}}
        [byte[]]$h=Slice $Media $at 20
        if($h[0]-ne[byte][char]'A'-or$h[1]-ne[byte][char]'R'-or$h[2]-ne1-or$h[3]-ne1-or$h[4]-ne3-or$h[5]-ne0xFF-or(Get16 $h 10)-ne0-or(Get16 $h 18)-ne(Crc16 (Slice $h 0 18))){return [pscustomobject]@{Status='CORRUPT';Rows=$rows;Tail=$at}}
        $n=Get16 $h 12;$commit=$at+20+$n;if($n-eq0-or$commit-ge4096){return [pscustomobject]@{Status='CORRUPT';Rows=$rows;Tail=$at}}
        if($Media[$commit]-ne0xA5){return [pscustomobject]@{Status='STAGED';Rows=$rows;Tail=$at}}
        [byte[]]$p=Slice $Media ($at+20) $n;if((Get32 $h 14)-ne(Fnv32 $p)){return [pscustomobject]@{Status='CORRUPT';Rows=$rows;Tail=$at}}
        $rows+=,[pscustomobject]@{Offset=$at;Object=Get16 $h 6;Generation=Get16 $h 8;Payload=$p};$at=$commit+1
    }
    for($i=$at;$i-lt4096;$i++){if($Media[$i]-ne0xFF){return [pscustomobject]@{Status='CORRUPT';Rows=$rows;Tail=$at}}}
    [pscustomobject]@{Status='OK';Rows=$rows;Tail=$at}
}
function Prepare-Install([byte[]]$Media,[int]$Bank,[int]$Sector,[int]$Object,[int]$Generation,[byte[]]$Package){
    if($Bank-lt0-or$Bank-gt2-or$Sector-lt8-or$Sector-gt15-or$Object-eq0-or$Generation-eq0){return [pscustomobject]@{Status='BAD_REQUEST'}}
    if(-not(Test-Ap $Package)){return [pscustomobject]@{Status='AP_INVALID'}}
    if(-not(Test-Sector $Media $Bank $Sector)){return [pscustomobject]@{Status='NOT_MANAGED'}}
    $log=Read-Log $Media;if($log.Status-ne'OK'){return [pscustomobject]@{Status='LOG_CORRUPT'}}
    foreach($r in $log.Rows){if($r.Object-eq$Object-and$r.Generation-eq$Generation){return [pscustomobject]@{Status='DUPLICATE'}}}
    if($log.Tail+20+$Package.Length-ge4096){return [pscustomobject]@{Status='NO_SPACE'}}
    [pscustomobject]@{Status='PREPARED';Bank=$Bank;Sector=$Sector;Object=$Object;Generation=$Generation;Offset=$log.Tail;Length=$Package.Length;PackageFNV=FNV32 $Package;MediaCRC=Crc16 $Media;Header=New-RecordHeader $Object $Generation $Package}
}
function Execute-Install($Prep,[byte[]]$Media,[byte[]]$Package,[bool]$Confirmed,[int]$Cut=-1){
    [byte[]]$out=$Media.Clone();if(-not$Confirmed){return [pscustomobject]@{Status='NOT_CONFIRMED';Media=$out;Actions=0}}
    if($Prep.Status-ne'PREPARED'-or(Crc16 $Media)-ne$Prep.MediaCRC-or$Package.Length-ne$Prep.Length-or(Fnv32 $Package)-ne$Prep.PackageFNV){return [pscustomobject]@{Status='MEDIA_CHANGED';Media=$out;Actions=0}}
    $again=Prepare-Install $Media $Prep.Bank $Prep.Sector $Prep.Object $Prep.Generation $Package;if($again.Status-ne'PREPARED'-or$again.Offset-ne$Prep.Offset){return [pscustomobject]@{Status='MEDIA_CHANGED';Media=$out;Actions=0}}
    $bytes=@($Prep.Header)+@($Package)+@(0xA5);$actions=0
    for($i=0;$i-lt$bytes.Count;$i++){if($Cut-eq$actions){return [pscustomobject]@{Status='FAULT';Media=$out;Actions=$bytes.Count}};$out[$Prep.Offset+$i]=[byte]$bytes[$i];$actions++}
    [pscustomobject]@{Status='OK';Media=$out;Actions=$actions}
}
function Find-Object([byte[]]$Media,[int]$Object,[int]$Generation){$log=Read-Log $Media;if($log.Status-ne'OK'){return $null};@($log.Rows|Where-Object{$_.Object-eq$Object-and$_.Generation-eq$Generation})|Select-Object -First 1}

[byte[]]$package=[IO.File]::ReadAllBytes((Resolve-Path $PackagePath))
if(-not(Test-Ap $package)){Fail 'golden APMARK package rejected'}
Test-Carrier $PackageCarrierPath $package 'APMARK'
[byte[]]$media=New-Sector 1 8 2
$prep=Prepare-Install $media 1 8 1 1 $package
if($prep.Status-ne'PREPARED'-or$prep.Offset-ne16-or$prep.Length-ne$package.Length){Fail 'golden PREPARE failed'}
$done=Execute-Install $prep $media $package $true
if($done.Status-ne'OK'){Fail 'golden EXECUTE failed'}
$log=Read-Log $done.Media
if($log.Status-ne'OK'-or$log.Rows.Count-ne1-or$log.Rows[0].Object-ne1-or$log.Rows[0].Generation-ne1-or-not(Equal $log.Rows[0].Payload $package)){Fail 'LIST/reconstruction failed'}
if(-not(Test-Ap $log.Rows[0].Payload)){Fail 'stored AP validation failed'}
$bodyTag=[Array]::IndexOf($package,[byte][char]'B',5);if($bodyTag-lt0){Fail 'golden BODY missing'}
$bodyLen=Get16 $package ($bodyTag+1);$body=Slice $package ($bodyTag+3) $bodyLen
if($body.Length-ne9-or$body[0]-ne0xA9-or$body[1]-ne0xA4-or$body[2]-ne0x8D-or$body[3]-ne0x00-or$body[4]-ne0x1A){Fail 'APMARK load marker changed'}

if((Prepare-Install $media 1 8 0 1 $package).Status-ne'BAD_REQUEST'){Fail 'zero object accepted'}
$bad=$package.Clone();$bad[0]=0
if((Prepare-Install $media 1 8 1 1 $bad).Status-ne'AP_INVALID'){Fail 'invalid AP accepted'}
if((Prepare-Install $done.Media 1 8 1 1 $package).Status-ne'DUPLICATE'){Fail 'duplicate object generation accepted'}
$notConfirmed=Execute-Install $prep $media $package $false
if($notConfirmed.Status-ne'NOT_CONFIRMED'-or-not(Equal $media $notConfirmed.Media)){Fail 'confirmation failure mutated media'}
$changed=$media.Clone();$changed[0x400]=0
$stale=Execute-Install $prep $changed $package $true
if($stale.Status-ne'MEDIA_CHANGED'-or-not(Equal $changed $stale.Media)){Fail 'stale media mutated'}

[byte[]]$packed=New-Sector 1 8 2
for($object=1;$object-lt0x1000;$object++){
    $packedPrep=Prepare-Install $packed 1 8 $object 1 $package
    if($packedPrep.Status-eq'NO_SPACE'){break}
    if($packedPrep.Status-ne'PREPARED'){Fail "valid fill failed at object $object"}
    $packedDone=Execute-Install $packedPrep $packed $package $true
    if($packedDone.Status-ne'OK'){Fail "valid fill execute failed at object $object"}
    $packed=$packedDone.Media
}
if($packedPrep.Status-ne'NO_SPACE'){Fail 'valid append log did not reach NO_SPACE'}
$nearly=$done.Media.Clone();for($i=(Read-Log $nearly).Tail;$i-lt4070;$i++){$nearly[$i]=0x00}
if((Prepare-Install $nearly 1 8 2 1 $package).Status-ne'LOG_CORRUPT'){Fail 'dirty tail accepted'}

$faults=0
for($cut=0;$cut-lt$done.Actions;$cut++){
    $fault=Execute-Install $prep $media $package $true $cut
    if($fault.Status-ne'FAULT'){Fail "fault $cut did not stop"}
    $row=Find-Object $fault.Media 1 1
    if($null-ne$row){Fail "object became live before commit at cut $cut"}
    $faults++
}

$banks=@();for($bank=0;$bank-lt4;$bank++){[byte[]]$b=[byte[]]::new(0x8000);for($i=0;$i-lt$b.Length;$i++){$b[$i]=[byte](($bank*29+$i)-band255)};$banks+=,$b}
$off=0;[Array]::Copy($media,0,$banks[1],$off,4096);$before=@();foreach($b in $banks){$before+=,([byte[]]$b.Clone())};[Array]::Copy($done.Media,0,$banks[1],$off,4096)
for($bank=0;$bank-lt4;$bank++){for($i=0;$i-lt0x8000;$i++){if((-not($bank-eq1-and$i-lt4096))-and$banks[$bank][$i]-ne$before[$bank][$i]){Fail "outside-sector mutation B$bank offset $i"}}}

Write-Host "AP Store object tool model passed: package=$($package.Length) object=0001 generation=0001 record-offset=0010 actions=$($done.Actions) fault-cuts=$faults"
Write-Host ("AP Store object golden header: " + ([BitConverter]::ToString($prep.Header)).Replace('-',' '))
Write-Host "AP Store object tool policy: explicit nonzero object id; AP-parse-before-write; FIRST+LAST single-sector record; commit-last; exact reconstruction"

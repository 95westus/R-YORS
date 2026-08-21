param(
    [string]$ContractPath = "ASM/ap-store-v1.inc",
    [string]$WorkerContractPath = "ASM/ap-store-v1-worker.inc"
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "AP Store V1 check: $Message" }
function Put-U16([byte[]]$B,[int]$O,[int]$V){$B[$O]=[byte]($V-band 0xFF);$B[$O+1]=[byte](($V-shr 8)-band 0xFF)}
function Put-U32([byte[]]$B,[int]$O,[uint32]$V){0..3|ForEach-Object{$B[$O+$_]=[byte]((([uint64]$V)-shr(8*$_))-band 0xFF)}}
function Get-U16([byte[]]$B,[int]$O){return [int]$B[$O]-bor([int]$B[$O+1]-shl 8)}
function Get-U32([byte[]]$B,[int]$O){return [uint32](([uint64]$B[$O])-bor([uint64]$B[$O+1]-shl 8)-bor([uint64]$B[$O+2]-shl 16)-bor([uint64]$B[$O+3]-shl 24))}
function Slice([byte[]]$B,[int]$O,[int]$N){[byte[]]$r=New-Object byte[] $N;[Array]::Copy($B,$O,$r,0,$N);return $r}
function Fnv32([byte[]]$B){[uint64]$h=2166136261;foreach($v in $B){$h=(($h-bxor[uint64]$v)*[uint64]16777619)-band[uint64]4294967295};return [uint32]$h}
function Crc16([byte[]]$B){
    [int]$crc=0xFFFF
    foreach($v in $B){$crc=$crc-bxor([int]$v-shl 8);1..8|ForEach-Object{$crc=if($crc-band 0x8000){(($crc-shl 1)-bxor 0x1021)-band 0xFFFF}else{($crc-shl 1)-band 0xFFFF}}}
    return $crc
}

if(-not(Test-Path -LiteralPath $ContractPath)){Fail "missing $ContractPath"}
if(-not(Test-Path -LiteralPath $WorkerContractPath)){Fail "missing $WorkerContractPath"}
$text=[IO.File]::ReadAllText((Resolve-Path $ContractPath))
$workerText=[IO.File]::ReadAllText((Resolve-Path $WorkerContractPath))
function Equ([string]$N){$m=[regex]::Match($text,'(?m)^'+[regex]::Escape($N)+'\s+EQU\s+\$([0-9A-Fa-f]+)\s*$');if(-not$m.Success){Fail "missing $N"};return [Convert]::ToInt32($m.Groups[1].Value,16)}
function Worker-Equ([string]$N){$m=[regex]::Match($workerText,'(?m)^'+[regex]::Escape($N)+'\s+EQU\s+\$([0-9A-Fa-f]+)\s*$');if(-not$m.Success){Fail "missing $N"};return [Convert]::ToInt32($m.Groups[1].Value,16)}
foreach($p in @(@('APS_SECTOR_BYTES',4096),@('APS_SECTOR_HEADER_BYTES',16),@('APS_RECORD_HEADER_BYTES',20),@('APS_RECORD_TRAILER_BYTES',1),@('APS_OBJECT_MAX_CHUNKS',8))){if((Equ $p[0])-ne$p[1]){Fail "$($p[0]) changed"}}
foreach($p in @(@('APSC_CARD_BASE',0x7C80),@('APSC_INSTALL_PLAN_ENTRY',0x7000),@('APSC_INSTALL_EXECUTE_ENTRY',0x7003),@('APSC_LIST_ENTRY',0x7000),@('APSC_VALIDATE_ENTRY',0x7003),@('APSC_LOAD_ENTRY',0x7006),@('APSC_PLAN_ROW_BYTES',10),@('APSC_PLAN_BASE',0x7CB0),@('APSC_RECORD_HEADER_BASE',0x7D00),@('APSC_CARD_END',0x7D3F))){if((Worker-Equ $p[0])-ne$p[1]){Fail "$($p[0]) changed"}}

function New-Sector([int]$Bank,[int]$Sector,[int]$Generation){
    if($Bank-lt 0-or$Bank-gt 2-or$Sector-lt 8-or$Sector-gt 15){Fail 'invalid bank/sector'}
    [byte[]]$b=New-Object byte[] 4096
    for($i=0;$i-lt$b.Length;$i++){$b[$i]=0xFF}
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('AS1'),$b,3)
    $b[3]=[byte](($Bank-shl 4)-bor$Sector);Put-U16 $b 4 $Generation
    Put-U32 $b 6 (Fnv32 (Slice $b 0 6));$b[15]=0xFE;return $b
}
function Test-Sector([byte[]]$B,[int]$Bank,[int]$Sector){
    $location=($Bank-shl 4)-bor$Sector
    if($B.Length-ne 4096-or([Text.Encoding]::ASCII.GetString($B,0,3))-ne'AS1'-or$B[3]-ne$location-or$B[10]-ne 0xFF-or$B[11]-ne 0xFF-or$B[12]-ne 0xFF-or$B[13]-ne 0xFF-or$B[14]-ne 0xFF-or($B[15]-band 0xF8)-ne 0xF8-or($B[15]-band 1)-ne 0){return $false}
    return (Get-U32 $B 6)-eq(Fnv32 (Slice $B 0 6))
}
function Sector-Class([byte[]]$B,[int]$Bank,[int]$Sector){
    $headerFF=$true
    foreach($offset in 0..15){if($B[$offset]-ne 0xFF){$headerFF=$false;break}}
    if($headerFF){return 'HEADER_FF'}
    if($B.Length-ne 4096-or([Text.Encoding]::ASCII.GetString($B,0,3))-ne'AS1'){return 'OPAQUE'}
    $location=($Bank-shl 4)-bor$Sector
    if($B[3]-ne$location-or(Get-U32 $B 6)-ne(Fnv32 (Slice $B 0 6))){return 'CORRUPT'}
    foreach($offset in 10..14){if($B[$offset]-ne 0xFF){return 'CORRUPT'}}
    switch($B[15]){0xFF{return 'STAGED'};0xFE{return 'ACTIVE'};0xFC{return 'RETIRED'};0xFA{return 'BAD'};0xF8{return 'RETIRED_BAD'};default{return 'CORRUPT'}}
}
function Add-Record([byte[]]$B,[int]$At,[int]$Type,[int]$Flags,[int]$Object,[int]$Generation,[int]$Logical,[byte[]]$Payload){
    $end=$At+20+$Payload.Length;if($end-ge 4096){Fail 'record does not fit'}
    $B[$At]=[byte][char]'A';$B[$At+1]=[byte][char]'R';$B[$At+2]=1;$B[$At+3]=[byte]$Type;$B[$At+4]=[byte]$Flags;$B[$At+5]=0xFF
    Put-U16 $B ($At+6) $Object;Put-U16 $B ($At+8) $Generation;Put-U16 $B ($At+10) $Logical;Put-U16 $B ($At+12) $Payload.Length
    Put-U32 $B ($At+14) (Fnv32 $Payload);Put-U16 $B ($At+18) (Crc16 (Slice $B $At 18));[Array]::Copy($Payload,0,$B,$At+20,$Payload.Length);$B[$end]=0xA5
    return $B
}
function Read-Records([byte[]]$B){
    $rows=@();$at=16
    while($at-lt 4096-and$B[$at]-ne 0xFF){
        if($at+20-ge 4096-or$B[$at]-ne[byte][char]'A'-or$B[$at+1]-ne[byte][char]'R'-or$B[$at+2]-ne 1-or$B[$at+5]-ne 0xFF){Fail 'bad record header'}
        $len=Get-U16 $B ($at+12);$end=$at+20+$len;if($end-ge 4096-or$B[$end]-ne 0xA5){break}
        if((Get-U16 $B ($at+18))-ne(Crc16 (Slice $B $at 18))){Fail 'record header CRC'}
        $payload=Slice $B ($at+20) $len;if((Fnv32 $payload)-ne(Get-U32 $B ($at+14))){Fail 'record payload FNV'}
        $rows+=,[pscustomobject]@{Type=$B[$at+3];Flags=$B[$at+4];Object=Get-U16 $B ($at+6);Generation=Get-U16 $B ($at+8);Logical=Get-U16 $B ($at+10);Payload=$payload};$at=$end+1
    }
    return $rows
}

# Golden nonadjacent Bank-2 sector chain.
[byte[]]$ap=[Text.Encoding]::ASCII.GetBytes('AP2-GOLDEN-ENVELOPE')
$s8=New-Sector 2 8 7;$sf=New-Sector 2 15 9
[byte[]]$p0=Slice $ap 0 7;[byte[]]$p1=Slice $ap 7 ($ap.Length-7)
$s8=Add-Record $s8 16 1 1 0x1234 3 0 $p0
$sf=Add-Record $sf 16 1 2 0x1234 3 7 $p1
if($s8[16]-ne[byte][char]'A'-or$sf[16]-ne[byte][char]'A'){Fail 'record encoder did not mutate sector'}
if(-not(Test-Sector $s8 2 8)-or-not(Test-Sector $sf 2 15)){Fail 'golden sector rejected'}
$rows=@()
$rows+=@(Read-Records $s8)
$rows+=@(Read-Records $sf)
$rows=@($rows|Sort-Object Logical)
[byte[]]$joined=@(foreach($row in $rows){foreach($value in $row.Payload){$value}})
$joinedText=[Text.Encoding]::ASCII.GetString($joined)
if($joinedText-ne'AP2-GOLDEN-ENVELOPE'){Fail "nonadjacent reconstruction failed rows=$($rows.Count) bytes=$($joined.Length): $joinedText"}

$bad=Slice $s8 0 4096;$bad[3]=0x18;if(Test-Sector $bad 2 8){Fail 'wrong-bank header accepted'}
$bad=Slice $s8 0 4096;$bad[15]=0xFF;if(Test-Sector $bad 2 8){Fail 'uncommitted header accepted'}
$bad=Slice $s8 0 4096;$bad[15]=0xFC;if(-not(Test-Sector $bad 2 8)){Fail 'retired managed header lost identity'}
$bad=Slice $s8 0 4096;$bad[15]=0xFA;if(-not(Test-Sector $bad 2 8)){Fail 'bad managed header lost identity'}
$bad=Slice $s8 0 4096;$bad[15]=0xF8;if(-not(Test-Sector $bad 2 8)){Fail 'retired/bad managed header lost identity'}
$bad=Slice $s8 0 4096;$bad[15]=0xF6;if(Test-Sector $bad 2 8){Fail 'reserved state bit accepted'}
$bad=Slice $s8 0 4096;$bad[4]=$bad[4]-bxor 1;if(Test-Sector $bad 2 8){Fail 'bad sector FNV accepted'}
$bad=Slice $s8 0 4096;$bad[20]=$bad[20]-bxor 1
try{$null=Read-Records $bad;Fail 'corrupt record accepted'}catch{if($_.Exception.Message-notmatch'record header CRC'){throw}}
$t=New-Sector 0 9 1;$t=Add-Record $t 16 2 0 0x1234 3 0 ([byte[]]@())
if(@(Read-Records $t).Count-ne 1){Fail 'tombstone fixture failed'}

# Bank-3-resident discovery model: exactly 3 banks x 8 candidate sectors.
$media=@{}
for($bank=0;$bank-le 2;$bank++){
    for($sector=8;$sector-le 15;$sector++){
        [byte[]]$blank=New-Object byte[] 4096
        for($i=0;$i-lt$blank.Length;$i++){$blank[$i]=0xFF}
        $media["$bank`:$sector"]=$blank
    }
}
$media['0:8']=New-Sector 0 8 1
$media['1:12']=New-Sector 1 12 2;$media['1:12'][15]=0xFC
$media['2:15']=New-Sector 2 15 3;$media['2:15'][15]=0xFA
$media['0:9'][0]=0x42
$counts=@{}
for($bank=0;$bank-le 2;$bank++){
    for($sector=8;$sector-le 15;$sector++){
        $class=Sector-Class $media["$bank`:$sector"] $bank $sector
        $counts[$class]=1+$counts[$class]
    }
}
if(($counts.Values|Measure-Object -Sum).Sum-ne 24-or$counts['ACTIVE']-ne 1-or$counts['RETIRED']-ne 1-or$counts['BAD']-ne 1-or$counts['OPAQUE']-ne 1-or$counts['HEADER_FF']-ne 20){Fail '24-sector inventory matrix failed'}

$payloadPerEmptySector=4096-16-20-1
if($payloadPerEmptySector-ne 4059-or[Math]::Ceiling(4096/[double]$payloadPerEmptySector)-ne 2){Fail 'capacity calculation changed'}

# Slice 5 model: deterministic allocation across an explicit same-bank sector
# mask, with logical-offset reconstruction and no on-media next pointers.
function Test-ApPackage([byte[]]$P){
    if($P.Length-lt5-or$P.Length-gt4096-or$P[0]-ne[byte][char]'A'-or$P[1]-ne[byte][char]'P'-or$P[2]-ne2-or(Get-U16 $P 3)-ne$P.Length){return $false}
    $tags='';$sections=@{};$at=5
    while($at-lt$P.Length){if($at+3-gt$P.Length){return $false};$tag=[char]$P[$at];$n=Get-U16 $P ($at+1);if($at+3+$n-gt$P.Length){return $false};$tags+=$tag;$sections[[string]$tag]=Slice $P ($at+3) $n;$at+=3+$n}
    if($tags-ne'SREIB'-or$sections['S'].Length-ne11-or$sections['B'].Length-eq0){return $false}
    $seal=$sections['S'];return (Get-U16 $seal 5)-eq$sections['B'].Length-and(Get-U32 $seal 7)-eq(Fnv32 $sections['B'])
}
function Add-ListByte($List,[int]$V){$List.Add([byte]($V-band255))}
function Add-ListWord($List,[int]$V){Add-ListByte $List $V;Add-ListByte $List ($V-shr8)}
function Add-ListBytes($List,[byte[]]$Bytes){foreach($v in $Bytes){Add-ListByte $List $v}}
function Add-ApSection($List,[char]$Tag,[byte[]]$Payload){Add-ListByte $List ([byte]$Tag);Add-ListWord $List $Payload.Length;Add-ListBytes $List $Payload}
function New-ChainPackage {
    [byte[]]$body=[byte[]]::new(4050);for($i=0;$i-lt$body.Length;$i++){$body[$i]=0xEA}
    [byte[]]$code=0xA9,0xC5,0x8D,0x01,0x1A,0xA9,0xAC,0x38,0x60;[Array]::Copy($code,$body,$code.Length)
    [byte[]]$seal=[byte[]]::new(11);$seal[0]=1;Put-U16 $seal 1 0x4000;Put-U16 $seal 3 (0x4000+$body.Length);Put-U16 $seal 5 $body.Length;Put-U32 $seal 7 (Fnv32 $body)
    [byte[]]$rel=0
    [byte[]]$export=1,0x81,0,0,0xED,0xFD,0xBA,0x24,6,0xCD,8,0x1B,9
    [byte[]]$import=0
    $p=New-Object 'System.Collections.Generic.List[byte]';Add-ListBytes $p ([byte[]](0x41,0x50,0x02,0,0));Add-ApSection $p 'S' $seal;Add-ApSection $p 'R' $rel;Add-ApSection $p 'E' $export;Add-ApSection $p 'I' $import;Add-ApSection $p 'B' $body
    [byte[]]$result=$p.ToArray();Put-U16 $result 3 $result.Length;return $result
}
function Inspect-ChainLog([byte[]]$B){
    $rows=@();$at=16
    while($at-lt4096){
        if($B[$at]-eq0xFF){for($i=$at;$i-lt4096;$i++){if($B[$i]-ne0xFF){return [pscustomobject]@{State='CLOSED';Rows=$rows;Tail=$at}}};return [pscustomobject]@{State='OK';Rows=$rows;Tail=$at}}
        if($at+20-ge4096-or$B[$at]-ne[byte][char]'A'-or$B[$at+1]-ne[byte][char]'R'-or$B[$at+2]-ne1-or$B[$at+5]-ne0xFF){return [pscustomobject]@{State='CLOSED';Rows=$rows;Tail=$at}}
        $len=Get-U16 $B ($at+12);$commit=$at+20+$len
        if($len-eq0-or$commit-ge4096-or(Get-U16 $B ($at+18))-ne(Crc16 (Slice $B $at 18))){return [pscustomobject]@{State='CLOSED';Rows=$rows;Tail=$at}}
        if($B[$commit]-ne0xA5){return [pscustomobject]@{State='CLOSED';Rows=$rows;Tail=$at}}
        [byte[]]$payload=Slice $B ($at+20) $len;if((Get-U32 $B ($at+14))-ne(Fnv32 $payload)){return [pscustomobject]@{State='CLOSED';Rows=$rows;Tail=$at}}
        $rows+=,[pscustomobject]@{Offset=$at;Type=$B[$at+3];Flags=$B[$at+4];Object=Get-U16 $B ($at+6);Generation=Get-U16 $B ($at+8);Logical=Get-U16 $B ($at+10);Payload=$payload}
        $at=$commit+1
    }
    return [pscustomobject]@{State='OK';Rows=$rows;Tail=$at}
}
function Copy-ChainMedia($Media){$copy=@{};foreach($key in $Media.Keys){$copy[$key]=[byte[]]$Media[$key].Clone()};return $copy}
function New-ChainHeader([int]$Flags,[int]$Object,[int]$Generation,[int]$Logical,[byte[]]$Payload){
    [byte[]]$h=[byte[]]::new(20);for($i=0;$i-lt20;$i++){$h[$i]=0xFF};$h[0]=[byte][char]'A';$h[1]=[byte][char]'R';$h[2]=1;$h[3]=1;$h[4]=[byte]$Flags
    Put-U16 $h 6 $Object;Put-U16 $h 8 $Generation;Put-U16 $h 10 $Logical;Put-U16 $h 12 $Payload.Length;Put-U32 $h 14 (Fnv32 $Payload);Put-U16 $h 18 (Crc16 (Slice $h 0 18));return $h
}
function Get-ChainPlan($Media,[int]$Bank,[int]$Mask,[int]$Object,[int]$Generation,[byte[]]$Package){
    if($Bank-lt0-or$Bank-gt2-or$Mask-eq0-or$Object-eq0-or$Generation-eq0){return [pscustomobject]@{Status='BAD_REQUEST'}}
    if(-not(Test-ApPackage $Package)){return [pscustomobject]@{Status='AP_INVALID'}}
    $logs=@{};$duplicate=$false
    for($sector=8;$sector-le15;$sector++){
        if(-not$Media.ContainsKey($sector)){continue}
        $class=Sector-Class $Media[$sector] $Bank $sector
        if($class-eq'ACTIVE'){
            $log=Inspect-ChainLog $Media[$sector];$logs[$sector]=$log
            foreach($row in $log.Rows){if($row.Type-eq1-and$row.Object-eq$Object-and$row.Generation-eq$Generation){$duplicate=$true}}
        }
    }
    if($duplicate){return [pscustomobject]@{Status='DUPLICATE'}}
    $rows=@();$remaining=$Package.Length;$logical=0;$capacity=0;$usedMask=0
    for($sector=8;$sector-le15;$sector++){
        $bit=1-shl($sector-8);if(($Mask-band$bit)-eq0){continue}
        if(-not$Media.ContainsKey($sector)-or(Sector-Class $Media[$sector] $Bank $sector)-ne'ACTIVE'){return [pscustomobject]@{Status='NOT_MANAGED';FailSector=$sector}}
        $log=$logs[$sector];if($log.State-ne'OK'){return [pscustomobject]@{Status='LOG_CORRUPT';FailSector=$sector}}
        $available=4096-$log.Tail-21;if($available-lt0){$available=0};$capacity+=$available
        if($remaining-gt0-and$available-gt0){
            $length=[Math]::Min($remaining,$available);$rows+=,[pscustomobject]@{Sector=$sector;Flags=0;Offset=$log.Tail;Logical=$logical;Length=$length;MediaCRC=Crc16 $Media[$sector]}
            $logical+=$length;$remaining-=$length;$usedMask=$usedMask-bor$bit
        }
    }
    if($remaining-gt0){return [pscustomobject]@{Status='NO_SPACE';Capacity=$capacity}}
    if($rows.Count-gt8){return [pscustomobject]@{Status='TOO_MANY'}}
    $rows[0].Flags=$rows[0].Flags-bor1;$rows[$rows.Count-1].Flags=$rows[$rows.Count-1].Flags-bor2
    return [pscustomobject]@{Status='PREPARED';Bank=$Bank;Mask=$Mask;Object=$Object;Generation=$Generation;Length=$Package.Length;PackageFNV=Fnv32 $Package;Capacity=$capacity;UsedMask=$usedMask;Rows=$rows}
}
function Get-ChainActions($Plan,[byte[]]$Package){
    $actions=New-Object 'System.Collections.Generic.List[object]'
    foreach($row in $Plan.Rows){
        [byte[]]$payload=Slice $Package $row.Logical $row.Length;[byte[]]$header=New-ChainHeader $row.Flags $Plan.Object $Plan.Generation $row.Logical $payload;$at=$row.Offset
        foreach($v in $header){$actions.Add([pscustomobject]@{Sector=$row.Sector;Offset=$at++;Value=$v})}
        foreach($v in $payload){$actions.Add([pscustomobject]@{Sector=$row.Sector;Offset=$at++;Value=$v})}
        $actions.Add([pscustomobject]@{Sector=$row.Sector;Offset=$at;Value=0xA5})
    }
    return $actions
}
function Resolve-Chain($Media,[int]$Bank,[int]$Object,[int]$Generation){
    $matches=@()
    for($sector=8;$sector-le15;$sector++){
        if(-not$Media.ContainsKey($sector)-or(Sector-Class $Media[$sector] $Bank $sector)-ne'ACTIVE'){continue}
        $log=Inspect-ChainLog $Media[$sector]
        foreach($row in $log.Rows){if($row.Type-eq1-and$row.Object-eq$Object-and$row.Generation-eq$Generation){$matches+=,[pscustomobject]@{Sector=$sector;Flags=$row.Flags;Logical=$row.Logical;Payload=$row.Payload}}}
    }
    if($matches.Count-eq0){return [pscustomobject]@{Status='NOT_FOUND'}}
    if($matches.Count-gt8){return [pscustomobject]@{Status='TOO_MANY'}}
    if(@($matches|Group-Object Sector|Where-Object Count -gt 1).Count-ne0){return [pscustomobject]@{Status='CONFLICT'}}
    $ordered=@($matches|Sort-Object Logical);$first=@($ordered|Where-Object{$_.Flags-band1});$last=@($ordered|Where-Object{$_.Flags-band2})
    if($first.Count-ne1-or$last.Count-ne1-or$ordered[0].Logical-ne0-or($ordered[0].Flags-band1)-eq0-or($ordered[-1].Flags-band2)-eq0){return [pscustomobject]@{Status='INCOMPLETE'}}
    $joined=New-Object 'System.Collections.Generic.List[byte]';$expected=0
    for($i=0;$i-lt$ordered.Count;$i++){
        $row=$ordered[$i];if(($row.Flags-band0xFC)-ne0){return [pscustomobject]@{Status='CONFLICT'}}
        if($i-gt0-and($row.Flags-band1)){return [pscustomobject]@{Status='CONFLICT'}};if($i-lt$ordered.Count-1-and($row.Flags-band2)){return [pscustomobject]@{Status='CONFLICT'}}
        if($row.Logical-lt$expected){return [pscustomobject]@{Status='CONFLICT'}};if($row.Logical-gt$expected){return [pscustomobject]@{Status='INCOMPLETE'}}
        Add-ListBytes $joined $row.Payload;$expected+=$row.Payload.Length;if($expected-gt4096){return [pscustomobject]@{Status='CONFLICT'}}
    }
    [byte[]]$package=$joined.ToArray();if(-not(Test-ApPackage $package)){return [pscustomobject]@{Status='AP_INVALID'}}
    return [pscustomobject]@{Status='LIVE';Package=$package;Rows=$ordered}
}

[byte[]]$chainPackage=New-ChainPackage
if($chainPackage.Length-ne4096-or-not(Test-ApPackage $chainPackage)){Fail '4096-byte chain AP fixture invalid'}
$chainMedia=@{};for($sector=8;$sector-le15;$sector++){[byte[]]$blank=[byte[]]::new(4096);for($i=0;$i-lt4096;$i++){$blank[$i]=0xFF};$chainMedia[$sector]=$blank}
$chainMedia[8]=New-Sector 1 8 2;$chainMedia[9]=New-Sector 1 9 1;$chainMedia[11]=New-Sector 1 11 1
[byte[]]$oldPayload=[byte[]]::new(55);for($i=0;$i-lt55;$i++){$oldPayload[$i]=[byte]$i};$chainMedia[9]=Add-Record $chainMedia[9] 16 1 3 1 1 0 $oldPayload
$chainPlan=Get-ChainPlan $chainMedia 1 0x0A 2 1 $chainPackage
if($chainPlan.Status-ne'PREPARED'-or$chainPlan.Rows.Count-ne2-or$chainPlan.UsedMask-ne0x0A){Fail 'golden nonadjacent plan failed'}
if($chainPlan.Rows[0].Sector-ne9-or$chainPlan.Rows[0].Offset-ne0x005C-or$chainPlan.Rows[0].Logical-ne0-or$chainPlan.Rows[0].Length-ne0x0F8F-or$chainPlan.Rows[0].Flags-ne1){Fail 'golden first extent changed'}
if($chainPlan.Rows[1].Sector-ne11-or$chainPlan.Rows[1].Offset-ne0x0010-or$chainPlan.Rows[1].Logical-ne0x0F8F-or$chainPlan.Rows[1].Length-ne0x0071-or$chainPlan.Rows[1].Flags-ne2){Fail 'golden last extent changed'}
if((Get-ChainPlan $chainMedia 1 0 2 1 $chainPackage).Status-ne'BAD_REQUEST'){Fail 'zero mask accepted'}
if((Get-ChainPlan $chainMedia 1 0x06 2 1 $chainPackage).Status-ne'NOT_MANAGED'){Fail 'unmanaged selected sector accepted'}
if((Get-ChainPlan $chainMedia 1 0x02 2 1 $chainPackage).Status-ne'NO_SPACE'){Fail 'single-sector overflow accepted'}
if((Get-ChainPlan $chainMedia 2 0x0A 2 1 $chainPackage).Status-ne'NOT_MANAGED'){Fail 'cross-bank sector identity accepted'}
foreach($otherBank in 0,2){
    $other=@{};for($sector=8;$sector-le15;$sector++){[byte[]]$blank=[byte[]]::new(4096);for($i=0;$i-lt4096;$i++){$blank[$i]=0xFF};$other[$sector]=$blank}
    $other[9]=New-Sector $otherBank 9 1;$other[11]=New-Sector $otherBank 11 1;$other[9]=Add-Record $other[9] 16 1 3 1 1 0 $oldPayload
    $otherPlan=Get-ChainPlan $other $otherBank 0x0A 2 1 $chainPackage
    if($otherPlan.Status-ne'PREPARED'-or$otherPlan.Rows.Count-ne2-or$otherPlan.Rows[0].Length-ne0x0F8F-or$otherPlan.Rows[1].Length-ne0x0071){Fail "bank $otherBank chain plan changed"}
}
$changed=Copy-ChainMedia $chainMedia;$changed[11][0x0500]=0
if((Get-ChainPlan $changed 1 0x0A 2 1 $chainPackage).Status-ne'LOG_CORRUPT'){Fail 'changed selected media remained appendable'}

$actions=Get-ChainActions $chainPlan $chainPackage;$faultMedia=Copy-ChainMedia $chainMedia;$faultCuts=0
for($cut=0;$cut-lt$actions.Count;$cut++){
    if((Resolve-Chain $faultMedia 1 2 1).Status-eq'LIVE'){Fail "chain became live before final action at cut $cut"}
    $a=$actions[$cut];$old=$faultMedia[$a.Sector][$a.Offset];if((($old-bor$a.Value)-band255)-ne$old){Fail "non-append write at cut $cut"};$faultMedia[$a.Sector][$a.Offset]=[byte]($old-band$a.Value);$faultCuts++
}
$resolved=Resolve-Chain $faultMedia 1 2 1
if($resolved.Status-ne'LIVE'-or$resolved.Rows.Count-ne2-or$resolved.Package.Length-ne4096-or(Fnv32 $resolved.Package)-ne(Fnv32 $chainPackage)){Fail 'completed chain did not reconstruct exactly'}
if((Get-ChainPlan $faultMedia 1 0x0A 2 1 $chainPackage).Status-ne'DUPLICATE'){Fail 'completed generation was reusable'}
for($sector=8;$sector-le15;$sector++){if($sector-notin@(9,11)){for($i=0;$i-lt4096;$i++){if($faultMedia[$sector][$i]-ne$chainMedia[$sector][$i]){Fail "outside-plan mutation sector $sector offset $i"}}}}
$corrupt=Copy-ChainMedia $faultMedia;$corrupt[11][0x0024]=$corrupt[11][0x0024]-bxor1
if((Resolve-Chain $corrupt 1 2 1).Status-eq'LIVE'){Fail 'corrupt chained payload remained live'}

$gap=Copy-ChainMedia $chainMedia;[byte[]]$g0=Slice $chainPackage 0 100;[byte[]]$g1=Slice $chainPackage 100 ($chainPackage.Length-100);$gap[9]=Add-Record $gap[9] 0x005C 1 1 3 1 0 $g0;$gap[11]=Add-Record $gap[11] 0x0010 1 2 3 1 101 $g1
if((Resolve-Chain $gap 1 3 1).Status-ne'INCOMPLETE'){Fail 'logical gap accepted'}
$overlap=Copy-ChainMedia $chainMedia;$overlap[9]=Add-Record $overlap[9] 0x005C 1 1 4 1 0 $g0;$overlap[11]=Add-Record $overlap[11] 0x0010 1 2 4 1 99 $g1
if((Resolve-Chain $overlap 1 4 1).Status-ne'CONFLICT'){Fail 'logical overlap accepted'}
$repeat=Copy-ChainMedia $chainMedia;[byte[]]$r0=Slice $chainPackage 0 10;[byte[]]$r1=Slice $chainPackage 10 10;$repeat[11]=Add-Record $repeat[11] 0x0010 1 1 5 1 0 $r0;$repeat[11]=Add-Record $repeat[11] (0x0010+21+$r0.Length) 1 2 5 1 10 $r1
if((Resolve-Chain $repeat 1 5 1).Status-ne'CONFLICT'){Fail 'repeated sector accepted'}
$badAp=[byte[]]$chainPackage.Clone();$badAp[0]=0;$badEnvelope=Copy-ChainMedia $chainMedia;[byte[]]$b0=Slice $badAp 0 0x0F8F;[byte[]]$b1=Slice $badAp 0x0F8F 0x0071;$badEnvelope[9]=Add-Record $badEnvelope[9] 0x005C 1 1 6 1 0 $b0;$badEnvelope[11]=Add-Record $badEnvelope[11] 0x0010 1 2 6 1 0x0F8F $b1
if((Resolve-Chain $badEnvelope 1 6 1).Status-ne'AP_INVALID'){Fail 'invalid reconstructed AP accepted'}
$tooMany=@{};for($sector=8;$sector-le15;$sector++){$tooMany[$sector]=New-Sector 1 $sector 1;$flags=if($sector-eq8){1}elseif($sector-eq15){2}else{0};$tooMany[$sector]=Add-Record $tooMany[$sector] 16 1 $flags 7 1 ($sector-8) ([byte[]]@($sector))};$tooMany[8]=Add-Record $tooMany[8] 38 1 0 7 1 8 ([byte[]]@(0xEE))
if((Resolve-Chain $tooMany 1 7 1).Status-ne'TOO_MANY'){Fail 'more than eight chunks accepted'}

Write-Host "AP Store V1 check passed: AS1 packed-location FNV32 active-low-state candidates=24 active=1 retired=1 bad=1 opaque=1 header-ff=20"
Write-Host "AP Store V1 capacity: sector=4096 header=16 record-overhead=21 empty-payload=$payloadPerEmptySector AP-max=4096 min-sectors=2"
Write-Host ("AP Store V1 chain model passed: mask=0A used=0A sectors=09,0B chunks=2 lengths=0F8F,0071 actions={0} fault-cuts={0}" -f $faultCuts)

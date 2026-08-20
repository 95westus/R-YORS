param([string]$ContractPath = "ASM/ap-store-v1.inc")

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
$text=[IO.File]::ReadAllText((Resolve-Path $ContractPath))
function Equ([string]$N){$m=[regex]::Match($text,'(?m)^'+[regex]::Escape($N)+'\s+EQU\s+\$([0-9A-Fa-f]+)\s*$');if(-not$m.Success){Fail "missing $N"};return [Convert]::ToInt32($m.Groups[1].Value,16)}
foreach($p in @(@('APS_SECTOR_BYTES',4096),@('APS_SECTOR_HEADER_BYTES',16),@('APS_RECORD_HEADER_BYTES',20),@('APS_RECORD_TRAILER_BYTES',1),@('APS_OBJECT_MAX_CHUNKS',8))){if((Equ $p[0])-ne$p[1]){Fail "$($p[0]) changed"}}

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
    $erased=$true
    foreach($value in $B){if($value-ne 0xFF){$erased=$false;break}}
    if($erased){return 'ERASED'}
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
if(($counts.Values|Measure-Object -Sum).Sum-ne 24-or$counts['ACTIVE']-ne 1-or$counts['RETIRED']-ne 1-or$counts['BAD']-ne 1-or$counts['OPAQUE']-ne 1-or$counts['ERASED']-ne 20){Fail '24-sector inventory matrix failed'}

$payloadPerEmptySector=4096-16-20-1
if($payloadPerEmptySector-ne 4059-or[Math]::Ceiling(4096/[double]$payloadPerEmptySector)-ne 2){Fail 'capacity calculation changed'}
Write-Host "AP Store V1 check passed: AS1 packed-location FNV32 active-low-state candidates=24 active=1 retired=1 bad=1 opaque=1 erased=20"
Write-Host "AP Store V1 capacity: sector=4096 header=16 record-overhead=21 empty-payload=$payloadPerEmptySector AP-max=4096 min-sectors=2"
